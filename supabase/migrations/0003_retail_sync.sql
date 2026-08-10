-- ============================================================================
-- Ms Beau Ave — Phase 3: Retail sync & cash controls (Spec.md §3.2, §6.6, §8)
--
--   * POS webhook ingestion — idempotent by POS event id, so queue-and-retry
--     delivery can never deduct the Retail Shelf pool twice
--   * Replenishment alerts when the shelf pool hits a per-SKU minimum
--   * Returns/exchanges with restock / damaged / tester dispositions
--   * Tester & damaged product logs, signed per shift, deducting shelf stock
--   * Blind cash drops: cashiers submit counts without seeing the POS total;
--     finance reconciles same-day; variances beyond threshold auto-flag and
--     repeat offenders surface on the finance dashboard
--
-- The POS webhook receiver authenticates as the retail channel
-- (app_role = RETAIL_CASHIER, app.actor = 'POS_WEBHOOK'): the adapter is the
-- point-of-sale acting remotely, so it gets exactly the cashier surface.
-- ============================================================================

alter table products
  add column if not exists retail_min_qty int not null default 0
  check (retail_min_qty >= 0);

-- ---------------------------------------------------------------------------
-- POS event ingestion (§3.2, §8 offline tolerance)
-- ---------------------------------------------------------------------------
create table if not exists pos_events (
  event_id    text primary key,        -- POS-side id: replays are no-ops
  payload     jsonb,
  order_id    bigint references orders (id),
  received_at timestamptz not null default now()
);

create or replace function ingest_pos_sale(
  p_event_id text,
  p_lines    jsonb,
  p_payload  jsonb default null
) returns bigint
language plpgsql security definer as $$
declare
  v_existing bigint;
  v_order_id bigint;
begin
  perform assert_role('OWNER_ADMIN','RETAIL_CASHIER');

  -- Idempotency: claim the event id first; a concurrent or replayed delivery
  -- sees the existing row and returns the original order untouched.
  insert into pos_events (event_id, payload)
  values (p_event_id, p_payload)
  on conflict (event_id) do nothing;
  if not found then
    select order_id into v_existing from pos_events where event_id = p_event_id;
    return v_existing;
  end if;

  v_order_id := place_order('RETAIL', p_lines);
  perform fulfill_order(v_order_id);   -- a POS sale has already left the store

  update pos_events set order_id = v_order_id where event_id = p_event_id;
  return v_order_id;
end;
$$;

-- Daily ingest totals — reconcile against the POS's own Z-report to detect
-- missed webhook deliveries (§8).
create or replace view pos_daily_ingest as
select o.created_at::date as business_date,
       count(*)           as orders_ingested,
       sum(o.total)       as total_ingested
  from pos_events e
  join orders o on o.id = e.order_id
 group by o.created_at::date;

-- ---------------------------------------------------------------------------
-- Replenishment alerts (§3.2): shelf pool at or below its minimum.
-- ---------------------------------------------------------------------------
create or replace view retail_replenishment_alerts as
select p.sku, p.name, p.retail_min_qty,
       coalesce(sum(sl.qty_on_hand - sl.qty_committed), 0)::int as shelf_available
  from products p
  left join batches b on b.sku = p.sku and b.expiry_date > current_date
  left join stock_ledger sl on sl.batch_id = b.id and sl.pool = 'RETAIL_SHELF'
 where p.active
 group by p.sku, p.name, p.retail_min_qty
having coalesce(sum(sl.qty_on_hand - sl.qty_committed), 0) <= p.retail_min_qty;

-- ---------------------------------------------------------------------------
-- Returns / exchanges and tester/damage logs (§3.2)
-- ---------------------------------------------------------------------------
create table if not exists retail_returns (
  id          bigint generated always as identity primary key,
  order_id    bigint not null references orders (id),
  sku         text   not null references products (sku),
  batch_id    bigint not null references batches (id),
  qty         int    not null check (qty > 0),
  reason      text   not null,
  disposition text   not null check (disposition in ('RESTOCK','DAMAGED','TESTER')),
  actor       text   not null default app_actor(),
  ts          timestamptz not null default now()
);

create table if not exists tester_logs (
  id        bigint generated always as identity primary key,
  log_date  date not null default current_date,
  shift     text not null,
  sku       text not null references products (sku),
  batch_id  bigint references batches (id),
  qty       int  not null check (qty > 0),
  reason    text not null,          -- TESTER | DAMAGED
  signed_by text not null,
  ts        timestamptz not null default now()
);

create or replace function process_retail_return(
  p_order_id    bigint,
  p_sku         text,
  p_batch_id    bigint,
  p_qty         int,
  p_reason      text,
  p_disposition text,
  p_signed_by   text default null
) returns void
language plpgsql security definer as $$
declare
  v_sold int;
  v_returned int;
begin
  perform assert_role('OWNER_ADMIN','RETAIL_CASHIER');

  select coalesce(sum(qty), 0) into v_sold
    from order_lines
   where order_id = p_order_id and sku = p_sku and batch_id = p_batch_id;
  select coalesce(sum(qty), 0) into v_returned
    from retail_returns
   where order_id = p_order_id and sku = p_sku and batch_id = p_batch_id;
  if p_qty + v_returned > v_sold then
    raise exception 'return qty % exceeds remaining sold qty % for order %',
      p_qty, v_sold - v_returned, p_order_id;
  end if;

  insert into retail_returns (order_id, sku, batch_id, qty, reason, disposition)
  values (p_order_id, p_sku, p_batch_id, p_qty, p_reason, p_disposition);

  if p_disposition = 'RESTOCK' then
    insert into stock_ledger (batch_id, pool, qty_on_hand)
    values (p_batch_id, 'RETAIL_SHELF', p_qty)
    on conflict (batch_id, pool)
    do update set qty_on_hand = stock_ledger.qty_on_hand + excluded.qty_on_hand;
    insert into stock_movements (batch_id, from_pool, to_pool, qty, reason)
    values (p_batch_id, null, 'RETAIL_SHELF', p_qty, 'RETAIL_RETURN_RESTOCK');
  else
    -- Damaged or converted to tester: logged and signed, never restocked.
    insert into tester_logs (shift, sku, batch_id, qty, reason, signed_by)
    values ('RETURNS', p_sku, p_batch_id, p_qty, p_disposition,
            coalesce(p_signed_by, app_actor()));
  end if;
end;
$$;

-- Shelf stock converted to tester / written off as damaged during a shift.
create or replace function log_tester(
  p_sku       text,
  p_batch_id  bigint,
  p_qty       int,
  p_shift     text,
  p_reason    text,
  p_signed_by text
) returns void
language plpgsql security definer as $$
declare
  v_row stock_ledger%rowtype;
begin
  perform assert_role('OWNER_ADMIN','RETAIL_CASHIER');
  if p_reason not in ('TESTER','DAMAGED') then
    raise exception 'reason must be TESTER or DAMAGED';
  end if;

  select * into v_row from stock_ledger
   where batch_id = p_batch_id and pool = 'RETAIL_SHELF' for update;
  if not found or v_row.qty_on_hand - v_row.qty_committed < p_qty then
    raise exception 'INSUFFICIENT_STOCK: batch % has fewer than % uncommitted shelf unit(s)',
      p_batch_id, p_qty using errcode = 'P0002';
  end if;

  update stock_ledger set qty_on_hand = qty_on_hand - p_qty
   where batch_id = p_batch_id and pool = 'RETAIL_SHELF';
  insert into stock_movements (batch_id, from_pool, to_pool, qty, reason)
  values (p_batch_id, 'RETAIL_SHELF', null, p_qty, p_reason);
  insert into tester_logs (shift, sku, batch_id, qty, reason, signed_by)
  values (p_shift, p_sku, p_batch_id, p_qty, p_reason, p_signed_by);
end;
$$;

-- ---------------------------------------------------------------------------
-- Blind cash drops & same-day reconciliation (§6.6)
-- The cashier's submission stores only the declared count. The POS total and
-- variance stay NULL until finance reconciles — and cashiers can never read
-- them (RLS below exposes only their own declared rows).
-- ---------------------------------------------------------------------------
create table if not exists cash_drops (
  id              bigint generated always as identity primary key,
  business_date   date not null default current_date,
  cashier         text not null default app_actor(),
  declared_amount numeric(12,2) not null check (declared_amount >= 0),
  pos_total       numeric(12,2),
  variance        numeric(12,2),
  flagged         boolean,
  submitted_at    timestamptz not null default now(),
  reconciled_at   timestamptz,
  unique (business_date, cashier)
);

drop trigger if exists trg_cash_drops_audit on cash_drops;
create trigger trg_cash_drops_audit
  after insert or update or delete on cash_drops
  for each row execute function audit_row();

create or replace function submit_cash_drop(
  p_declared      numeric,
  p_business_date date default current_date
) returns bigint
language plpgsql security definer as $$
declare
  v_id bigint;
begin
  perform assert_role('OWNER_ADMIN','RETAIL_CASHIER');
  insert into cash_drops (business_date, declared_amount)
  values (p_business_date, p_declared)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function reconcile_cash_drops(
  p_business_date date default current_date,
  p_threshold     numeric default 100
) returns int
language plpgsql security definer as $$
declare
  v_count int := 0;
  v_drop  record;
  v_total numeric(12,2);
begin
  perform assert_role('OWNER_ADMIN','HR_FINANCE');

  for v_drop in
    select * from cash_drops
     where business_date = p_business_date and reconciled_at is null
       for update
  loop
    select coalesce(sum(o.total), 0) into v_total
      from orders o
     where o.channel = 'RETAIL'
       and o.status = 'FULFILLED'
       and o.created_by = v_drop.cashier
       and o.created_at::date = p_business_date;

    update cash_drops
       set pos_total     = v_total,
           variance      = v_drop.declared_amount - v_total,
           flagged       = abs(v_drop.declared_amount - v_total) > p_threshold,
           reconciled_at = now()
     where id = v_drop.id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- Repeat discrepancies per cashier surface on the finance dashboard (§6.6).
create or replace view cashier_variance_watch as
select cashier,
       count(*)                        as flagged_drops_90d,
       sum(variance)                   as net_variance_90d,
       max(business_date)              as last_flagged_date
  from cash_drops
 where flagged and business_date > current_date - 90
 group by cashier
having count(*) >= 2;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table pos_events     enable row level security;
alter table retail_returns enable row level security;
alter table tester_logs    enable row level security;
alter table cash_drops     enable row level security;

create policy pos_events_staff_read on pos_events for select
  using (app_role() in ('OWNER_ADMIN','RETAIL_CASHIER','HR_FINANCE'));
create policy retail_returns_read on retail_returns for select
  using (app_role() in ('OWNER_ADMIN','RETAIL_CASHIER','HR_FINANCE'));
create policy tester_logs_read on tester_logs for select
  using (app_role() in ('OWNER_ADMIN','RETAIL_CASHIER','HR_FINANCE'));

-- Blind drops: finance/admin see everything; cashiers see only their own
-- declared amounts, and never the POS total or variance columns (exposed
-- through the my_cash_drops view below).
create policy cash_drops_finance_read on cash_drops for select
  using (app_role() in ('OWNER_ADMIN','HR_FINANCE'));

create or replace view my_cash_drops as
select business_date, declared_amount, submitted_at,
       (reconciled_at is not null) as reconciled
  from cash_drops
 where cashier = app_actor();

grant select on all tables in schema public to app_client;
grant select on pos_daily_ingest, retail_replenishment_alerts,
                cashier_variance_watch, my_cash_drops to app_client;
grant execute on all functions in schema public to app_client;

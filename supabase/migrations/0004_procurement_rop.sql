-- ============================================================================
-- Ms Beau Ave — Phase 4: Procurement & reorder-point engine
-- (Spec.md §3.1, §3.4, §6.3, §9)
--
--   * Vendors with negotiated terms; PO lifecycle DRAFT → SENT → IN_TRANSIT →
--     CUSTOMS → RECEIVED with customs/FDA tracking and actual-lead-time capture
--     (lead time includes customs + FDA, not just shipping)
--   * ROP engine, exactly §6.3:
--       Safety stock = (Max daily sales × Max lead time) − (Avg daily × Avg lead)
--       ROP          = (Avg daily sales × Avg lead time) + Safety stock
--   * Reorder alerts with the shelf-life cap: never suggest more than sells
--     before the batch falls under the 12-months-remaining reseller floor
--   * ABC segmentation from revenue (top ~80% cumulative revenue = A)
--   * Aging-stock report: batches within 6 months of expiry (clearance playbook)
--   * Cycle counting with variance capture
--   * Quarterly ROP recalculation prompts
-- ============================================================================

create table if not exists vendors (
  id                 bigint generated always as identity primary key,
  name               text not null,
  moq_terms          text,
  exclusivity_notes  text,
  avg_lead_time_days int,
  max_lead_time_days int,
  active             boolean not null default true,
  created_at         timestamptz not null default now()
);

create table if not exists purchase_orders (
  id               bigint generated always as identity primary key,
  vendor_id        bigint not null references vendors (id),
  status           text not null default 'DRAFT'
                   check (status in ('DRAFT','SENT','IN_TRANSIT','CUSTOMS','RECEIVED','CANCELLED')),
  customs_status   text,
  fda_status       text,      -- FDA notification paperwork starts pre-shipment (§3.4)
  expected_arrival date,
  sent_at          date,
  received_at      date,
  lead_time_actual int,       -- days, sent → received: shipping + customs + FDA
  notes            text,
  created_by       text not null default app_actor(),
  created_at       timestamptz not null default now()
);

create table if not exists po_lines (
  id         bigint generated always as identity primary key,
  po_id      bigint not null references purchase_orders (id) on delete cascade,
  sku        text   not null references products (sku),
  qty        int    not null check (qty > 0),
  unit_cost  numeric(12,2) not null default 0
);

drop trigger if exists trg_purchase_orders_audit on purchase_orders;
create trigger trg_purchase_orders_audit
  after insert or update or delete on purchase_orders
  for each row execute function audit_row();

-- Inbound receipts now link back to their PO.
alter table batches
  drop constraint if exists batches_vendor_po_fk,
  add constraint batches_vendor_po_fk
    foreign key (vendor_po_id) references purchase_orders (id);

create or replace function advance_po_status(
  p_po_id  bigint,
  p_status text,
  p_on     date default current_date
) returns void
language plpgsql security definer as $$
declare
  v_po purchase_orders%rowtype;
begin
  perform assert_role('OWNER_ADMIN','WAREHOUSE');
  select * into v_po from purchase_orders where id = p_po_id for update;
  if not found then
    raise exception 'unknown PO %', p_po_id;
  end if;

  update purchase_orders
     set status      = p_status,
         sent_at     = case when p_status = 'SENT' then p_on else sent_at end,
         received_at = case when p_status = 'RECEIVED' then p_on else received_at end,
         lead_time_actual = case
           when p_status = 'RECEIVED' and coalesce(sent_at, case when p_status = 'SENT' then p_on end) is not null
           then p_on - sent_at
           else lead_time_actual end
   where id = p_po_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- ROP engine (§6.3). rop_formula is pure — the spec's worked example is a
-- unit test: avg 10/day, max 15/day, avg lead 60d, max 75d
--   → safety stock 525, ROP 1,125.
-- ---------------------------------------------------------------------------
create or replace function rop_formula(
  p_avg_daily numeric, p_max_daily numeric,
  p_avg_lead  numeric, p_max_lead  numeric,
  out safety_stock numeric, out rop numeric
) returns record
language sql immutable as $$
  select (p_max_daily * p_max_lead) - (p_avg_daily * p_avg_lead) as safety_stock,
         (p_avg_daily * p_avg_lead)
           + ((p_max_daily * p_max_lead) - (p_avg_daily * p_avg_lead)) as rop;
$$;

create table if not exists rop_settings (
  sku             text primary key references products (sku),
  avg_daily_sales numeric not null check (avg_daily_sales >= 0),
  max_daily_sales numeric not null check (max_daily_sales >= avg_daily_sales),
  avg_lead_days   numeric not null check (avg_lead_days >= 0),
  max_lead_days   numeric not null check (max_lead_days >= avg_lead_days),
  safety_stock    numeric not null,
  rop             numeric not null,
  last_recalc     timestamptz not null default now()
);

create or replace function set_rop(
  p_sku       text,
  p_avg_daily numeric, p_max_daily numeric,
  p_avg_lead  numeric, p_max_lead  numeric
) returns rop_settings
language plpgsql security definer as $$
declare
  v_calc record;
  v_row  rop_settings;
begin
  perform assert_role('OWNER_ADMIN','WAREHOUSE');
  select * into v_calc from rop_formula(p_avg_daily, p_max_daily, p_avg_lead, p_max_lead);

  insert into rop_settings (sku, avg_daily_sales, max_daily_sales, avg_lead_days,
                            max_lead_days, safety_stock, rop, last_recalc)
  values (p_sku, p_avg_daily, p_max_daily, p_avg_lead, p_max_lead,
          v_calc.safety_stock, v_calc.rop, now())
  on conflict (sku) do update
    set avg_daily_sales = excluded.avg_daily_sales,
        max_daily_sales = excluded.max_daily_sales,
        avg_lead_days   = excluded.avg_lead_days,
        max_lead_days   = excluded.max_lead_days,
        safety_stock    = excluded.safety_stock,
        rop             = excluded.rop,
        last_recalc     = now()
  returning * into v_row;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- Reorder alerts (§6.3). Suggested order qty is capped by the shelf-life
-- rule: resellers refuse stock under 12 months remaining, so a new batch is
-- sellable for (shelf_life_months × 30 − 365) days at avg daily sales.
-- ---------------------------------------------------------------------------
create or replace view reorder_alerts as
with sellable as (
  select b.sku, coalesce(sum(sl.qty_on_hand - sl.qty_committed), 0)::int as stock
    from batches b
    join stock_ledger sl on sl.batch_id = b.id
   where b.expiry_date > current_date
   group by b.sku
)
select p.sku, p.name, p.abc_class,
       coalesce(s.stock, 0)                as sellable_stock,
       r.rop, r.safety_stock,
       greatest(r.rop - coalesce(s.stock, 0), 0)::numeric as shortfall,
       least(
         greatest(r.rop - coalesce(s.stock, 0), 0),
         greatest(r.avg_daily_sales * (coalesce(p.shelf_life_months, 24) * 30 - 365), 0)
       )::numeric as suggested_order_qty
  from products p
  join rop_settings r on r.sku = p.sku
  left join sellable s on s.sku = p.sku
 where p.active
   and coalesce(s.stock, 0) <= r.rop;

-- Quarterly recalculation prompt (§6.3): a ROP set during a viral spike must
-- not persist.
create or replace view rop_recalc_due as
select sku, last_recalc, now() - last_recalc as age
  from rop_settings
 where last_recalc < now() - interval '90 days';

-- ---------------------------------------------------------------------------
-- ABC segmentation (§6.3): cumulative revenue share over a trailing window,
-- top 80% = A, next 15% = B, remainder (and no-sales SKUs) = C.
-- ---------------------------------------------------------------------------
create or replace function recompute_abc(p_days int default 90) returns int
language plpgsql security definer as $$
declare
  v_count int;
begin
  perform assert_role('OWNER_ADMIN');

  with revenue as (
    select ol.sku, sum(ol.qty * ol.unit_price - ol.discount) as rev
      from order_lines ol
      join orders o on o.id = ol.order_id
     where o.status = 'FULFILLED'
       and o.created_at > now() - make_interval(days => p_days)
     group by ol.sku
  ),
  ranked as (
    select sku, rev,
           sum(rev) over (order by rev desc, sku) / nullif(sum(rev) over (), 0) as cum_share
      from revenue
  ),
  classed as (
    select p.sku,
           case
             when r.cum_share is null then 'C'
             when r.cum_share <= 0.80 then 'A'
             when r.cum_share <= 0.95 then 'B'
             else 'C'
           end as cls
      from products p
      left join ranked r on r.sku = p.sku
     where p.active
  )
  update products p
     set abc_class = c.cls
    from classed c
   where c.sku = p.sku
     and p.abc_class is distinct from c.cls;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- Aging stock (§3.1, §6.4): everything inside the 6-month expiry window,
-- valued so the owner dashboard can show ₱ at risk. Feeds the clearance
-- playbook (bundles, reseller flash discounts, tester conversion).
-- ---------------------------------------------------------------------------
create or replace view aging_stock_alerts as
select b.sku, p.name, b.id as batch_id, b.batch_number, b.expiry_date,
       (b.expiry_date - current_date) as days_to_expiry,
       sum(sl.qty_on_hand - sl.qty_committed)::int as qty_at_risk,
       (sum(sl.qty_on_hand - sl.qty_committed) * p.unit_cost)::numeric(12,2) as value_at_risk,
       (b.expiry_date < current_date + 365) as below_reseller_floor  -- §6.3 12-month floor
  from batches b
  join products p on p.sku = b.sku
  join stock_ledger sl on sl.batch_id = b.id
 where b.expiry_date <= current_date + 180
   and b.expiry_date > current_date
 group by b.sku, p.name, b.id, b.batch_number, b.expiry_date, p.unit_cost
having sum(sl.qty_on_hand - sl.qty_committed) > 0;

-- ---------------------------------------------------------------------------
-- Cycle counting (§3.1): rotating weekly slices instead of annual full counts.
-- ---------------------------------------------------------------------------
create table if not exists cycle_counts (
  id          bigint generated always as identity primary key,
  count_week  text not null default to_char(now(), 'IYYY-"W"IW'),
  sku         text not null references products (sku),
  counted_qty int  not null check (counted_qty >= 0),
  system_qty  int  not null,
  variance    int  not null,
  counted_by  text not null default app_actor(),
  ts          timestamptz not null default now()
);

create or replace function record_cycle_count(p_sku text, p_counted int)
returns cycle_counts
language plpgsql security definer as $$
declare
  v_system int;
  v_row cycle_counts;
begin
  perform assert_role('OWNER_ADMIN','WAREHOUSE');

  select coalesce(sum(sl.qty_on_hand), 0)::int into v_system
    from batches b join stock_ledger sl on sl.batch_id = b.id
   where b.sku = p_sku;

  insert into cycle_counts (sku, counted_qty, system_qty, variance)
  values (p_sku, p_counted, v_system, p_counted - v_system)
  returning * into v_row;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table vendors         enable row level security;
alter table purchase_orders enable row level security;
alter table po_lines        enable row level security;
alter table rop_settings    enable row level security;
alter table cycle_counts    enable row level security;

create policy vendors_staff_read on vendors for select
  using (app_role() in ('OWNER_ADMIN','WAREHOUSE','HR_FINANCE'));
create policy pos_staff_read on purchase_orders for select
  using (app_role() in ('OWNER_ADMIN','WAREHOUSE','HR_FINANCE'));
create policy po_lines_staff_read on po_lines for select
  using (app_role() in ('OWNER_ADMIN','WAREHOUSE','HR_FINANCE'));
create policy rop_staff_read on rop_settings for select
  using (app_role() in ('OWNER_ADMIN','WAREHOUSE'));
create policy cycle_counts_staff_read on cycle_counts for select
  using (app_role() in ('OWNER_ADMIN','WAREHOUSE'));

grant select on all tables in schema public to app_client;
grant select on reorder_alerts, rop_recalc_due, aging_stock_alerts to app_client;
grant execute on all functions in schema public to app_client;

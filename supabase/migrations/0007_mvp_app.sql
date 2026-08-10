-- ============================================================================
-- MS BEAU AVE — Phase 7: MVP unified web app support (Spec-MVP.md)
--
--   * Reseller shelf-life floor (§6.3 MVP): batches under the per-product
--     floor (default 12 months remaining) are excluded from B2B availability,
--     FEFO pick lists and order commitment — retail may still sell them.
--   * POS checkout: sequential receipt numbers, payment method, tendered/
--     change, atomic FEFO deduction from RETAIL_SHELF, auto restock alert
--     when the shelf hits the per-SKU minimum (default 0).
--   * Blind end-of-day close: cashier declares the count first; the expected
--     total and variance are computed and revealed only after submission.
--   * Returns quarantine: cashiers file return requests against a receipt;
--     admin decides restock vs damaged/tester write-off.
--   * Restock requests ("move stock to the storefront") with dedupe.
--   * Delivery confirmation (delivered_at) layered on FULFILLED, without
--     disturbing what FULFILLED means to the earlier migrations.
--   * Expired write-off as an explicit, journalled action.
--   * ROP: target months of cover on suggestions + "recalculate from the last
--     90 days of sales" helper.
--   * app_users: login identities for the web app (Admin / Warehouse /
--     Cashier / Reseller), scrypt password hashes verified app-side.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Reseller shelf-life floor (§6.3 MVP, acceptance #3)
-- ---------------------------------------------------------------------------
alter table products
  add column if not exists reseller_floor_months int not null default 12
  check (reseller_floor_months >= 0);

-- Earliest acceptable expiry for a pool: B2B refuses batches below the floor.
create or replace function pool_min_expiry(p_pool text, p_sku text)
returns date
language sql stable as $$
  select case when p_pool = 'B2B_POOL'
              then (current_date
                    + make_interval(months => coalesce(
                        (select reseller_floor_months from products where sku = p_sku), 12)))::date
              else current_date end;
$$;

-- FEFO pick, now floor-aware for the B2B pool.
create or replace function fefo_pick(p_pool text, p_sku text, p_qty int)
returns table (batch_id bigint, batch_number text, expiry_date date, pick_qty int)
language sql stable security definer as $$
  with avail as (
    select sl.batch_id, b.batch_number, b.expiry_date,
           sl.qty_on_hand - sl.qty_committed as available,
           sum(sl.qty_on_hand - sl.qty_committed)
             over (order by b.expiry_date, b.id) as running
      from stock_ledger sl
      join batches b on b.id = sl.batch_id
     where sl.pool = p_pool
       and b.sku = p_sku
       and b.expiry_date > pool_min_expiry(p_pool, p_sku)
       and sl.qty_on_hand - sl.qty_committed > 0
  )
  select batch_id, batch_number, expiry_date,
         least(available, p_qty - (running - available))::int as pick_qty
    from avail
   where running - available < p_qty
   order by expiry_date, batch_id;
$$;

-- Reseller catalog view now counts only floor-viable batches.
create or replace view b2b_available_stock as
select p.sku, p.name, p.brand, p.category, p.wholesale_price, p.srp,
       coalesce(sum(sl.qty_on_hand - sl.qty_committed), 0)::int as available
  from products p
  left join batches b  on b.sku = p.sku
   and b.expiry_date > (current_date + make_interval(months => p.reseller_floor_months))::date
  left join stock_ledger sl on sl.batch_id = b.id and sl.pool = 'B2B_POOL'
 where p.active
 group by p.sku, p.name, p.brand, p.category, p.wholesale_price, p.srp;

-- place_order: identical to the Phase 1 engine, plus the per-line viability
-- floor — a B2B order can never commit units from a batch that a reseller
-- would refuse.
create or replace function place_order(
  p_channel     text,
  p_lines       jsonb,
  p_reseller_id bigint default null
) returns bigint
language plpgsql security definer as $$
declare
  v_pool       text;
  v_order_id   bigint;
  v_line       record;
  v_row        record;
  v_needed     int;
  v_take       int;
  v_price      numeric(12,2);
  v_subtotal   numeric(12,2) := 0;
  v_discount   numeric(12,2) := 0;
  v_min_expiry date;
begin
  if p_channel = 'B2B' then
    perform assert_role('OWNER_ADMIN','B2B_AGENT','RESELLER');
    if app_role() = 'RESELLER' and (p_reseller_id is distinct from app_reseller_id()) then
      raise exception 'FORBIDDEN: resellers may only order for themselves'
        using errcode = '42501';
    end if;
    v_pool := 'B2B_POOL';
  elsif p_channel = 'RETAIL' then
    perform assert_role('OWNER_ADMIN','RETAIL_CASHIER');
    v_pool := 'RETAIL_SHELF';
  else
    raise exception 'unknown channel %', p_channel;
  end if;

  if p_channel = 'B2B'
     and exists (select 1 from pg_proc where proname = 'check_reseller_can_order') then
    execute 'select check_reseller_can_order($1, $2)'
      using p_reseller_id, (
        select coalesce(sum(
          coalesce((l ->> 'unit_price')::numeric,
                   (select wholesale_price from products p where p.sku = l ->> 'sku'))
          * (l ->> 'qty')::int), 0)
        from jsonb_array_elements(p_lines) l);
  end if;

  insert into orders (channel, reseller_id)
  values (p_channel, p_reseller_id)
  returning id into v_order_id;

  for v_line in
    select (l ->> 'sku')                 as sku,
           (l ->> 'qty')::int            as qty,
           (l ->> 'unit_price')::numeric as unit_price,
           coalesce((l ->> 'discount')::numeric, 0) as discount
      from jsonb_array_elements(p_lines) l
     order by l ->> 'sku'
  loop
    if v_line.qty is null or v_line.qty <= 0 then
      raise exception 'line qty must be positive for sku %', v_line.sku;
    end if;

    select coalesce(v_line.unit_price,
                    case when p_channel = 'B2B' then wholesale_price else retail_price end)
      into v_price
      from products where sku = v_line.sku and active;
    if not found then
      raise exception 'unknown or inactive SKU %', v_line.sku;
    end if;

    v_min_expiry := pool_min_expiry(v_pool, v_line.sku);

    v_needed := v_line.qty;
    for v_row in
      select sl.id, sl.qty_on_hand, sl.qty_committed, b.id as batch_id
        from stock_ledger sl
        join batches b on b.id = sl.batch_id
       where sl.pool = v_pool
         and b.sku = v_line.sku
         and b.expiry_date > v_min_expiry
       order by b.expiry_date, b.id
         for update of sl
    loop
      exit when v_needed <= 0;
      v_take := least(v_row.qty_on_hand - v_row.qty_committed, v_needed);
      if v_take > 0 then
        update stock_ledger
           set qty_committed = qty_committed + v_take
         where id = v_row.id;
        insert into order_lines (order_id, sku, batch_id, qty, unit_price, discount)
        values (v_order_id, v_line.sku, v_row.batch_id, v_take, v_price,
                round(v_line.discount * v_take / v_line.qty, 2));
        v_needed := v_needed - v_take;
      end if;
    end loop;

    if v_needed > 0 then
      raise exception 'INSUFFICIENT_STOCK: sku % short % unit(s) in pool %',
        v_line.sku, v_needed, v_pool
        using errcode = 'P0002';
    end if;

    v_subtotal := v_subtotal + v_price * v_line.qty;
    v_discount := v_discount + v_line.discount;
  end loop;

  update orders
     set subtotal = v_subtotal,
         discount = v_discount,
         total    = v_subtotal - v_discount
   where id = v_order_id;

  if p_channel = 'B2B'
     and exists (select 1 from pg_proc where proname = 'create_invoice_for_order') then
    execute 'select create_invoice_for_order($1)' using v_order_id;
  end if;

  return v_order_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Delivery confirmation (§6 MVP pipeline … → DISPATCHED → DELIVERED).
--
-- Delivery is recorded as its own fact rather than as a new `status` value.
-- `FULFILLED` means the stock left the building, and four earlier migrations
-- already ask exactly that question (commissions in 0005, ABC in 0004, cash
-- reconciliation in 0003, sales_by_channel in 0006). Adding a status *after*
-- FULFILLED would quietly drop every delivered order out of all four — a
-- cashier's drawer would reconcile over, and an agent's commission would
-- vanish on the next recompute. A timestamp keeps those queries correct
-- forever, including ones not yet written.
-- ---------------------------------------------------------------------------
alter table orders add column if not exists delivered_at timestamptz;

create or replace function mark_order_delivered(p_order_id bigint) returns void
language plpgsql security definer as $$
declare
  v_order orders%rowtype;
begin
  perform assert_role('OWNER_ADMIN','WAREHOUSE');
  select * into v_order from orders where id = p_order_id for update;
  if not found then
    raise exception 'unknown order %', p_order_id;
  end if;
  if v_order.channel <> 'B2B' then
    raise exception 'order % is a counter sale — it was handed over at the till',
      p_order_id;
  end if;
  if v_order.status <> 'FULFILLED' then
    raise exception 'order % is % — only dispatched orders can be marked delivered',
      p_order_id, v_order.status;
  end if;
  if v_order.delivered_at is not null then
    raise exception 'order % was already marked delivered on %',
      p_order_id, v_order.delivered_at::date;
  end if;
  update orders set delivered_at = now() where id = p_order_id;
end;
$$;

create or replace function mark_order_picking(p_order_id bigint) returns void
language plpgsql security definer as $$
declare
  v_status text;
begin
  perform assert_role('OWNER_ADMIN','WAREHOUSE');
  select status into v_status from orders where id = p_order_id for update;
  if not found then
    raise exception 'unknown order %', p_order_id;
  end if;
  if v_status <> 'PLACED' then
    raise exception 'order % is % — only committed (PLACED) orders can start picking',
      p_order_id, v_status;
  end if;
  update orders set status = 'PICKING' where id = p_order_id;
end;
$$;

-- Resellers may cancel their own unfulfilled orders from the portal (§6.2
-- MVP: cancelling an uncommitted/unfulfilled order releases stock).
create or replace function cancel_order(p_order_id bigint) returns void
language plpgsql security definer as $$
declare
  v_order record;
  v_line  record;
  v_pool  text;
begin
  perform assert_role('OWNER_ADMIN','B2B_AGENT','RETAIL_CASHIER','WAREHOUSE','RESELLER');

  select * into v_order from orders where id = p_order_id for update;
  if not found then
    raise exception 'unknown order %', p_order_id;
  end if;
  if app_role() = 'RESELLER' and v_order.reseller_id is distinct from app_reseller_id() then
    raise exception 'FORBIDDEN: resellers may only cancel their own orders'
      using errcode = '42501';
  end if;
  if v_order.status not in ('PLACED','PICKING') then
    raise exception 'order % is % — cannot cancel', p_order_id, v_order.status;
  end if;

  v_pool := case when v_order.channel = 'B2B' then 'B2B_POOL' else 'RETAIL_SHELF' end;

  for v_line in
    select batch_id, sum(qty) as qty
      from order_lines where order_id = p_order_id
     group by batch_id order by batch_id
  loop
    update stock_ledger
       set qty_committed = qty_committed - v_line.qty
     where batch_id = v_line.batch_id and pool = v_pool;
  end loop;

  update orders set status = 'CANCELLED' where id = p_order_id;

  if v_order.channel = 'B2B'
     and exists (select 1 from pg_proc where proname = 'void_invoice_for_order') then
    execute 'select void_invoice_for_order($1)' using p_order_id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Restock requests (§6.1 MVP): "move stock from warehouse to storefront"
-- ---------------------------------------------------------------------------
create table if not exists restock_requests (
  id           bigint generated always as identity primary key,
  sku          text not null references products (sku),
  note         text,
  status       text not null default 'OPEN' check (status in ('OPEN','DONE')),
  requested_by text not null default app_actor(),
  ts           timestamptz not null default now(),
  done_by      text,
  done_at      timestamptz
);

-- One open task per SKU, enforced by the index rather than by a check-then-
-- insert: two cashiers tapping "request restock" at the same moment, or a
-- sale's auto-alert racing a manual tap, must not queue the job twice.
create unique index if not exists restock_requests_one_open_idx
  on restock_requests (sku) where status = 'OPEN';

create or replace function request_restock(p_sku text, p_note text default null)
returns bigint
language plpgsql security definer as $$
declare
  v_id bigint;
begin
  perform assert_role('OWNER_ADMIN','WAREHOUSE','RETAIL_CASHIER');
  insert into restock_requests (sku, note) values (p_sku, p_note)
  on conflict (sku) where status = 'OPEN' do nothing
  returning id into v_id;
  if v_id is null then           -- someone already raised it; hand back theirs
    select id into v_id from restock_requests
     where sku = p_sku and status = 'OPEN' limit 1;
  end if;
  return v_id;
end;
$$;

create or replace function close_restock(p_id bigint) returns void
language plpgsql security definer as $$
declare
  v_rows int;
begin
  perform assert_role('OWNER_ADMIN','WAREHOUSE');
  update restock_requests
     set status = 'DONE', done_by = app_actor(), done_at = now()
   where id = p_id and status = 'OPEN';
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    raise exception 'restock task % is not open — someone may have just closed it', p_id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- POS checkout (§6.6 MVP): receipt numbers, payment method, tendered/change.
-- The sale itself is the Phase 1/3 engine: atomic FEFO deduction from
-- RETAIL_SHELF, blocked with INSUFFICIENT_STOCK when the shelf is short.
-- ---------------------------------------------------------------------------
create sequence if not exists receipt_seq;

create table if not exists retail_sales (
  id             bigint generated always as identity primary key,
  order_id       bigint not null unique references orders (id),
  receipt_no     text   not null unique,
  payment_method text   not null check (payment_method in ('CASH','GCASH','CARD')),
  amount_due     numeric(12,2) not null,
  tendered       numeric(12,2),
  change         numeric(12,2),
  cashier        text not null default app_actor(),
  ts             timestamptz not null default now()
);

drop trigger if exists trg_retail_sales_audit on retail_sales;
create trigger trg_retail_sales_audit
  after insert or update or delete on retail_sales
  for each row execute function audit_row();

create or replace function pos_checkout(
  p_lines    jsonb,
  p_method   text,
  p_tendered numeric default null
) returns jsonb
language plpgsql security definer as $$
declare
  v_order_id   bigint;
  v_total      numeric(12,2);
  v_change     numeric(12,2);
  v_receipt_no text;
  v_sku        text;
  v_shelf      int;
  v_min        int;
begin
  perform assert_role('OWNER_ADMIN','RETAIL_CASHIER');
  if p_method not in ('CASH','GCASH','CARD') then
    raise exception 'payment method must be CASH, GCASH or CARD';
  end if;

  v_order_id := place_order('RETAIL', p_lines);
  perform fulfill_order(v_order_id);

  select total into v_total from orders where id = v_order_id;

  if p_method = 'CASH' then
    if p_tendered is null or p_tendered < v_total then
      raise exception 'INSUFFICIENT_TENDER: ₱% tendered for a ₱% sale',
        coalesce(p_tendered, 0)::numeric(12,2), v_total using errcode = 'P0006';
    end if;
    v_change := p_tendered - v_total;
  else
    p_tendered := v_total;
    v_change := 0;
  end if;

  v_receipt_no := 'OR-' || to_char(now() at time zone 'Asia/Manila', 'YYYYMMDD')
                  || '-' || lpad(nextval('receipt_seq')::text, 5, '0');

  insert into retail_sales (order_id, receipt_no, payment_method, amount_due, tendered, change)
  values (v_order_id, v_receipt_no, p_method, v_total, p_tendered, v_change);

  -- Shelf at or below its minimum after this sale → raise the restock task.
  for v_sku in
    select distinct l ->> 'sku' from jsonb_array_elements(p_lines) l
  loop
    select coalesce(sum(sl.qty_on_hand - sl.qty_committed), 0)::int,
           max(p.retail_min_qty)
      into v_shelf, v_min
      from products p
      left join batches b on b.sku = p.sku and b.expiry_date > current_date
      left join stock_ledger sl on sl.batch_id = b.id and sl.pool = 'RETAIL_SHELF'
     where p.sku = v_sku
     group by p.sku;
    if v_shelf <= coalesce(v_min, 0) then
      perform request_restock(v_sku,
        format('AUTO: shelf at %s after sale %s — move stock to the storefront',
               v_shelf, v_receipt_no));
    end if;
  end loop;

  return jsonb_build_object(
    'receipt_no', v_receipt_no,
    'order_id',   v_order_id,
    'total',      v_total,
    'method',     p_method,
    'tendered',   p_tendered,
    'change',     v_change,
    'cashier',    app_actor(),
    'ts',         now(),
    'lines', (
      select jsonb_agg(jsonb_build_object(
               'sku', ol.sku, 'name', p.name, 'qty', ol.qty,
               'unit_price', ol.unit_price, 'batch_number', b.batch_number)
             order by ol.id)
        from order_lines ol
        join products p on p.sku = ol.sku
        join batches  b on b.id = ol.batch_id
       where ol.order_id = v_order_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- Returns quarantine (§6.6 MVP): cashier files a request against a receipt;
-- stock only moves when the admin decides restock vs damaged/tester.
-- ---------------------------------------------------------------------------
create table if not exists return_requests (
  id           bigint generated always as identity primary key,
  receipt_no   text   not null references retail_sales (receipt_no),
  order_id     bigint not null references orders (id),
  sku          text   not null references products (sku),
  batch_id     bigint not null references batches (id),
  qty          int    not null check (qty > 0),
  reason       text   not null,
  status       text   not null default 'PENDING'
               check (status in ('PENDING','APPROVED','REJECTED')),
  disposition  text   check (disposition in ('RESTOCK','DAMAGED','TESTER')),
  requested_by text   not null default app_actor(),
  ts           timestamptz not null default now(),
  decided_by   text,
  decided_at   timestamptz
);

create or replace function request_return(
  p_receipt_no text,
  p_sku        text,
  p_batch_id   bigint,
  p_qty        int,
  p_reason     text
) returns bigint
language plpgsql security definer as $$
declare
  v_order_id bigint;
  v_sold     int;
  v_used     int;
  v_id       bigint;
begin
  perform assert_role('OWNER_ADMIN','RETAIL_CASHIER');

  select order_id into v_order_id from retail_sales where receipt_no = p_receipt_no;
  if not found then
    raise exception 'unknown receipt %', p_receipt_no;
  end if;

  select coalesce(sum(qty), 0) into v_sold
    from order_lines
   where order_id = v_order_id and sku = p_sku and batch_id = p_batch_id;
  select coalesce((select sum(qty) from retail_returns
                    where order_id = v_order_id and sku = p_sku and batch_id = p_batch_id), 0)
       + coalesce((select sum(qty) from return_requests
                    where order_id = v_order_id and sku = p_sku and batch_id = p_batch_id
                      and status = 'PENDING'), 0)
    into v_used;
  if p_qty + v_used > v_sold then
    raise exception 'return qty % exceeds remaining sold qty % on receipt %',
      p_qty, v_sold - v_used, p_receipt_no;
  end if;

  insert into return_requests (receipt_no, order_id, sku, batch_id, qty, reason)
  values (p_receipt_no, v_order_id, p_sku, p_batch_id, p_qty, p_reason)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function decide_return(
  p_request_id  bigint,
  p_approve     boolean,
  p_disposition text default 'RESTOCK'
) returns void
language plpgsql security definer as $$
declare
  v_req return_requests%rowtype;
begin
  perform assert_role('OWNER_ADMIN');

  select * into v_req from return_requests where id = p_request_id for update;
  if not found then
    raise exception 'unknown return request %', p_request_id;
  end if;
  if v_req.status <> 'PENDING' then
    raise exception 'return request % already %', p_request_id, v_req.status;
  end if;

  if p_approve then
    if p_disposition not in ('RESTOCK','DAMAGED','TESTER') then
      raise exception 'disposition must be RESTOCK, DAMAGED or TESTER';
    end if;
    perform process_retail_return(
      v_req.order_id, v_req.sku, v_req.batch_id, v_req.qty,
      v_req.reason, p_disposition, app_actor());
    update return_requests
       set status = 'APPROVED', disposition = p_disposition,
           decided_by = app_actor(), decided_at = now()
     where id = p_request_id;
  else
    update return_requests
       set status = 'REJECTED', decided_by = app_actor(), decided_at = now()
     where id = p_request_id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Blind end-of-day close (§6.6 MVP, acceptance #7): one call submits the
-- blind count and reveals expected vs counted. The declared amount is stored
-- before the expected total is computed; the cashier UI never sees the
-- expected figure until this returns.
-- ---------------------------------------------------------------------------
create or replace function pos_eod_close(
  p_declared      numeric,
  p_business_date date default current_date,
  p_threshold     numeric default 100
) returns jsonb
language plpgsql security definer as $$
declare
  v_id       bigint;
  v_expected numeric(12,2);
  v_variance numeric(12,2);
  v_flagged  boolean;
begin
  perform assert_role('OWNER_ADMIN','RETAIL_CASHIER');
  if p_declared is null or p_declared < 0 then
    raise exception 'declared cash count must be zero or more';
  end if;

  insert into cash_drops (business_date, declared_amount)
  values (p_business_date, p_declared)
  returning id into v_id;

  -- Expected cash = this cashier's fulfilled CASH sales for the day.
  select coalesce(sum(rs.amount_due), 0) into v_expected
    from retail_sales rs
    join orders o on o.id = rs.order_id
   where rs.cashier = app_actor()
     and rs.payment_method = 'CASH'
     and o.status = 'FULFILLED'
     and rs.ts::date = p_business_date;

  v_variance := p_declared - v_expected;
  v_flagged  := abs(v_variance) > p_threshold;

  update cash_drops
     set pos_total = v_expected, variance = v_variance,
         flagged = v_flagged, reconciled_at = now()
   where id = v_id;

  return jsonb_build_object(
    'declared', p_declared, 'expected', v_expected,
    'variance', v_variance, 'flagged', v_flagged,
    'business_date', p_business_date);
exception when unique_violation then
  raise exception 'end-of-day already submitted for % — one blind count per day', p_business_date;
end;
$$;

-- ---------------------------------------------------------------------------
-- Expired write-off (§6.3 MVP): expired stock is blocked from every sale by
-- the pick filters; this journals it out of the ledger explicitly.
-- ---------------------------------------------------------------------------
create or replace view expired_stock as
select b.sku, p.name, b.id as batch_id, b.batch_number, b.expiry_date, sl.pool,
       (sl.qty_on_hand - sl.qty_committed)::int as qty
  from batches b
  join products p on p.sku = b.sku
  join stock_ledger sl on sl.batch_id = b.id
 where b.expiry_date <= current_date
   and sl.qty_on_hand - sl.qty_committed > 0;

create or replace function write_off_expired(p_batch_id bigint default null)
returns int
language plpgsql security definer as $$
declare
  v_row   record;
  v_units int := 0;
begin
  perform assert_role('OWNER_ADMIN','WAREHOUSE');
  for v_row in
    select sl.id, sl.batch_id, sl.pool, sl.qty_on_hand - sl.qty_committed as qty
      from stock_ledger sl
      join batches b on b.id = sl.batch_id
     where b.expiry_date <= current_date
       and sl.qty_on_hand - sl.qty_committed > 0
       and (p_batch_id is null or sl.batch_id = p_batch_id)
       for update of sl
  loop
    update stock_ledger set qty_on_hand = qty_on_hand - v_row.qty
     where id = v_row.id;
    insert into stock_movements (batch_id, from_pool, to_pool, qty, reason)
    values (v_row.batch_id, v_row.pool, null, v_row.qty, 'EXPIRED_WRITE_OFF');
    v_units := v_units + v_row.qty;
  end loop;
  return v_units;
end;
$$;

-- ---------------------------------------------------------------------------
-- ROP (§6.4 MVP): suggested order qty = target months of cover × avg monthly
-- sales, capped by shelf life (never more than sells before a fresh batch
-- would drop under the reseller floor).
-- ---------------------------------------------------------------------------
alter table rop_settings
  add column if not exists target_months_cover numeric not null default 3
  check (target_months_cover > 0);

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
         r.target_months_cover * 30 * r.avg_daily_sales,
         greatest(r.avg_daily_sales
                  * (coalesce(p.shelf_life_months, 24) * 30
                     - p.reseller_floor_months * 365.0 / 12), 0)
       )::numeric as suggested_order_qty
  from products p
  join rop_settings r on r.sku = p.sku
  left join sellable s on s.sku = p.sku
 where p.active
   and coalesce(s.stock, 0) <= r.rop;

create or replace function set_rop_cover(p_sku text, p_months numeric) returns void
language plpgsql security definer as $$
begin
  perform assert_role('OWNER_ADMIN','WAREHOUSE');
  if p_months is null or p_months <= 0 then
    raise exception 'target months of cover must be greater than zero';
  end if;
  update rop_settings set target_months_cover = p_months where sku = p_sku;
end;
$$;

-- "Recalculate from the last N days of sales" helper (§6.4 MVP). Lead times
-- stay manual; daily-sales figures come from fulfilled order history.
create or replace function recalc_rop_from_sales(p_sku text, p_days int default 90)
returns rop_settings
language plpgsql security definer as $$
declare
  v_existing rop_settings%rowtype;
  v_avg numeric;
  v_max numeric;
begin
  perform assert_role('OWNER_ADMIN','WAREHOUSE');

  select * into v_existing from rop_settings where sku = p_sku;
  if not found then
    raise exception 'set lead times for % first — recalculation only refreshes daily sales', p_sku;
  end if;

  select coalesce(sum(ol.qty), 0)::numeric / p_days into v_avg
    from order_lines ol
    join orders o on o.id = ol.order_id
   where ol.sku = p_sku
     and o.status = 'FULFILLED'
     and o.created_at > now() - make_interval(days => p_days);

  select coalesce(max(day_qty), 0) into v_max from (
    select sum(ol.qty) as day_qty
      from order_lines ol
      join orders o on o.id = ol.order_id
     where ol.sku = p_sku
       and o.status = 'FULFILLED'
       and o.created_at > now() - make_interval(days => p_days)
     group by o.created_at::date) d;

  return set_rop(p_sku, round(v_avg, 2), greatest(round(v_avg, 2), v_max),
                 v_existing.avg_lead_days, v_existing.max_lead_days);
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin conveniences used by the web app
-- ---------------------------------------------------------------------------
create or replace function admin_create_reseller(
  p_name         text,
  p_email        text,
  p_tier         int default 1,
  p_credit_limit numeric default 0,
  p_terms_days   int default 0,
  p_avg_monthly  numeric default 0
) returns bigint
language plpgsql security definer as $$
declare
  v_id bigint;
begin
  perform assert_role('OWNER_ADMIN');
  insert into resellers (name, email, tier, credit_limit, payment_terms_days, avg_monthly_order)
  values (p_name, p_email, p_tier, p_credit_limit, p_terms_days, p_avg_monthly)
  returning id into v_id;
  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fulfilment view for the pick screen.
--
-- Warehouse staff are not on the `resellers` / `invoices` read policies (they
-- have no business with credit), but a picker still has to know whose order
-- they are packing and whether a prepaid account has actually paid. Reading
-- the tables through this view would otherwise LEFT JOIN to all-NULL rows and
-- silently show blank names. The view is definer-owned, so it decides for
-- itself: names and payment state for staff, money only for the roles allowed
-- to see money.
-- ---------------------------------------------------------------------------
create or replace view order_fulfilment as
select o.id, o.channel, o.status, o.total, o.created_at, o.created_by,
       o.delivered_at, o.reseller_id,
       r.name as reseller_name, r.tier,
       i.id as invoice_id, i.status as invoice_status, i.due_date,
       case when app_role() in ('OWNER_ADMIN','HR_FINANCE','B2B_AGENT')
            then (i.amount - i.paid_amount - i.discount_applied) end as invoice_balance
  from orders o
  left join resellers r on r.id = o.reseller_id
  left join invoices  i on i.order_id = o.id
 where app_role() in ('OWNER_ADMIN','WAREHOUSE','HR_FINANCE','B2B_AGENT');

-- Movement ledger browser (reports): joined, human-readable journal.
create or replace view movement_ledger as
select m.id, m.ts, b.sku, p.name, b.batch_number,
       m.from_pool, m.to_pool, m.qty, m.reason, m.actor
  from stock_movements m
  join batches  b on b.id = m.batch_id
  join products p on p.sku = b.sku;

-- ---------------------------------------------------------------------------
-- Web app login identities. Password hashes are scrypt, verified app-side;
-- the database never sees a plaintext password.
-- ---------------------------------------------------------------------------
create table if not exists app_users (
  id            bigint generated always as identity primary key,
  username      text not null,
  display_name  text not null,
  password_hash text not null,
  role          text not null check (role in ('OWNER_ADMIN','WAREHOUSE','RETAIL_CASHIER','RESELLER')),
  reseller_id   bigint references resellers (id),
  active        boolean not null default true,
  created_at    timestamptz not null default now(),
  constraint reseller_users_link check (role <> 'RESELLER' or reseller_id is not null)
);

create unique index if not exists app_users_username_idx on app_users (lower(username));

drop trigger if exists trg_app_users_audit on app_users;
create trigger trg_app_users_audit
  after insert or update or delete on app_users
  for each row execute function audit_row();

create or replace function admin_create_user(
  p_username      text,
  p_display_name  text,
  p_password_hash text,
  p_role          text,
  p_reseller_id   bigint default null
) returns bigint
language plpgsql security definer as $$
declare
  v_id bigint;
begin
  perform assert_role('OWNER_ADMIN');
  insert into app_users (username, display_name, password_hash, role, reseller_id)
  values (p_username, p_display_name, p_password_hash, p_role, p_reseller_id)
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function admin_set_user_active(p_user_id bigint, p_active boolean)
returns void
language plpgsql security definer as $$
declare
  v_rows int;
begin
  perform assert_role('OWNER_ADMIN');
  update app_users set active = p_active where id = p_user_id;
  get diagnostics v_rows = row_count;
  if v_rows = 0 then
    raise exception 'unknown user %', p_user_id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS + grants
-- ---------------------------------------------------------------------------
alter table restock_requests enable row level security;
alter table retail_sales     enable row level security;
alter table return_requests  enable row level security;
alter table app_users        enable row level security;

create policy restock_requests_read on restock_requests for select
  using (app_role() in ('OWNER_ADMIN','WAREHOUSE','RETAIL_CASHIER'));
create policy retail_sales_read on retail_sales for select
  using (app_role() in ('OWNER_ADMIN','RETAIL_CASHIER','HR_FINANCE'));
create policy return_requests_read on return_requests for select
  using (app_role() in ('OWNER_ADMIN','RETAIL_CASHIER'));
create policy app_users_admin_read on app_users for select
  using (app_role() = 'OWNER_ADMIN');

-- Admin edits products directly (allocation split editor, pricing, floors) —
-- the RLS policy from Phase 1 already restricts writes to OWNER_ADMIN.
grant insert, update, delete on products to app_client;

grant select on all tables in schema public to app_client;
grant select on b2b_available_stock, movement_ledger, expired_stock, order_fulfilment,
                reorder_alerts to app_client;
grant execute on all functions in schema public to app_client;

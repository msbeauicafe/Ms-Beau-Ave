-- ============================================================================
-- Ms Beau Ave — Phase 1: Core IMS (Spec.md §3.1, §5, §6.2, §6.4, §8)
--
-- Products, batches, virtual stock pools, stock ledger + movement journal,
-- receiving with auto-allocation (70/20/10 default, per-SKU override),
-- FEFO picking, atomic committed-stock locking, pool transfers with
-- admin-gated safety-buffer release, RBAC helpers, RLS, immutable audit log.
--
-- Runs on plain Postgres 16 and on Supabase. Role identity comes from
-- request.jwt.claims ->> 'app_role' (Supabase) with a local fallback GUC
-- app.role, so the same policies are testable off-platform.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Identity helpers (RBAC)
-- Roles: OWNER_ADMIN, WAREHOUSE, RETAIL_CASHIER, B2B_AGENT, RESELLER, HR_FINANCE
-- ---------------------------------------------------------------------------
create or replace function app_role() returns text
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'app_role',
    nullif(current_setting('app.role', true), ''),
    'ANON');
$$;

create or replace function app_reseller_id() returns bigint
language sql stable as $$
  select coalesce(
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'reseller_id'),
    nullif(current_setting('app.reseller_id', true), ''))::bigint;
$$;

create or replace function app_actor() returns text
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub',
    nullif(current_setting('app.actor', true), ''),
    app_role());
$$;

create or replace function assert_role(variadic allowed text[]) returns void
language plpgsql stable as $$
begin
  if not (app_role() = any (allowed)) then
    raise exception 'FORBIDDEN: role % may not perform this action (needs one of %)',
      app_role(), allowed
      using errcode = '42501';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Audit log — immutable, everything financial/stock (§8)
-- ---------------------------------------------------------------------------
create table if not exists audit_log (
  id         bigint generated always as identity primary key,
  actor      text        not null default app_actor(),
  action     text        not null,             -- INSERT | UPDATE | DELETE | note
  entity     text        not null,             -- table / domain name
  entity_id  text,
  before     jsonb,
  after      jsonb,
  ts         timestamptz not null default now()
);

create or replace function audit_log_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'audit_log is append-only' using errcode = '55000';
end;
$$;

drop trigger if exists trg_audit_log_immutable on audit_log;
create trigger trg_audit_log_immutable
  before update or delete on audit_log
  for each row execute function audit_log_immutable();

create or replace function audit_row() returns trigger
language plpgsql security definer as $$
begin
  insert into audit_log (actor, action, entity, entity_id, before, after)
  values (
    app_actor(),
    tg_op,
    tg_table_name,
    coalesce(
      case when tg_op = 'DELETE' then null else (to_jsonb(new) ->> 'id') end,
      (to_jsonb(old) ->> 'id'),
      case when tg_op = 'DELETE' then (to_jsonb(old) ->> 'sku') else (to_jsonb(new) ->> 'sku') end),
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end);
  return coalesce(new, old);
end;
$$;

-- ---------------------------------------------------------------------------
-- Products (§5). MAP enforcement at the schema level (§6.5):
-- retail_price must be >= reseller SRP whenever both are set.
-- Allocation ratio override per SKU (§6.2); must sum to 1.
-- ---------------------------------------------------------------------------
create table if not exists products (
  sku                text primary key,
  name               text not null,
  brand              text,
  category           text,
  unit_cost          numeric(12,2) not null default 0 check (unit_cost >= 0),
  wholesale_price    numeric(12,2) not null default 0 check (wholesale_price >= 0),
  srp                numeric(12,2) not null default 0 check (srp >= 0),
  retail_price       numeric(12,2) not null default 0 check (retail_price >= 0),
  shelf_life_months  int,
  alloc_b2b          numeric(5,4),   -- per-SKU override; null = system default
  alloc_retail       numeric(5,4),
  alloc_safety       numeric(5,4),
  abc_class          char(1) check (abc_class in ('A','B','C')),
  active             boolean not null default true,
  created_at         timestamptz not null default now(),
  constraint map_enforcement check (retail_price = 0 or srp = 0 or retail_price >= srp),
  constraint alloc_override_complete check (
    (alloc_b2b is null and alloc_retail is null and alloc_safety is null)
    or (alloc_b2b is not null and alloc_retail is not null and alloc_safety is not null
        and alloc_b2b >= 0 and alloc_retail >= 0 and alloc_safety >= 0
        and abs(alloc_b2b + alloc_retail + alloc_safety - 1.0) < 0.0001)
  )
);

drop trigger if exists trg_products_audit on products;
create trigger trg_products_audit
  after insert or update or delete on products
  for each row execute function audit_row();

-- ---------------------------------------------------------------------------
-- Batches: every inbound receipt logs SKU + batch number + expiry (§3.1)
-- ---------------------------------------------------------------------------
create table if not exists batches (
  id            bigint generated always as identity primary key,
  sku           text not null references products (sku),
  batch_number  text not null,
  expiry_date   date not null,
  qty_received  int  not null check (qty_received > 0),
  received_at   timestamptz not null default now(),
  vendor_po_id  bigint,               -- FK attached in the procurement phase
  unique (sku, batch_number)
);

create index if not exists batches_fefo_idx on batches (sku, expiry_date, id);

-- ---------------------------------------------------------------------------
-- Stock ledger: current balance per (batch × pool). Pools are virtual (§6.2):
--   WAREHOUSE_BULK — staging/unallocated, RETAIL_SHELF — retail channel pool,
--   B2B_POOL — reseller channel pool, SAFETY — admin-gated buffer.
-- Invariant: 0 <= qty_committed <= qty_on_hand (committed units stay on hand
-- until fulfilment, but are invisible to every other channel).
-- ---------------------------------------------------------------------------
create table if not exists stock_ledger (
  id            bigint generated always as identity primary key,
  batch_id      bigint not null references batches (id),
  pool          text   not null check (pool in ('WAREHOUSE_BULK','RETAIL_SHELF','B2B_POOL','SAFETY')),
  qty_on_hand   int    not null default 0 check (qty_on_hand >= 0),
  qty_committed int    not null default 0 check (qty_committed >= 0),
  unique (batch_id, pool),
  constraint committed_within_on_hand check (qty_committed <= qty_on_hand)
);

drop trigger if exists trg_stock_ledger_audit on stock_ledger;
create trigger trg_stock_ledger_audit
  after insert or update or delete on stock_ledger
  for each row execute function audit_row();

-- Movement journal — append-only record of every stock move (§5)
create table if not exists stock_movements (
  id         bigint generated always as identity primary key,
  batch_id   bigint not null references batches (id),
  from_pool  text check (from_pool in ('WAREHOUSE_BULK','RETAIL_SHELF','B2B_POOL','SAFETY')),
  to_pool    text check (to_pool   in ('WAREHOUSE_BULK','RETAIL_SHELF','B2B_POOL','SAFETY')),
  qty        int  not null check (qty > 0),
  reason     text not null,          -- RECEIVE_ALLOCATION | TRANSFER | SAFETY_RELEASE | B2B_SHIP | POS_SALE | ...
  actor      text not null default app_actor(),
  ts         timestamptz not null default now(),
  check (from_pool is not null or to_pool is not null)
);

create or replace function stock_movements_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'stock_movements is append-only' using errcode = '55000';
end;
$$;

drop trigger if exists trg_stock_movements_immutable on stock_movements;
create trigger trg_stock_movements_immutable
  before update or delete on stock_movements
  for each row execute function stock_movements_immutable();

-- ---------------------------------------------------------------------------
-- Orders (§5). Channel reads only from its own pool (§6.2).
-- ---------------------------------------------------------------------------
create table if not exists orders (
  id           bigint generated always as identity primary key,
  channel      text not null check (channel in ('B2B','RETAIL')),
  reseller_id  bigint,               -- FK attached in the B2B/credit phase
  status       text not null default 'PLACED'
               check (status in ('PLACED','PICKING','FULFILLED','CANCELLED')),
  subtotal     numeric(12,2) not null default 0,
  discount     numeric(12,2) not null default 0,
  total        numeric(12,2) not null default 0,
  created_by   text not null default app_actor(),
  created_at   timestamptz not null default now(),
  constraint b2b_needs_reseller check (channel <> 'B2B' or reseller_id is not null)
);

create table if not exists order_lines (
  id          bigint generated always as identity primary key,
  order_id    bigint not null references orders (id) on delete cascade,
  sku         text   not null references products (sku),
  batch_id    bigint not null references batches (id),
  qty         int    not null check (qty > 0),
  unit_price  numeric(12,2) not null check (unit_price >= 0),
  discount    numeric(12,2) not null default 0 check (discount >= 0)
);

create index if not exists order_lines_order_idx on order_lines (order_id);
create index if not exists orders_reseller_idx on orders (reseller_id) where reseller_id is not null;

drop trigger if exists trg_orders_audit on orders;
create trigger trg_orders_audit
  after insert or update or delete on orders
  for each row execute function audit_row();

-- ---------------------------------------------------------------------------
-- Receiving with auto-allocation (§3.1, §6.2)
-- Default split 70% B2B / 20% Retail / 10% Safety; per-SKU override on the
-- product row. Largest-remainder rounding so allocated units always sum to
-- the received quantity.
-- ---------------------------------------------------------------------------
create or replace function receive_batch(
  p_sku          text,
  p_batch_number text,
  p_expiry_date  date,
  p_qty          int,
  p_vendor_po_id bigint default null
) returns bigint
language plpgsql security definer as $$
declare
  v_batch_id  bigint;
  v_b2b       numeric; v_retail numeric; v_safety numeric;
  v_exact     numeric[]; v_floor int[]; v_rem numeric[];
  v_pools     text[] := array['B2B_POOL','RETAIL_SHELF','SAFETY'];
  v_leftover  int; i int; v_max_i int;
begin
  perform assert_role('OWNER_ADMIN','WAREHOUSE');
  if p_qty <= 0 then
    raise exception 'received quantity must be positive';
  end if;

  select coalesce(alloc_b2b, 0.70), coalesce(alloc_retail, 0.20), coalesce(alloc_safety, 0.10)
    into v_b2b, v_retail, v_safety
    from products where sku = p_sku and active;
  if not found then
    raise exception 'unknown or inactive SKU %', p_sku;
  end if;

  insert into batches (sku, batch_number, expiry_date, qty_received, vendor_po_id)
  values (p_sku, p_batch_number, p_expiry_date, p_qty, p_vendor_po_id)
  returning id into v_batch_id;

  v_exact := array[p_qty * v_b2b, p_qty * v_retail, p_qty * v_safety];
  v_floor := array[floor(v_exact[1])::int, floor(v_exact[2])::int, floor(v_exact[3])::int];
  v_rem   := array[v_exact[1] - v_floor[1], v_exact[2] - v_floor[2], v_exact[3] - v_floor[3]];
  v_leftover := p_qty - (v_floor[1] + v_floor[2] + v_floor[3]);

  while v_leftover > 0 loop
    v_max_i := 1;
    for i in 2..3 loop
      if v_rem[i] > v_rem[v_max_i] then v_max_i := i; end if;
    end loop;
    v_floor[v_max_i] := v_floor[v_max_i] + 1;
    v_rem[v_max_i] := -1;             -- each pool takes at most one leftover unit
    v_leftover := v_leftover - 1;
  end loop;

  for i in 1..3 loop
    if v_floor[i] > 0 then
      insert into stock_ledger (batch_id, pool, qty_on_hand)
      values (v_batch_id, v_pools[i], v_floor[i]);
      insert into stock_movements (batch_id, from_pool, to_pool, qty, reason)
      values (v_batch_id, null, v_pools[i], v_floor[i], 'RECEIVE_ALLOCATION');
    end if;
  end loop;

  return v_batch_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- FEFO pick suggestion (§6.4): oldest viable (unexpired) batch first,
-- counting only uncommitted units in the requested pool.
-- ---------------------------------------------------------------------------
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
       and b.expiry_date > current_date
       and sl.qty_on_hand - sl.qty_committed > 0
  )
  select batch_id, batch_number, expiry_date,
         least(available, p_qty - (running - available))::int as pick_qty
    from avail
   where running - available < p_qty
   order by expiry_date, batch_id;
$$;

-- ---------------------------------------------------------------------------
-- Order placement with atomic committed-stock locking (§6.2, §8).
-- Locks the FEFO-ordered ledger rows FOR UPDATE, re-checks availability under
-- the lock, and commits units in one transaction — two simultaneous orders
-- for the last units can never both succeed.
-- Lines: jsonb array of {"sku": text, "qty": int, "unit_price"?: numeric,
--                        "discount"?: numeric}
-- ---------------------------------------------------------------------------
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

  -- Credit-engine hook (installed by the Phase 2 migration). Dynamic call so
  -- Phase 1 stands alone; once present it hard-blocks past-due / over-limit
  -- resellers per §6.1.
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

  -- Deterministic lock order (sku, then FEFO) prevents deadlocks between
  -- concurrent multi-line orders.
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

    v_needed := v_line.qty;
    for v_row in
      select sl.id, sl.qty_on_hand, sl.qty_committed, b.id as batch_id
        from stock_ledger sl
        join batches b on b.id = sl.batch_id
       where sl.pool = v_pool
         and b.sku = v_line.sku
         and b.expiry_date > current_date
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

  -- Invoicing hook (installed by the Phase 2 migration): wholesale invoice
  -- raised at placement; Tier 1 invoices fall due immediately (prepayment).
  if p_channel = 'B2B'
     and exists (select 1 from pg_proc where proname = 'create_invoice_for_order') then
    execute 'select create_invoice_for_order($1)' using v_order_id;
  end if;

  return v_order_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fulfilment: committed units leave the pool (ship / POS handover).
-- ---------------------------------------------------------------------------
create or replace function fulfill_order(p_order_id bigint) returns void
language plpgsql security definer as $$
declare
  v_order  record;
  v_line   record;
  v_pool   text;
  v_reason text;
begin
  perform assert_role('OWNER_ADMIN','WAREHOUSE','RETAIL_CASHIER');

  select * into v_order from orders where id = p_order_id for update;
  if not found then
    raise exception 'unknown order %', p_order_id;
  end if;
  if v_order.status not in ('PLACED','PICKING') then
    raise exception 'order % is % — cannot fulfil', p_order_id, v_order.status;
  end if;

  -- Prepayment gate hook (Phase 2): Tier 1 resellers must pay before shipment.
  if v_order.channel = 'B2B'
     and exists (select 1 from pg_proc where proname = 'check_order_fulfillable') then
    execute 'select check_order_fulfillable($1)' using p_order_id;
  end if;

  v_pool   := case when v_order.channel = 'B2B' then 'B2B_POOL' else 'RETAIL_SHELF' end;
  v_reason := case when v_order.channel = 'B2B' then 'B2B_SHIP' else 'POS_SALE' end;

  for v_line in
    select batch_id, sum(qty) as qty
      from order_lines where order_id = p_order_id
     group by batch_id order by batch_id
  loop
    update stock_ledger
       set qty_on_hand   = qty_on_hand   - v_line.qty,
           qty_committed = qty_committed - v_line.qty
     where batch_id = v_line.batch_id and pool = v_pool;
    insert into stock_movements (batch_id, from_pool, to_pool, qty, reason)
    values (v_line.batch_id, v_pool, null, v_line.qty, v_reason);
  end loop;

  update orders set status = 'FULFILLED' where id = p_order_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Cancellation: release the committed lock back to the pool.
-- ---------------------------------------------------------------------------
create or replace function cancel_order(p_order_id bigint) returns void
language plpgsql security definer as $$
declare
  v_order record;
  v_line  record;
  v_pool  text;
begin
  perform assert_role('OWNER_ADMIN','B2B_AGENT','RETAIL_CASHIER','WAREHOUSE');

  select * into v_order from orders where id = p_order_id for update;
  if not found then
    raise exception 'unknown order %', p_order_id;
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

  -- Void the placement invoice (Phase 2 hook).
  if v_order.channel = 'B2B'
     and exists (select 1 from pg_proc where proname = 'void_invoice_for_order') then
    execute 'select void_invoice_for_order($1)' using p_order_id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Pool transfers (§6.2): only uncommitted units may move; releasing the
-- SAFETY buffer is an explicit OWNER_ADMIN action.
-- ---------------------------------------------------------------------------
create or replace function transfer_stock(
  p_batch_id bigint,
  p_from     text,
  p_to       text,
  p_qty      int,
  p_reason   text default 'TRANSFER'
) returns void
language plpgsql security definer as $$
declare
  v_row stock_ledger%rowtype;
begin
  if p_from = 'SAFETY' then
    perform assert_role('OWNER_ADMIN');   -- §6.2: admin-only safety release
  else
    perform assert_role('OWNER_ADMIN','WAREHOUSE');
  end if;
  if p_qty <= 0 then
    raise exception 'transfer qty must be positive';
  end if;
  if p_from = p_to then
    raise exception 'from and to pool are the same';
  end if;

  select * into v_row from stock_ledger
   where batch_id = p_batch_id and pool = p_from
     for update;
  if not found or v_row.qty_on_hand - v_row.qty_committed < p_qty then
    raise exception 'INSUFFICIENT_STOCK: batch % has fewer than % uncommitted unit(s) in %',
      p_batch_id, p_qty, p_from
      using errcode = 'P0002';
  end if;

  update stock_ledger set qty_on_hand = qty_on_hand - p_qty
   where batch_id = p_batch_id and pool = p_from;

  insert into stock_ledger (batch_id, pool, qty_on_hand)
  values (p_batch_id, p_to, p_qty)
  on conflict (batch_id, pool)
  do update set qty_on_hand = stock_ledger.qty_on_hand + excluded.qty_on_hand;

  insert into stock_movements (batch_id, from_pool, to_pool, qty, reason)
  values (p_batch_id, p_from, p_to, p_qty,
          case when p_from = 'SAFETY' then 'SAFETY_RELEASE' else p_reason end);
end;
$$;

-- ---------------------------------------------------------------------------
-- Reseller-facing catalog view: B2B pool availability only — never warehouse
-- totals, never retail pricing internals (§2, §3.3).
-- ---------------------------------------------------------------------------
create or replace view b2b_available_stock as
select p.sku, p.name, p.brand, p.category, p.wholesale_price, p.srp,
       coalesce(sum(sl.qty_on_hand - sl.qty_committed), 0)::int as available
  from products p
  left join batches b  on b.sku = p.sku and b.expiry_date > current_date
  left join stock_ledger sl on sl.batch_id = b.id and sl.pool = 'B2B_POOL'
 where p.active
 group by p.sku, p.name, p.brand, p.category, p.wholesale_price, p.srp;

-- ---------------------------------------------------------------------------
-- Row-level security (§8): enforced at the database layer.
-- Writes flow through the SECURITY DEFINER functions above; direct table
-- access is read-only per role. Resellers see only their own orders and the
-- b2b_available_stock view (which the view's definer rights allow).
-- ---------------------------------------------------------------------------
alter table products        enable row level security;
alter table batches         enable row level security;
alter table stock_ledger    enable row level security;
alter table stock_movements enable row level security;
alter table orders          enable row level security;
alter table order_lines     enable row level security;
alter table audit_log       enable row level security;

-- Staff read access
create policy staff_read_products on products for select
  using (app_role() in ('OWNER_ADMIN','WAREHOUSE','RETAIL_CASHIER','B2B_AGENT','HR_FINANCE'));
create policy staff_read_batches on batches for select
  using (app_role() in ('OWNER_ADMIN','WAREHOUSE','RETAIL_CASHIER','B2B_AGENT'));
create policy staff_read_ledger on stock_ledger for select
  using (app_role() in ('OWNER_ADMIN','WAREHOUSE','RETAIL_CASHIER'));
create policy staff_read_movements on stock_movements for select
  using (app_role() in ('OWNER_ADMIN','WAREHOUSE'));
create policy admin_read_audit on audit_log for select
  using (app_role() in ('OWNER_ADMIN','HR_FINANCE'));
create policy audit_append on audit_log for insert
  with check (true);                       -- appended by definer triggers

-- Admin table writes (normal flows use the functions; this keeps admin tooling usable)
create policy admin_write_products on products for all
  using (app_role() = 'OWNER_ADMIN') with check (app_role() = 'OWNER_ADMIN');

-- Orders: staff see channel-appropriate orders; resellers only their own
create policy orders_staff_read on orders for select
  using (app_role() in ('OWNER_ADMIN','WAREHOUSE','HR_FINANCE')
         or (app_role() = 'B2B_AGENT'      and channel = 'B2B')
         or (app_role() = 'RETAIL_CASHIER' and channel = 'RETAIL'));
create policy orders_reseller_read on orders for select
  using (app_role() = 'RESELLER' and reseller_id = app_reseller_id());

create policy order_lines_read on order_lines for select
  using (exists (select 1 from orders o where o.id = order_id));  -- delegates to orders RLS

-- ---------------------------------------------------------------------------
-- Non-superuser client role for app connections and RLS tests.
-- Supabase's own anon/authenticated roles work the same way via GRANTs.
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'app_client') then
    create role app_client nologin;
  end if;
exception when insufficient_privilege then
  raise notice 'skipping app_client role creation (no CREATEROLE)';
end;
$$;

grant usage on schema public to app_client;
grant select on all tables in schema public to app_client;
grant select on b2b_available_stock to app_client;
grant execute on all functions in schema public to app_client;

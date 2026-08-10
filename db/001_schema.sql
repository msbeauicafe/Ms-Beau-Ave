-- ============================================================================
-- MS BEAU AVE — operations schema
--
-- One stock pool, three channels. Every rule that protects the stock or the
-- money lives here rather than in the application, so no UI, API, integration
-- or psql prompt can route around it.
--
-- Runs on plain Postgres 15+ and on Supabase.
--
--   Identity comes from the JWT claim `app_role` on Supabase, or the
--   `app.role` setting locally. The application connects as a non-superuser
--   role, so the row-level security policies at the bottom actually apply.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Who is asking
--
-- Roles: admin, warehouse, cashier, reseller
-- ---------------------------------------------------------------------------
create or replace function current_role_name() returns text
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'app_role',
    nullif(current_setting('app.role', true), ''),
    'anon');
$$;

create or replace function current_actor() returns text
language sql stable as $$
  select coalesce(nullif(current_setting('app.actor', true), ''), current_role_name());
$$;

create or replace function current_reseller() returns bigint
language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'reseller_id',
    nullif(current_setting('app.reseller_id', true), ''))::bigint;
$$;

create or replace function require_role(variadic allowed text[]) returns void
language plpgsql stable as $$
begin
  if not (current_role_name() = any (allowed)) then
    raise exception 'FORBIDDEN: % may not do that', current_role_name()
      using errcode = '42501';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Audit log — append only, enforced by trigger
-- ---------------------------------------------------------------------------
create table audit_log (
  id        bigint generated always as identity primary key,
  actor     text        not null default current_actor(),
  action    text        not null,
  entity    text        not null,
  entity_id text,
  before    jsonb,
  after     jsonb,
  at        timestamptz not null default now()
);

create or replace function refuse_change() returns trigger
language plpgsql as $$
begin
  raise exception '% is append-only', tg_table_name using errcode = '55000';
end;
$$;

create trigger audit_log_immutable before update or delete on audit_log
  for each row execute function refuse_change();

create or replace function write_audit() returns trigger
language plpgsql security definer as $$
begin
  insert into audit_log (action, entity, entity_id, before, after)
  values (tg_op, tg_table_name,
          coalesce(to_jsonb(new) ->> 'id', to_jsonb(old) ->> 'id',
                   to_jsonb(new) ->> 'sku', to_jsonb(old) ->> 'sku'),
          case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
          case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end);
  return coalesce(new, old);
end;
$$;

-- ---------------------------------------------------------------------------
-- Sign-ins. Password digests are scrypt, computed and checked by the app —
-- the database never sees a plaintext password.
-- ---------------------------------------------------------------------------
create table app_users (
  id            bigint generated always as identity primary key,
  username      text not null,
  display_name  text not null,
  password_hash text not null,
  role          text not null check (role in ('admin','warehouse','cashier','reseller')),
  reseller_id   bigint,
  active        boolean not null default true,
  created_at    timestamptz not null default now(),
  constraint reseller_login_needs_reseller check (role <> 'reseller' or reseller_id is not null)
);
create unique index app_users_username on app_users (lower(username));
create trigger app_users_audit after insert or update or delete on app_users
  for each row execute function write_audit();

-- ---------------------------------------------------------------------------
-- Products
--
-- Pricing discipline (MAP): the shop's own price may never undercut the price
-- resellers are told to sell at, or the reseller network gets undercut by its
-- own supplier. Enforced as a constraint, not a warning.
--
-- alloc_* is this product's split across the three pools on receipt. Null
-- means "use the house default" (70/20/10).
-- ---------------------------------------------------------------------------
create table products (
  sku             text primary key,
  name            text not null,
  brand           text,
  category        text,
  unit_cost       numeric(12,2) not null default 0 check (unit_cost >= 0),
  wholesale_price numeric(12,2) not null default 0 check (wholesale_price >= 0),
  srp             numeric(12,2) not null default 0 check (srp >= 0),
  retail_price    numeric(12,2) not null default 0 check (retail_price >= 0),
  shelf_life_months  int not null default 24 check (shelf_life_months > 0),
  -- Resellers will not accept stock with less than this much life left.
  reseller_floor_months int not null default 12 check (reseller_floor_months >= 0),
  shelf_min       int not null default 0 check (shelf_min >= 0),
  abc_class       char(1) check (abc_class in ('A','B','C')),
  alloc_b2b       numeric(4,3),
  alloc_shop      numeric(4,3),
  alloc_reserve   numeric(4,3),
  active          boolean not null default true,
  created_at      timestamptz not null default now(),

  constraint map_discipline check (retail_price = 0 or srp = 0 or retail_price >= srp),
  constraint allocation_is_whole check (
    (alloc_b2b is null and alloc_shop is null and alloc_reserve is null)
    or (alloc_b2b >= 0 and alloc_shop >= 0 and alloc_reserve >= 0
        and abs(alloc_b2b + alloc_shop + alloc_reserve - 1) < 0.001))
);
create trigger products_audit after insert or update or delete on products
  for each row execute function write_audit();

-- ---------------------------------------------------------------------------
-- Batches. All stock is batched — there is no batchless quantity anywhere,
-- because an expiry date you cannot trace is an expiry date you cannot manage.
-- ---------------------------------------------------------------------------
create table batches (
  id           bigint generated always as identity primary key,
  sku          text not null references products (sku),
  batch_no     text not null,
  expiry       date not null,
  qty_received int  not null check (qty_received > 0),
  received_at  timestamptz not null default now(),
  unique (sku, batch_no)
);
create index batches_fefo on batches (sku, expiry, id);

-- ---------------------------------------------------------------------------
-- The ledger: how much of each batch sits in each pool.
--
--   b2b     — reserved for reseller orders
--   shop    — on the retail shelf
--   reserve — safety buffer, released by an admin only
--
-- `committed` is stock spoken for by a submitted order but not yet shipped.
-- It stays on hand but is invisible to every other channel, which is what
-- stops two orders selling the same unit.
-- ---------------------------------------------------------------------------
create table stock (
  id        bigint generated always as identity primary key,
  batch_id  bigint not null references batches (id),
  pool      text   not null check (pool in ('b2b','shop','reserve')),
  on_hand   int    not null default 0 check (on_hand >= 0),
  committed int    not null default 0 check (committed >= 0),
  unique (batch_id, pool),
  constraint cannot_commit_more_than_held check (committed <= on_hand)
);
create trigger stock_audit after insert or update or delete on stock
  for each row execute function write_audit();

-- Every movement, forever. Current stock is a consequence of this journal.
create table movements (
  id        bigint generated always as identity primary key,
  batch_id  bigint not null references batches (id),
  from_pool text check (from_pool in ('b2b','shop','reserve')),
  to_pool   text check (to_pool   in ('b2b','shop','reserve')),
  qty       int  not null check (qty > 0),
  reason    text not null,
  actor     text not null default current_actor(),
  at        timestamptz not null default now(),
  check (from_pool is not null or to_pool is not null)
);
create trigger movements_immutable before update or delete on movements
  for each row execute function refuse_change();

-- ---------------------------------------------------------------------------
-- Resellers and their credit standing
--
-- Tier 1 new accounts pay before anything ships. Tier 2 and 3 get terms and a
-- limit. `blocked` is set by the system, not by a person.
-- ---------------------------------------------------------------------------
create table resellers (
  id             bigint generated always as identity primary key,
  name           text not null,
  contact        text,
  email          text,
  tier           int not null default 1 check (tier in (1,2,3)),
  credit_limit   numeric(12,2) not null default 0 check (credit_limit >= 0),
  terms_days     int not null default 0 check (terms_days >= 0),
  status         text not null default 'pending' check (status in ('pending','active','suspended')),
  docs_verified  boolean not null default false,
  blocked        boolean not null default false,
  blocked_reason text,
  created_at     timestamptz not null default now()
);
create trigger resellers_audit after insert or update or delete on resellers
  for each row execute function write_audit();

alter table app_users add constraint app_users_reseller_fk
  foreign key (reseller_id) references resellers (id);

create table reseller_documents (
  id          bigint generated always as identity primary key,
  reseller_id bigint not null references resellers (id),
  kind        text not null,
  reference   text not null,
  verified    boolean not null default false,
  uploaded_at timestamptz not null default now()
);

-- Tier changes, blocks, overrides — the account's history.
create table reseller_events (
  id          bigint generated always as identity primary key,
  reseller_id bigint not null references resellers (id),
  kind        text not null,
  detail      jsonb,
  actor       text not null default current_actor(),
  at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Orders. One table for both channels: a counter sale and a wholesale order
-- move the same stock, and reporting should not have to union two shapes.
--
-- `delivered_at` rather than a DELIVERED status: fulfilled means the stock
-- left the building, which is the question every report actually asks.
-- Layering delivery on as a status would silently drop delivered orders out
-- of every one of them.
-- ---------------------------------------------------------------------------
create table orders (
  id           bigint generated always as identity primary key,
  channel      text not null check (channel in ('b2b','shop')),
  reseller_id  bigint references resellers (id),
  status       text not null default 'placed'
               check (status in ('placed','picking','fulfilled','cancelled')),
  subtotal     numeric(12,2) not null default 0,
  discount     numeric(12,2) not null default 0,
  total        numeric(12,2) not null default 0,
  placed_by    text not null default current_actor(),
  placed_at    timestamptz not null default now(),
  delivered_at timestamptz,
  constraint wholesale_needs_a_reseller check (channel <> 'b2b' or reseller_id is not null)
);
create index orders_open on orders (status) where status in ('placed','picking');
create index orders_by_reseller on orders (reseller_id) where reseller_id is not null;
create trigger orders_audit after insert or update or delete on orders
  for each row execute function write_audit();

-- A line per batch actually picked, so the pick list and the receipt both
-- trace to real stock.
create table order_lines (
  id         bigint generated always as identity primary key,
  order_id   bigint not null references orders (id) on delete cascade,
  sku        text   not null references products (sku),
  batch_id   bigint not null references batches (id),
  qty        int    not null check (qty > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0)
);
create index order_lines_by_order on order_lines (order_id);

-- ---------------------------------------------------------------------------
-- Wholesale invoicing
-- ---------------------------------------------------------------------------
create table invoices (
  id          bigint generated always as identity primary key,
  order_id    bigint not null unique references orders (id),
  reseller_id bigint not null references resellers (id),
  issued_on   date not null default current_date,
  due_on      date not null,
  amount      numeric(12,2) not null check (amount >= 0),
  paid        numeric(12,2) not null default 0 check (paid >= 0),
  discount    numeric(12,2) not null default 0 check (discount >= 0),
  status      text not null default 'open' check (status in ('open','paid','void')),
  settled_on  date
);
create index invoices_outstanding on invoices (reseller_id) where status = 'open';
create trigger invoices_audit after insert or update or delete on invoices
  for each row execute function write_audit();

create table payments (
  id         bigint generated always as identity primary key,
  invoice_id bigint not null references invoices (id),
  amount     numeric(12,2) not null check (amount > 0),
  paid_on    date not null default current_date,
  recorded_by text not null default current_actor(),
  at         timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Counter sales
-- ---------------------------------------------------------------------------
create sequence receipt_counter;

create table sales (
  id         bigint generated always as identity primary key,
  order_id   bigint not null unique references orders (id),
  receipt_no text   not null unique,
  method     text   not null check (method in ('cash','gcash','card')),
  total      numeric(12,2) not null,
  tendered   numeric(12,2),
  change_due numeric(12,2),
  cashier    text not null default current_actor(),
  at         timestamptz not null default now()
);
create trigger sales_audit after insert or update or delete on sales
  for each row execute function write_audit();

-- Returns wait here until an admin decides what happens to the goods.
create table returns (
  id          bigint generated always as identity primary key,
  receipt_no  text   not null references sales (receipt_no),
  order_id    bigint not null references orders (id),
  sku         text   not null references products (sku),
  batch_id    bigint not null references batches (id),
  qty         int    not null check (qty > 0),
  reason      text   not null,
  status      text   not null default 'pending' check (status in ('pending','approved','rejected')),
  outcome     text   check (outcome in ('restock','damaged','tester')),
  raised_by   text   not null default current_actor(),
  raised_at   timestamptz not null default now(),
  decided_by  text,
  decided_at  timestamptz
);

-- Testers and breakages leave the shelf too, and someone signs for them.
create table shrinkage (
  id        bigint generated always as identity primary key,
  sku       text not null references products (sku),
  batch_id  bigint references batches (id),
  qty       int  not null check (qty > 0),
  reason    text not null check (reason in ('tester','damaged')),
  signed_by text not null,
  at        timestamptz not null default now()
);

-- "The shop shelf is empty, bring stock from the back."
create table restock_tasks (
  id        bigint generated always as identity primary key,
  sku       text not null references products (sku),
  note      text,
  status    text not null default 'open' check (status in ('open','done')),
  raised_by text not null default current_actor(),
  raised_at timestamptz not null default now(),
  done_by   text,
  done_at   timestamptz
);
-- One open task per product: two cashiers tapping at once, or a sale's own
-- alert racing a manual tap, must not queue the same job twice.
create unique index restock_one_open_per_sku on restock_tasks (sku) where status = 'open';

-- ---------------------------------------------------------------------------
-- Blind cash count. The declared figure is stored before the expected figure
-- is computed, and a cashier can never read the expected one.
-- ---------------------------------------------------------------------------
create table cash_counts (
  id            bigint generated always as identity primary key,
  business_date date not null default current_date,
  cashier       text not null default current_actor(),
  declared      numeric(12,2) not null check (declared >= 0),
  expected      numeric(12,2),
  variance      numeric(12,2),
  flagged       boolean,
  counted_at    timestamptz not null default now(),
  unique (business_date, cashier)
);
create trigger cash_counts_audit after insert or update or delete on cash_counts
  for each row execute function write_audit();

-- ---------------------------------------------------------------------------
-- Reorder points. Lead time is door to door — shipping plus customs plus FDA
-- processing — because that is how long the shelf has to last.
-- ---------------------------------------------------------------------------
create table reorder_points (
  sku            text primary key references products (sku),
  avg_daily      numeric not null check (avg_daily >= 0),
  max_daily      numeric not null,
  avg_lead_days  numeric not null check (avg_lead_days >= 0),
  max_lead_days  numeric not null,
  months_cover   numeric not null default 3 check (months_cover > 0),
  safety_stock   numeric not null,
  reorder_at     numeric not null,
  reviewed_at    timestamptz not null default now(),
  constraint max_is_not_below_average check (max_daily >= avg_daily and max_lead_days >= avg_lead_days)
);

create table stock_counts (
  id         bigint generated always as identity primary key,
  sku        text not null references products (sku),
  counted    int  not null check (counted >= 0),
  on_system  int  not null,
  variance   int  not null,
  counted_by text not null default current_actor(),
  at         timestamptz not null default now()
);

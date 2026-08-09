-- Ms Beau Ave — demo persistence schema (members + orders)
-- Run this once in the Supabase SQL Editor (or let Claude run it via the
-- Supabase connector). Demo-grade RLS: the anon key may read and write these
-- two tables so the static storefront can persist without a backend.
-- Tighten these policies before any production use.

create table if not exists members (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text unique not null,
  qr text unique not null,
  origin text not null default 'app',
  points int not null default 0,
  tags text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  order_no text unique not null,
  member_id uuid references members(id),
  customer_name text not null default 'Guest',
  channel text not null,                -- 'online' | 'store'
  fulfillment text not null,            -- 'courier' | 'bopis' | 'counter'
  status text not null default 'pending',
  payment text,                         -- e.g. 'GCash (ref GC-123456)'
  lines jsonb not null,                 -- [{productId, name, qty, unitPrice, pick:[...]}]
  subtotal numeric not null default 0,
  discount numeric not null default 0,
  total numeric not null,
  points_redeemed int not null default 0,
  points_earned int not null default 0,
  tracking_no text,
  created_at timestamptz not null default now()
);

create index if not exists orders_created_at_idx on orders (created_at desc);
create index if not exists orders_member_idx on orders (member_id);

alter table members enable row level security;
alter table orders enable row level security;

-- Demo policies (anon read/write). Replace with authenticated policies in production.
drop policy if exists "demo anon select members" on members;
drop policy if exists "demo anon insert members" on members;
drop policy if exists "demo anon update members" on members;
drop policy if exists "demo anon select orders" on orders;
drop policy if exists "demo anon insert orders" on orders;
drop policy if exists "demo anon update orders" on orders;

create policy "demo anon select members" on members for select using (true);
create policy "demo anon insert members" on members for insert with check (true);
create policy "demo anon update members" on members for update using (true);
create policy "demo anon select orders" on orders for select using (true);
create policy "demo anon insert orders" on orders for insert with check (true);
create policy "demo anon update orders" on orders for update using (true);

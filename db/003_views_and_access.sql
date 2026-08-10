-- ============================================================================
-- MS BEAU AVE — what each screen reads, and who is allowed to read it
--
-- Screens read views, never ad-hoc queries, so the definition of "available"
-- or "overdue" lives in one place. Access is then enforced twice: the API
-- gates each route by role, and the policies here apply underneath in case a
-- route is ever declared wrongly.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Stock
-- ---------------------------------------------------------------------------

-- What resellers may buy: their pool only, and only batches with enough life
-- left that they will actually accept them.
create or replace view b2b_catalog as
select p.sku, p.name, p.brand, p.category, p.wholesale_price, p.srp,
       coalesce(sum(s.on_hand - s.committed), 0)::int as available
  from products p
  left join batches b
    on b.sku = p.sku
   and b.expiry > (current_date + make_interval(months => p.reseller_floor_months))::date
  left join stock s on s.batch_id = b.id and s.pool = 'b2b'
 where p.active
 group by p.sku, p.name, p.brand, p.category, p.wholesale_price, p.srp;

-- What the till may sell.
create or replace view shop_catalog as
select p.sku, p.name, p.brand, p.category, p.retail_price,
       coalesce(sum(s.on_hand - s.committed), 0)::int as on_shelf
  from products p
  left join batches b on b.sku = p.sku and b.expiry > current_date
  left join stock s on s.batch_id = b.id and s.pool = 'shop'
 where p.active
 group by p.sku, p.name, p.brand, p.category, p.retail_price;

-- The whole picture, for the people allowed to see it.
create or replace view stock_summary as
select p.sku, p.name, p.brand, p.category, p.unit_cost, p.wholesale_price,
       p.srp, p.retail_price, p.shelf_life_months, p.reseller_floor_months,
       p.shelf_min, p.abc_class, p.active,
       coalesce(p.alloc_b2b, 0.70)     as alloc_b2b,
       coalesce(p.alloc_shop, 0.20)    as alloc_shop,
       coalesce(p.alloc_reserve, 0.10) as alloc_reserve,
       coalesce(sum(s.on_hand - s.committed) filter (where s.pool = 'b2b'), 0)::int     as free_b2b,
       coalesce(sum(s.on_hand - s.committed) filter (where s.pool = 'shop'), 0)::int    as free_shop,
       coalesce(sum(s.on_hand - s.committed) filter (where s.pool = 'reserve'), 0)::int as free_reserve,
       coalesce(sum(s.committed) filter (where s.pool = 'b2b'), 0)::int                 as committed_b2b,
       coalesce(sum(s.on_hand), 0)::int                                                 as total_on_hand,
       (coalesce(sum(s.on_hand), 0) * p.unit_cost)::numeric(12,2)                       as value_at_cost
  from products p
  left join batches b on b.sku = p.sku and b.expiry > current_date
  left join stock s on s.batch_id = b.id
 group by p.sku;

create or replace view batch_detail as
select b.id as batch_id, b.sku, p.name, b.batch_no, b.expiry, b.qty_received, b.received_at,
       (b.expiry - current_date)                       as days_left,
       b.expiry <= current_date                        as expired,
       b.expiry > current_date
         and b.expiry <= current_date + 180            as ageing,
       b.expiry <= (current_date
         + make_interval(months => p.reseller_floor_months))::date as below_reseller_floor,
       coalesce(sum(s.on_hand - s.committed) filter (where s.pool = 'b2b'), 0)::int     as free_b2b,
       coalesce(sum(s.on_hand - s.committed) filter (where s.pool = 'shop'), 0)::int    as free_shop,
       coalesce(sum(s.on_hand - s.committed) filter (where s.pool = 'reserve'), 0)::int as free_reserve
  from batches b
  join products p on p.sku = b.sku
  left join stock s on s.batch_id = b.id
 group by b.id, b.sku, p.name, p.reseller_floor_months;

-- Six months out is the point where a batch still has enough life to clear
-- through bundles or a promotion, and little enough that waiting is a risk.
create or replace view ageing_stock as
select b.id as batch_id, b.sku, p.name, b.batch_no, b.expiry,
       (b.expiry - current_date) as days_left,
       sum(s.on_hand - s.committed)::int as qty,
       (sum(s.on_hand - s.committed) * p.unit_cost)::numeric(12,2) as value_at_risk,
       b.expiry <= (current_date
         + make_interval(months => p.reseller_floor_months))::date as shop_only
  from batches b
  join products p on p.sku = b.sku
  join stock s on s.batch_id = b.id
 where b.expiry > current_date and b.expiry <= current_date + 180
 group by b.id, b.sku, p.name, b.batch_no, b.expiry, p.unit_cost, p.reseller_floor_months
having sum(s.on_hand - s.committed) > 0;

create or replace view expired_stock as
select b.id as batch_id, b.sku, p.name, b.batch_no, b.expiry, s.pool,
       (s.on_hand - s.committed)::int as qty
  from batches b
  join products p on p.sku = b.sku
  join stock s on s.batch_id = b.id
 where b.expiry <= current_date and s.on_hand - s.committed > 0;

create or replace view shelf_alerts as
select p.sku, p.name, p.shelf_min,
       coalesce(sum(s.on_hand - s.committed), 0)::int as on_shelf
  from products p
  left join batches b on b.sku = p.sku and b.expiry > current_date
  left join stock s on s.batch_id = b.id and s.pool = 'shop'
 where p.active
 group by p.sku, p.name, p.shelf_min
having coalesce(sum(s.on_hand - s.committed), 0) <= p.shelf_min;

create or replace view movement_journal as
select m.id, m.at, b.sku, p.name, b.batch_no,
       m.from_pool, m.to_pool, m.qty, m.reason, m.actor
  from movements m
  join batches b on b.id = m.batch_id
  join products p on p.sku = b.sku;

-- ---------------------------------------------------------------------------
-- Buying
-- ---------------------------------------------------------------------------
create or replace view reorder_alerts as
with sellable as (
  select b.sku, coalesce(sum(s.on_hand - s.committed), 0)::int as qty
    from batches b join stock s on s.batch_id = b.id
   where b.expiry > current_date
   group by b.sku)
select p.sku, p.name, p.abc_class,
       coalesce(x.qty, 0) as in_stock,
       r.reorder_at, r.safety_stock,
       greatest(r.reorder_at - coalesce(x.qty, 0), 0)::numeric as short_by,
       least(
         r.months_cover * 30 * r.avg_daily,
         greatest(r.avg_daily * (p.shelf_life_months * 30
                  - p.reseller_floor_months * 365.0 / 12), 0)
       )::numeric as suggested_order
  from products p
  join reorder_points r on r.sku = p.sku
  left join sellable x on x.sku = p.sku
 where p.active and coalesce(x.qty, 0) <= r.reorder_at;

-- A reorder point set during a spike should not quietly govern for a year.
create or replace view reorder_points_due_review as
select sku, reviewed_at, now() - reviewed_at as age
  from reorder_points where reviewed_at < now() - interval '90 days';

-- ---------------------------------------------------------------------------
-- Orders and money
-- ---------------------------------------------------------------------------

-- The pick screen needs to know whose order it is and whether a prepaid
-- account has actually paid. It has no business with the amount, so the
-- balance resolves to null for the warehouse.
create or replace view order_board as
select o.id, o.channel, o.status, o.total, o.placed_at, o.placed_by, o.delivered_at,
       o.reseller_id, r.name as reseller, r.tier,
       i.id as invoice_id, i.status as invoice_status, i.due_on,
       i.status = 'open' and i.due_on < current_date as invoice_overdue,
       case when current_role_name() = 'admin'
            then (i.amount - i.paid - i.discount) end as balance
  from orders o
  left join resellers r on r.id = o.reseller_id
  left join invoices i on i.order_id = o.id
 where current_role_name() in ('admin','warehouse');

create or replace view ar_ageing as
select r.id as reseller_id, r.name, r.tier,
       sum(case when i.due_on >= current_date then i.amount - i.paid - i.discount else 0 end) as not_yet_due,
       sum(case when current_date - i.due_on between 1 and 30  then i.amount - i.paid - i.discount else 0 end) as overdue_1_30,
       sum(case when current_date - i.due_on between 31 and 60 then i.amount - i.paid - i.discount else 0 end) as overdue_31_60,
       sum(case when current_date - i.due_on > 60              then i.amount - i.paid - i.discount else 0 end) as overdue_60_plus,
       sum(i.amount - i.paid - i.discount) as total_owed
  from resellers r
  join invoices i on i.reseller_id = r.id and i.status = 'open'
 group by r.id, r.name, r.tier;

-- Too much of the receivable resting on one account is a risk worth naming
-- before it becomes a bad debt.
create or replace view ar_concentration as
with total as (
  select coalesce(sum(amount - paid - discount), 0) as book from invoices where status = 'open')
select r.id as reseller_id, r.name,
       amount_outstanding(r.id) as owed,
       t.book,
       case when t.book > 0 then round(amount_outstanding(r.id) / t.book, 4) else 0 end as share,
       t.book > 0 and amount_outstanding(r.id) / t.book > 0.15 as flagged
  from resellers r cross join total t
 where amount_outstanding(r.id) > 0;

create or replace view sales_by_channel as
select o.channel, o.placed_at::date as day,
       count(*)::int as orders, sum(o.total) as revenue
  from orders o where o.status = 'fulfilled'
 group by o.channel, o.placed_at::date;

-- What a cashier is allowed to see about their own drawer: the count they
-- declared, and nothing that would let them work backwards to the expected
-- figure before declaring it.
create or replace view my_cash_counts as
select business_date, declared, counted_at, expected is not null as reconciled
  from cash_counts where cashier = current_actor();

create or replace view cash_variance_watch as
select cashier, count(*)::int as flagged_counts, sum(variance) as net_variance,
       max(business_date) as most_recent
  from cash_counts
 where flagged and business_date > current_date - 90
 group by cashier
having count(*) >= 2;

-- ---------------------------------------------------------------------------
-- Row-level security
--
-- Writes go through the functions above, which run as their definer. Direct
-- table reads are what these policies govern.
-- ---------------------------------------------------------------------------
alter table products           enable row level security;
alter table batches            enable row level security;
alter table stock              enable row level security;
alter table movements          enable row level security;
alter table orders             enable row level security;
alter table order_lines        enable row level security;
alter table resellers          enable row level security;
alter table reseller_documents enable row level security;
alter table reseller_events    enable row level security;
alter table invoices           enable row level security;
alter table payments           enable row level security;
alter table sales              enable row level security;
alter table returns            enable row level security;
alter table shrinkage          enable row level security;
alter table restock_tasks      enable row level security;
alter table cash_counts        enable row level security;
alter table reorder_points     enable row level security;
alter table stock_counts       enable row level security;
alter table audit_log          enable row level security;
alter table app_users          enable row level security;

create policy staff_read_products on products for select
  using (current_role_name() in ('admin','warehouse','cashier'));
create policy admin_writes_products on products for all
  using (current_role_name() = 'admin') with check (current_role_name() = 'admin');

create policy staff_read_batches on batches for select
  using (current_role_name() in ('admin','warehouse','cashier'));
create policy staff_read_stock on stock for select
  using (current_role_name() in ('admin','warehouse','cashier'));
create policy staff_read_movements on movements for select
  using (current_role_name() in ('admin','warehouse'));

-- Resellers see their own orders and nobody else's.
create policy staff_read_orders on orders for select
  using (current_role_name() in ('admin','warehouse','cashier'));
create policy reseller_reads_own_orders on orders for select
  using (current_role_name() = 'reseller' and reseller_id = current_reseller());
create policy order_lines_follow_orders on order_lines for select
  using (exists (select 1 from orders o where o.id = order_id));

create policy staff_read_resellers on resellers for select
  using (current_role_name() in ('admin'));
create policy reseller_reads_self on resellers for select
  using (current_role_name() = 'reseller' and id = current_reseller());

create policy admin_reads_documents on reseller_documents for select
  using (current_role_name() = 'admin');
create policy reseller_reads_own_documents on reseller_documents for select
  using (current_role_name() = 'reseller' and reseller_id = current_reseller());
create policy admin_reads_events on reseller_events for select
  using (current_role_name() = 'admin');

create policy admin_reads_invoices on invoices for select
  using (current_role_name() = 'admin');
create policy reseller_reads_own_invoices on invoices for select
  using (current_role_name() = 'reseller' and reseller_id = current_reseller());
create policy admin_reads_payments on payments for select
  using (current_role_name() = 'admin');

create policy till_reads_sales on sales for select
  using (current_role_name() in ('admin','cashier'));
create policy till_reads_returns on returns for select
  using (current_role_name() in ('admin','cashier'));
create policy till_reads_shrinkage on shrinkage for select
  using (current_role_name() in ('admin','cashier'));
create policy staff_reads_restock on restock_tasks for select
  using (current_role_name() in ('admin','warehouse','cashier'));

-- Only the admin reads the reconciliation table itself; a cashier gets the
-- my_cash_counts view, which has no expected column to leak.
create policy admin_reads_cash_counts on cash_counts for select
  using (current_role_name() = 'admin');

create policy stock_staff_reads_reorder on reorder_points for select
  using (current_role_name() in ('admin','warehouse'));
create policy stock_staff_reads_counts on stock_counts for select
  using (current_role_name() in ('admin','warehouse'));
create policy admin_reads_audit on audit_log for select
  using (current_role_name() = 'admin');
create policy audit_is_appendable on audit_log for insert with check (true);
create policy admin_reads_users on app_users for select
  using (current_role_name() = 'admin');

-- ---------------------------------------------------------------------------
-- The role the application connects as. It can read what the policies allow
-- and call the functions; it owns nothing and can bypass nothing.
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'app_client') then
    create role app_client nologin;
  end if;
exception when insufficient_privilege then
  raise notice 'skipping app_client creation (no permission to create roles)';
end;
$$;

grant usage on schema public to app_client;
grant select on all tables in schema public to app_client;
grant insert, update on products to app_client;      -- admin product editor
grant insert on reseller_documents to app_client;
grant execute on all functions in schema public to app_client;
grant usage, select on all sequences in schema public to app_client;

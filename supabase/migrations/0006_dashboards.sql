-- ============================================================================
-- Ms Beau Ave — Phase 6: Dashboard data layer (Spec.md §9)
--
-- The §9 dashboards read from these views; several were already created by
-- earlier phases (ar_aging, ar_exposure, reorder_alerts, aging_stock_alerts,
-- retail_replenishment_alerts, cashier_variance_watch, rop_recalc_due,
-- training_compliance, expiring_documents, cycle counts). This migration adds
-- what §9 still needs: sales by channel, expiry risk value, days of cover per
-- A-item, the warehouse pick list, and attendance exceptions.
-- ============================================================================

-- Owner: sales by channel (§9.1)
create or replace view sales_by_channel as
select created_at::date as business_date, channel,
       count(*) as orders, sum(total) as revenue
  from orders
 where status = 'FULFILLED'
 group by created_at::date, channel;

-- Owner: ₱ of stock inside the 6-month expiry window (§9.1)
create or replace view expiry_risk_value as
select coalesce(sum(value_at_risk), 0)::numeric(14,2) as total_value_at_risk,
       coalesce(sum(qty_at_risk), 0)::bigint          as total_qty_at_risk,
       count(*)                                       as batches_at_risk
  from aging_stock_alerts;

-- Owner: days of cover per A-item (§9.1) — sellable stock ÷ avg daily sales.
create or replace view a_item_days_of_cover as
select p.sku, p.name,
       coalesce(sum(sl.qty_on_hand - sl.qty_committed), 0)::int as sellable_stock,
       r.avg_daily_sales,
       case when r.avg_daily_sales > 0
            then round(coalesce(sum(sl.qty_on_hand - sl.qty_committed), 0)
                       / r.avg_daily_sales, 1) end as days_of_cover,
       r.rop
  from products p
  join rop_settings r on r.sku = p.sku
  left join batches b on b.sku = p.sku and b.expiry_date > current_date
  left join stock_ledger sl on sl.batch_id = b.id
 where p.active and p.abc_class = 'A'
 group by p.sku, p.name, r.avg_daily_sales, r.rop;

-- Warehouse: today's FEFO pick list (§9.2) — committed lines of open orders,
-- batch-directed, oldest expiry first.
create or replace view warehouse_pick_list as
select o.id as order_id, o.channel, o.created_at, ol.sku, p.name,
       ol.batch_id, b.batch_number, b.expiry_date, ol.qty
  from orders o
  join order_lines ol on ol.order_id = o.id
  join batches b on b.id = ol.batch_id
  join products p on p.sku = ol.sku
 where o.status in ('PLACED','PICKING')
 order by o.created_at, ol.sku, b.expiry_date;

-- HR: attendance exceptions (§9.5) — flagged punches and shifts left open
-- past 16 hours.
create or replace view attendance_exceptions as
select a.id, a.employee_id, e.name, a.clock_in, a.clock_out, a.method, a.flags,
       case
         when cardinality(a.flags) > 0 then 'FLAGGED_PUNCH'
         when a.clock_out is null and a.clock_in < now() - interval '16 hours'
           then 'MISSING_CLOCK_OUT'
       end as exception_type
  from attendance a
  join employees e on e.id = a.employee_id
 where cardinality(a.flags) > 0
    or (a.clock_out is null and a.clock_in < now() - interval '16 hours');

grant select on sales_by_channel, expiry_risk_value, a_item_days_of_cover,
                warehouse_pick_list, attendance_exceptions to app_client;

// Phase 6 — Dashboard data layer (Spec.md §9)
import test from 'node:test';
import assert from 'node:assert/strict';
import { pool, asRole, uniq, createProduct, receiveBatch } from './helpers/db.js';

const db = pool();
test.after(() => db.end());

const FUTURE = '2027-06-30';

test('warehouse pick list shows committed FEFO lines of open orders (§9.2)', async () => {
  const sku = await createProduct(db, uniq('SKU'), { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  const nearNo = uniq('NEAR');
  await receiveBatch(db, sku, nearNo, '2026-10-15', 10);
  await receiveBatch(db, sku, uniq('FAR'), FUTURE, 10);

  const resellerId = (await db.query(
    `insert into resellers (name, tier, credit_limit, payment_terms_days, status, docs_verified)
     values ($1, 2, 100000, 30, 'ACTIVE', true) returning id`, [uniq('R')])).rows[0].id;
  const orderId = await asRole(db, 'B2B_AGENT', async (c) =>
    (await c.query(`select place_order('B2B', $1, $2) as id`,
      [JSON.stringify([{ sku, qty: 6 }]), resellerId])).rows[0].id);

  const picks = await db.query(
    'select batch_number, qty from warehouse_pick_list where order_id = $1', [orderId]);
  assert.deepEqual(picks.rows, [{ batch_number: nearNo, qty: 6 }]);

  await asRole(db, 'WAREHOUSE', (c) => c.query('select fulfill_order($1)', [orderId]));
  const gone = await db.query(
    'select 1 from warehouse_pick_list where order_id = $1', [orderId]);
  assert.equal(gone.rows.length, 0, 'fulfilled orders leave the pick list');
});

test('sales by channel and days-of-cover feed the owner dashboard (§9.1)', async () => {
  const sku = await createProduct(db, uniq('SKU'), { alloc_b2b: 0, alloc_retail: 1, alloc_safety: 0 });
  await receiveBatch(db, sku, uniq('B'), FUTURE, 100);
  await db.query(`update products set abc_class = 'A' where sku = $1`, [sku]);
  await asRole(db, 'WAREHOUSE', (c) => c.query('select set_rop($1, 4, 6, 10, 15)', [sku]));

  const orderId = await asRole(db, 'RETAIL_CASHIER', async (c) =>
    (await c.query(`select place_order('RETAIL', $1) as id`,
      [JSON.stringify([{ sku, qty: 2 }])])).rows[0].id);
  await asRole(db, 'RETAIL_CASHIER', (c) => c.query('select fulfill_order($1)', [orderId]));

  const sales = await db.query(
    `select revenue from sales_by_channel
      where business_date = current_date and channel = 'RETAIL'`);
  assert.ok(Number(sales.rows[0].revenue) >= 900, 'today has retail revenue');

  const cover = (await db.query(
    'select sellable_stock, days_of_cover from a_item_days_of_cover where sku = $1', [sku])).rows[0];
  assert.equal(cover.sellable_stock, 98);           // 100 received − 2 sold
  assert.equal(Number(cover.days_of_cover), 24.5);  // 98 ÷ 4/day
});

test('expiry risk value totals the aging window (§9.1)', async () => {
  const sku = await createProduct(db, uniq('SKU'), { unit_cost: 200 });
  await receiveBatch(db, sku, uniq('B'), '2026-10-20', 30);   // inside 6 months

  const risk = (await db.query('select * from expiry_risk_value')).rows[0];
  assert.ok(Number(risk.total_value_at_risk) >= 6000, '30 units × ₱200 counted');
  assert.ok(Number(risk.batches_at_risk) >= 1);
});

test('attendance exceptions: flagged punches surface for HR (§9.5)', async () => {
  const empId = (await db.query(
    `insert into employees (name, actor_name, role_type, pay_basis, base_pay)
     values ($1, $2, 'B2B_AGENT', 'MONTHLY', 20000) returning id`,
    [uniq('Emp'), uniq('actor')])).rows[0].id;
  await asRole(db, 'B2B_AGENT', (c) =>
    c.query(`select punch_clock($1, 'GPS', now(), 0, 0)`, [empId]));  // nowhere near a geofence

  const rows = await db.query(
    'select exception_type from attendance_exceptions where employee_id = $1', [empId]);
  assert.deepEqual(rows.rows.map((r) => r.exception_type), ['FLAGGED_PUNCH']);
});

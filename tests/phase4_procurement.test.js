// Phase 4 — Procurement & ROP engine (Spec.md §3.4, §6.3)
import test from 'node:test';
import assert from 'node:assert/strict';
import { pool, asRole, uniq, createProduct, receiveBatch, monthsOut } from './helpers/db.js';

const db = pool();
test.after(() => db.end());

const FUTURE = monthsOut(24);

test("§6.3 worked example: imported serum — safety stock 525, ROP 1,125", async () => {
  const r = await db.query('select * from rop_formula(10, 15, 60, 75)');
  assert.equal(Number(r.rows[0].safety_stock), 525); // (15×75) − (10×60)
  assert.equal(Number(r.rows[0].rop), 1125);         // (10×60) + 525
});

test('set_rop persists the calculation and reorder alerts apply the shelf-life cap (§6.3)', async () => {
  // 13-month shelf life: a fresh batch stays above the 12-month reseller floor
  // for 13×30 − 365 = 25 days → cap = 10/day × 25 = 250 units.
  const sku = await createProduct(db, uniq('SERUM'), { shelf_life_months: 13 });
  await receiveBatch(db, sku, uniq('B'), FUTURE, 100);

  await asRole(db, 'WAREHOUSE', (c) =>
    c.query('select set_rop($1, 10, 15, 60, 75)', [sku]));

  const s = await db.query('select safety_stock, rop from rop_settings where sku = $1', [sku]);
  assert.equal(Number(s.rows[0].safety_stock), 525);
  assert.equal(Number(s.rows[0].rop), 1125);

  const alert = await db.query('select * from reorder_alerts where sku = $1', [sku]);
  assert.equal(alert.rows.length, 1, '100 in stock vs ROP 1,125 → alert');
  assert.equal(Number(alert.rows[0].shortfall), 1025);
  assert.equal(Number(alert.rows[0].suggested_order_qty), 250,
    'suggestion capped by what sells before the 12-month floor');

  // Plenty of stock → no alert.
  await receiveBatch(db, sku, uniq('B'), FUTURE, 2000);
  const quiet = await db.query('select 1 from reorder_alerts where sku = $1', [sku]);
  assert.equal(quiet.rows.length, 0);
});

test('quarterly ROP recalculation prompt (§6.3)', async () => {
  const sku = await createProduct(db, uniq('SKU'));
  await asRole(db, 'WAREHOUSE', (c) => c.query('select set_rop($1, 5, 8, 30, 40)', [sku]));

  assert.equal(
    (await db.query('select 1 from rop_recalc_due where sku = $1', [sku])).rows.length, 0);
  await db.query(
    `update rop_settings set last_recalc = now() - interval '100 days' where sku = $1`, [sku]);
  assert.equal(
    (await db.query('select 1 from rop_recalc_due where sku = $1', [sku])).rows.length, 1);
});

test('ABC segmentation from trailing revenue (§6.3)', async () => {
  // Dominant revenues so concurrent test data cannot move the thresholds:
  // 8M (80% → A), 1.5M (95% → B), 0.5M (→ C).
  const mk = async (price) => {
    const sku = await createProduct(db, uniq('ABC'), {
      alloc_b2b: 0, alloc_retail: 1, alloc_safety: 0,
      srp: price, retail_price: price,
    });
    await receiveBatch(db, sku, uniq('B'), FUTURE, 5);
    const orderId = await asRole(db, 'RETAIL_CASHIER', async (c) =>
      (await c.query(`select place_order('RETAIL', $1) as id`,
        [JSON.stringify([{ sku, qty: 1, unit_price: price }])])).rows[0].id);
    await asRole(db, 'RETAIL_CASHIER', (c) => c.query('select fulfill_order($1)', [orderId]));
    return sku;
  };
  const [a, b, c] = [await mk(8000000), await mk(1500000), await mk(500000)];

  await asRole(db, 'OWNER_ADMIN', (cl) => cl.query('select recompute_abc(90)'));

  const classes = await db.query(
    'select sku, abc_class from products where sku in ($1, $2, $3) order by srp desc',
    [a, b, c]);
  assert.deepEqual(classes.rows.map((r) => r.abc_class), ['A', 'B', 'C']);
});

test('aging stock report: batches inside the 6-month window, valued, floor-flagged (§3.1)', async () => {
  const sku = await createProduct(db, uniq('SKU'), { unit_cost: 120 });
  const soonNo = uniq('SOON');
  await receiveBatch(db, sku, soonNo, '2026-11-10', 40);   // ~3 months out
  await receiveBatch(db, sku, uniq('FAR'), monthsOut(17), 40);

  const rows = await db.query(
    'select batch_number, qty_at_risk, value_at_risk, below_reseller_floor from aging_stock_alerts where sku = $1',
    [sku]);
  assert.equal(rows.rows.length, 1, 'only the soon-to-expire batch is at risk');
  assert.equal(rows.rows[0].batch_number, soonNo);
  assert.equal(rows.rows[0].qty_at_risk, 40);
  assert.equal(Number(rows.rows[0].value_at_risk), 4800); // 40 × ₱120
  assert.equal(rows.rows[0].below_reseller_floor, true);
});

test('cycle count records variance against system quantity (§3.1)', async () => {
  const sku = await createProduct(db, uniq('SKU'));
  await receiveBatch(db, sku, uniq('B'), FUTURE, 50);

  const row = await asRole(db, 'WAREHOUSE', async (c) =>
    (await c.query('select (record_cycle_count($1, 47)).*', [sku])).rows[0]);
  assert.equal(row.system_qty, 50);
  assert.equal(row.counted_qty, 47);
  assert.equal(row.variance, -3);
});

test('PO lifecycle captures actual lead time incl. customs/FDA legs (§3.4)', async () => {
  const vendorId = (await db.query(
    `insert into vendors (name, avg_lead_time_days, max_lead_time_days)
     values ($1, 60, 75) returning id`, [uniq('Vendor')])).rows[0].id;
  const sku = await createProduct(db, uniq('SKU'));

  const poId = (await db.query(
    `insert into purchase_orders (vendor_id, fda_status)
     values ($1, 'NOTIFICATION_FILED') returning id`, [vendorId])).rows[0].id;
  await db.query(`insert into po_lines (po_id, sku, qty, unit_cost) values ($1, $2, 1000, 90)`,
    [poId, sku]);

  await asRole(db, 'WAREHOUSE', async (c) => {
    await c.query(`select advance_po_status($1, 'SENT', current_date - 70)`, [poId]);
    await c.query(`select advance_po_status($1, 'IN_TRANSIT', current_date - 50)`, [poId]);
    await c.query(`select advance_po_status($1, 'CUSTOMS', current_date - 10)`, [poId]);
    await c.query(`select advance_po_status($1, 'RECEIVED', current_date)`, [poId]);
  });

  const po = await db.query(
    'select status, lead_time_actual from purchase_orders where id = $1', [poId]);
  assert.equal(po.rows[0].status, 'RECEIVED');
  assert.equal(po.rows[0].lead_time_actual, 70); // shipping + customs, door to door

  // Receiving links the batch to its PO for traceability.
  const batchId = await asRole(db, 'WAREHOUSE', async (c) =>
    (await c.query('select receive_batch($1, $2, $3, 1000, $4) as id',
      [sku, uniq('B'), FUTURE, poId])).rows[0].id);
  const link = await db.query('select vendor_po_id from batches where id = $1', [batchId]);
  assert.equal(Number(link.rows[0].vendor_po_id), Number(poId));
});

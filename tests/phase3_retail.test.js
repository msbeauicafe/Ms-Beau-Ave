// Phase 3 — Retail sync & cash controls (Spec.md §3.2, §6.6, §8)
import test from 'node:test';
import assert from 'node:assert/strict';
import { pool, asRole, uniq, createProduct, receiveBatch, ledger, monthsOut } from './helpers/db.js';

const db = pool();
test.after(() => db.end());

const FUTURE = monthsOut(24);

async function retailSku(db, qty, overrides = {}) {
  const sku = await createProduct(db, uniq('SKU'), {
    alloc_b2b: 0, alloc_retail: 1, alloc_safety: 0, ...overrides,
  });
  const batchId = await receiveBatch(db, sku, uniq('B'), FUTURE, qty);
  return { sku, batchId };
}

const ingest = (eventId, lines, actor) =>
  asRole(db, 'RETAIL_CASHIER', async (c) =>
    (await c.query('select ingest_pos_sale($1, $2) as id',
      [eventId, JSON.stringify(lines)])).rows[0].id, { actor });

test('POS webhook ingestion deducts Retail Shelf only, idempotent on replay (§3.2, §8)', async () => {
  const { sku, batchId } = await retailSku(db, 20);
  const eventId = uniq('EVT');

  const orderId = await ingest(eventId, [{ sku, qty: 3 }], 'cashier-anna');
  assert.equal((await ledger(db, batchId)).RETAIL_SHELF.onHand, 17);

  // Queue-and-retry redelivers the same event: no double deduction.
  const replayId = await ingest(eventId, [{ sku, qty: 3 }], 'cashier-anna');
  assert.equal(Number(replayId), Number(orderId));
  assert.equal((await ledger(db, batchId)).RETAIL_SHELF.onHand, 17);

  // A genuinely new sale deducts again.
  await ingest(uniq('EVT'), [{ sku, qty: 2 }], 'cashier-anna');
  assert.equal((await ledger(db, batchId)).RETAIL_SHELF.onHand, 15);
});

test('replenishment alert fires when shelf hits the per-SKU minimum (§3.2)', async () => {
  const { sku } = await retailSku(db, 8, { retail_min_qty: 5 });

  const before = await db.query(
    'select * from retail_replenishment_alerts where sku = $1', [sku]);
  assert.equal(before.rows.length, 0, '8 on shelf, min 5 — no alert yet');

  await ingest(uniq('EVT'), [{ sku, qty: 4 }], 'cashier-anna');
  const after = await db.query(
    'select shelf_available from retail_replenishment_alerts where sku = $1', [sku]);
  assert.equal(after.rows.length, 1, '4 on shelf, min 5 — alert');
  assert.equal(after.rows[0].shelf_available, 4);
});

test('tester/damage log deducts shelf stock and records the signed entry (§3.2)', async () => {
  const { sku, batchId } = await retailSku(db, 10);

  await asRole(db, 'RETAIL_CASHIER', (c) =>
    c.query(`select log_tester($1, $2, 2, 'AM', 'TESTER', 'anna')`, [sku, batchId]));

  assert.equal((await ledger(db, batchId)).RETAIL_SHELF.onHand, 8);
  const logRows = await db.query(
    'select qty, reason, signed_by from tester_logs where batch_id = $1', [batchId]);
  assert.deepEqual(logRows.rows, [{ qty: 2, reason: 'TESTER', signed_by: 'anna' }]);
  const move = await db.query(
    `select count(*)::int as n from stock_movements where batch_id = $1 and reason = 'TESTER'`,
    [batchId]);
  assert.equal(move.rows[0].n, 1);
});

test('returns: RESTOCK goes back on the shelf, DAMAGED is logged and never restocked', async () => {
  const { sku, batchId } = await retailSku(db, 10);
  const orderId = await ingest(uniq('EVT'), [{ sku, qty: 4 }], 'cashier-anna');
  assert.equal((await ledger(db, batchId)).RETAIL_SHELF.onHand, 6);

  await asRole(db, 'RETAIL_CASHIER', (c) =>
    c.query(`select process_retail_return($1, $2, $3, 1, 'wrong shade', 'RESTOCK')`,
      [orderId, sku, batchId]));
  assert.equal((await ledger(db, batchId)).RETAIL_SHELF.onHand, 7);

  await asRole(db, 'RETAIL_CASHIER', (c) =>
    c.query(`select process_retail_return($1, $2, $3, 1, 'leaking pump', 'DAMAGED', 'anna')`,
      [orderId, sku, batchId]));
  assert.equal((await ledger(db, batchId)).RETAIL_SHELF.onHand, 7); // unchanged
  const dmg = await db.query(
    `select count(*)::int as n from tester_logs
      where batch_id = $1 and reason = 'DAMAGED'`, [batchId]);
  assert.equal(dmg.rows[0].n, 1);

  // Cannot return more than was sold.
  await assert.rejects(
    asRole(db, 'RETAIL_CASHIER', (c) =>
      c.query(`select process_retail_return($1, $2, $3, 3, 'nope', 'RESTOCK')`,
        [orderId, sku, batchId])),
    /exceeds remaining sold qty/);
});

test('blind cash drops: cashier never sees POS total; variance auto-flags; repeats surface (§6.6)', async () => {
  const { sku } = await retailSku(db, 50);
  const honest = uniq('cashier-honest');
  const shaky = uniq('cashier-shaky');

  // Today's sales: honest rings up 2 × ₱450, shaky rings up 2 × ₱450.
  await ingest(uniq('EVT'), [{ sku, qty: 2 }], honest);
  await ingest(uniq('EVT'), [{ sku, qty: 2 }], shaky);

  // Blind submission: declared count only, POS total invisible.
  await asRole(db, 'RETAIL_CASHIER', (c) =>
    c.query('select submit_cash_drop(900)'), { actor: honest });
  await asRole(db, 'RETAIL_CASHIER', (c) =>
    c.query('select submit_cash_drop(400)'), { actor: shaky });

  // Before reconciliation the drop rows carry no POS total, and a cashier
  // reading through the portal role sees only their own declared amounts.
  await asRole(db, 'RETAIL_CASHIER', async (c) => {
    const direct = await c.query('select count(*)::int as n from cash_drops');
    assert.equal(direct.rows[0].n, 0, 'cashiers cannot read the cash_drops table');
    const mine = await c.query('select * from my_cash_drops');
    assert.equal(mine.rows.length, 1);
    assert.equal(Number(mine.rows[0].declared_amount), 400);
    assert.ok(!('pos_total' in mine.rows[0]), 'POS total is never exposed to cashiers');
  }, { actor: shaky, rls: true });

  // Same-day reconciliation by finance: ±100 threshold.
  await asRole(db, 'HR_FINANCE', (c) =>
    c.query('select reconcile_cash_drops(current_date, 100)'));

  const drops = await db.query(
    `select cashier, pos_total, variance, flagged from cash_drops
      where cashier in ($1, $2) order by cashier = $1 desc`, [honest, shaky]);
  assert.equal(Number(drops.rows[0].pos_total), 900);
  assert.equal(drops.rows[0].flagged, false);
  assert.equal(Number(drops.rows[1].variance), -500);
  assert.equal(drops.rows[1].flagged, true);

  // A second flagged day puts the cashier on the finance watch list.
  await asRole(db, 'RETAIL_CASHIER', (c) =>
    c.query('select submit_cash_drop(300, current_date - 1)'), { actor: shaky });
  await asRole(db, 'HR_FINANCE', (c) =>
    c.query('select reconcile_cash_drops(current_date - 1, 100)'));

  const watch = await db.query(
    'select flagged_drops_90d from cashier_variance_watch where cashier = $1', [shaky]);
  assert.equal(Number(watch.rows[0].flagged_drops_90d), 2);
  const clean = await db.query(
    'select 1 from cashier_variance_watch where cashier = $1', [honest]);
  assert.equal(clean.rows.length, 0);
});

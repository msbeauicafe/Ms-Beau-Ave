// Phase 1 — Core IMS acceptance tests (Spec.md §10 "done when" + §8)
// Runs against a real Postgres via scripts/test-ims.sh.
import test from 'node:test';
import assert from 'node:assert/strict';
import { pool, asRole, uniq, createProduct, receiveBatch, ledger } from './helpers/db.js';

const db = pool();
test.after(() => db.end());

const FUTURE = '2027-06-30';

/** An ACTIVE, verified Tier-2 reseller with room to order (credit engine satisfied). */
async function activeReseller(db, overrides = {}) {
  return asRole(db, 'OWNER_ADMIN', async (c) => {
    const r = await c.query(
      `insert into resellers (name, tier, credit_limit, payment_terms_days, status, docs_verified)
       values ($1, $2, $3, $4, 'ACTIVE', true) returning id`,
      [uniq('Reseller'), overrides.tier ?? 2, overrides.credit_limit ?? 1000000,
       overrides.payment_terms_days ?? 30]);
    return r.rows[0].id;
  });
}

test('receiving auto-splits 70/20/10 with largest-remainder rounding', async () => {
  const sku = await createProduct(db, uniq('SKU'));
  const batchId = await receiveBatch(db, sku, uniq('B'), FUTURE, 100);
  assert.deepEqual(await ledger(db, batchId), {
    B2B_POOL:     { onHand: 70, committed: 0 },
    RETAIL_SHELF: { onHand: 20, committed: 0 },
    SAFETY:       { onHand: 10, committed: 0 },
  });

  // 33 units → exact 23.1 / 6.6 / 3.3 → floors 23/6/3, leftover goes to the
  // largest remainder (retail) → 23/7/3, summing exactly to 33.
  const b2 = await receiveBatch(db, sku, uniq('B'), FUTURE, 33);
  const l2 = await ledger(db, b2);
  assert.equal(l2.B2B_POOL.onHand, 23);
  assert.equal(l2.RETAIL_SHELF.onHand, 7);
  assert.equal(l2.SAFETY.onHand, 3);
});

test('per-SKU allocation ratio override is honored', async () => {
  const sku = await createProduct(db, uniq('SKU'), {
    alloc_b2b: 0.5, alloc_retail: 0.5, alloc_safety: 0,
  });
  const batchId = await receiveBatch(db, sku, uniq('B'), FUTURE, 10);
  const l = await ledger(db, batchId);
  assert.equal(l.B2B_POOL.onHand, 5);
  assert.equal(l.RETAIL_SHELF.onHand, 5);
  assert.equal(l.SAFETY, undefined);
});

test('FEFO pick proposes oldest viable batch first and skips expired stock', async () => {
  const sku = await createProduct(db, uniq('SKU'), { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  await receiveBatch(db, sku, uniq('EXPIRED'), '2026-01-15', 50); // already expired
  await receiveBatch(db, sku, uniq('FAR'),  '2027-12-01', 40);
  const nearNo = uniq('NEAR');
  await receiveBatch(db, sku, nearNo, '2026-10-01', 30);

  const picks = await asRole(db, 'WAREHOUSE', async (c) =>
    (await c.query(`select * from fefo_pick('B2B_POOL', $1, 50)`, [sku])).rows);

  assert.equal(picks.length, 2);
  assert.equal(picks[0].batch_number, nearNo); // oldest viable first
  assert.equal(picks[0].pick_qty, 30);
  assert.equal(picks[1].pick_qty, 20);         // remainder from the later batch
});

test('order placement commits stock FEFO and hides it from availability', async () => {
  const sku = await createProduct(db, uniq('SKU'), { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  const nearBatch = await receiveBatch(db, sku, uniq('NEAR'), '2026-11-01', 10);
  await receiveBatch(db, sku, uniq('FAR'), '2027-11-01', 10);
  const resellerId = await activeReseller(db);

  const before = await db.query(
    'select available from b2b_available_stock where sku = $1', [sku]);
  assert.equal(before.rows[0].available, 20);

  const orderId = await asRole(db, 'B2B_AGENT', async (c) =>
    (await c.query(`select place_order('B2B', $1, $2) as id`,
      [JSON.stringify([{ sku, qty: 12 }]), resellerId])).rows[0].id);

  // FEFO: the near batch is fully committed before the far one is touched.
  const near = await ledger(db, nearBatch);
  assert.equal(near.B2B_POOL.committed, 10);

  const after = await db.query(
    'select available from b2b_available_stock where sku = $1', [sku]);
  assert.equal(after.rows[0].available, 8); // 20 - 12 committed

  // Retail pool untouched and retail channel cannot see or take B2B stock.
  await assert.rejects(
    asRole(db, 'RETAIL_CASHIER', (c) =>
      c.query(`select place_order('RETAIL', $1)`, [JSON.stringify([{ sku, qty: 1 }])])),
    /INSUFFICIENT_STOCK/);

  // Fulfilment drains on-hand and committed together; ledger invariants hold.
  await asRole(db, 'WAREHOUSE', (c) => c.query('select fulfill_order($1)', [orderId]));
  const shipped = await ledger(db, nearBatch);
  assert.deepEqual(shipped.B2B_POOL, { onHand: 0, committed: 0 });
});

test('§8 concurrency: two simultaneous orders for the last 5 units — exactly one succeeds', async () => {
  const sku = await createProduct(db, uniq('SKU'), { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  await receiveBatch(db, sku, uniq('B'), FUTURE, 5);
  const [r1, r2] = [await activeReseller(db), await activeReseller(db)];

  const order = (resellerId) => asRole(db, 'B2B_AGENT', (c) =>
    c.query(`select place_order('B2B', $1, $2) as id`,
      [JSON.stringify([{ sku, qty: 5 }]), resellerId]));

  const results = await Promise.allSettled([order(r1), order(r2)]);
  const ok = results.filter((r) => r.status === 'fulfilled');
  const failed = results.filter((r) => r.status === 'rejected');

  assert.equal(ok.length, 1, 'exactly one order must win the last units');
  assert.equal(failed.length, 1);
  assert.match(failed[0].reason.message, /INSUFFICIENT_STOCK/);

  // The loser must leave nothing behind: no orphan order, committed == 5 total.
  const l = await db.query(
    `select sum(sl.qty_committed)::int as committed
       from stock_ledger sl join batches b on b.id = sl.batch_id where b.sku = $1`, [sku]);
  assert.equal(l.rows[0].committed, 5);
  const orders = await db.query(
    `select count(*)::int as n from orders o
      where exists (select 1 from order_lines ol where ol.order_id = o.id and ol.sku = $1)`, [sku]);
  assert.equal(orders.rows[0].n, 1);
});

test('cancelling an order releases the committed lock', async () => {
  const sku = await createProduct(db, uniq('SKU'), { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  const batchId = await receiveBatch(db, sku, uniq('B'), FUTURE, 8);
  const resellerId = await activeReseller(db);

  const orderId = await asRole(db, 'B2B_AGENT', async (c) =>
    (await c.query(`select place_order('B2B', $1, $2) as id`,
      [JSON.stringify([{ sku, qty: 8 }]), resellerId])).rows[0].id);
  assert.equal((await ledger(db, batchId)).B2B_POOL.committed, 8);

  await asRole(db, 'B2B_AGENT', (c) => c.query('select cancel_order($1)', [orderId]));
  assert.deepEqual((await ledger(db, batchId)).B2B_POOL, { onHand: 8, committed: 0 });
});

test('safety buffer releases only via explicit admin action (§6.2)', async () => {
  const sku = await createProduct(db, uniq('SKU'));
  const batchId = await receiveBatch(db, sku, uniq('B'), FUTURE, 100); // 10 in SAFETY

  await assert.rejects(
    asRole(db, 'WAREHOUSE', (c) =>
      c.query(`select transfer_stock($1, 'SAFETY', 'RETAIL_SHELF', 5)`, [batchId])),
    /FORBIDDEN/);

  await asRole(db, 'OWNER_ADMIN', (c) =>
    c.query(`select transfer_stock($1, 'SAFETY', 'RETAIL_SHELF', 5)`, [batchId]));
  const l = await ledger(db, batchId);
  assert.equal(l.SAFETY.onHand, 5);
  assert.equal(l.RETAIL_SHELF.onHand, 25);
});

test('MAP enforcement: retail price below reseller SRP is rejected at save (§6.5)', async () => {
  await assert.rejects(
    createProduct(db, uniq('SKU'), { srp: 500, retail_price: 450 }),
    /map_enforcement/);
});

test('audit log is written for stock changes and is immutable (§8)', async () => {
  const sku = await createProduct(db, uniq('SKU'));
  await receiveBatch(db, sku, uniq('B'), FUTURE, 10);

  const rows = await db.query(
    `select count(*)::int as n from audit_log where entity = 'stock_ledger'`);
  assert.ok(rows.rows[0].n > 0, 'ledger inserts must be audited');

  await assert.rejects(db.query('update audit_log set actor = $1 where true', ['tamper']),
    /append-only/);
  await assert.rejects(db.query('delete from audit_log where true'), /append-only/);
  await assert.rejects(
    db.query(`update stock_movements set qty = 999 where true`), /append-only/);
});

test('RLS: resellers cannot see warehouse totals or other resellers\' orders (§2, §8)', async () => {
  const sku = await createProduct(db, uniq('SKU'), { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  await receiveBatch(db, sku, uniq('B'), FUTURE, 50);
  const mine = await activeReseller(db);
  const other = await activeReseller(db);

  const myOrder = await asRole(db, 'B2B_AGENT', async (c) =>
    (await c.query(`select place_order('B2B', $1, $2) as id`,
      [JSON.stringify([{ sku, qty: 2 }]), mine])).rows[0].id);
  const otherOrder = await asRole(db, 'B2B_AGENT', async (c) =>
    (await c.query(`select place_order('B2B', $1, $2) as id`,
      [JSON.stringify([{ sku, qty: 3 }]), other])).rows[0].id);

  await asRole(db, 'RESELLER', async (c) => {
    // Stock ledger and movements: zero rows visible.
    assert.equal((await c.query('select count(*)::int as n from stock_ledger')).rows[0].n, 0);
    assert.equal((await c.query('select count(*)::int as n from stock_movements')).rows[0].n, 0);
    // Orders: own order visible, the other reseller's is not.
    const seen = await c.query('select id from orders order by id');
    const ids = seen.rows.map((r) => Number(r.id));
    assert.ok(ids.includes(Number(myOrder)), 'own order must be visible');
    assert.ok(!ids.includes(Number(otherOrder)), "other resellers' orders must be hidden");
    // Catalog view still works — B2B availability only.
    const cat = await c.query('select available from b2b_available_stock where sku = $1', [sku]);
    assert.equal(cat.rows[0].available, 45);
  }, { resellerId: mine, rls: true });
});

test('resellers may only place orders for themselves', async () => {
  const sku = await createProduct(db, uniq('SKU'), { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  await receiveBatch(db, sku, uniq('B'), FUTURE, 10);
  const mine = await activeReseller(db);
  const other = await activeReseller(db);

  await assert.rejects(
    asRole(db, 'RESELLER', (c) =>
      c.query(`select place_order('B2B', $1, $2)`,
        [JSON.stringify([{ sku, qty: 1 }]), other]), { resellerId: mine }),
    /FORBIDDEN/);

  await asRole(db, 'RESELLER', (c) =>
    c.query(`select place_order('B2B', $1, $2)`,
      [JSON.stringify([{ sku, qty: 1 }]), mine]), { resellerId: mine });
});

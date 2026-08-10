// Phase 2 — B2B credit engine acceptance tests (Spec.md §6.1, §10)
// "Done when: a past-due Tier 2 reseller is auto-blocked and cannot place an order."
import test from 'node:test';
import assert from 'node:assert/strict';
import { pool, asRole, uniq, createProduct, receiveBatch, monthsOut } from './helpers/db.js';

const db = pool();
test.after(() => db.end());

const FUTURE = monthsOut(24);

async function newReseller(db, overrides = {}) {
  return asRole(db, 'OWNER_ADMIN', async (c) => {
    const r = await c.query(
      `insert into resellers (name, tier, credit_limit, payment_terms_days, status, docs_verified)
       values ($1, $2, $3, $4, $5, $6) returning id`,
      [uniq('Reseller'), overrides.tier ?? 2, overrides.credit_limit ?? 1000000,
       overrides.payment_terms_days ?? 30, overrides.status ?? 'ACTIVE',
       overrides.docs_verified ?? true]);
    return r.rows[0].id;
  });
}

async function stockedSku(db, qty = 1000) {
  const sku = await createProduct(db, uniq('SKU'), {
    alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0,
  });
  await receiveBatch(db, sku, uniq('B'), FUTURE, qty);
  return sku;
}

const placeOrder = (resellerId, lines) =>
  asRole(db, 'B2B_AGENT', async (c) =>
    (await c.query(`select place_order('B2B', $1, $2) as id`,
      [JSON.stringify(lines), resellerId])).rows[0].id);

const invoiceFor = async (orderId) =>
  (await db.query('select * from invoices where order_id = $1', [orderId])).rows[0];

test('ACCEPTANCE §10: past-due Tier 2 reseller is auto-blocked and cannot order', async () => {
  const sku = await stockedSku(db);
  const resellerId = await newReseller(db, { tier: 2 });

  const orderId = await placeOrder(resellerId, [{ sku, qty: 10 }]);
  const inv = await invoiceFor(orderId);
  assert.equal(inv.status, 'OPEN');

  // Time passes: the invoice goes past due.
  await db.query(`update invoices set due_date = current_date - 5 where id = $1`, [inv.id]);

  await assert.rejects(placeOrder(resellerId, [{ sku, qty: 1 }]), /RESELLER_BLOCKED/);

  // The AR job persists the sticky block flag + event (its own transaction —
  // it can never be rolled back by a failing order).
  const n = await asRole(db, 'HR_FINANCE', async (c) =>
    (await c.query('select refresh_reseller_blocks($1) as n', [resellerId])).rows[0].n);
  assert.equal(n, 1);

  const r = await db.query('select blocked, blocked_reason from resellers where id = $1', [resellerId]);
  assert.equal(r.rows[0].blocked, true);
  assert.equal(r.rows[0].blocked_reason, 'PAST_DUE_INVOICE');
  const ev = await db.query(
    `select count(*)::int as n from reseller_events
      where reseller_id = $1 and event_type = 'AUTO_BLOCK'`, [resellerId]);
  assert.equal(ev.rows[0].n, 1);

  // Curing the past-due invoice lifts the block automatically…
  await asRole(db, 'HR_FINANCE', (c) =>
    c.query('select record_payment($1, $2)', [inv.id, inv.amount]));
  const cured = await db.query('select blocked from resellers where id = $1', [resellerId]);
  assert.equal(cured.rows[0].blocked, false);
  await placeOrder(resellerId, [{ sku, qty: 1 }]); // …and ordering works again
});

test('credit-limit breach blocks the order (§6.1)', async () => {
  const sku = await stockedSku(db); // wholesale 250
  const resellerId = await newReseller(db, { tier: 2, credit_limit: 1000 });

  await placeOrder(resellerId, [{ sku, qty: 3 }]);              // 750 outstanding
  await assert.rejects(
    placeOrder(resellerId, [{ sku, qty: 2 }]),                  // would be 1250 > 1000
    /CREDIT_LIMIT_EXCEEDED/);
  await placeOrder(resellerId, [{ sku, qty: 1 }]);              // 1000 == limit is fine
});

test('Tier 1 is prepayment-only: invoice due at placement, no shipment until paid (§6.1)', async () => {
  const sku = await stockedSku(db);
  const resellerId = await newReseller(db, { tier: 1, credit_limit: 0, payment_terms_days: 0 });

  const orderId = await placeOrder(resellerId, [{ sku, qty: 4 }]);
  const inv = await invoiceFor(orderId);
  assert.equal(new Date(inv.due_date).toDateString(), new Date(inv.issued_at).toDateString());

  await assert.rejects(
    asRole(db, 'WAREHOUSE', (c) => c.query('select fulfill_order($1)', [orderId])),
    /PREPAYMENT_REQUIRED/);

  await asRole(db, 'HR_FINANCE', (c) =>
    c.query('select record_payment($1, $2)', [inv.id, inv.amount]));
  await asRole(db, 'WAREHOUSE', (c) => c.query('select fulfill_order($1)', [orderId]));
  const done = await db.query('select status from orders where id = $1', [orderId]);
  assert.equal(done.rows[0].status, 'FULFILLED');
});

test('2/10 net 30: 2% early-payment discount auto-applied at recording (§6.1)', async () => {
  const sku = await stockedSku(db);
  const resellerId = await newReseller(db, { tier: 2, payment_terms_days: 30 });

  const orderId = await placeOrder(resellerId, [{ sku, qty: 10 }]); // 2500.00
  const inv = await invoiceFor(orderId);
  assert.equal(Number(inv.amount), 2500);

  // Paying 98% within 10 days settles the invoice in full.
  await asRole(db, 'HR_FINANCE', (c) =>
    c.query('select record_payment($1, $2, current_date + 5)', [inv.id, 2450]));

  const paid = await invoiceFor(orderId);
  assert.equal(paid.status, 'PAID');
  assert.equal(Number(paid.discount_applied), 50); // 2% of 2500
  assert.equal(Number(paid.paid_amount), 2450);
});

test('no early-payment discount outside the 10-day window', async () => {
  const sku = await stockedSku(db);
  const resellerId = await newReseller(db, { tier: 2, payment_terms_days: 30 });
  const orderId = await placeOrder(resellerId, [{ sku, qty: 10 }]);
  const inv = await invoiceFor(orderId);

  await asRole(db, 'HR_FINANCE', (c) =>
    c.query('select record_payment($1, $2, current_date + 15)', [inv.id, 2450]));
  const partial = await invoiceFor(orderId);
  assert.equal(partial.status, 'OPEN');                 // 2450 < 2500, no discount
  assert.equal(Number(partial.discount_applied), 0);
});

test('auto-demote: two late payments within a quarter drop one tier (§6.1)', async () => {
  const sku = await stockedSku(db);
  const resellerId = await newReseller(db, { tier: 3, payment_terms_days: 60, credit_limit: 5000000 });

  for (const i of [1, 2]) {
    const orderId = await placeOrder(resellerId, [{ sku, qty: 5 }]);
    const inv = await invoiceFor(orderId);
    await db.query('update invoices set due_date = current_date - 10 where id = $1', [inv.id]);
    await asRole(db, 'HR_FINANCE', (c) =>
      c.query('select record_payment($1, $2)', [inv.id, inv.amount])); // paid, but late

    const r = await db.query('select tier from resellers where id = $1', [resellerId]);
    assert.equal(r.rows[0].tier, i === 1 ? 3 : 2, `after late payment #${i}`);
  }

  const ev = await db.query(
    `select details from reseller_events
      where reseller_id = $1 and event_type = 'AUTO_DEMOTE'`, [resellerId]);
  assert.equal(ev.rows.length, 1);
  assert.equal(ev.rows[0].details.from_tier, 3);
  assert.equal(ev.rows[0].details.to_tier, 2);
});

test('unverified or pending resellers cannot order until admin verifies (§3.3)', async () => {
  const sku = await stockedSku(db);
  const resellerId = await newReseller(db, { status: 'PENDING', docs_verified: false });

  await assert.rejects(placeOrder(resellerId, [{ sku, qty: 1 }]), /RESELLER_NOT_ELIGIBLE/);

  await asRole(db, 'OWNER_ADMIN', (c) =>
    c.query('select admin_verify_reseller($1)', [resellerId]));
  await placeOrder(resellerId, [{ sku, qty: 1 }]);
});

test('cancelling a B2B order voids its unpaid invoice', async () => {
  const sku = await stockedSku(db);
  const resellerId = await newReseller(db);
  const orderId = await placeOrder(resellerId, [{ sku, qty: 2 }]);

  await asRole(db, 'B2B_AGENT', (c) => c.query('select cancel_order($1)', [orderId]));
  assert.equal((await invoiceFor(orderId)).status, 'VOID');
});

test('exposure view flags a reseller holding the bulk of AR (§6.1)', async () => {
  const sku = await stockedSku(db);
  const whale = await newReseller(db, { credit_limit: 100000000 });
  const minnow = await newReseller(db);

  await placeOrder(whale, [{ sku, qty: 10, unit_price: 5000000 }]); // ₱50M AR
  await placeOrder(minnow, [{ sku, qty: 1 }]);                      // ₱250 AR

  const rows = await db.query(
    'select reseller_id, flagged from ar_exposure where reseller_id in ($1, $2) order by reseller_id',
    [whale, minnow]);
  const byId = Object.fromEntries(rows.rows.map((r) => [r.reseller_id, r.flagged]));
  assert.equal(byId[whale], true);
  assert.equal(byId[minnow], false);
});

test('RLS: resellers see only their own invoices and reseller record', async () => {
  const sku = await stockedSku(db);
  const mine = await newReseller(db);
  const other = await newReseller(db);
  await placeOrder(mine, [{ sku, qty: 1 }]);
  await placeOrder(other, [{ sku, qty: 1 }]);

  await asRole(db, 'RESELLER', async (c) => {
    const inv = await c.query('select distinct reseller_id from invoices');
    assert.deepEqual(inv.rows.map((r) => Number(r.reseller_id)), [Number(mine)]);
    const rs = await c.query('select id from resellers');
    assert.deepEqual(rs.rows.map((r) => Number(r.id)), [Number(mine)]);
  }, { resellerId: mine, rls: true });
});

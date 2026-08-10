// MVP acceptance tests (Spec-MVP.md §10) — driven through the real HTTP API,
// so authentication, role gating, the database rules and the plain-language
// error translation are all exercised the way a user would hit them.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { pool, uniq, monthsOut } from './helpers/db.js';
import { hashPassword } from '../app/password.js';
import { server, db as appDb } from '../app/server.js';

const db = pool();
let BASE;

test.before(async () => {
  await new Promise((resolve) => server.listen(0, resolve));
  BASE = `http://127.0.0.1:${server.address().port}`;
});
test.after(async () => {
  await new Promise((resolve) => server.close(resolve));
  await appDb.end();
  await db.end();
});

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------
async function call(cookie, method, path, body) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: { 'Content-Type': 'application/json', ...(cookie ? { Cookie: cookie } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, data };
}
const GET = (c, p) => call(c, 'GET', p);
const POST = (c, p, b) => call(c, 'POST', p, b ?? {});
const PUT = (c, p, b) => call(c, 'PUT', p, b);

/** Create a login and return its session cookie. */
async function user(role, resellerId = null) {
  const username = uniq(role.toLowerCase());
  await db.query(
    `insert into app_users (username, display_name, password_hash, role, reseller_id)
     values ($1, $1, $2, $3, $4)`,
    [username, hashPassword('pw'), role, resellerId]);
  const res = await fetch(`${BASE}/api/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username, password: 'pw' }),
  });
  assert.equal(res.status, 200, `login failed for ${username}`);
  const raw = res.headers.getSetCookie?.()[0] ?? res.headers.get('set-cookie');
  return Object.assign(raw.split(';')[0], { username });
}

async function product(admin, overrides = {}) {
  const sku = uniq('MVP');
  const { status, data } = await POST(admin, '/api/products', {
    sku, name: `Test ${sku}`, brand: 'Beau Glow', category: 'Serums',
    unit_cost: 100, wholesale_price: 250, srp: 400, retail_price: 450,
    shelf_life_months: 24, ...overrides,
  });
  assert.equal(status, 200, JSON.stringify(data));
  if (overrides.alloc_b2b !== undefined) {
    await PUT(admin, `/api/products/${sku}`, {
      alloc_b2b: overrides.alloc_b2b, alloc_retail: overrides.alloc_retail,
      alloc_safety: overrides.alloc_safety,
    });
  }
  return sku;
}

/** An ACTIVE, docs-verified reseller with the given tier/limit/terms. */
async function reseller(admin, { tier = 2, credit_limit = 1000000, terms = 30 } = {}) {
  const { data } = await POST(admin, '/api/resellers', {
    name: uniq('Reseller'), email: 'x@example.com', tier,
    credit_limit, payment_terms_days: terms,
  });
  await POST(admin, `/api/resellers/${data.id}/verify`);
  return data.id;
}

// ===========================================================================
// §10.1 — receiving auto-allocates 70/20/10, and the admin can change it
// ===========================================================================
test('ACCEPTANCE 1: receiving 100 units splits 70/20/10, and the split is editable', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const sku = await product(admin);

  const first = await POST(wh, '/api/receive', {
    sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 100,
  });
  assert.equal(first.status, 200, JSON.stringify(first.data));
  const split = Object.fromEntries(first.data.allocation.map((a) => [a.pool, a.qty_on_hand]));
  assert.deepEqual(split, { B2B_POOL: 70, RETAIL_SHELF: 20, SAFETY: 10 });

  // Admin retunes the split for this SKU; the next receipt follows the override.
  const edit = await PUT(admin, `/api/products/${sku}`,
    { alloc_b2b: 0.5, alloc_retail: 0.4, alloc_safety: 0.1 });
  assert.equal(edit.status, 200, JSON.stringify(edit.data));

  const second = await POST(wh, '/api/receive', {
    sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 100,
  });
  const split2 = Object.fromEntries(second.data.allocation.map((a) => [a.pool, a.qty_on_hand]));
  assert.deepEqual(split2, { B2B_POOL: 50, RETAIL_SHELF: 40, SAFETY: 10 });

  // Odd quantities never lose or invent units (largest-remainder rounding).
  const odd = await POST(wh, '/api/receive', {
    sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 7,
  });
  assert.equal(odd.data.allocation.reduce((s, a) => s + a.qty_on_hand, 0), 7);
});

// ===========================================================================
// §10.2 — a reseller order and a POS sale can never consume the same units
// ===========================================================================
test('ACCEPTANCE 2a: POS cannot reach stock allocated to the B2B pool', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const cashier = await user('RETAIL_CASHIER');
  const sku = await product(admin, { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 50 });

  const sale = await POST(cashier, '/api/pos/checkout',
    { lines: [{ sku, qty: 1 }], method: 'CASH', tendered: 1000 });
  assert.equal(sale.status, 400);
  assert.match(sale.data.error, /Not enough stock/,
    'the retail shelf is empty even though 50 units sit in the B2B pool');
});

test('ACCEPTANCE 2b: two simultaneous orders for the last units — exactly one wins', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const sku = await product(admin, { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 5 });

  const rid1 = await reseller(admin);
  const rid2 = await reseller(admin);
  const buyer1 = await user('RESELLER', rid1);
  const buyer2 = await user('RESELLER', rid2);

  const [a, b] = await Promise.all([
    POST(buyer1, '/api/portal/orders', { lines: [{ sku, qty: 5 }] }),
    POST(buyer2, '/api/portal/orders', { lines: [{ sku, qty: 5 }] }),
  ]);

  const wins = [a, b].filter((r) => r.status === 200);
  const losses = [a, b].filter((r) => r.status !== 200);
  assert.equal(wins.length, 1, 'exactly one order may take the last 5 units');
  assert.equal(losses.length, 1);
  assert.match(losses[0].data.error, /Not enough stock/,
    'the loser gets a plain-language shortage message, not a database error');

  // The ledger agrees: 5 committed, nothing left to sell.
  const stock = await GET(admin, '/api/products?q=' + sku);
  assert.equal(stock.data[0].b2b_avail, 0);
  assert.equal(stock.data[0].b2b_committed, 5);
});

// ===========================================================================
// §10.3 — FEFO picks the earliest-expiring viable batch; batches under the
// 12-month floor never reach a reseller
// ===========================================================================
test('ACCEPTANCE 3: FEFO picks earliest viable; sub-12-month batches stay out of B2B', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const cashier = await user('RETAIL_CASHIER');
  const sku = await product(admin, { alloc_b2b: 0.5, alloc_retail: 0.5, alloc_safety: 0 });

  const shortNo = uniq('SHORT');           // 6 months out — under the reseller floor
  const midNo = uniq('MID');               // 18 months — viable, expires first
  const farNo = uniq('FAR');               // 30 months — viable, expires later
  await POST(wh, '/api/receive', { sku, batch_number: shortNo, expiry_date: monthsOut(6), qty: 40 });
  await POST(wh, '/api/receive', { sku, batch_number: farNo, expiry_date: monthsOut(30), qty: 40 });
  await POST(wh, '/api/receive', { sku, batch_number: midNo, expiry_date: monthsOut(18), qty: 40 });

  const rid = await reseller(admin);
  const buyer = await user('RESELLER', rid);

  // Reseller availability counts only the two viable batches (20 + 20 of 60).
  const catalog = await GET(buyer, '/api/portal/catalog');
  assert.equal(catalog.data.find((p) => p.sku === sku).available, 40,
    'the 6-month batch is invisible to resellers');

  const order = await POST(buyer, '/api/portal/orders', { lines: [{ sku, qty: 25 }] });
  assert.equal(order.status, 200, JSON.stringify(order.data));

  const detail = await GET(wh, `/api/orders/${order.data.order_id}`);
  const picked = detail.data.lines;
  assert.equal(picked[0].batch_number, midNo, 'earliest viable batch is picked first');
  assert.equal(picked[0].qty, 20);
  assert.equal(picked[1].batch_number, farNo, 'then the later batch covers the remainder');
  assert.equal(picked[1].qty, 5);
  assert.ok(!picked.some((l) => l.batch_number === shortNo),
    'a batch under the 12-month floor must never appear on a reseller pick list');

  // Retail may still sell the short-dated batch — and FEFO sends it out first.
  const sale = await POST(cashier, '/api/pos/checkout',
    { lines: [{ sku, qty: 1 }], method: 'CASH', tendered: 1000 });
  assert.equal(sale.status, 200, JSON.stringify(sale.data));
  assert.equal(sale.data.lines[0].batch_number, shortNo,
    'the shelf clears its shortest-dated stock first');
});

// ===========================================================================
// §10.4 — the worked ROP example
// ===========================================================================
test('ACCEPTANCE 4: avg 10/day, max 15/day, lead 60/75 → safety stock 525, ROP 1,125', async () => {
  const admin = await user('OWNER_ADMIN');
  const sku = await product(admin, { shelf_life_months: 24 });

  const { status, data } = await POST(admin, `/api/rop/${sku}`, {
    avg_daily: 10, max_daily: 15, avg_lead: 60, max_lead: 75, target_months_cover: 3,
  });
  assert.equal(status, 200, JSON.stringify(data));
  assert.equal(Number(data.safety_stock), 525);
  assert.equal(Number(data.rop), 1125);

  // Nothing received yet → below ROP → ORDER NOW with a shelf-life-capped
  // suggestion: 3 months of cover (900) is under the 12-month-floor cap.
  const rop = await GET(admin, '/api/rop');
  const row = rop.data.find((r) => r.sku === sku);
  assert.equal(Number(row.shortfall), 1125);
  assert.equal(Number(row.suggested_order_qty), 900);
});

// ===========================================================================
// §10.5 — credit rules: Tier 1 prepayment, past-due auto-block, logged override
// ===========================================================================
test('ACCEPTANCE 5a: a Tier 1 order cannot be dispatched until payment is recorded', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const sku = await product(admin, { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 20 });

  const rid = await reseller(admin, { tier: 1, credit_limit: 0, terms: 0 });
  const buyer = await user('RESELLER', rid);

  const order = await POST(buyer, '/api/portal/orders', { lines: [{ sku, qty: 4 }] });
  assert.equal(order.status, 200, JSON.stringify(order.data));
  const invoiceId = order.data.invoice.id;

  const tooSoon = await POST(wh, `/api/orders/${order.data.order_id}/fulfill`);
  assert.equal(tooSoon.status, 400);
  assert.match(tooSoon.data.error, /pay before dispatch/i);

  await POST(admin, `/api/invoices/${invoiceId}/pay`, { amount: order.data.invoice.amount });

  const now = await POST(wh, `/api/orders/${order.data.order_id}/fulfill`);
  assert.equal(now.status, 200, JSON.stringify(now.data));
});

test('ACCEPTANCE 5b: a past-due Tier 2 reseller is auto-blocked, told what to pay, and can be overridden', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const sku = await product(admin, { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 100 });

  const rid = await reseller(admin, { tier: 2, credit_limit: 1000000, terms: 30 });
  const buyer = await user('RESELLER', rid);

  const first = await POST(buyer, '/api/portal/orders', { lines: [{ sku, qty: 10 }] });
  assert.equal(first.status, 200, JSON.stringify(first.data));

  // Age that invoice past its due date, the way the calendar would.
  await db.query(
    `update invoices set issued_at = current_date - 60, due_date = current_date - 30
      where order_id = $1`, [first.data.order_id]);

  const blocked = await POST(buyer, '/api/portal/orders', { lines: [{ sku, qty: 1 }] });
  assert.equal(blocked.status, 400);
  assert.match(blocked.data.error, /blocked/i);

  // The portal spells out exactly why and exactly what to pay.
  const credit = await GET(buyer, '/api/portal/credit');
  assert.equal(credit.data.blocked, true);
  assert.match(credit.data.blocked_reason, /past-due/i);
  assert.equal(Number(credit.data.pay_to_unblock), Number(first.data.invoice.amount));

  // Admin override requires a reason, and the reason is written to the log.
  const noNote = await POST(admin, `/api/resellers/${rid}/unblock`, {});
  assert.equal(noNote.status, 400, 'an override without a note must be refused');

  const ok = await POST(admin, `/api/resellers/${rid}/unblock`,
    { note: 'Owner approved — cheque in transit' });
  assert.equal(ok.status, 200);

  const detail = await GET(admin, `/api/resellers/${rid}`);
  const unblock = detail.data.events.find((e) => e.event_type === 'UNBLOCK');
  assert.ok(unblock, 'the override is recorded as a reseller event');
  assert.match(unblock.details.note, /cheque in transit/);
  assert.equal(unblock.details.by, admin.username, 'the log names the admin who overrode');
});

test('ACCEPTANCE 5c: an order beyond the credit limit is refused with the numbers spelled out', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const sku = await product(admin, { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 100 });

  const rid = await reseller(admin, { tier: 2, credit_limit: 1000, terms: 30 });
  const buyer = await user('RESELLER', rid);

  const over = await POST(buyer, '/api/portal/orders', { lines: [{ sku, qty: 10 }] }); // ₱2,500
  assert.equal(over.status, 400);
  assert.match(over.data.error, /credit limit/i);
  assert.match(over.data.error, /₱/, 'the message quotes the amounts in pesos');
});

// ===========================================================================
// §10.6 — the last shelf unit sells, the shelf hits zero, a restock task fires
// ===========================================================================
test('ACCEPTANCE 6: selling the last shelf unit empties the shelf and raises a restock task', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const cashier = await user('RETAIL_CASHIER');
  const sku = await product(admin, { alloc_b2b: 0, alloc_retail: 1, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 1 });

  const sale = await POST(cashier, '/api/pos/checkout',
    { lines: [{ sku, qty: 1 }], method: 'CASH', tendered: 500 });
  assert.equal(sale.status, 200, JSON.stringify(sale.data));
  assert.match(sale.data.receipt_no, /^OR-\d{8}-\d{5}$/, 'sequential receipt number');
  assert.equal(Number(sale.data.change), 50);            // ₱500 tendered on a ₱450 sale

  const shelf = await GET(cashier, `/api/pos/products?q=${sku}`);
  assert.equal(shelf.data[0].shelf_available, 0, 'the shelf is now empty');

  const tasks = await GET(wh, '/api/restock-requests');
  const mine = tasks.data.find((t) => t.sku === sku && t.status === 'OPEN');
  assert.ok(mine, 'the system raised its own "move stock to the storefront" task');
  assert.match(mine.note, /shelf at 0/);

  const again = await POST(cashier, '/api/pos/checkout',
    { lines: [{ sku, qty: 1 }], method: 'CASH', tendered: 500 });
  assert.equal(again.status, 400, 'the next sale is blocked');
  assert.match(again.data.error, /Not enough stock/);

  // Warehouse moves the safety/B2B stock across and closes the task.
  const close = await POST(wh, `/api/restock-requests/${mine.id}/close`);
  assert.equal(close.status, 200);
});

test('cash tendered below the total is refused before any stock moves', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const cashier = await user('RETAIL_CASHIER');
  const sku = await product(admin, { alloc_b2b: 0, alloc_retail: 1, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 5 });

  const short = await POST(cashier, '/api/pos/checkout',
    { lines: [{ sku, qty: 1 }], method: 'CASH', tendered: 100 });
  assert.equal(short.status, 400);
  assert.match(short.data.error, /Not enough cash/);

  const shelf = await GET(cashier, `/api/pos/products?q=${sku}`);
  assert.equal(shelf.data[0].shelf_available, 5, 'the failed sale rolled back completely');
});

// ===========================================================================
// §10.7 — blind end-of-day reconciliation
// ===========================================================================
test('ACCEPTANCE 7: the expected total stays hidden until the blind count is submitted', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const cashier = await user('RETAIL_CASHIER');
  const sku = await product(admin, { alloc_b2b: 0, alloc_retail: 1, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 10 });

  await POST(cashier, '/api/pos/checkout', { lines: [{ sku, qty: 2 }], method: 'CASH', tendered: 1000 });
  await POST(cashier, '/api/pos/checkout', { lines: [{ sku, qty: 1 }], method: 'GCASH' });

  // Before submitting, nothing the cashier can read reveals the drawer total.
  const before = await GET(cashier, '/api/pos/eod');
  assert.equal(before.status, 200);
  const leaked = JSON.stringify(before.data);
  assert.ok(!/pos_total|expected|variance/.test(leaked),
    'the cashier must not be able to peek at the expected total');

  // Declare short by ₱50.
  const expected = 450 * 2;                       // cash sales only; GCash excluded
  const { status, data } = await POST(cashier, '/api/pos/eod', { declared: expected - 50 });
  assert.equal(status, 200, JSON.stringify(data));
  assert.equal(Number(data.expected), expected);
  assert.equal(Number(data.declared), expected - 50);
  assert.equal(Number(data.variance), -50);
  assert.equal(data.flagged, false, '₱50 is inside the ₱100 tolerance');

  // One blind count per cashier per day.
  const twice = await POST(cashier, '/api/pos/eod', { declared: 1 });
  assert.equal(twice.status, 400);
  assert.match(twice.data.error, /already submitted/i);
});

test('a large cash variance is flagged for admin review', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const cashier = await user('RETAIL_CASHIER');
  const sku = await product(admin, { alloc_b2b: 0, alloc_retail: 1, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 10 });
  await POST(cashier, '/api/pos/checkout', { lines: [{ sku, qty: 2 }], method: 'CASH', tendered: 1000 });

  const { data } = await POST(cashier, '/api/pos/eod', { declared: 200 });
  assert.equal(Number(data.variance), 200 - 900);
  assert.equal(data.flagged, true);
});

// ===========================================================================
// §10.8 — the dusty pink design system, on a tablet
// ===========================================================================
test('ACCEPTANCE 8: the UI ships the dusty pink palette and a responsive viewport', () => {
  const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'app', 'public');
  const css = fs.readFileSync(path.join(dir, 'styles.css'), 'utf8');
  const html = fs.readFileSync(path.join(dir, 'index.html'), 'utf8');

  for (const token of ['#D8A7B1', '#B4838D', '#FAF6F4', '#F4E4E8', '#4A3B40',
    '#A8B8A0', '#E0A458', '#C46A6A']) {
    assert.ok(css.includes(token), `design token ${token} must be defined`);
  }
  assert.match(html, /name="viewport"[^>]*width=device-width/, 'responsive viewport meta');
  assert.ok(/@media \(max-width: 980px\)/.test(css) && /@media \(max-width: 900px\)/.test(css),
    'tablet breakpoints for the back office and the POS');
  assert.ok(css.includes('--radius') && css.includes('box-shadow'),
    'soft rounded cards rather than harsh borders');
});

// ===========================================================================
// Role isolation — nobody reads another channel's numbers
// ===========================================================================
test('role gating: cashiers, warehouse staff and resellers stay in their lane', async () => {
  const admin = await user('OWNER_ADMIN');
  const cashier = await user('RETAIL_CASHIER');
  const wh = await user('WAREHOUSE');
  const rid = await reseller(admin);
  const buyer = await user('RESELLER', rid);

  assert.equal((await GET(cashier, '/api/dashboard')).status, 403);
  assert.equal((await GET(cashier, '/api/resellers')).status, 403);
  assert.equal((await GET(wh, '/api/reports/ar')).status, 403);
  assert.equal((await GET(buyer, '/api/stock')).status, 403,
    'a reseller can never read warehouse totals');
  assert.equal((await GET(buyer, '/api/products?q=')).status, 403);
  assert.equal((await GET(buyer, '/api/pos/products?q=')).status, 403);
  assert.equal((await GET(null, '/api/dashboard')).status, 401);

  // Resellers see only their own orders, never another account's.
  const other = await reseller(admin);
  const otherBuyer = await user('RESELLER', other);
  const mine = await GET(buyer, '/api/portal/orders');
  const theirs = await GET(otherBuyer, '/api/portal/orders');
  assert.equal(mine.status, 200);
  assert.equal(theirs.status, 200);
  const overlap = mine.data.filter((o) => theirs.data.some((t) => t.id === o.id));
  assert.equal(overlap.length, 0);
});

// ===========================================================================
// Supporting MVP flows
// ===========================================================================
test('cancelling an unfulfilled order releases the committed stock', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const sku = await product(admin, { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 10 });
  const rid = await reseller(admin);
  const buyer = await user('RESELLER', rid);

  const order = await POST(buyer, '/api/portal/orders', { lines: [{ sku, qty: 10 }] });
  assert.equal((await GET(buyer, '/api/portal/catalog')).data.find((p) => p.sku === sku).available, 0);

  assert.equal((await POST(buyer, `/api/portal/orders/${order.data.order_id}/cancel`)).status, 200);
  assert.equal((await GET(buyer, '/api/portal/catalog')).data.find((p) => p.sku === sku).available, 10,
    'cancelled units go back on sale');
});

test('returns sit in quarantine until the admin decides restock or write-off', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const cashier = await user('RETAIL_CASHIER');
  const sku = await product(admin, { alloc_b2b: 0, alloc_retail: 1, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 10 });

  const sale = await POST(cashier, '/api/pos/checkout',
    { lines: [{ sku, qty: 3 }], method: 'CASH', tendered: 2000 });
  const receiptNo = sale.data.receipt_no;

  const receipt = await GET(cashier, `/api/pos/receipt/${receiptNo}`);
  const line = receipt.data.lines[0];
  assert.equal(Number(line.returnable), 3);

  const req = await POST(cashier, '/api/pos/returns', {
    receipt_no: receiptNo, sku, batch_id: line.batch_id, qty: 2, reason: 'unopened, wrong shade',
  });
  assert.equal(req.status, 200, JSON.stringify(req.data));

  // Quarantine: the shelf has not moved yet.
  assert.equal((await GET(cashier, `/api/pos/products?q=${sku}`)).data[0].shelf_available, 7);

  const over = await POST(cashier, '/api/pos/returns', {
    receipt_no: receiptNo, sku, batch_id: line.batch_id, qty: 2, reason: 'again',
  });
  assert.equal(over.status, 400, 'cannot return more than was sold');

  const decided = await POST(admin, `/api/returns/${req.data.id}/decide`,
    { approve: true, disposition: 'RESTOCK' });
  assert.equal(decided.status, 200);
  assert.equal((await GET(cashier, `/api/pos/products?q=${sku}`)).data[0].shelf_available, 9,
    'approved restock puts the units back on the shelf');
});

test('MAP discipline: a retail price below the reseller SRP is refused with a plain warning', async () => {
  const admin = await user('OWNER_ADMIN');
  const sku = await product(admin);
  const bad = await PUT(admin, `/api/products/${sku}`, { retail_price: 100, srp: 400 });
  assert.equal(bad.status, 400);
  assert.match(bad.data.error, /MAP/);
});

test('expired stock is unsellable and can be written off to the ledger', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const cashier = await user('RETAIL_CASHIER');
  const sku = await product(admin, { alloc_b2b: 0, alloc_retail: 1, alloc_safety: 0 });
  const batchNo = uniq('EXP');
  await POST(wh, '/api/receive', { sku, batch_number: batchNo, expiry_date: monthsOut(24), qty: 10 });
  await db.query(`update batches set expiry_date = current_date - 1 where batch_number = $1`, [batchNo]);

  const sale = await POST(cashier, '/api/pos/checkout',
    { lines: [{ sku, qty: 1 }], method: 'CASH', tendered: 1000 });
  assert.equal(sale.status, 400, 'expired stock is blocked from sale');

  const expired = await GET(wh, '/api/expired');
  const row = expired.data.find((x) => x.batch_number === batchNo);
  assert.ok(row, 'expired stock is listed for write-off');

  const off = await POST(wh, '/api/write-off-expired', { batch_id: row.batch_id });
  assert.equal(Number(off.data.units_written_off), 10);

  const ledger = await GET(wh, `/api/reports/ledger?q=${sku}`);
  assert.ok(ledger.data.some((m) => m.reason === 'EXPIRED_WRITE_OFF' && m.qty === 10),
    'the write-off is journalled with its reason');
});

test('the 90-day recalculation refreshes daily sales from real order history', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const cashier = await user('RETAIL_CASHIER');
  const sku = await product(admin, { alloc_b2b: 0, alloc_retail: 1, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 200 });
  await POST(admin, `/api/rop/${sku}`, { avg_daily: 1, max_daily: 2, avg_lead: 30, max_lead: 40 });

  await POST(cashier, '/api/pos/checkout', { lines: [{ sku, qty: 90 }], method: 'GCASH' });

  const { status, data } = await POST(wh, `/api/rop/${sku}/recalc`);
  assert.equal(status, 200, JSON.stringify(data));
  assert.equal(Number(data.avg_daily_sales), 1, '90 units over 90 days = 1/day');
  assert.equal(Number(data.max_daily_sales), 90, 'the busiest single day sets the max');
  assert.equal(Number(data.rop), Number(data.safety_stock) + 30);
});

test('opening the dashboard persists the auto-block flag and its audit event', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const sku = await product(admin, { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 50 });

  const rid = await reseller(admin, { tier: 2, credit_limit: 500000, terms: 30 });
  const buyer = await user('RESELLER', rid);
  const order = await POST(buyer, '/api/portal/orders', { lines: [{ sku, qty: 5 }] });
  await db.query(
    `update invoices set issued_at = current_date - 60, due_date = current_date - 30
      where order_id = $1`, [order.data.order_id]);

  // The flag is still clean — nothing has run the AR sweep yet.
  assert.equal((await GET(admin, `/api/resellers/${rid}`)).data.blocked, false);

  await GET(admin, '/api/dashboard');

  const after = await GET(admin, `/api/resellers/${rid}`);
  assert.equal(after.data.blocked, true);
  assert.equal(after.data.blocked_reason, 'PAST_DUE_INVOICE');
  assert.ok(after.data.events.some((e) => e.event_type === 'AUTO_BLOCK'),
    'the auto-block is recorded as an event, not just a flag');
});

test('hostile query parameters are rejected without leaking database errors', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');

  const inject = await GET(admin, `/api/products?q=${encodeURIComponent("'; drop table products;--")}`);
  assert.equal(inject.status, 200);
  assert.deepEqual(inject.data, [], 'the injection string is matched as literal text');
  assert.ok((await GET(admin, '/api/products?q=')).data.length > 0, 'products table intact');

  for (const bad of ['-5', '0', 'abc', '1e999', '']) {
    const r = await GET(wh, `/api/reports/ledger?limit=${encodeURIComponent(bad)}`);
    assert.equal(r.status, 200, `limit=${bad} should be clamped, not error`);
    assert.ok(Array.isArray(r.data));
    assert.ok(r.data.length <= 1000);
  }
});

// ===========================================================================
// Regression cover for issues found in review
// ===========================================================================
test('marking an order delivered does not erase it from sales, commissions or cash reconciliation', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const sku = await product(admin, { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 40 });
  const rid = await reseller(admin);
  const buyer = await user('RESELLER', rid);

  const order = await POST(buyer, '/api/portal/orders', { lines: [{ sku, qty: 10 }] });
  await POST(wh, `/api/orders/${order.data.order_id}/fulfill`);

  const revenueOf = async () => {
    const rep = await GET(admin, '/api/reports/sales');
    const row = rep.data.by_product.find((p) => p.sku === sku);
    return row ? Number(row.revenue) : 0;
  };
  const before = await revenueOf();
  assert.ok(before > 0, 'a dispatched order counts as revenue');

  const delivered = await POST(wh, `/api/orders/${order.data.order_id}/deliver`);
  assert.equal(delivered.status, 200, JSON.stringify(delivered.data));

  assert.equal(await revenueOf(), before,
    'confirming delivery must not remove the sale from the books');

  // The engine's own consumers still see it: FULFILLED is untouched.
  const still = await db.query(
    `select status, delivered_at is not null as delivered from orders where id = $1`,
    [order.data.order_id]);
  assert.equal(still.rows[0].status, 'FULFILLED');
  assert.equal(still.rows[0].delivered, true);

  const abc = await db.query(
    `select count(*)::int as n from order_lines ol join orders o on o.id = ol.order_id
      where ol.sku = $1 and o.status = 'FULFILLED'`, [sku]);
  assert.equal(abc.rows[0].n > 0, true, 'ABC/commission queries still match the order');

  // Delivery is a one-time confirmation, and only for wholesale orders.
  const twice = await POST(wh, `/api/orders/${order.data.order_id}/deliver`);
  assert.equal(twice.status, 400);
  assert.match(twice.data.error, /already/i);
});

test('a counter sale cannot be marked delivered', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const cashier = await user('RETAIL_CASHIER');
  const sku = await product(admin, { alloc_b2b: 0, alloc_retail: 1, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 5 });
  const sale = await POST(cashier, '/api/pos/checkout',
    { lines: [{ sku, qty: 1 }], method: 'CASH', tendered: 1000 });

  const bad = await POST(wh, `/api/orders/${sale.data.order_id}/deliver`);
  assert.equal(bad.status, 400);
  assert.match(bad.data.error, /counter sale/i);
});

test('warehouse pickers see who the order is for and whether it is paid', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const sku = await product(admin, { alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 20 });
  const rid = await reseller(admin, { tier: 1, credit_limit: 0, terms: 0 });
  const buyer = await user('RESELLER', rid);
  const order = await POST(buyer, '/api/portal/orders', { lines: [{ sku, qty: 3 }] });

  const seen = await GET(wh, `/api/orders/${order.data.order_id}`);
  assert.equal(seen.status, 200);
  assert.ok(seen.data.reseller_name, 'the picker can see the reseller name');
  assert.equal(seen.data.tier, 1);
  assert.equal(seen.data.invoice_status, 'OPEN',
    'and that a prepaid account has not paid yet');
  assert.equal(seen.data.invoice_balance, null,
    'but not the money — warehouse has no business with credit');

  const asAdmin = await GET(admin, `/api/orders/${order.data.order_id}`);
  assert.ok(Number(asAdmin.data.invoice_balance) > 0, 'the owner does see the balance');
});

test('disabling a user ends their open session immediately', async () => {
  const admin = await user('OWNER_ADMIN');
  const cashier = await user('RETAIL_CASHIER');
  assert.equal((await GET(cashier, '/api/pos/products?q=')).status, 200);

  const row = await db.query('select id from app_users where username = $1', [cashier.username]);
  const disable = await POST(admin, `/api/users/${row.rows[0].id}/active`, { active: false });
  assert.equal(disable.status, 200);

  const after = await GET(cashier, '/api/pos/products?q=');
  assert.equal(after.status, 401, 'the still-valid cookie must stop working at once');
  assert.match(after.data.error, /turned off/i);
});

test('a restock task cannot be queued twice or closed twice', async () => {
  const admin = await user('OWNER_ADMIN');
  const wh = await user('WAREHOUSE');
  const cashier = await user('RETAIL_CASHIER');
  const sku = await product(admin, { alloc_b2b: 0, alloc_retail: 1, alloc_safety: 0 });
  await POST(wh, '/api/receive', { sku, batch_number: uniq('B'), expiry_date: monthsOut(24), qty: 5 });

  const both = await Promise.all([
    POST(cashier, '/api/restock-requests', { sku, note: 'first' }),
    POST(cashier, '/api/restock-requests', { sku, note: 'second' }),
  ]);
  assert.ok(both.every((r) => r.status === 200), JSON.stringify(both.map((r) => r.data)));
  assert.equal(both[0].data.id, both[1].data.id, 'both taps land on one task');

  const open = await db.query(
    `select count(*)::int as n from restock_requests where sku = $1 and status = 'OPEN'`, [sku]);
  assert.equal(open.rows[0].n, 1);

  assert.equal((await POST(wh, `/api/restock-requests/${both[0].data.id}/close`)).status, 200);
  const again = await POST(wh, `/api/restock-requests/${both[0].data.id}/close`);
  assert.equal(again.status, 400, 'closing an already-closed task is not a silent success');
});

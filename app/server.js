#!/usr/bin/env node
// ============================================================================
// MS BEAU AVE — unified web application (Spec-MVP.md)
//
// One Node server, no framework: role-based auth (scrypt + signed cookies),
// JSON API over the Postgres operations engine (supabase/migrations/*), and
// the static SPA in app/public. Every business rule lives in the database —
// this layer authenticates, sets the per-request role GUCs, switches to the
// non-superuser app_client role so RLS applies, and translates errors into
// plain language.
//
//   DATABASE_URL=postgres://…  node app/server.js       # any Postgres 16+
//   npm run app:demo                                    # ephemeral PG + seed
// ============================================================================
import http from 'node:http';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';
import { hashPassword, verifyPassword } from './password.js';

// The business runs on Manila time; pin the process so date columns, receipt
// numbers and end-of-day cut-offs agree no matter where the server is hosted.
process.env.TZ = process.env.TZ || 'Asia/Manila';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC_DIR = path.join(__dirname, 'public');
const PORT = Number(process.env.PORT || 4300);
const DSN = process.env.DATABASE_URL || process.env.IMS_TEST_DSN;
if (!DSN) {
  console.error('Set DATABASE_URL (or IMS_TEST_DSN) to a Postgres with the migrations applied.');
  process.exit(1);
}
const SECRET = process.env.SESSION_SECRET || crypto.randomBytes(32).toString('hex');
const db = new pg.Pool({ connectionString: DSN, max: 10 });

// ---------------------------------------------------------------------------
// Sessions — signed, HttpOnly cookies; no server-side session store to lose.
// ---------------------------------------------------------------------------
const b64u = (buf) => Buffer.from(buf).toString('base64url');
function sign(payload) {
  const body = b64u(JSON.stringify(payload));
  const mac = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  return `${body}.${mac}`;
}
function unsign(token) {
  const [body, mac] = String(token || '').split('.');
  if (!body || !mac) return null;
  const want = crypto.createHmac('sha256', SECRET).update(body).digest('base64url');
  if (mac.length !== want.length ||
      !crypto.timingSafeEqual(Buffer.from(mac), Buffer.from(want))) return null;
  try {
    const s = JSON.parse(Buffer.from(body, 'base64url').toString());
    return s.exp > Date.now() ? s : null;
  } catch { return null; }
}

function session(req) {
  const cookies = Object.fromEntries((req.headers.cookie || '')
    .split(';').map((c) => c.trim().split('=').map(decodeURIComponent)).filter((c) => c[0]));
  return unsign(cookies.mba);
}

// ---------------------------------------------------------------------------
// Money and error translation — every peso figure carries thousands
// separators (§3), and cashiers and resellers are not technical (§9 MVP).
// ---------------------------------------------------------------------------
const peso = (v) => '₱' + Number(v || 0).toLocaleString('en-PH', {
  minimumFractionDigits: 2, maximumFractionDigits: 2,
});

function friendly(err) {
  const m = String(err.message || err);
  if (m.includes('INSUFFICIENT_STOCK')) {
    const short = m.match(/sku (\S+) short (\d+)/);
    return short
      ? `Not enough stock: ${short[1]} is short ${short[2]} unit(s). Someone may have just bought or ordered it — refresh and try a smaller quantity.`
      : 'Not enough stock for that quantity. Refresh to see what is available now.';
  }
  if (m.includes('RESELLER_BLOCKED')) return 'This account is blocked from ordering. Check the credit status page to see exactly what to pay to unblock.';
  if (m.includes('CREDIT_LIMIT_EXCEEDED')) {
    const nums = m.match(/outstanding ([\d.]+) \+ order ([\d.]+) exceeds limit ([\d.]+)/);
    return nums
      ? `This order would exceed the credit limit: ${peso(nums[1])} outstanding + ${peso(nums[2])} order is over the ${peso(nums[3])} limit. Pay down the balance or place a smaller order.`
      : 'This order would exceed the credit limit.';
  }
  if (m.includes('RESELLER_NOT_ELIGIBLE')) return 'This reseller account is not active yet — the application or documents are still awaiting admin approval.';
  if (m.includes('PREPAYMENT_REQUIRED')) return 'Tier 1 accounts pay before dispatch: record the payment for this order’s invoice first.';
  if (m.includes('INSUFFICIENT_TENDER')) {
    const nums = m.match(/₱([\d.]+) tendered for a ₱([\d.]+) sale/);
    return nums
      ? `Not enough cash: ${peso(nums[1])} tendered for a ${peso(nums[2])} sale.`
      : 'Not enough cash tendered for this sale.';
  }
  if (m.includes('map_enforcement')) return 'MAP warning: the retail price cannot be set below the reseller SRP. Raise the retail price or lower the SRP.';
  if (m.includes('FORBIDDEN') || err.code === '42501') return 'Your role is not allowed to do that.';
  if (m.includes('one blind count per day')) return m;
  if (err.code === '23505') return 'That already exists — use a different code/number.';
  return m.replace(/^error: /, '');
}

// ---------------------------------------------------------------------------
// Request plumbing: every API handler runs in one transaction with the
// session's role GUCs set and RLS active (SET LOCAL ROLE app_client).
// ---------------------------------------------------------------------------
async function withRole(sess, fn) {
  const client = await db.connect();
  try {
    await client.query('begin');
    // Role and reseller come from the user record, not the cookie. The cookie
    // is signed, so it cannot be forged — but it can be stale: disabling a
    // dismissed cashier has to end their open session now, not in twelve
    // hours when the cookie happens to expire.
    const live = await client.query(
      'select role, reseller_id, active, display_name from app_users where id = $1',
      [sess.uid]);
    const u = live.rows[0];
    if (!u || !u.active) {
      const err = new Error('Your access has been turned off. Please check with the owner.');
      err.status = 401;
      throw err;
    }
    await client.query(
      `select set_config('app.role', $1, true),
              set_config('app.actor', $2, true),
              set_config('app.reseller_id', $3, true)`,
      [u.role, sess.username, u.reseller_id == null ? '' : String(u.reseller_id)]);
    await client.query('set local role app_client');

    const out = await fn(client, { ...sess, role: u.role, rid: u.reseller_id == null ? null : Number(u.reseller_id) });
    await client.query('commit');
    return out;
  } catch (e) {
    try { await client.query('rollback'); } catch { /* connection gone */ }
    throw e;
  } finally {
    client.release();
  }
}

/**
 * Run several queries on one client. A pooled client executes strictly one
 * query at a time, so these are issued in sequence rather than with
 * Promise.all — handing pg overlapping queries on the same connection is
 * deprecated and stops working in pg@9.
 */
async function queries(c, list) {
  const out = [];
  for (const [sql, params] of list) out.push(await c.query(sql, params));
  return out;
}

/** A row limit that is always a sane positive integer, whatever was asked for. */
const clampLimit = (v, fallback = 200, max = 1000) => {
  const n = Math.floor(Number(v));
  return Number.isFinite(n) && n > 0 ? Math.min(n, max) : fallback;
};

/**
 * Handlers stage their response rather than writing it, and the request loop
 * flushes it only once the transaction has committed. A cashier must never be
 * shown a receipt — and hand over the goods — for a sale that then failed to
 * commit.
 */
const json = (res, code, obj) => { res.staged = { code, body: JSON.stringify(obj) }; };

function flush(res, fallback) {
  if (res.headersSent) return;
  const { code, body } = res.staged ?? fallback ?? { code: 204, body: '' };
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (c) => { data += c; if (data.length > 1e6) req.destroy(); });
    req.on('end', () => {
      try { resolve(data ? JSON.parse(data) : {}); } catch { reject(new Error('bad JSON body')); }
    });
    req.on('error', reject);
  });
}

// ---------------------------------------------------------------------------
// Routes: [method, pattern, allowedRoles (null = any signed-in), handler]
// Handler ctx: { c: db client (role set), sess, body, params, query }
// ---------------------------------------------------------------------------
const ADMIN = ['OWNER_ADMIN'];
const WH = ['OWNER_ADMIN', 'WAREHOUSE'];
const CASHIER = ['OWNER_ADMIN', 'RETAIL_CASHIER'];
const STAFF = ['OWNER_ADMIN', 'WAREHOUSE', 'RETAIL_CASHIER'];
const RESELLER = ['RESELLER'];

const routes = [];
const route = (method, pattern, roles, fn) => routes.push({
  method,
  keys: [...pattern.matchAll(/:(\w+)/g)].map((m) => m[1]),
  re: new RegExp(`^${pattern.replace(/:(\w+)/g, '([^/]+)')}$`),
  roles,
  fn,
});

// ---- auth ------------------------------------------------------------------
route('POST', '/api/login', 'public', async ({ req, body, res }) => {
  const { username, password } = body;
  const r = await db.query(
    `select * from app_users where lower(username) = lower($1) and active`, [username || '']);
  const u = r.rows[0];
  if (!u || !verifyPassword(password || '', u.password_hash)) {
    return json(res, 401, { error: 'Wrong username or password.' });
  }
  const sess = {
    uid: Number(u.id), username: u.username, display: u.display_name,
    role: u.role, rid: u.reseller_id == null ? null : Number(u.reseller_id),
    exp: Date.now() + 12 * 3600e3,
  };
  // SameSite=Lax already blocks the cross-site POSTs that CSRF needs; Secure is
  // added whenever the request arrived over TLS (directly or via a proxy) so
  // the cookie never travels in the clear in production.
  const secure = req.socket.encrypted || req.headers['x-forwarded-proto'] === 'https';
  res.setHeader('Set-Cookie',
    `mba=${sign(sess)}; HttpOnly; SameSite=Lax; Path=/;${secure ? ' Secure;' : ''} Max-Age=${12 * 3600}`);
  json(res, 200, { user: publicUser(sess) });
});

route('POST', '/api/logout', 'public', async ({ res }) => {
  res.setHeader('Set-Cookie', 'mba=; HttpOnly; SameSite=Lax; Path=/; Max-Age=0');
  json(res, 200, { ok: true });
});

const publicUser = (s) => ({
  username: s.username, display: s.display, role: s.role, reseller_id: s.rid,
});

// Public on purpose: the app asks "who am I?" before it can know, and a 401
// on first paint would just be console noise. Signed out is a fact, not an error.
route('GET', '/api/me', 'public', async ({ req, res }) => {
  const sess = session(req);
  json(res, 200, { user: sess ? publicUser(sess) : null });
});

// ---- admin dashboard -------------------------------------------------------
route('GET', '/api/dashboard', ADMIN, async ({ c, res }) => {
  // Ordering is refused live off the invoice table, but the sticky blocked
  // flag and its AUTO_BLOCK event need a job to write them. Without a
  // scheduler in the MVP, the owner opening the dashboard is that job.
  await c.query('select refresh_reseller_blocks()');

  const [today, pending, reorder, aging, overdue, exposure, shelf, restock, expired, variance] =
    await queries(c, [
      [`select count(*)::int as sales, coalesce(sum(total),0) as total
          from orders where channel='RETAIL' and status = 'FULFILLED'
           and created_at::date = current_date`],
      [`select count(*)::int as n from orders
         where channel='B2B' and status in ('PLACED','PICKING')`],
      [`select * from reorder_alerts order by shortfall desc`],
      [`select * from aging_stock_alerts order by days_to_expiry asc limit 25`],
      [`select i.id, i.due_date, r.name,
               (i.amount - i.paid_amount - i.discount_applied) as balance,
               (current_date - i.due_date)::int as days_overdue
          from invoices i join resellers r on r.id = i.reseller_id
         where i.status='OPEN' and i.due_date < current_date
         order by i.due_date`],
      [`select * from ar_exposure where flagged`],
      [`select * from retail_replenishment_alerts order by shelf_available`],
      [`select rr.*, p.name from restock_requests rr join products p on p.sku=rr.sku
         where rr.status='OPEN' order by rr.ts`],
      [`select * from expired_stock`],
      [`select * from cashier_variance_watch`],
    ]);
  json(res, 200, {
    today_retail: today.rows[0],
    pending_b2b: pending.rows[0].n,
    reorder_alerts: reorder.rows,
    aging_stock: aging.rows,
    overdue_invoices: overdue.rows,
    ar_exposure: exposure.rows,
    shelf_alerts: shelf.rows,
    restock_requests: restock.rows,
    expired_stock: expired.rows,
    cashier_variance: variance.rows,
  });
});

// ---- products & batches ----------------------------------------------------
const POOL_SUMS = `
  select p.sku, p.name, p.brand, p.category, p.unit_cost, p.wholesale_price, p.srp,
         p.retail_price, p.shelf_life_months, p.reseller_floor_months, p.abc_class,
         p.active, p.retail_min_qty,
         coalesce(p.alloc_b2b, 0.70) as alloc_b2b,
         coalesce(p.alloc_retail, 0.20) as alloc_retail,
         coalesce(p.alloc_safety, 0.10) as alloc_safety,
         coalesce(sum(case when sl.pool='B2B_POOL' then sl.qty_on_hand - sl.qty_committed end),0)::int as b2b_avail,
         coalesce(sum(case when sl.pool='RETAIL_SHELF' then sl.qty_on_hand - sl.qty_committed end),0)::int as retail_avail,
         coalesce(sum(case when sl.pool='SAFETY' then sl.qty_on_hand - sl.qty_committed end),0)::int as safety_avail,
         coalesce(sum(case when sl.pool='B2B_POOL' then sl.qty_committed end),0)::int as b2b_committed,
         coalesce(sum(sl.qty_on_hand),0)::int as total_on_hand
    from products p
    left join batches b on b.sku = p.sku and b.expiry_date > current_date
    left join stock_ledger sl on sl.batch_id = b.id
   group by p.sku`;

route('GET', '/api/products', STAFF, async ({ c, query, res }) => {
  const q = `%${query.q || ''}%`;
  const r = await c.query(
    `${POOL_SUMS} having p.sku ilike $1 or p.name ilike $1 or coalesce(p.brand,'') ilike $1
      order by p.name`, [q]);
  json(res, 200, r.rows);
});

route('POST', '/api/products', ADMIN, async ({ c, body, res }) => {
  const b = body;
  await c.query(
    `insert into products (sku, name, brand, category, unit_cost, wholesale_price, srp,
                           retail_price, shelf_life_months, reseller_floor_months, retail_min_qty)
     values ($1,$2,$3,$4,$5,$6,$7,$8,$9,coalesce($10,12),coalesce($11,0))`,
    [b.sku, b.name, b.brand || null, b.category || null, b.unit_cost || 0,
     b.wholesale_price || 0, b.srp || 0, b.retail_price || 0,
     b.shelf_life_months || 24, b.reseller_floor_months, b.retail_min_qty]);
  json(res, 200, { ok: true });
});

route('PUT', '/api/products/:sku', ADMIN, async ({ c, body, params, res }) => {
  const allowed = ['name', 'brand', 'category', 'unit_cost', 'wholesale_price', 'srp',
    'retail_price', 'shelf_life_months', 'reseller_floor_months', 'retail_min_qty',
    'active', 'alloc_b2b', 'alloc_retail', 'alloc_safety'];
  const sets = []; const vals = [params.sku];
  for (const k of allowed) {
    if (k in body) { vals.push(body[k]); sets.push(`${k} = $${vals.length}`); }
  }
  if (!sets.length) return json(res, 400, { error: 'nothing to update' });
  await c.query(`update products set ${sets.join(', ')} where sku = $1`, vals);
  json(res, 200, { ok: true });
});

route('GET', '/api/products/:sku/batches', STAFF, async ({ c, params, res }) => {
  const r = await c.query(
    `select b.id, b.batch_number, b.expiry_date, b.qty_received, b.received_at,
            (b.expiry_date - current_date)::int as days_to_expiry,
            (b.expiry_date <= current_date) as expired,
            (b.expiry_date <= current_date + 180 and b.expiry_date > current_date) as aging,
            (b.expiry_date <= (current_date + make_interval(months => p.reseller_floor_months))::date) as below_floor,
            coalesce(jsonb_object_agg(sl.pool,
              jsonb_build_object('on_hand', sl.qty_on_hand, 'committed', sl.qty_committed))
              filter (where sl.pool is not null), '{}'::jsonb) as pools
       from batches b
       join products p on p.sku = b.sku
       left join stock_ledger sl on sl.batch_id = b.id
      where b.sku = $1
      group by b.id, p.reseller_floor_months
      order by b.expiry_date`, [params.sku]);
  json(res, 200, r.rows);
});

route('POST', '/api/receive', WH, async ({ c, body, res }) => {
  const { sku, batch_number, expiry_date, qty } = body;
  const r = await c.query('select receive_batch($1,$2,$3,$4) as id',
    [sku, batch_number, expiry_date, Number(qty)]);
  const alloc = await c.query(
    `select pool, qty_on_hand from stock_ledger where batch_id = $1 order by pool`,
    [r.rows[0].id]);
  json(res, 200, { batch_id: Number(r.rows[0].id), allocation: alloc.rows });
});

// ---- stock, transfers, counts ---------------------------------------------
route('GET', '/api/stock', STAFF, async ({ c, res }) => {
  const r = await c.query(`${POOL_SUMS} order by p.name`);
  json(res, 200, r.rows);
});

route('POST', '/api/transfer', WH, async ({ c, body, res }) => {
  await c.query('select transfer_stock($1,$2,$3,$4)',
    [Number(body.batch_id), body.from_pool, body.to_pool, Number(body.qty)]);
  json(res, 200, { ok: true });
});

route('POST', '/api/cycle-count', WH, async ({ c, body, res }) => {
  const r = await c.query('select to_jsonb(record_cycle_count($1,$2)) as row',
    [body.sku, Number(body.counted)]);
  json(res, 200, r.rows[0].row);
});

route('GET', '/api/cycle-counts', WH, async ({ c, res }) => {
  const r = await c.query(
    `select cc.*, p.name from cycle_counts cc join products p on p.sku = cc.sku
      order by cc.ts desc limit 50`);
  json(res, 200, r.rows);
});

route('GET', '/api/expired', WH, async ({ c, res }) => {
  const r = await c.query('select * from expired_stock order by expiry_date');
  json(res, 200, r.rows);
});

route('POST', '/api/write-off-expired', WH, async ({ c, body, res }) => {
  const r = await c.query('select write_off_expired($1) as units',
    [body.batch_id == null ? null : Number(body.batch_id)]);
  json(res, 200, { units_written_off: r.rows[0].units });
});

route('GET', '/api/restock-requests', STAFF, async ({ c, res }) => {
  const r = await c.query(
    `select rr.*, p.name from restock_requests rr join products p on p.sku = rr.sku
      order by (rr.status = 'OPEN') desc, rr.ts desc limit 100`);
  json(res, 200, r.rows);
});

route('POST', '/api/restock-requests', STAFF, async ({ c, body, res }) => {
  const r = await c.query('select request_restock($1,$2) as id', [body.sku, body.note || null]);
  json(res, 200, { id: Number(r.rows[0].id) });
});

route('POST', '/api/restock-requests/:id/close', WH, async ({ c, params, res }) => {
  await c.query('select close_restock($1)', [Number(params.id)]);
  json(res, 200, { ok: true });
});

// ---- B2B orders pipeline ---------------------------------------------------
route('GET', '/api/orders', WH, async ({ c, query, res }) => {
  const status = query.status || '';
  const r = await c.query(
    `select * from order_fulfilment
      where channel = 'B2B'
        and ($1 = '' or ($1 = 'DELIVERED' and delivered_at is not null)
                     or ($1 <> 'DELIVERED' and status = $1
                         and ($1 <> 'FULFILLED' or delivered_at is null)))
      order by created_at desc limit 200`, [status]);
  json(res, 200, r.rows);
});

route('GET', '/api/orders/:id', WH, async ({ c, params, res }) => {
  const o = await c.query('select * from order_fulfilment where id = $1', [Number(params.id)]);
  if (!o.rows.length) return json(res, 404, { error: 'unknown order' });
  const lines = await c.query(
    `select ol.sku, p.name, ol.qty, ol.unit_price, b.batch_number, b.expiry_date
       from order_lines ol
       join products p on p.sku = ol.sku
       join batches b on b.id = ol.batch_id
      where ol.order_id = $1
      order by b.expiry_date, b.id`, [Number(params.id)]);
  json(res, 200, { ...o.rows[0], lines: lines.rows });
});

route('POST', '/api/orders/:id/picking', WH, async ({ c, params, res }) => {
  await c.query('select mark_order_picking($1)', [Number(params.id)]);
  json(res, 200, { ok: true });
});
route('POST', '/api/orders/:id/fulfill', WH, async ({ c, params, res }) => {
  await c.query('select fulfill_order($1)', [Number(params.id)]);
  json(res, 200, { ok: true });
});
route('POST', '/api/orders/:id/deliver', WH, async ({ c, params, res }) => {
  await c.query('select mark_order_delivered($1)', [Number(params.id)]);
  json(res, 200, { ok: true });
});
route('POST', '/api/orders/:id/cancel', WH, async ({ c, params, res }) => {
  await c.query('select cancel_order($1)', [Number(params.id)]);
  json(res, 200, { ok: true });
});

// ---- resellers & credit (admin) -------------------------------------------
route('GET', '/api/resellers', ADMIN, async ({ c, res }) => {
  const r = await c.query(
    `select r.*, reseller_outstanding(r.id) as outstanding,
            reseller_has_past_due(r.id) as past_due,
            (select count(*)::int from invoices i
              where i.reseller_id = r.id and i.status='PAID' and i.paid_at <= i.due_date) as on_time_paid,
            (select count(*)::int from reseller_events e
              where e.reseller_id = r.id and e.event_type='LATE_PAYMENT'
                and e.ts > now() - interval '90 days') as lates_this_quarter
       from resellers r order by r.name`);
  json(res, 200, r.rows);
});

route('POST', '/api/resellers', ADMIN, async ({ c, body, res }) => {
  const r = await c.query('select admin_create_reseller($1,$2,$3,$4,$5,$6) as id',
    [body.name, body.email || null, body.tier || 1, body.credit_limit || 0,
     body.payment_terms_days || 0, body.avg_monthly_order || 0]);
  json(res, 200, { id: Number(r.rows[0].id) });
});

route('GET', '/api/resellers/:id', ADMIN, async ({ c, params, res }) => {
  const id = Number(params.id);
  const [r, invoices, events, docs] = await queries(c, [
    [`select r.*, reseller_outstanding(r.id) as outstanding,
             reseller_has_past_due(r.id) as past_due
        from resellers r where r.id = $1`, [id]],
    [`select i.*, (i.amount - i.paid_amount - i.discount_applied) as balance,
             (i.status='OPEN' and i.due_date < current_date) as overdue
        from invoices i where i.reseller_id = $1 order by i.issued_at desc`, [id]],
    [`select * from reseller_events where reseller_id = $1 order by ts desc limit 50`, [id]],
    [`select * from reseller_documents where reseller_id = $1 order by uploaded_at desc`, [id]],
  ]);
  if (!r.rows.length) return json(res, 404, { error: 'unknown reseller' });
  json(res, 200, { ...r.rows[0], invoices: invoices.rows, events: events.rows, documents: docs.rows });
});

route('POST', '/api/resellers/:id/verify', ADMIN, async ({ c, params, res }) => {
  await c.query('select admin_verify_reseller($1)', [Number(params.id)]);
  json(res, 200, { ok: true });
});
route('POST', '/api/resellers/:id/tier', ADMIN, async ({ c, params, body, res }) => {
  await c.query('select admin_set_tier($1,$2,$3,$4)',
    [Number(params.id), Number(body.tier), Number(body.credit_limit),
     Number(body.payment_terms_days)]);
  json(res, 200, { ok: true });
});
route('POST', '/api/resellers/:id/unblock', ADMIN, async ({ c, params, body, res }) => {
  if (!body.note) return json(res, 400, { error: 'An override note is required — it is logged.' });
  await c.query('select admin_unblock_reseller($1,$2)', [Number(params.id), body.note]);
  json(res, 200, { ok: true });
});
route('POST', '/api/resellers/:id/documents', ADMIN, async ({ c, params, body, res }) => {
  await c.query(
    `insert into reseller_documents (reseller_id, doc_type, file_ref, verified, verified_by, verified_at)
     values ($1,$2,$3,true,app_actor(),now())`,
    [Number(params.id), body.doc_type, body.file_ref]);
  json(res, 200, { ok: true });
});

route('GET', '/api/invoices', ADMIN, async ({ c, query, res }) => {
  const r = await c.query(
    `select i.*, r.name as reseller_name,
            (i.amount - i.paid_amount - i.discount_applied) as balance,
            (i.status='OPEN' and i.due_date < current_date) as overdue
       from invoices i join resellers r on r.id = i.reseller_id
      where ($1 = '' or i.status = $1)
      order by i.issued_at desc limit 200`, [query.status || '']);
  json(res, 200, r.rows);
});

route('POST', '/api/invoices/:id/pay', ADMIN, async ({ c, params, body, res }) => {
  await c.query('select record_payment($1,$2,$3)',
    [Number(params.id), Number(body.amount), body.paid_on || new Date().toISOString().slice(0, 10)]);
  json(res, 200, { ok: true });
});

// ---- users (admin) ---------------------------------------------------------
route('GET', '/api/users', ADMIN, async ({ c, res }) => {
  const r = await c.query(
    `select u.id, u.username, u.display_name, u.role, u.reseller_id, u.active, r.name as reseller_name
       from app_users u left join resellers r on r.id = u.reseller_id order by u.username`);
  json(res, 200, r.rows);
});
route('POST', '/api/users', ADMIN, async ({ c, body, res }) => {
  if (!body.username || !body.password) return json(res, 400, { error: 'username and password required' });
  const r = await c.query('select admin_create_user($1,$2,$3,$4,$5) as id',
    [body.username, body.display_name || body.username, hashPassword(body.password),
     body.role, body.reseller_id == null ? null : Number(body.reseller_id)]);
  json(res, 200, { id: Number(r.rows[0].id) });
});
route('POST', '/api/users/:id/active', ADMIN, async ({ c, params, body, res }) => {
  await c.query('select admin_set_user_active($1,$2)', [Number(params.id), !!body.active]);
  json(res, 200, { ok: true });
});

// ---- ROP -------------------------------------------------------------------
route('GET', '/api/rop', WH, async ({ c, res }) => {
  const r = await c.query(
    `select p.sku, p.name, p.abc_class, r.avg_daily_sales, r.max_daily_sales,
            r.avg_lead_days, r.max_lead_days, r.safety_stock, r.rop,
            r.target_months_cover, r.last_recalc,
            ra.sellable_stock, ra.shortfall, ra.suggested_order_qty
       from products p
       left join rop_settings r on r.sku = p.sku
       left join reorder_alerts ra on ra.sku = p.sku
      where p.active order by p.name`);
  json(res, 200, r.rows);
});
route('POST', '/api/rop/:sku', WH, async ({ c, params, body, res }) => {
  await c.query('select set_rop($1,$2,$3,$4,$5)',
    [params.sku, Number(body.avg_daily), Number(body.max_daily),
     Number(body.avg_lead), Number(body.max_lead)]);
  if (body.target_months_cover) {
    await c.query('select set_rop_cover($1,$2)', [params.sku, Number(body.target_months_cover)]);
  }
  const r = await c.query('select to_jsonb(s) as row from rop_settings s where sku = $1', [params.sku]);
  json(res, 200, r.rows[0].row);
});
route('POST', '/api/rop/:sku/recalc', WH, async ({ c, params, res }) => {
  const r = await c.query('select to_jsonb(recalc_rop_from_sales($1)) as row', [params.sku]);
  json(res, 200, r.rows[0].row);
});

// ---- reports (admin) -------------------------------------------------------
route('GET', '/api/reports/sales', ADMIN, async ({ c, query, res }) => {
  const from = query.from || '1970-01-01';
  const to = query.to || '2999-12-31';
  const [byChannel, byProduct, byDay] = await queries(c, [
    [`select channel, count(*)::int as orders, sum(total) as revenue
        from orders where status = 'FULFILLED'
         and created_at::date between $1 and $2 group by channel`, [from, to]],
    [`select ol.sku, p.name, sum(ol.qty)::int as units,
             sum(ol.qty * ol.unit_price - ol.discount) as revenue
        from order_lines ol
        join orders o on o.id = ol.order_id
        join products p on p.sku = ol.sku
       where o.status = 'FULFILLED'
         and o.created_at::date between $1 and $2
       group by ol.sku, p.name order by revenue desc limit 50`, [from, to]],
    [`select created_at::date as day, channel, sum(total) as revenue
        from orders where status = 'FULFILLED'
         and created_at::date between $1 and $2
       group by day, channel order by day`, [from, to]],
  ]);
  json(res, 200, { by_channel: byChannel.rows, by_product: byProduct.rows, by_day: byDay.rows });
});

route('GET', '/api/reports/valuation', ADMIN, async ({ c, res }) => {
  const r = await c.query(
    `select p.sku, p.name, p.unit_cost,
            coalesce(sum(sl.qty_on_hand),0)::int as units,
            coalesce(sum(sl.qty_on_hand),0) * p.unit_cost as value
       from products p
       left join batches b on b.sku = p.sku and b.expiry_date > current_date
       left join stock_ledger sl on sl.batch_id = b.id
      group by p.sku order by value desc`);
  json(res, 200, r.rows);
});

route('GET', '/api/reports/aging', ADMIN, async ({ c, res }) => {
  const r = await c.query('select * from aging_stock_alerts order by days_to_expiry');
  json(res, 200, r.rows);
});

route('GET', '/api/reports/ar', ADMIN, async ({ c, res }) => {
  const [aging, exposure] = await queries(c, [
    ['select * from ar_aging order by total_outstanding desc'],
    ['select * from ar_exposure order by share desc'],
  ]);
  json(res, 200, { aging: aging.rows, exposure: exposure.rows });
});

route('GET', '/api/reports/ledger', WH, async ({ c, query, res }) => {
  const r = await c.query(
    `select * from movement_ledger
      where ($1 = '' or sku ilike $2 or name ilike $2 or reason ilike $2)
      order by ts desc limit $3`,
    [query.q || '', `%${query.q || ''}%`, clampLimit(query.limit)]);
  json(res, 200, r.rows);
});

// ---- POS (cashier) ---------------------------------------------------------
route('GET', '/api/pos/products', CASHIER, async ({ c, query, res }) => {
  const q = `%${query.q || ''}%`;
  const r = await c.query(
    `select p.sku, p.name, p.brand, p.category, p.retail_price,
            coalesce(sum(sl.qty_on_hand - sl.qty_committed),0)::int as shelf_available
       from products p
       left join batches b on b.sku = p.sku and b.expiry_date > current_date
       left join stock_ledger sl on sl.batch_id = b.id and sl.pool = 'RETAIL_SHELF'
      where p.active and (p.sku ilike $1 or p.name ilike $1 or coalesce(p.brand,'') ilike $1)
      group by p.sku order by p.name limit 60`, [q]);
  json(res, 200, r.rows);
});

route('POST', '/api/pos/checkout', CASHIER, async ({ c, body, res }) => {
  const lines = (body.lines || []).map((l) => ({ sku: l.sku, qty: Number(l.qty) }));
  if (!lines.length) return json(res, 400, { error: 'Cart is empty.' });
  const r = await c.query('select pos_checkout($1,$2,$3) as receipt',
    [JSON.stringify(lines), body.method,
     body.tendered == null ? null : Number(body.tendered)]);
  json(res, 200, r.rows[0].receipt);
});

route('GET', '/api/pos/receipts', CASHIER, async ({ c, res }) => {
  const r = await c.query(
    `select rs.receipt_no, rs.amount_due, rs.payment_method, rs.ts, rs.cashier
       from retail_sales rs order by rs.ts desc limit 50`);
  json(res, 200, r.rows);
});

route('GET', '/api/pos/receipt/:no', CASHIER, async ({ c, params, res }) => {
  const s = await c.query('select * from retail_sales where receipt_no = $1', [params.no]);
  if (!s.rows.length) return json(res, 404, { error: 'No receipt with that number.' });
  const lines = await c.query(
    `select ol.sku, p.name, ol.qty, ol.unit_price, ol.batch_id, b.batch_number,
            ol.qty
            - coalesce((select sum(rr2.qty) from retail_returns rr2
                         where rr2.order_id = ol.order_id and rr2.sku = ol.sku
                           and rr2.batch_id = ol.batch_id), 0)
            - coalesce((select sum(q.qty) from return_requests q
                         where q.order_id = ol.order_id and q.sku = ol.sku
                           and q.batch_id = ol.batch_id and q.status = 'PENDING'), 0)
            as returnable
       from order_lines ol
       join products p on p.sku = ol.sku
       join batches b on b.id = ol.batch_id
      where ol.order_id = $1 order by ol.id`, [s.rows[0].order_id]);
  json(res, 200, { ...s.rows[0], lines: lines.rows });
});

route('POST', '/api/pos/returns', CASHIER, async ({ c, body, res }) => {
  const r = await c.query('select request_return($1,$2,$3,$4,$5) as id',
    [body.receipt_no, body.sku, Number(body.batch_id), Number(body.qty), body.reason]);
  json(res, 200, { id: Number(r.rows[0].id) });
});

route('GET', '/api/pos/returns', CASHIER, async ({ c, res }) => {
  const r = await c.query(
    `select q.*, p.name from return_requests q join products p on p.sku = q.sku
      order by (q.status='PENDING') desc, q.ts desc limit 100`);
  json(res, 200, r.rows);
});

route('POST', '/api/pos/tester-log', CASHIER, async ({ c, body, sess, res }) => {
  await c.query('select log_tester($1,$2,$3,$4,$5,$6)',
    [body.sku, Number(body.batch_id), Number(body.qty),
     body.shift || 'DAY', body.reason, sess.username]);
  json(res, 200, { ok: true });
});

route('GET', '/api/pos/shelf-batches/:sku', CASHIER, async ({ c, params, res }) => {
  const r = await c.query(
    `select b.id as batch_id, b.batch_number, b.expiry_date,
            (sl.qty_on_hand - sl.qty_committed)::int as available
       from batches b join stock_ledger sl on sl.batch_id = b.id
      where b.sku = $1 and sl.pool = 'RETAIL_SHELF'
        and sl.qty_on_hand - sl.qty_committed > 0
      order by b.expiry_date`, [params.sku]);
  json(res, 200, r.rows);
});

route('POST', '/api/pos/eod', CASHIER, async ({ c, body, res }) => {
  const r = await c.query('select pos_eod_close($1) as result', [Number(body.declared)]);
  json(res, 200, r.rows[0].result);
});

route('GET', '/api/pos/eod', CASHIER, async ({ c, res }) => {
  const r = await c.query('select * from my_cash_drops order by business_date desc limit 30');
  json(res, 200, r.rows);
});

// ---- returns queue (admin) -------------------------------------------------
route('GET', '/api/returns', ADMIN, async ({ c, res }) => {
  const r = await c.query(
    `select q.*, p.name, b.batch_number
       from return_requests q
       join products p on p.sku = q.sku
       join batches b on b.id = q.batch_id
      order by (q.status='PENDING') desc, q.ts desc limit 100`);
  json(res, 200, r.rows);
});
route('POST', '/api/returns/:id/decide', ADMIN, async ({ c, params, body, res }) => {
  await c.query('select decide_return($1,$2,$3)',
    [Number(params.id), !!body.approve, body.disposition || 'RESTOCK']);
  json(res, 200, { ok: true });
});

// ---- reseller portal -------------------------------------------------------
route('GET', '/api/portal/catalog', RESELLER, async ({ c, res }) => {
  const r = await c.query(
    `select sku, name, brand, category, wholesale_price, srp, available
       from b2b_available_stock order by name`);
  json(res, 200, r.rows);
});

route('POST', '/api/portal/orders', RESELLER, async ({ c, body, sess, res }) => {
  // Prices always come from the catalog server-side — never from the client.
  const lines = (body.lines || []).map((l) => ({ sku: l.sku, qty: Number(l.qty) }));
  if (!lines.length) return json(res, 400, { error: 'Your cart is empty.' });
  const r = await c.query('select place_order($1,$2,$3) as id',
    ['B2B', JSON.stringify(lines), sess.rid]);
  const inv = await c.query('select * from invoices where order_id = $1', [r.rows[0].id]);
  json(res, 200, { order_id: Number(r.rows[0].id), invoice: inv.rows[0] || null });
});

route('GET', '/api/portal/orders', RESELLER, async ({ c, res }) => {
  const r = await c.query(
    `select o.id, o.status, o.total, o.created_at,
            i.id as invoice_id, i.status as invoice_status, i.due_date,
            (i.amount - i.paid_amount - i.discount_applied) as invoice_balance,
            coalesce(jsonb_agg(jsonb_build_object(
              'sku', ol.sku, 'qty', ol.qty, 'unit_price', ol.unit_price)
              order by ol.id) filter (where ol.id is not null), '[]'::jsonb) as lines
       from orders o
       left join invoices i on i.order_id = o.id
       left join order_lines ol on ol.order_id = o.id
      group by o.id, i.id
      order by o.created_at desc limit 100`);
  json(res, 200, r.rows);
});

route('POST', '/api/portal/orders/:id/cancel', RESELLER, async ({ c, params, res }) => {
  await c.query('select cancel_order($1)', [Number(params.id)]);
  json(res, 200, { ok: true });
});

route('GET', '/api/portal/credit', RESELLER, async ({ c, sess, res }) => {
  const r = await c.query('select * from resellers where id = $1', [sess.rid]);
  if (!r.rows.length) return json(res, 404, { error: 'no reseller record linked' });
  const inv = await c.query(
    `select i.*, (i.amount - i.paid_amount - i.discount_applied) as balance,
            (i.status='OPEN' and i.due_date < current_date) as overdue
       from invoices i order by i.issued_at desc limit 100`);
  const open = inv.rows.filter((i) => i.status === 'OPEN');
  const pastDue = open.filter((i) => i.overdue);
  const outstanding = open.reduce((s, i) => s + Number(i.balance), 0);
  const toUnblock = pastDue.reduce((s, i) => s + Number(i.balance), 0);
  const row = r.rows[0];
  json(res, 200, {
    reseller: row,
    invoices: inv.rows,
    outstanding,
    credit_limit: Number(row.credit_limit),
    blocked: row.blocked || pastDue.length > 0,
    blocked_reason: pastDue.length
      ? `You have ${pastDue.length} past-due invoice(s) totalling ${peso(toUnblock)}. Pay this amount to unblock ordering.`
      : (row.blocked ? `Your account is blocked: ${row.blocked_reason || 'contact MS BEAU AVE'}.` : null),
    pay_to_unblock: toUnblock,
  });
});

// ---------------------------------------------------------------------------
// Static SPA + logo
// ---------------------------------------------------------------------------
const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.svg': 'image/svg+xml', '.png': 'image/png',
  '.jpg': 'image/jpeg', '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json',
};
const LOGO = path.join(__dirname, '..', 'ms beau logo.jpg');

function serveStatic(req, res, pathname) {
  if (pathname === '/logo.jpg' && fs.existsSync(LOGO)) {
    res.writeHead(200, { 'Content-Type': 'image/jpeg', 'Cache-Control': 'public, max-age=86400' });
    return fs.createReadStream(LOGO).pipe(res);
  }
  let file = path.normalize(path.join(PUBLIC_DIR, pathname === '/' ? 'index.html' : pathname));
  // Compare on a path boundary — a bare prefix test would also accept a
  // sibling directory whose name merely starts with "public".
  if (file !== PUBLIC_DIR && !file.startsWith(PUBLIC_DIR + path.sep)) {
    res.writeHead(403); return res.end();
  }
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) {
    file = path.join(PUBLIC_DIR, 'index.html');   // SPA fallback
  }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
}

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x');
  const pathname = decodeURIComponent(url.pathname);
  if (!pathname.startsWith('/api/')) return serveStatic(req, res, pathname);

  const found = routes.filter((r) => r.re.test(pathname));
  const match = found.find((r) => r.method === req.method);
  if (!match) {
    json(res, found.length ? 405 : 404,
      { error: found.length ? 'method not allowed' : 'no such endpoint' });
    return flush(res);
  }

  const params = {};
  match.re.exec(pathname).slice(1).forEach((v, i) => { params[match.keys[i]] = v; });
  const query = Object.fromEntries(url.searchParams);

  try {
    const body = ['POST', 'PUT', 'PATCH'].includes(req.method) ? await readBody(req) : {};

    if (match.roles === 'public') {
      await match.fn({ req, res, body, params, query });
    } else {
      const sess = session(req);
      if (!sess) {
        json(res, 401, { error: 'Please sign in.' });
      } else if (Array.isArray(match.roles) && !match.roles.includes(sess.role)) {
        json(res, 403, { error: 'Your role is not allowed to do that.' });
      } else {
        // The staged response is only flushed below, after the commit lands.
        await withRole(sess, (c, live) =>
          match.fn({ req, res, c, sess: live, body, params, query }));
      }
    }
    flush(res);
  } catch (e) {
    res.staged = null;                       // never emit a half-finished result
    flush(res, {
      code: e.status ?? 400,
      body: JSON.stringify({ error: friendly(e), code: e.code }),
    });
  }
});

// First run on an empty database: create the owner login so the user can get in.
async function ensureAdmin() {
  const r = await db.query('select count(*)::int as n from app_users');
  if (r.rows[0].n === 0) {
    await db.query(
      `insert into app_users (username, display_name, password_hash, role)
       values ('admin', 'Owner', $1, 'OWNER_ADMIN')`, [hashPassword('msbeauave')]);
    console.log('Created first admin login → username: admin  password: msbeauave (change it!)');
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  ensureAdmin()
    .then(() => server.listen(PORT, () =>
      console.log(`MS BEAU AVE running → http://localhost:${PORT}`)))
    .catch((e) => { console.error('startup failed:', e.message); process.exit(1); });
}

export { server, db, ensureAdmin };

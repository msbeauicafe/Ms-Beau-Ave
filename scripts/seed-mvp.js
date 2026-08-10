#!/usr/bin/env node
// ============================================================================
// MS BEAU AVE — demo seed (Spec-MVP.md §9 "Seed data")
//
// ~30 SKUs across brands and categories, batches with staggered expiries
// (including some inside 6 months and some under the 12-month reseller floor),
// 5 resellers across all three tiers with one past-due/blocked account,
// two months of sales history so the reports and the 90-day ROP recalculation
// have something real to chew on, and one login per role.
//
//   DATABASE_URL=postgres://…  node scripts/seed-mvp.js
// ============================================================================
import pg from 'pg';
import { hashPassword } from '../app/password.js';

const DSN = process.env.DATABASE_URL || process.env.IMS_TEST_DSN;
if (!DSN) {
  console.error('Set DATABASE_URL (or IMS_TEST_DSN) first.');
  process.exit(1);
}
const db = new pg.Client({ connectionString: DSN });

/** ISO date n months from today (negative = in the past). */
function monthsOut(n) {
  const d = new Date();
  d.setMonth(d.getMonth() + n);
  return d.toISOString().slice(0, 10);
}
const daysAgo = (n) => new Date(Date.now() - n * 864e5);

async function as(role, actor, fn) {
  await db.query(`select set_config('app.role', $1, false), set_config('app.actor', $2, false)`,
    [role, actor]);
  const out = await fn();
  await db.query(`select set_config('app.role', 'OWNER_ADMIN', false),
                         set_config('app.actor', 'seed', false)`);
  return out;
}

// ---------------------------------------------------------------------------
// Catalog: sku, name, brand, category, cost, wholesale, srp, retail, shelf life,
// shelf minimum. MAP discipline: retail >= srp >= wholesale > cost.
// ---------------------------------------------------------------------------
const PRODUCTS = [
  ['SER-001', 'Radiance Vitamin C Serum 30ml',       'Beau Glow',     'Serums',    210, 380,  650,  690, 24, 6],
  ['SER-002', 'Retinoid Night Active Serum 30ml',    'Aurea Lab',     'Serums',    295, 520,  890,  950, 18, 4],
  ['SER-003', 'Niacinamide Clarifying Serum 30ml',   'Beau Glow',     'Serums',    185, 340,  580,  620, 24, 6],
  ['SER-004', 'Hyaluronic Hydra Boost Serum 30ml',   'Luna Derm',     'Serums',    225, 410,  700,  740, 24, 5],
  ['SER-005', 'Peptide Firming Serum 30ml',          'Aurea Lab',     'Serums',    340, 610, 1050, 1120, 18, 3],
  ['SER-006', 'Centella Calming Ampoule 30ml',       'Isla Naturals', 'Serums',    195, 355,  610,  650, 24, 4],
  ['CRM-001', 'Photoprotectant Day Cream 50ml',      'Luna Derm',     'Creams',    240, 430,  740,  780, 24, 5],
  ['CRM-002', 'Barrier Repair Night Cream 50ml',     'Luna Derm',     'Creams',    265, 470,  810,  850, 24, 4],
  ['CRM-003', 'Brightening Underarm Cream 30ml',     'Rosa Botanica', 'Creams',    120, 225,  390,  420, 24, 8],
  ['CRM-004', 'Ceramide Moisture Gel 50ml',          'Isla Naturals', 'Creams',    175, 320,  550,  590, 24, 5],
  ['CRM-005', 'Anti-Melasma Spot Cream 15ml',        'Aurea Lab',     'Creams',    280, 500,  860,  900, 18, 3],
  ['CRM-006', 'Rice Water Sleeping Mask 60ml',       'Isla Naturals', 'Creams',    160, 295,  510,  545, 24, 6],
  ['LIP-001', 'Rose Tint Lip & Cheek 6ml',           'Rosa Botanica', 'Lip',        85, 165,  290,  310, 30, 10],
  ['LIP-002', 'Velvet Matte Lipstick — Dusty Pink',  'Rosa Botanica', 'Lip',       110, 210,  360,  390, 36, 10],
  ['LIP-003', 'Hydrating Lip Sleeping Mask 8g',      'Beau Glow',     'Lip',        95, 180,  310,  330, 30, 8],
  ['LIP-004', 'Peptide Lip Serum 5ml',               'Aurea Lab',     'Lip',       140, 260,  450,  480, 24, 6],
  ['LIP-005', 'Tinted Lip Balm SPF15 4g',            'Luna Derm',     'Lip',        75, 145,  250,  270, 30, 12],
  ['SOP-001', 'Micro-Exfoliating Beauty Soap 120g',  'Beau Glow',     'Soaps',      55, 110,  190,  205, 36, 20],
  ['SOP-002', 'Clarifying Kojic Soap 120g',          'Beau Glow',     'Soaps',      60, 120,  210,  225, 36, 20],
  ['SOP-003', 'Brightening Papaya Soap 120g',        'Rosa Botanica', 'Soaps',      48,  95,  165,  180, 36, 24],
  ['SOP-004', 'Charcoal Detox Soap 120g',            'Isla Naturals', 'Soaps',      52, 105,  180,  195, 36, 18],
  ['SOP-005', 'Goat Milk Gentle Soap 120g',          'Isla Naturals', 'Soaps',      58, 115,  200,  215, 36, 16],
  ['SOP-006', 'Sulfur Acne Bar 100g',                'Aurea Lab',     'Soaps',      65, 130,  225,  240, 30, 12],
  ['TON-001', 'Peeling Toner / Keratolytic 120ml',   'Aurea Lab',     'Toners',    190, 350,  600,  640, 18, 5],
  ['TON-002', 'Rose Hydrating Toner 200ml',          'Rosa Botanica', 'Toners',    135, 250,  430,  460, 24, 8],
  ['TON-003', 'BHA Pore Clarifying Toner 150ml',     'Beau Glow',     'Toners',    165, 305,  525,  560, 18, 6],
  ['TON-004', 'Green Tea Balancing Toner 200ml',     'Isla Naturals', 'Toners',    125, 235,  405,  435, 24, 8],
  ['SUN-001', 'Daily Shield Sunscreen SPF50 50ml',   'Luna Derm',     'Sunscreen', 235, 425,  730,  770, 24, 8],
  ['SUN-002', 'Tinted Mineral Sunscreen SPF40 40ml', 'Beau Glow',     'Sunscreen', 260, 470,  810,  860, 24, 5],
  ['SUN-003', 'Sunscreen Stick SPF50 15g',           'Rosa Botanica', 'Sunscreen', 195, 360,  620,  660, 24, 6],
];

// Batch plan per SKU: [monthsToExpiry, qty]. The first entry is the bulk of the
// stock; extra entries deliberately exercise FEFO, the 6-month aging flag and
// the 12-month reseller floor.
const EXTRA_BATCHES = {
  'SER-001': [[4, 60], [14, 180]],    // one aging batch, one mid-life
  'SER-002': [[10, 90]],              // under the 12-month floor → retail only
  'SER-004': [[5, 40]],               // aging
  'CRM-001': [[11, 120]],             // under the floor
  'CRM-003': [[3, 50]],               // aging hard
  'LIP-002': [[15, 200]],
  'SOP-001': [[9, 240]],              // under the floor
  'TON-001': [[5, 70]],               // aging — expiry-sensitive active
  'SUN-001': [[13, 150]],
};

const RESELLERS = [
  { name: 'Bella Skin Manila',       email: 'orders@bellaskin.ph',    tier: 3, limit: 500000, terms: 45, verify: true,  avg: 320000 },
  { name: 'Cebu Glow Distributors',  email: 'buyer@cebuglow.ph',      tier: 2, limit: 150000, terms: 30, verify: true,  avg: 110000 },
  { name: 'Davao Beauty Hub',        email: 'admin@davaobeauty.ph',   tier: 2, limit: 120000, terms: 30, verify: true,  avg: 90000 },
  { name: 'Iloilo Radiance Store',   email: 'hello@iloiloradiance.ph', tier: 1, limit: 0,     terms: 0,  verify: true,  avg: 25000 },
  { name: 'Baguio Beaute Corner',    email: 'apply@baguiobeaute.ph',  tier: 1, limit: 0,      terms: 0,  verify: false, avg: 0 },
];

// Reorder points. SER-001 is the spec's worked example: avg 10/day, max 15/day,
// avg lead 60, max lead 75 → safety stock 525, ROP 1,125.
const ROP = [
  ['SER-001', 10, 15, 60, 75],
  ['SER-002', 4, 7, 60, 80],
  ['SER-003', 6, 10, 45, 60],
  ['CRM-001', 5, 9, 50, 70],
  ['CRM-003', 8, 14, 40, 55],
  ['LIP-002', 12, 20, 35, 50],
  ['SOP-001', 25, 40, 30, 45],
  ['SOP-002', 18, 30, 30, 45],
  ['TON-001', 5, 9, 60, 80],
  ['SUN-001', 7, 12, 45, 65],
];

// SKUs that carry retail sales history, with a rough daily rate.
const HISTORY = [
  ['SOP-001', 3], ['SOP-002', 2], ['LIP-002', 2], ['LIP-001', 2],
  ['SER-001', 1], ['CRM-003', 2], ['TON-002', 1], ['SUN-001', 1],
];

async function main() {
  await db.connect();
  await db.query(`select set_config('app.role', 'OWNER_ADMIN', false),
                         set_config('app.actor', 'seed', false)`);

  const already = await db.query('select count(*)::int as n from products');
  if (already.rows[0].n > 0 && !process.argv.includes('--force')) {
    console.log('Products already exist — nothing seeded. Re-run with --force to add anyway.');
    return db.end();
  }

  // The whole seed is one transaction: a half-seeded database would be worse
  // than none, and the guard above would then refuse to re-run. It also means
  // the trigger below is re-armed by the rollback if anything goes wrong —
  // DDL is transactional in Postgres, so the journal can never be left
  // mutable by a crash.
  await db.query('begin');

  // Historical rows are written with real timestamps, so the movement journal
  // has to accept back-dated corrections during the seed only.
  await db.query('alter table stock_movements disable trigger trg_stock_movements_immutable');

  console.log('→ products');
  for (const [sku, name, brand, category, cost, ws, srp, retail, life, min] of PRODUCTS) {
    await db.query(
      `insert into products (sku, name, brand, category, unit_cost, wholesale_price, srp,
                             retail_price, shelf_life_months, reseller_floor_months, retail_min_qty)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,12,$10)`,
      [sku, name, brand, category, cost, ws, srp, retail, life, min]);
  }

  console.log('→ batches (staggered expiries)');
  let batchSeq = 1000;
  await as('WAREHOUSE', 'seed-warehouse', async () => {
    for (const [sku, , , , , , , , life] of PRODUCTS) {
      const plan = [[Math.min(life, 22), 400], ...(EXTRA_BATCHES[sku] || [])];
      for (const [months, qty] of plan) {
        await db.query('select receive_batch($1,$2,$3,$4)',
          [sku, `B${++batchSeq}`, monthsOut(months), qty]);
      }
    }
  });

  console.log('→ resellers');
  const resellerIds = {};
  for (const r of RESELLERS) {
    const id = (await db.query('select admin_create_reseller($1,$2,$3,$4,$5,$6) as id',
      [r.name, r.email, r.tier, r.limit, r.terms, r.avg])).rows[0].id;
    resellerIds[r.name] = Number(id);
    await db.query(
      `insert into reseller_documents (reseller_id, doc_type, file_ref, verified, verified_by, verified_at)
       values ($1,'BUSINESS_LICENSE',$2,$3,'seed',case when $3 then now() end),
              ($1,'TAX_DOCUMENT',$4,$3,'seed',case when $3 then now() end)`,
      [id, `${r.name.toLowerCase().replace(/\W+/g, '-')}-dti.pdf`, r.verify,
       `${r.name.toLowerCase().replace(/\W+/g, '-')}-bir2303.pdf`]);
    if (r.verify) await db.query('select admin_verify_reseller($1)', [id]);
  }

  console.log('→ reorder points');
  await as('WAREHOUSE', 'seed-warehouse', async () => {
    for (const [sku, avg, max, avgLead, maxLead] of ROP) {
      await db.query('select set_rop($1,$2,$3,$4,$5)', [sku, avg, max, avgLead, maxLead]);
    }
  });

  console.log('→ retail sales history (last 60 days)');
  let receiptSeq = 0;
  await as('RETAIL_CASHIER', 'cashier', async () => {
    for (let d = 60; d >= 1; d -= 1) {
      const when = daysAgo(d);
      if (when.getDay() === 0) continue;                       // closed Sundays
      const lines = HISTORY
        .filter((_, i) => (d + i) % 2 === 0)                   // a rotating subset each day
        .map(([sku, rate]) => ({ sku, qty: Math.max(1, rate - (d % 2)) }));
      if (!lines.length) continue;

      const orderId = (await db.query(`select place_order('RETAIL', $1) as id`,
        [JSON.stringify(lines)])).rows[0].id;
      await db.query('select fulfill_order($1)', [orderId]);
      const total = (await db.query('select total from orders where id = $1', [orderId])).rows[0].total;
      const stamp = when.toISOString().slice(0, 10).replace(/-/g, '');
      await db.query(
        `insert into retail_sales (order_id, receipt_no, payment_method, amount_due,
                                   tendered, change, cashier, ts)
         values ($1,$2,$3,$4,$4,0,'cashier',$5)`,
        [orderId, `OR-${stamp}-${String(++receiptSeq).padStart(5, '0')}`,
         ['CASH', 'CASH', 'GCASH', 'CARD'][d % 4], total, when]);
      await db.query('update orders set created_at = $2, created_by = $3 where id = $1',
        [orderId, when, 'cashier']);
      await db.query(
        `update stock_movements set ts = $2
          where batch_id in (select batch_id from order_lines where order_id = $1)
            and reason = 'POS_SALE' and ts > now() - interval '1 minute'`, [orderId, when]);
    }
  });

  console.log('→ B2B order history, invoices and payments');
  const b2b = async (resellerName, lines, opts = {}) => {
    const rid = resellerIds[resellerName];
    const orderId = (await as('B2B_AGENT', 'agent', async () =>
      (await db.query(`select place_order('B2B', $1, $2) as id`,
        [JSON.stringify(lines), rid])).rows[0].id));
    if (opts.placedDaysAgo) {
      const when = daysAgo(opts.placedDaysAgo);
      await db.query('update orders set created_at = $2 where id = $1', [orderId, when]);
      await db.query(
        `update invoices set issued_at = $2::date, due_date = $2::date + $3::int where order_id = $1`,
        [orderId, when.toISOString().slice(0, 10), opts.terms ?? 30]);
    }
    if (opts.pay) {
      const inv = (await db.query('select * from invoices where order_id = $1', [orderId])).rows[0];
      await db.query('select record_payment($1,$2,$3)',
        [inv.id, inv.amount, opts.paidOn || new Date().toISOString().slice(0, 10)]);
    }
    if (opts.ship) {
      await as('WAREHOUSE', 'seed-warehouse', () => db.query('select fulfill_order($1)', [orderId]));
      if (opts.delivered) {
        await as('WAREHOUSE', 'seed-warehouse', () =>
          db.query('select mark_order_delivered($1)', [orderId]));
      }
      if (opts.placedDaysAgo) {
        await db.query(
          `update stock_movements set ts = $2
            where batch_id in (select batch_id from order_lines where order_id = $1)
              and reason = 'B2B_SHIP' and ts > now() - interval '1 minute'`,
          [orderId, daysAgo(opts.placedDaysAgo)]);
      }
    }
    return orderId;
  };

  // Tier 3 key account: paid on time, one open invoice inside terms.
  await b2b('Bella Skin Manila',
    [{ sku: 'SER-001', qty: 60 }, { sku: 'SOP-001', qty: 150 }, { sku: 'CRM-001', qty: 40 }],
    { placedDaysAgo: 50, terms: 45, pay: true, paidOn: daysAgo(20).toISOString().slice(0, 10), ship: true, delivered: true });
  await b2b('Bella Skin Manila',
    [{ sku: 'LIP-002', qty: 80 }, { sku: 'SUN-001', qty: 40 }],
    { placedDaysAgo: 12, terms: 45, ship: true });

  // Tier 2 healthy: settled a Net-30 invoice inside 10 days → 2/10 discount.
  await b2b('Cebu Glow Distributors',
    [{ sku: 'SOP-002', qty: 120 }, { sku: 'TON-002', qty: 50 }],
    { placedDaysAgo: 40, terms: 30, pay: true, paidOn: daysAgo(34).toISOString().slice(0, 10), ship: true, delivered: true });

  // Tier 2 gone bad: invoice issued 60 days ago on Net 30 → past due → blocked.
  await b2b('Davao Beauty Hub',
    [{ sku: 'SER-003', qty: 45 }, { sku: 'CRM-003', qty: 90 }],
    { placedDaysAgo: 60, terms: 30, ship: true, delivered: true });

  // Tier 1 prepaid: paid up front, then dispatched.
  await b2b('Iloilo Radiance Store',
    [{ sku: 'SOP-003', qty: 60 }, { sku: 'LIP-005', qty: 40 }],
    { placedDaysAgo: 8, pay: true, paidOn: daysAgo(8).toISOString().slice(0, 10), ship: true });

  // Open order waiting in the pipeline for the warehouse to pick.
  await b2b('Cebu Glow Distributors', [{ sku: 'SER-004', qty: 30 }, { sku: 'SOP-004', qty: 100 }]);

  await as('HR_FINANCE', 'seed-finance', () => db.query('select refresh_reseller_blocks()'));

  console.log('→ shelf drawdown so the restock alert has something to say');
  // Rebalance most of one SKU's shelf allocation back to the B2B pool (a normal
  // warehouse move), then let an ordinary counter sale take the last units —
  // the shelf hits zero and the system raises its own restock task.
  const lastUnits = 2;
  const shelfRows = (await db.query(
    `select sl.batch_id, (sl.qty_on_hand - sl.qty_committed)::int as free
       from batches b join stock_ledger sl on sl.batch_id = b.id
      where b.sku = 'LIP-003' and sl.pool = 'RETAIL_SHELF'
        and b.expiry_date > current_date and sl.qty_on_hand - sl.qty_committed > 0
      order by b.expiry_date`)).rows;
  let keep = lastUnits;
  await as('WAREHOUSE', 'seed-warehouse', async () => {
    for (const row of shelfRows) {
      const move = Math.max(0, row.free - keep);
      keep = Math.max(0, keep - row.free);
      if (move > 0) {
        await db.query('select transfer_stock($1,$2,$3,$4,$5)',
          [row.batch_id, 'RETAIL_SHELF', 'B2B_POOL', move, 'REBALANCE']);
      }
    }
  });
  await as('RETAIL_CASHIER', 'cashier', () =>
    db.query('select pos_checkout($1,$2,$3)',
      [JSON.stringify([{ sku: 'LIP-003', qty: lastUnits }]), 'CASH', 1000]));

  console.log('→ logins');
  const users = [
    ['admin', 'Ms Beau (Owner)', 'OWNER_ADMIN', null],
    ['warehouse', 'Warehouse Staff', 'WAREHOUSE', null],
    ['cashier', 'Store Cashier', 'RETAIL_CASHIER', null],
    ['reseller', 'Cebu Glow Distributors', 'RESELLER', resellerIds['Cebu Glow Distributors']],
    ['blocked', 'Davao Beauty Hub', 'RESELLER', resellerIds['Davao Beauty Hub']],
  ];
  for (const [username, display, role, rid] of users) {
    await db.query('select admin_create_user($1,$2,$3,$4,$5)',
      [username, display, hashPassword('msbeauave'), role, rid]);
  }

  await db.query('alter table stock_movements enable trigger trg_stock_movements_immutable');
  await db.query('select recompute_abc(90)');
  await db.query('commit');

  console.log(`
Seeded ✿  ${PRODUCTS.length} products · ${RESELLERS.length} resellers · ${receiptSeq} retail sales

  Logins (all with password "msbeauave"):
    admin      — owner: everything
    warehouse  — receiving, picking, transfers, counts
    cashier    — POS + end-of-day
    reseller   — Cebu Glow Distributors (Tier 2, in good standing)
    blocked    — Davao Beauty Hub (Tier 2, past due → auto-blocked)
`);
  await db.end();
}

main().catch(async (e) => {
  console.error('seed failed:', e.message);
  try {
    await db.query('rollback');   // also re-arms the immutability trigger
    await db.end();
  } catch { /* already down */ }
  process.exit(1);
});

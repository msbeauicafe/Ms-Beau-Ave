#!/usr/bin/env node
// Demo data.
//
// Everything is built by calling the engine's own functions rather than
// inserting rows, so the pool splits, FEFO picks, invoices and ledger all
// reconcile exactly as they would in real use.
//
//   DATABASE_URL=postgres://…  node scripts/seed.js
import pg from 'pg';
import { hashPassword } from '../lib/auth.js';

const DSN = process.env.DATABASE_URL || process.env.TEST_DATABASE_URL;
if (!DSN) {
  console.error('Set DATABASE_URL first.');
  process.exit(1);
}
const db = new pg.Client({ connectionString: DSN });

const monthsOut = (n) => {
  const d = new Date();
  d.setMonth(d.getMonth() + n);
  return d.toISOString().slice(0, 10);
};
const daysAgo = (n) => new Date(Date.now() - n * 864e5);

async function as(role, actor, work) {
  await db.query(`select set_config('app.role',$1,false), set_config('app.actor',$2,false)`,
    [role, actor]);
  const out = await work();
  await db.query(`select set_config('app.role','admin',false), set_config('app.actor','seed',false)`);
  return out;
}

// sku, name, brand, category, cost, wholesale, they-sell-at, we-sell-at, shelf life, keep at least
const CATALOGUE = [
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

// Extra batches that deliberately exercise FEFO, the six-month warning and the
// twelve-month floor resellers hold us to.
const EXTRA_BATCHES = {
  'SER-001': [[4, 60], [14, 180]],   // one near expiry, one mid-life
  'SER-002': [[10, 90]],             // under the floor — shop only
  'SER-004': [[5, 40]],
  'CRM-001': [[11, 120]],
  'CRM-003': [[3, 50]],              // going off soon
  'LIP-002': [[15, 200]],
  'SOP-001': [[9, 240]],
  'TON-001': [[5, 70]],              // an active, and expiry-sensitive
  'SUN-001': [[13, 150]],
};

const RESELLERS = [
  { name: 'Bella Skin Manila',      email: 'orders@bellaskin.ph',     tier: 3, limit: 500000, days: 45, approve: true },
  { name: 'Cebu Glow Distributors', email: 'buyer@cebuglow.ph',       tier: 2, limit: 150000, days: 30, approve: true },
  { name: 'Davao Beauty Hub',       email: 'admin@davaobeauty.ph',    tier: 2, limit: 120000, days: 30, approve: true },
  { name: 'Iloilo Radiance Store',  email: 'hello@iloiloradiance.ph', tier: 1, limit: 0,      days: 0,  approve: true },
  { name: 'Baguio Beaute Corner',   email: 'apply@baguiobeaute.ph',   tier: 1, limit: 0,      days: 0,  approve: false },
];

// SER-001 is the worked example: 10 a day, 15 at worst, 60-day wait, 75 at
// worst → buffer 525, reorder at 1,125.
const REORDER = [
  ['SER-001', 10, 15, 60, 75], ['SER-002', 4, 7, 60, 80], ['SER-003', 6, 10, 45, 60],
  ['CRM-001', 5, 9, 50, 70], ['CRM-003', 8, 14, 40, 55], ['LIP-002', 12, 20, 35, 50],
  ['SOP-001', 25, 40, 30, 45], ['SOP-002', 18, 30, 30, 45], ['TON-001', 5, 9, 60, 80],
  ['SUN-001', 7, 12, 45, 65],
];

const SELLS_WELL = [
  ['SOP-001', 3], ['SOP-002', 2], ['LIP-002', 2], ['LIP-001', 2],
  ['SER-001', 1], ['CRM-003', 2], ['TON-002', 1], ['SUN-001', 1],
];

async function main() {
  await db.connect();
  await db.query(`select set_config('app.role','admin',false), set_config('app.actor','seed',false)`);

  const already = await db.query('select count(*)::int as n from products');
  if (already.rows[0].n > 0 && !process.argv.includes('--force')) {
    console.log('There are already products here — nothing seeded. Use --force to add anyway.');
    return db.end();
  }

  // One transaction: a half-seeded database is worse than none, and the guard
  // above would then refuse to try again. Disabling the journal trigger is
  // transactional too, so a crash can never leave it mutable.
  await db.query('begin');
  await db.query('alter table movements disable trigger movements_immutable');

  console.log('→ products');
  for (const [sku, name, brand, category, cost, ws, srp, retail, life, min] of CATALOGUE) {
    await db.query(
      `insert into products (sku, name, brand, category, unit_cost, wholesale_price,
                             srp, retail_price, shelf_life_months, shelf_min)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [sku, name, brand, category, cost, ws, srp, retail, life, min]);
  }

  console.log('→ deliveries');
  let batchNo = 1000;
  await as('warehouse', 'seed-warehouse', async () => {
    for (const [sku, , , , , , , , life] of CATALOGUE) {
      for (const [months, qty] of [[Math.min(life, 22), 400], ...(EXTRA_BATCHES[sku] || [])]) {
        await db.query('select receive_stock($1,$2,$3,$4)',
          [sku, `B${++batchNo}`, monthsOut(months), qty]);
      }
    }
  });

  console.log('→ reseller accounts');
  const ids = {};
  for (const r of RESELLERS) {
    const { rows } = await db.query(
      `insert into resellers (name, email, tier, credit_limit, terms_days)
       values ($1,$2,$3,$4,$5) returning id`, [r.name, r.email, r.tier, r.limit, r.days]);
    ids[r.name] = Number(rows[0].id);
    const slug = r.name.toLowerCase().replace(/\W+/g, '-');
    await db.query(
      `insert into reseller_documents (reseller_id, kind, reference, verified)
       values ($1,'business licence',$2,$3), ($1,'tax paper',$4,$3)`,
      [ids[r.name], `${slug}-dti.pdf`, r.approve, `${slug}-bir2303.pdf`]);
    if (r.approve) await db.query('select approve_reseller($1)', [ids[r.name]]);
  }

  console.log('→ reorder points');
  await as('warehouse', 'seed-warehouse', async () => {
    for (const [sku, avg, max, avgLead, maxLead] of REORDER) {
      await db.query('select set_reorder_point($1,$2,$3,$4,$5)', [sku, avg, max, avgLead, maxLead]);
    }
  });

  console.log('→ two months of counter sales');
  let receipts = 0;
  await as('cashier', 'cashier', async () => {
    for (let back = 60; back >= 1; back -= 1) {
      const day = daysAgo(back);
      if (day.getDay() === 0) continue;                        // closed on Sundays
      const lines = SELLS_WELL
        .filter((_, i) => (back + i) % 2 === 0)
        .map(([sku, rate]) => ({ sku, qty: Math.max(1, rate - (back % 2)) }));
      if (!lines.length) continue;

      const { rows } = await db.query(`select place_order('shop',$1) as id`,
        [JSON.stringify(lines)]);
      const orderId = rows[0].id;
      await db.query('select fulfil_order($1)', [orderId]);
      const { rows: [{ total }] } = await db.query('select total from orders where id = $1', [orderId]);
      const stamp = day.toISOString().slice(0, 10).replace(/-/g, '');
      await db.query(
        `insert into sales (order_id, receipt_no, method, total, tendered, change_due, cashier, at)
         values ($1,$2,$3,$4,$4,0,'cashier',$5)`,
        [orderId, `OR-${stamp}-${String(++receipts).padStart(5, '0')}`,
         ['cash', 'cash', 'gcash', 'card'][back % 4], total, day]);
      await db.query('update orders set placed_at = $2, placed_by = $3 where id = $1',
        [orderId, day, 'cashier']);
      await db.query(
        `update movements set at = $2
          where batch_id in (select batch_id from order_lines where order_id = $1)
            and reason = 'sold' and at > now() - interval '1 minute'`, [orderId, day]);
    }
  });

  console.log('→ wholesale history');
  const wholesale = async (who, lines, opts = {}) => {
    const id = await as('admin', 'agent', async () => {
      const { rows } = await db.query(`select place_order('b2b',$1,$2) as id`,
        [JSON.stringify(lines), ids[who]]);
      return rows[0].id;
    });
    if (opts.daysAgo) {
      const day = daysAgo(opts.daysAgo);
      await db.query('update orders set placed_at = $2 where id = $1', [id, day]);
      await db.query(
        `update invoices set issued_on = $2::date, due_on = $2::date + $3::int where order_id = $1`,
        [id, day.toISOString().slice(0, 10), opts.days ?? 30]);
    }
    if (opts.pay) {
      const { rows: [inv] } = await db.query('select * from invoices where order_id = $1', [id]);
      await db.query('select record_payment($1,$2,$3)',
        [inv.id, inv.amount, opts.paidOn ?? new Date().toISOString().slice(0, 10)]);
    }
    if (opts.ship) {
      await as('warehouse', 'seed-warehouse', () => db.query('select fulfil_order($1)', [id]));
      if (opts.delivered) {
        await as('warehouse', 'seed-warehouse', () => db.query('select mark_delivered($1)', [id]));
      }
      if (opts.daysAgo) {
        await db.query(
          `update movements set at = $2
            where batch_id in (select batch_id from order_lines where order_id = $1)
              and reason = 'shipped' and at > now() - interval '1 minute'`,
          [id, daysAgo(opts.daysAgo)]);
      }
    }
    return id;
  };

  // A key account paying on time.
  await wholesale('Bella Skin Manila',
    [{ sku: 'SER-001', qty: 60 }, { sku: 'SOP-001', qty: 150 }, { sku: 'CRM-001', qty: 40 }],
    { daysAgo: 50, days: 45, pay: true, paidOn: daysAgo(20).toISOString().slice(0, 10),
      ship: true, delivered: true });
  await wholesale('Bella Skin Manila',
    [{ sku: 'LIP-002', qty: 80 }, { sku: 'SUN-001', qty: 40 }],
    { daysAgo: 12, days: 45, ship: true });

  // Settled inside ten days, so the 2% came off by itself.
  await wholesale('Cebu Glow Distributors',
    [{ sku: 'SOP-002', qty: 120 }, { sku: 'TON-002', qty: 50 }],
    { daysAgo: 40, days: 30, pay: true, paidOn: daysAgo(34).toISOString().slice(0, 10),
      ship: true, delivered: true });

  // Sixty days on thirty-day terms: past due, so the system blocks them.
  await wholesale('Davao Beauty Hub',
    [{ sku: 'SER-003', qty: 45 }, { sku: 'CRM-003', qty: 90 }],
    { daysAgo: 60, days: 30, ship: true, delivered: true });

  // Prepaid, paid, then shipped.
  await wholesale('Iloilo Radiance Store',
    [{ sku: 'SOP-003', qty: 60 }, { sku: 'LIP-005', qty: 40 }],
    { daysAgo: 8, pay: true, paidOn: daysAgo(8).toISOString().slice(0, 10), ship: true });

  // One still waiting to be picked.
  await wholesale('Cebu Glow Distributors',
    [{ sku: 'SER-004', qty: 30 }, { sku: 'SOP-004', qty: 100 }]);

  await db.query('select refresh_blocks()');

  console.log('→ one shelf run down to nothing');
  // Move most of a product back to the wholesale pool, then let an ordinary
  // sale take the last two — the shelf empties and the system raises its own
  // task, rather than the seed inventing one.
  const keep = 2;
  const { rows: shelf } = await db.query(
    `select s.batch_id, (s.on_hand - s.committed)::int as free
       from batches b join stock s on s.batch_id = b.id
      where b.sku = 'LIP-003' and s.pool = 'shop'
        and b.expiry > current_date and s.on_hand - s.committed > 0
      order by b.expiry`);
  let leave = keep;
  await as('warehouse', 'seed-warehouse', async () => {
    for (const row of shelf) {
      const move = Math.max(0, row.free - leave);
      leave = Math.max(0, leave - row.free);
      if (move > 0) {
        await db.query(`select move_stock($1,'shop','b2b',$2,'rebalanced')`, [row.batch_id, move]);
      }
    }
  });
  await as('cashier', 'cashier', () => db.query(`select sell($1,'cash',$2)`,
    [JSON.stringify([{ sku: 'LIP-003', qty: keep }]), 1000]));

  console.log('→ sign-ins');
  for (const [username, name, role, reseller] of [
    ['admin', 'Ms Beau (Owner)', 'admin', null],
    ['warehouse', 'Warehouse Staff', 'warehouse', null],
    ['cashier', 'Shop Cashier', 'cashier', null],
    ['reseller', 'Cebu Glow Distributors', 'reseller', ids['Cebu Glow Distributors']],
    ['blocked', 'Davao Beauty Hub', 'reseller', ids['Davao Beauty Hub']],
  ]) {
    await db.query(
      `insert into app_users (username, display_name, password_hash, role, reseller_id)
       values ($1,$2,$3,$4,$5)`,
      [username, name, hashPassword('msbeauave'), role, reseller]);
  }

  await db.query('select classify_abc(90)');
  await db.query('alter table movements enable trigger movements_immutable');
  await db.query('commit');

  console.log(`
Seeded ✿  ${CATALOGUE.length} products · ${RESELLERS.length} resellers · ${receipts} counter sales

  Sign in with any of these — the password is "msbeauave":

    admin      the owner: everything
    warehouse  receiving, picking, moving stock
    cashier    the till and the close of day
    reseller   Cebu Glow Distributors, in good standing
    blocked    Davao Beauty Hub, past due, so it cannot order
`);
  await db.end();
}

main().catch(async (e) => {
  console.error('seeding failed:', e.message);
  try { await db.query('rollback'); await db.end(); } catch { /* already gone */ }
  process.exit(1);
});

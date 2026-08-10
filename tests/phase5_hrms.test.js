// Phase 5 — HRMS & payroll (Spec.md §3.6)
import test from 'node:test';
import assert from 'node:assert/strict';
import { pool, asRole, uniq, createProduct, receiveBatch, monthsOut } from './helpers/db.js';

const db = pool();
test.after(() => db.end());

const FUTURE = monthsOut(24);
const num = (x) => Number(x);

async function newEmployee(db, overrides = {}) {
  const r = await db.query(
    `insert into employees (name, actor_name, role_type, pay_basis, base_pay, commission_plan_id)
     values ($1, $2, $3, $4, $5, $6) returning id`,
    [overrides.name ?? uniq('Emp'), overrides.actor_name ?? uniq('actor'),
     overrides.role_type ?? 'OFFICE', overrides.pay_basis ?? 'MONTHLY',
     overrides.base_pay ?? 30000, overrides.commission_plan_id ?? null]);
  return r.rows[0].id;
}

test('PH statutory module: SSS / PhilHealth / Pag-IBIG match published schedules', async () => {
  const sss = async (s) => (await db.query('select * from ph_sss($1)', [s])).rows[0];
  const phic = async (s) => (await db.query('select * from ph_philhealth($1)', [s])).rows[0];
  const hdmf = async (s) => (await db.query('select * from ph_pagibig($1)', [s])).rows[0];

  // SSS 15% (EE 5 / ER 10) on the MSC, ₱5k floor, ₱35k ceiling
  assert.deepEqual([num((await sss(25000)).ee), num((await sss(25000)).er)], [1250, 2500]);
  assert.deepEqual([num((await sss(3000)).ee), num((await sss(3000)).er)], [250, 500]);
  assert.deepEqual([num((await sss(60000)).ee), num((await sss(60000)).er)], [1750, 3500]);

  // PhilHealth 5% split 50/50, ₱10k floor, ₱100k cap
  assert.equal(num((await phic(25000)).ee), 625);
  assert.equal(num((await phic(8000)).ee), 250);
  assert.equal(num((await phic(150000)).ee), 2500);

  // Pag-IBIG 2%/2% on ≤₱10k fund salary; 1% EE at ≤₱1,500
  assert.deepEqual([num((await hdmf(25000)).ee), num((await hdmf(25000)).er)], [200, 200]);
  assert.deepEqual([num((await hdmf(1200)).ee), num((await hdmf(1200)).er)], [12, 24]);
});

test('PH withholding tax follows the TRAIN monthly table', async () => {
  const wht = async (t) => num((await db.query('select ph_wht($1) as t', [t])).rows[0].t);
  assert.equal(await wht(20000), 0);
  assert.equal(await wht(25000), 625.05);      // (25,000 − 20,833) × 15%
  assert.equal(await wht(40000), 3833.4);      // 2,500 + (40,000 − 33,333) × 20%
});

test('monthly payroll line: contributions, WHT and net for ₱30,000 basic', async () => {
  const empId = await newEmployee(db, { base_pay: 30000 });
  const runId = await asRole(db, 'HR_FINANCE', async (c) =>
    (await c.query(`select run_payroll('2025-01-01', '2025-01-31') as id`)).rows[0].id);

  const line = (await db.query(
    'select * from payroll_lines where run_id = $1 and employee_id = $2', [runId, empId])).rows[0];
  assert.equal(num(line.gross), 30000);
  assert.equal(num(line.sss_ee), 1500);
  assert.equal(num(line.sss_er), 3000);
  assert.equal(num(line.philhealth_ee), 750);
  assert.equal(num(line.pagibig_ee), 200);
  assert.equal(num(line.taxable_income), 27550);
  assert.equal(num(line.wht), 1007.55);        // (27,550 − 20,833) × 15%
  assert.equal(num(line.net_pay), 26542.45);
});

test('warehouse hourly pay: OT ×1.25 past 8h, 10% night differential 22:00–06:00', async () => {
  const empId = await newEmployee(db, {
    role_type: 'WAREHOUSE', pay_basis: 'HOURLY', base_pay: 100,
  });
  // 14:00 → 24:00 Manila = 10h: 8 regular + 2 OT; the 22:00 and 23:00 hours
  // also earn the night differential.
  await db.query(
    `insert into attendance (employee_id, clock_in, clock_out, method)
     values ($1, '2025-02-04 14:00+08', '2025-02-05 00:00+08', 'BIOMETRIC')`, [empId]);

  const runId = await asRole(db, 'HR_FINANCE', async (c) =>
    (await c.query(`select run_payroll('2025-02-01', '2025-02-28') as id`)).rows[0].id);
  const line = (await db.query(
    'select * from payroll_lines where run_id = $1 and employee_id = $2', [runId, empId])).rows[0];

  assert.equal(num(line.basic_pay), 800);      // 8h × ₱100
  assert.equal(num(line.ot_pay), 250);         // 2h × ₱100 × 1.25
  assert.equal(num(line.night_diff_pay), 20);  // 2h × ₱100 × 10%
  assert.equal(num(line.gross), 1070);
});

test('holiday premium from the PH calendar (regular holiday = 200%)', async () => {
  await db.query(
    `insert into ph_holidays (holiday_date, kind, name)
     values ('2025-06-12', 'REGULAR', 'Independence Day') on conflict do nothing`);
  const empId = await newEmployee(db, {
    role_type: 'WAREHOUSE', pay_basis: 'HOURLY', base_pay: 100,
  });
  await db.query(
    `insert into attendance (employee_id, clock_in, clock_out, method)
     values ($1, '2025-06-12 09:00+08', '2025-06-12 17:00+08', 'BIOMETRIC')`, [empId]);

  const runId = await asRole(db, 'HR_FINANCE', async (c) =>
    (await c.query(`select run_payroll('2025-06-01', '2025-06-30') as id`)).rows[0].id);
  const line = (await db.query(
    'select * from payroll_lines where run_id = $1 and employee_id = $2', [runId, empId])).rows[0];
  assert.equal(num(line.basic_pay), 800);
  assert.equal(num(line.holiday_pay), 800);    // +100% on a regular holiday
});

test('retail commission: % of own shop sales + brand boost (§3.6)', async () => {
  const planId = (await db.query(
    `insert into commission_plans (name, role_type, config)
     values ('retail-2pct', 'RETAIL', '{"rate": 0.02, "brand_boosts": {"GlowLab": 0.05}}')
     returning id`)).rows[0].id;
  const actor = uniq('cashier');
  await newEmployee(db, {
    role_type: 'RETAIL', actor_name: actor, commission_plan_id: planId, base_pay: 16000,
  });

  const sku = await createProduct(db, uniq('SKU'), {
    alloc_b2b: 0, alloc_retail: 1, alloc_safety: 0, srp: 500, retail_price: 500,
  });
  await db.query(`update products set brand = 'GlowLab' where sku = $1`, [sku]);
  await receiveBatch(db, sku, uniq('B'), FUTURE, 10);

  const orderId = await asRole(db, 'RETAIL_CASHIER', async (c) =>
    (await c.query(`select place_order('RETAIL', $1) as id`,
      [JSON.stringify([{ sku, qty: 2 }])])).rows[0].id, { actor });
  await asRole(db, 'RETAIL_CASHIER', (c) =>
    c.query('select fulfill_order($1)', [orderId]), { actor });

  await asRole(db, 'HR_FINANCE', (c) =>
    c.query(`select compute_commissions(current_date, current_date)`));

  const entry = (await db.query(
    `select amount, details from commission_entries where order_id = $1`, [orderId])).rows[0];
  assert.equal(num(entry.amount), 70);         // 1,000 × 2% + 1,000 × 5% brand boost
  assert.equal(num(entry.details.base), 20);
  assert.equal(num(entry.details.brand_boost), 50);
});

test('B2B agent commission: reseller volume + close-to-expiry clearance boost (§3.6)', async () => {
  const planId = (await db.query(
    `insert into commission_plans (name, role_type, config)
     values ('b2b-3pct', 'B2B_AGENT',
             '{"rate": 0.03, "clearance_boost": 0.02, "clearance_window_days": 550}')
     returning id`)).rows[0].id;
  const agentId = await newEmployee(db, {
    role_type: 'B2B_AGENT', commission_plan_id: planId, base_pay: 20000,
  });

  const resellerId = (await db.query(
    `insert into resellers (name, tier, credit_limit, payment_terms_days, status,
                            docs_verified, agent_employee_id)
     values ($1, 2, 1000000, 30, 'ACTIVE', true, $2) returning id`,
    [uniq('Reseller'), agentId])).rows[0].id;

  // Stock above the 12-month reseller floor (so B2B can still take it) but
  // inside the plan's clearance window — the window now counts batches
  // approaching the floor cutoff, since below-floor stock can't be sold B2B.
  const sku = await createProduct(db, uniq('SKU'), {
    alloc_b2b: 1, alloc_retail: 0, alloc_safety: 0,
  });
  await receiveBatch(db, sku, uniq('B'), monthsOut(15), 50);

  const orderId = await asRole(db, 'B2B_AGENT', async (c) =>
    (await c.query(`select place_order('B2B', $1, $2) as id`,
      [JSON.stringify([{ sku, qty: 10 }]), resellerId])).rows[0].id);
  await asRole(db, 'WAREHOUSE', (c) => c.query('select fulfill_order($1)', [orderId]));

  await asRole(db, 'HR_FINANCE', (c) =>
    c.query(`select compute_commissions(current_date, current_date)`));

  const entry = (await db.query(
    `select amount, details from commission_entries
      where order_id = $1 and employee_id = $2`, [orderId, agentId])).rows[0];
  assert.equal(num(entry.details.base), 75);            // 2,500 × 3%
  assert.equal(num(entry.details.clearance_boost), 50); // 2,500 × 2%
  assert.equal(num(entry.amount), 125);
});

test('GPS punches are geofenced to registered reseller locations (§3.6)', async () => {
  const resellerId = (await db.query(
    `insert into resellers (name, status, docs_verified) values ($1, 'ACTIVE', true)
     returning id`, [uniq('Reseller')])).rows[0].id;
  await db.query(
    `insert into reseller_locations (reseller_id, label, lat, lng, radius_m)
     values ($1, 'Manila store', 14.5995, 120.9842, 200)`, [resellerId]);

  const inside = await newEmployee(db, { role_type: 'B2B_AGENT' });
  const outside = await newEmployee(db, { role_type: 'B2B_AGENT' });

  const okId = await asRole(db, 'B2B_AGENT', async (c) =>
    (await c.query(`select punch_clock($1, 'GPS', now(), 14.5996, 120.9843) as id`,
      [inside])).rows[0].id);
  const okFlags = await db.query('select flags from attendance where id = $1', [okId]);
  assert.deepEqual(okFlags.rows[0].flags, []);

  const farId = await asRole(db, 'B2B_AGENT', async (c) =>
    (await c.query(`select punch_clock($1, 'GPS', now(), 14.6500, 121.0500) as id`,
      [outside])).rows[0].id);
  const farFlags = await db.query('select flags from attendance where id = $1', [farId]);
  assert.deepEqual(farFlags.rows[0].flags, ['OUT_OF_GEOFENCE']);
});

test('13th-month pay and BIR 2316 data from approved runs (§3.6)', async () => {
  const empId = await newEmployee(db, { base_pay: 24000 });
  const runId = await asRole(db, 'HR_FINANCE', async (c) =>
    (await c.query(`select run_payroll('2025-03-01', '2025-03-31') as id`)).rows[0].id);

  const thirteenth = num((await db.query(
    'select ph_13th_month($1, 2025) as v', [empId])).rows[0].v);
  assert.equal(thirteenth, 2000);              // 24,000 × 1 month ÷ 12

  // 2316 shows only approved/paid runs.
  const before = await db.query(
    'select 1 from bir_2316_data where employee_id = $1', [empId]);
  assert.equal(before.rows.length, 0);
  await asRole(db, 'OWNER_ADMIN', (c) => c.query('select approve_payroll_run($1)', [runId]));
  const after = (await db.query(
    'select * from bir_2316_data where employee_id = $1 and tax_year = 2025', [empId])).rows[0];
  assert.equal(num(after.gross_compensation), 24000);
  assert.ok(num(after.tax_withheld) > 0);
});

test('LMS gates floor access: required module must be passed (§3.6)', async () => {
  const moduleId = (await db.query(
    `insert into training_modules (name, required_for, pass_score)
     values ('Actives & allergens', '{RETAIL}', 80) returning id`)).rows[0].id;
  const empId = await newEmployee(db, { role_type: 'RETAIL' });

  const compliant = async () => (await db.query(
    'select is_training_compliant($1) as ok', [empId])).rows[0].ok;

  assert.equal(await compliant(), false, 'new hire has not passed the module');
  await asRole(db, 'RETAIL_CASHIER', (c) =>
    c.query('select record_training($1, $2, 70)', [empId, moduleId]));
  assert.equal(await compliant(), false, '70 < pass score 80');
  await asRole(db, 'RETAIL_CASHIER', (c) =>
    c.query('select record_training($1, $2, 95)', [empId, moduleId]));
  assert.equal(await compliant(), true);
});

test('201 files: expiring documents surface 60 days out (§3.6)', async () => {
  const empId = await newEmployee(db);
  await db.query(
    `insert into documents_201 (employee_id, doc_type, file_ref, expires_on, verified)
     values ($1, 'MEDICAL_CLEARANCE', 'locker://med-1', current_date + 30, true),
            ($1, 'GOVT_ID', 'locker://id-1', current_date + 300, true)`, [empId]);

  const rows = await db.query(
    'select doc_type from expiring_documents where employee_id = $1', [empId]);
  assert.deepEqual(rows.rows.map((r) => r.doc_type), ['MEDICAL_CLEARANCE']);
});

test('transparent dashboards: employees see their own numbers, not colleagues\' (§3.6)', async () => {
  const planId = (await db.query(
    `insert into commission_plans (name, role_type, config)
     values ('retail-flat', 'RETAIL', '{"rate": 0.02}') returning id`)).rows[0].id;
  const actorA = uniq('rep');
  const actorB = uniq('rep');
  const empA = await newEmployee(db, { role_type: 'RETAIL', actor_name: actorA, commission_plan_id: planId });
  const empB = await newEmployee(db, { role_type: 'RETAIL', actor_name: actorB, commission_plan_id: planId });

  await db.query(
    `insert into commission_entries (employee_id, period_start, period_end, source, amount)
     values ($1, '2024-05-01', '2024-05-31', 'MANUAL', 111),
            ($2, '2024-05-01', '2024-05-31', 'MANUAL', 222)`, [empA, empB]);

  await asRole(db, 'RETAIL_CASHIER', async (c) => {
    const mine = await c.query('select employee_id, amount from commission_entries');
    assert.equal(mine.rows.length, 1);
    assert.equal(num(mine.rows[0].employee_id), num(empA));
    assert.equal(num(mine.rows[0].amount), 111);
  }, { actor: actorA, rls: true });
});

import pg from 'pg';

const DSN = process.env.IMS_TEST_DSN;
if (!DSN) {
  throw new Error('IMS_TEST_DSN not set — run tests via scripts/test-ims.sh');
}

export function pool() {
  return new pg.Pool({ connectionString: DSN, max: 10 });
}

/** Run fn with a dedicated client acting as the given app role. */
export async function asRole(db, role, fn, extra = {}) {
  const client = await db.connect();
  try {
    await client.query(`set app.role = '${role}'`);
    if (extra.resellerId != null) {
      await client.query(`set app.reseller_id = '${extra.resellerId}'`);
    }
    if (extra.actor) {
      await client.query(`set app.actor = '${extra.actor}'`);
    }
    // Non-superuser role so RLS actually applies to direct table reads.
    if (extra.rls) await client.query('set role app_client');
    return await fn(client);
  } finally {
    // Pooled connections keep session state — scrub it before handing back.
    try {
      await client.query('reset role');
      await client.query('reset all');
    } catch {
      // connection already broken; discard it
    }
    client.release();
  }
}

let seq = 0;
/**
 * Unique suffix so tests never collide on skus/batch numbers. Includes the
 * pid because each test file runs in its own process — a timestamp+counter
 * alone can collide across files landing on the same millisecond.
 */
export function uniq(prefix) {
  return `${prefix}-${process.pid}-${Date.now()}-${++seq}`;
}

export async function createProduct(db, sku, overrides = {}) {
  const cols = {
    name: `Test product ${sku}`,
    unit_cost: 100,
    wholesale_price: 250,
    srp: 400,
    retail_price: 450,
    shelf_life_months: 24,
    ...overrides,
  };
  await asRole(db, 'OWNER_ADMIN', (c) =>
    c.query(
      `insert into products (sku, name, unit_cost, wholesale_price, srp, retail_price,
                             shelf_life_months, alloc_b2b, alloc_retail, alloc_safety,
                             retail_min_qty)
       values ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)`,
      [sku, cols.name, cols.unit_cost, cols.wholesale_price, cols.srp, cols.retail_price,
       cols.shelf_life_months, cols.alloc_b2b ?? null, cols.alloc_retail ?? null,
       cols.alloc_safety ?? null, cols.retail_min_qty ?? 0],
    ));
  return sku;
}

export async function receiveBatch(db, sku, batchNumber, expiryDate, qty) {
  return asRole(db, 'WAREHOUSE', async (c) => {
    const r = await c.query('select receive_batch($1,$2,$3,$4) as id',
      [sku, batchNumber, expiryDate, qty]);
    return r.rows[0].id;
  });
}

export async function ledger(db, batchId) {
  const r = await db.query(
    `select pool, qty_on_hand, qty_committed from stock_ledger
      where batch_id = $1 order by pool`, [batchId]);
  return Object.fromEntries(r.rows.map((x) => [
    x.pool, { onHand: x.qty_on_hand, committed: x.qty_committed },
  ]));
}

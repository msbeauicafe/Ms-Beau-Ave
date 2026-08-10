# Ms Beau Ave — Operations Engine (IMS + Credit)

The real, database-enforced core of the system described in [`Spec.md`](Spec.md).
Everything lives in Postgres (Supabase-compatible) so that no UI, API, or human
can bypass the business rules: virtual stock pools, FEFO, atomic committed-stock
locking, reseller credit control, RLS isolation, and an immutable audit log.

## Layout

| Path | What it is |
|---|---|
| `supabase/migrations/0001_core_ims.sql` | **Phase 1 — Core IMS**: products, batches, pools, ledger, movements, orders, receiving with 70/20/10 auto-allocation, FEFO picking, atomic `place_order`, transfers, RBAC + RLS, immutable audit log |
| `supabase/migrations/0002_credit_engine.sql` | **Phase 2 — Credit engine**: resellers, tiers, invoices/AR, payments, §6.1 hard rules, AR aging + exposure views, onboarding docs |
| `tests/` | Acceptance tests run against a real Postgres 16 (`node --test`) |
| `scripts/test-ims.sh` | Spins up an ephemeral Postgres cluster, applies migrations, runs the suite |
| `supabase/schema.sql` | Legacy demo persistence (members + orders for the static demo app) — unchanged |

Run the suite locally (needs Postgres 16 binaries + Node 22, no running server):

```bash
npm ci
npm test
```

## Phase status vs Spec §10

| Phase | Status | "Done when" |
|---|---|---|
| 1 — Core IMS | ✅ built + tested | Receiving → allocation → FEFO pick → committed lock end-to-end; §8 concurrency test passes (two simultaneous orders for the last 5 units — exactly one succeeds) |
| 2 — B2B credit engine | ✅ built + tested | A past-due Tier 2 reseller is auto-blocked and cannot place an order |
| 3 — Retail sync & cash controls | ⏳ next | POS webhook adapter, retail-pool deduction, blind drops |
| 4 — Procurement & ROP | ⏳ | ROP engine with the §6.3 serum unit test (525 / 1,125) |
| 5 — HRMS & payroll | ⏳ | PH statutory payroll, 3 attendance modes, commissions |
| 6 — Dashboards & polish | ⏳ | §9 dashboards, notification center |

## How the rules are enforced (design notes)

- **Pools (§6.2).** Every receipt auto-splits into `B2B_POOL` / `RETAIL_SHELF` /
  `SAFETY` (default 70/20/10, per-SKU override on `products`, largest-remainder
  rounding so units never vanish). Orders read **only** their channel's pool.
  Moving stock out of `SAFETY` requires `OWNER_ADMIN` and is journalled as
  `SAFETY_RELEASE`.
- **Committed locking (§6.2, §8).** `place_order()` walks the FEFO-ordered
  ledger rows under `SELECT … FOR UPDATE`, re-checks availability under the
  lock, and raises `INSUFFICIENT_STOCK` (rolling back the whole order) if the
  pool comes up short. Two concurrent orders for the last units serialize on the
  row locks — exactly one wins; the test proves it.
- **FEFO (§6.4).** `fefo_pick(pool, sku, qty)` returns oldest-viable-batch-first
  pick lists, skipping expired stock and committed units.
- **Credit tiers (§6.1).** `place_order` calls `check_reseller_can_order`
  before touching stock: past-due invoice → `RESELLER_BLOCKED`; Tier ≥2 with
  outstanding + order > limit → `CREDIT_LIMIT_EXCEEDED`; Tier 1 orders are
  accepted but invoiced due-immediately and `fulfill_order` refuses to ship
  until paid (`PREPAYMENT_REQUIRED`). The sticky block flag + `AUTO_BLOCK`
  event are persisted by `refresh_reseller_blocks()` (AR job / on bounce), in
  its own transaction so a failed order can never roll it back. Paying off the
  last past-due invoice auto-lifts a `PAST_DUE_INVOICE` block.
- **2/10 net 30 (§6.1).** `record_payment()` auto-applies the 2% discount when
  a Net-30 invoice is settled within 10 days of issue.
- **Auto-demotion (§6.1).** Two late payments inside a rolling 90-day window
  (since the last demotion) drop the reseller one tier, logged in
  `reseller_events`.
- **MAP (§6.5).** `products.map_enforcement` CHECK: `retail_price >= srp`,
  rejected at save.
- **RLS (§8).** Role comes from the JWT claim `app_role` (Supabase) or the
  `app.role` GUC (local/tests). Resellers see only their own reseller row,
  orders, invoices, and the `b2b_available_stock` view (B2B pool only — never
  warehouse totals or retail pricing). Verified by tests running as a
  non-superuser role.
- **Audit (§8).** Triggers append every products/ledger/orders/resellers/
  invoices change to `audit_log`; `audit_log` and `stock_movements` reject
  UPDATE/DELETE at the trigger level.

## Deploying to Supabase

Apply `supabase/migrations/*.sql` in order (SQL editor or `supabase db push`).
Map your auth to the engine by putting `app_role` (and `reseller_id` for portal
users) into the JWT claims; everything else is enforced by the database.

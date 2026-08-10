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
| `supabase/migrations/0003_retail_sync.sql` | **Phase 3 — Retail sync & cash controls**: idempotent POS webhook ingestion, replenishment alerts, returns + tester/damage logs, blind cash drops with same-day reconciliation and repeat-variance watch |
| `supabase/migrations/0004_procurement_rop.sql` | **Phase 4 — Procurement & ROP**: vendors, PO lifecycle with customs/FDA legs + actual lead-time capture, §6.3 ROP engine, shelf-life-capped reorder suggestions, ABC segmentation, aging-stock report, cycle counts |
| `supabase/migrations/0005_hrms_payroll.sql` | **Phase 5 — HRMS & payroll**: employees, 3-mode attendance (biometric REST / POS / GPS-geofenced), 3-structure commission engine, PH statutory payroll as a data-driven locale module (SSS/PhilHealth/Pag-IBIG/WHT), 13th month, BIR 2316 data, 201 files, LMS gating |
| `supabase/migrations/0006_dashboards.sql` | **Phase 6 — Dashboard data layer**: sales by channel, expiry risk ₱, A-item days of cover, warehouse FEFO pick list, attendance exceptions (§9) |
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
| 3 — Retail sync & cash controls | ✅ built + tested | POS sales deduct the Retail Shelf pool only, replays can't double-deduct; blind drops reconcile same-day with auto-flagging |
| 4 — Procurement & ROP | ✅ built + tested | §6.3 serum unit test passes exactly (safety stock 525, ROP 1,125); reorder suggestions respect the 12-month shelf-life floor |
| 5 — HRMS & payroll | ✅ built + tested | Statutory computations match the published PH schedules; OT/night-diff/holiday, brand-boost and clearance-boost commissions, geofenced GPS punches all covered by tests |
| 6 — Dashboards & polish | ✅ built + tested | Every §9 dashboard has a database view feeding it, and the `docs/` app now surfaces them: owner dashboard cards (days-of-cover stockout risk, AR aging + exposure cap, cash-variance watch, clearance playbook), a 🔔 notification center aggregating every actionable signal, gray-market lot trace lookup, and the quarterly ROP recalibration action |

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
  invoices/cash-drops/PO change to `audit_log`; `audit_log` and
  `stock_movements` reject UPDATE/DELETE at the trigger level.
- **POS sync (§3.2, §8).** `ingest_pos_sale(event_id, lines)` claims the POS
  event id first (`ON CONFLICT DO NOTHING`), so queue-and-retry webhook
  delivery is idempotent — a replayed event returns the original order and
  never deducts the shelf twice. `pos_daily_ingest` reconciles ingested totals
  against the POS Z-report to detect missed events. The webhook adapter
  authenticates as the retail channel (`app_role = RETAIL_CASHIER`,
  `app.actor = 'POS_WEBHOOK'`).
- **Blind drops (§6.6).** `submit_cash_drop()` stores only the declared count;
  `pos_total`/`variance` stay NULL until finance runs
  `reconcile_cash_drops(date, threshold)`. Cashiers can only read
  `my_cash_drops`, which never exposes the POS total. Variances beyond the
  threshold auto-flag; `cashier_variance_watch` surfaces cashiers with ≥2
  flags in 90 days.
- **ROP (§6.3).** `rop_formula` implements the spec formulas verbatim (the
  serum worked example is a unit test). `reorder_alerts` caps
  `suggested_order_qty` at `avg_daily_sales × (shelf_life × 30 − 365)` — never
  order more than sells before the batch falls under the 12-month reseller
  floor. `rop_recalc_due` prompts quarterly recalculation. `recompute_abc()`
  classes SKUs by cumulative revenue share (80/95 cutoffs).
- **Procurement (§3.4).** PO lifecycle `DRAFT → SENT → IN_TRANSIT → CUSTOMS →
  RECEIVED` with customs/FDA status fields; `lead_time_actual` is captured
  door-to-door (shipping + customs + FDA) on receipt, and received batches
  link back to their PO for traceability.
- **Attendance (§3.6).** One `punch_clock()` endpoint serves all three modes:
  biometric devices post punches through the device-agnostic REST adapter, POS
  tablets punch on shift login, and agents' phones send GPS coordinates that
  are validated (haversine) against registered reseller geofences —
  out-of-fence punches are flagged for HR review, never silently dropped.
- **Commissions (§3.6).** `compute_commissions(period)` writes per-order
  entries: retail staff earn a % of their own fulfilled shop sales plus
  per-brand boost rates; B2B agents earn on their assigned resellers'
  fulfilled volume plus a clearance boost on lines picked from batches inside
  the 180-day expiry window. Entries are RLS'd so every rep sees their own
  live numbers (transparent dashboards).
- **PH payroll (§3.6).** All statutory rates live in `statutory_rates` as
  effective-dated jsonb config — a pluggable locale module, updated with data
  not code. `run_payroll(period)` computes monthly or hourly pay (OT ×1.25
  past 8h/day, +10% night differential 22:00–06:00 Asia/Manila, holiday
  premiums from the `ph_holidays` calendar), then SSS/PhilHealth/Pag-IBIG and
  TRAIN-table withholding per employee. `ph_13th_month()` accrues 1/12 of
  basic earned; `bir_2316_data` exposes the annual figures (PDF rendering is
  app-layer). Payroll approval is owner-level and audited.
- **Dashboards (§9).** Each dashboard reads views, not ad-hoc queries:
  owner (`sales_by_channel`, `expiry_risk_value`, `a_item_days_of_cover`,
  `ar_aging`, `ar_exposure`, `cashier_variance_watch`), warehouse
  (`warehouse_pick_list`, `retail_replenishment_alerts`, `reorder_alerts`,
  `aging_stock_alerts`), HR (`attendance_exceptions`, `training_compliance`,
  `expiring_documents`), reps (`commission_entries` under self-RLS),
  resellers (`b2b_available_stock`, own invoices/orders).

## Deploying to Supabase

Apply `supabase/migrations/*.sql` in order (SQL editor or `supabase db push`).
Map your auth to the engine by putting `app_role` (and `reseller_id` for portal
users) into the JWT claims; everything else is enforced by the database.

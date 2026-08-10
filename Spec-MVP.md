# Spec-MVP.md — MS BEAU AVE Business System (MVP)

> This is the MVP scope brief that `app/` implements, kept beside the broader
> platform vision in [`Spec.md`](Spec.md). Where the two disagree, this file
> governs what is built today; `Spec.md` describes where it is heading.

## 1. Project Overview

MS BEAU AVE is a beauty and skincare products **distributor** with three
channels sharing one stock pool:

1. A **warehouse** (master inventory, bulk stock)
2. **B2B resellers** (wholesale orders, tiered credit terms)
3. An **on-site physical retail store** (walk-in customers)

Everything previously ran on manual spreadsheets and WhatsApp orders. The MVP
replaces that with a **unified web application** acting as a single source of
truth: every retail sale and every reseller order instantly updates master
stock counts, with batch/expiry tracking (FEFO) and virtual stock allocation
preventing channel conflicts and overselling.

**Primary user:** the business owner/admin. Secondary: warehouse staff, retail
cashiers, and resellers (self-service portal).

**Currency:** PHP (₱). **Timezone:** Asia/Manila (the server process is pinned
to it, so receipt numbers, due dates and end-of-day cut-offs all agree).
Tax/statutory automation is out of MVP scope.

## 2. Tech Stack (as built)

| Requirement | Choice |
|---|---|
| Web application, responsive | One Node 22 HTTP server + a vanilla-JS SPA. No build step, no framework, no bundler — the whole UI is three files served statically. |
| Relational DB with transactional integrity | PostgreSQL 16 (Supabase-compatible). Stock commitment is atomic under row locks; the oversell race has an automated test. |
| Near-real-time stock across sessions | Short polling (6–12s per screen, paused while a dialog is open). Chosen over websockets because a warehouse tablet on flaky Wi-Fi recovers from polling automatically. |
| Role-based auth | Four roles — Admin, Warehouse, Cashier, Reseller — enforced twice: route gating in the API, and Postgres RLS underneath (the app connects as the non-superuser `app_client` role). |

**Why not Next.js/Supabase-hosted?** The business rules already live in the
database as migrations `0001`–`0006`, written and tested before this MVP. Those
rules are the product; a heavy front-end framework would only wrap them. A
dependency-free server keeps `npm ci` at one package (`pg`) and makes the whole
thing deployable to any box with Node and Postgres — including Supabase, by
pointing `DATABASE_URL` at it.

## 3. Design System

Dusty pink palette, defined once as CSS custom properties in
`app/public/styles.css`:

| Token | Value | Used for |
|---|---|---|
| `--pink` | `#D8A7B1` | primary actions, active nav |
| `--rose` | `#B4838D` | headings, links |
| `--bg` | `#FAF6F4` | page background |
| `--blush` | `#F4E4E8` | secondary surfaces, borders |
| `--ink` | `#4A3B40` | body text |
| `--sage` | `#A8B8A0` | success / in-stock |
| `--amber` | `#E0A458` | warnings / aging stock |
| `--red` | `#C46A6A` | expiry / blocked / past-due |

Soft rounded cards (`--radius: 14px`), diffuse shadows instead of hard borders,
generous whitespace. Every list view has search and/or filters. Every money
figure is formatted `₱1,234.56` — on the client *and* in server-generated
messages.

## 4. Roles & Permissions

| Role | Screens |
|---|---|
| **Admin** (owner) | Dashboard, Products & Batches, Receive Stock, B2B Orders, Resellers, Returns Queue, Reorder Points, Reports, Transfers & Counts, Users |
| **Warehouse** | Pick & Fulfill, Receive Stock, Transfers & Counts, Restock Tasks, Reorder Points |
| **Cashier** | Point of Sale, Returns & Damage Log, End of Day |
| **Reseller** | Catalog & Cart, My Orders, Invoices & Credit |

Gating is defence-in-depth: an API route names its allowed roles, and every
request additionally runs inside a transaction as `app_client` with
`app.role` / `app.reseller_id` set, so RLS policies apply even if a route were
mis-declared. A reseller hitting `/api/stock` gets 403 from the router; had it
slipped through, RLS would still return nothing.

## 5. Core Data Model

Migrations `0001`–`0006` (pre-existing) carry products, batches, the pool
ledger, the immutable movement journal, orders, resellers, invoices, payments,
ROP settings and the audit log. Migration **`0007_mvp_app.sql`** adds what the
MVP screens need:

| Addition | Why |
|---|---|
| `products.reseller_floor_months` (default 12) | The shelf-life floor is now a property of the product, not a report footnote. |
| `pool_min_expiry()`, rewritten `fefo_pick()` / `place_order()` / `b2b_available_stock` | The floor is enforced at commitment time, not just displayed. |
| `retail_sales` + `receipt_seq`, `pos_checkout()` | Sequential receipt numbers, payment method, tendered/change. |
| `return_requests`, `request_return()`, `decide_return()` | Returns quarantine: the cashier files, the admin decides restock vs write-off. |
| `restock_requests`, `request_restock()` | "Move stock to the storefront" tasks, de-duplicated per SKU. |
| `pos_eod_close()` | Blind count in, expected/variance out — in that order, in one call. |
| `expired_stock`, `write_off_expired()` | Expiry write-off as an explicit, journalled action. |
| `orders.delivered_at`, `mark_order_picking/delivered()` | The full `… → DISPATCHED → DELIVERED` pipeline. Delivery is a timestamp rather than a new `status`, so the four earlier migrations that ask `status = 'FULFILLED'` (commissions, ABC, cash reconciliation, sales-by-channel) keep counting delivered orders. |
| `rop_settings.target_months_cover`, `recalc_rop_from_sales()` | Months-of-cover suggestions and the "recalculate from the last 90 days" helper. |
| `app_users` | Login identities per role; scrypt digests, verified in the app, never plaintext in the DB. Role and reseller are re-read from this table on every request, so disabling a user ends their open session at once. |
| `order_fulfilment` view | Lets warehouse pickers see the reseller name and whether a prepaid order is paid, without putting them on the credit tables — the money column resolves to NULL for their role. |

## 6. Business Rules

All of these are enforced in Postgres, so no UI, API or human can route around
them.

- **Virtual allocation.** Receiving splits 70/20/10 into `B2B_POOL` /
  `RETAIL_SHELF` / `SAFETY`, editable per product; largest-remainder rounding
  so units are never lost. Each channel reads only its own pool.
- **Committed-stock locking.** `place_order()` walks FEFO-ordered ledger rows
  under `SELECT … FOR UPDATE` and re-checks availability under the lock. Two
  simultaneous orders for the last units serialise; exactly one wins.
- **FEFO with a viability floor.** Picking always takes the earliest-expiring
  batch. For B2B, "viable" excludes anything inside the product's floor
  (default 12 months) — retail may still sell it.
- **Reorder points.** `safety = (max/day × max lead) − (avg/day × avg lead)`;
  `ROP = (avg/day × avg lead) + safety`. Suggested quantity is
  `months of cover × avg monthly sales`, capped by what can sell before a fresh
  batch would drop under the floor.
- **Credit tiers.** Tier 1 prepaid (no dispatch until paid), Tier 2 Net 15–30,
  Tier 3 Net 30–60. Any past-due invoice, or `AR + new order > limit`, blocks
  ordering automatically. 2/10 net 30 early-payment discount applies itself.
  Admin override requires a reason and is written to `reseller_events`.
- **POS.** Search or barcode-wedge scan, cart, cash/GCash/card, tendered and
  change, printable receipt with batch numbers. A sale that empties the shelf
  raises its own restock task; the next sale is blocked.
- **Blind reconciliation.** The declared count is stored before the expected
  total is computed, and cashiers can only read `my_cash_drops`, which has no
  expected/variance columns at all.

## 7. Screens

Ten, matching §4 above. See the README for a guided walkthrough.

## 8. Out of Scope (hooks, not features)

HRMS/payroll/commissions (migration `0005` already models them for Phase 2),
procurement PO workflows beyond ROP alerts, external POS/e-commerce
integrations, payment gateway processing, SMS/email (in-app alerts only),
statutory tax filing, multi-warehouse.

## 9. Non-Functional

- **Auditability.** Every stock and money mutation is a ledger row plus an
  `audit_log` entry with actor and timestamp. `stock_movements` and `audit_log`
  reject UPDATE and DELETE at the trigger level. No hard deletes.
- **Concurrency.** The oversell race is covered by an automated test that fires
  two real HTTP orders simultaneously.
- **Performance.** POS search and checkout are single indexed queries; the
  checkout round-trip measures in the low tens of milliseconds locally.
- **Seed data.** 30 SKUs, staggered batch expiries (including inside 6 months
  and under the 12-month floor), 5 resellers across all tiers with one past-due
  and one pending application, two months of sales history.
- **Plain language.** Database errors are translated before they reach a user:
  `INSUFFICIENT_STOCK` becomes "Not enough stock: SER-001 is short 3 unit(s).
  Someone may have just bought or ordered it…".

## 10. Acceptance Criteria

Every one is an automated test in `tests/phase7_mvp_app.test.js`, run against a
real Postgres through the real HTTP API.

| # | Criterion | Test |
|---|---|---|
| 1 | 100 units auto-allocate 70/20/10; admin can adjust | `ACCEPTANCE 1` |
| 2 | A reseller order and a POS sale can never consume the same units | `ACCEPTANCE 2a` (pool isolation) + `2b` (concurrency race) |
| 3 | Fulfilment picks earliest-expiring viable batch; sub-12-month stock never reaches a reseller | `ACCEPTANCE 3` |
| 4 | The serum example yields safety stock 525, ROP 1,125 | `ACCEPTANCE 4` |
| 5 | Tier 1 blocked without payment; past-due Tier 2 auto-blocked with a clear message; override logged | `ACCEPTANCE 5a/5b/5c` |
| 6 | Last shelf unit sells, shelf hits zero, restock alert fires, next sale blocked | `ACCEPTANCE 6` |
| 7 | Blind reconciliation hides the expected total until submission | `ACCEPTANCE 7` |
| 8 | Dusty pink design system, usable on a tablet | `ACCEPTANCE 8` + a Chromium pass at 820×1180 confirming no horizontal overflow |

## 11. Assumptions

Recorded rather than guessed at silently:

- **One barcode field.** MVP treats the SKU code as the scannable barcode;
  keyboard-wedge scanners type it and press Enter. A separate `barcode` column
  can be added without touching the POS flow.
- **Documents are references, not uploads.** Reseller license/tax documents are
  stored as file references (a Drive link or filename) with a verification
  flag. Binary upload needs object storage, which the MVP does not provision.
- **Expected cash = that cashier's CASH sales for the day.** GCash and card
  sales are recorded but excluded from the drawer count, and the flag threshold
  is ₱100.
- **Tier changes stay manual**, as specified. The system surfaces the signals
  (on-time streak, lates this quarter) on the Resellers list; the engine's own
  auto-demotion on two lates per quarter remains active underneath.
- **`shelf_life_months` is nominal per product**, used for the ROP shelf-life
  cap. Actual viability always comes from the batch's real expiry date.
- **Retail may sell below-floor stock.** Deliberate, per §6.3 — it is how
  short-dated stock clears without being written off.

# MS BEAU AVE — Skincare Distribution & Retail Operations

One system for a warehouse, a reseller network and a retail counter sharing a
single stock pool. Every sale and every wholesale order moves the same
inventory, tracked by batch and expiry, so no channel can oversell another.

```bash
npm ci
npm run app            # throwaway Postgres + demo data + the app on :4300
```

Then sign in at <http://localhost:4300> — all demo passwords are `msbeauave`:

| Login | Sees |
|---|---|
| `admin` | Everything: dashboard, products, receiving, orders, resellers, reports, users |
| `warehouse` | Pick & fulfil, receiving, transfers, cycle counts, restock tasks |
| `cashier` | Point of sale, returns, blind end-of-day count |
| `reseller` | Wholesale portal for Cebu Glow Distributors (Tier 2, in good standing) |
| `blocked` | Same portal for Davao Beauty Hub — past due, so ordering is blocked |

`npm run app` throws the database away on exit. To keep data, point the app at
a real Postgres or Supabase project:

```bash
export DATABASE_URL='postgres://…'
for f in supabase/migrations/*.sql; do psql "$DATABASE_URL" -f "$f"; done
node scripts/seed-mvp.js          # optional demo data
SESSION_SECRET='…' node app/server.js
```

On a fresh database with no users, the server creates `admin` / `msbeauave` on
first start and tells you to change it. Set `SESSION_SECRET` in production —
without it, sessions are signed with a random key that changes on restart
(everyone gets logged out on deploy).

## A five-minute tour

1. **Sign in as `admin`.** The dashboard leads with today's takings, then the
   things that need a decision: ORDER NOW alerts, overdue invoices, batches
   inside six months of expiry, and any reseller holding more than 15% of
   receivables. Radiance Vitamin C Serum shows ROP **1,125** — the worked
   example from the spec, computed by the database.
2. **Receive Stock** → any SKU, a batch number, an expiry, 100 units. It splits
   **70 / 20 / 10** across the reseller pool, the shop shelf and the safety
   buffer. Change the split per product under Products & Batches.
3. **Sign in as `cashier`.** Search or scan, tap to build a cart, take cash and
   get a receipt with the batch numbers that actually left the shelf — always
   the earliest-expiring ones. Sell a product down to zero and a restock task
   appears on the warehouse screen by itself.
4. **End of Day** asks for the drawer count *before* showing what it should be.
   Submit, and the variance is recorded; repeat offenders surface on the
   admin dashboard.
5. **Sign in as `blocked`.** The portal says exactly why ordering is refused
   and exactly what to pay to lift it. Sign in as `reseller` to place a real
   order — stock is reserved the moment it goes through, and the warehouse sees
   it under Pick & Fulfill with a FEFO pick list.

## How it is put together

| Path | What it is |
|---|---|
| [`Spec-MVP.md`](Spec-MVP.md) | The MVP brief this implements — scope, design system, business rules, acceptance criteria, and the assumptions taken |
| [`Spec.md`](Spec.md) | The wider platform vision (Bitrix24-style workspace, HR, e-commerce) this grows into |
| [`ENGINE.md`](ENGINE.md) | The operations engine: how each rule is enforced in Postgres |
| `app/server.js` | HTTP API — auth, role gating, plain-language errors. No framework |
| `app/public/` | The SPA: `app.js`, `styles.css`, `index.html` |
| `supabase/migrations/` | The rules themselves. `0001`–`0006` are the engine; `0007_mvp_app.sql` adds the MVP app layer |
| `tests/` | 68 tests against a real Postgres 16 — `phase7_mvp_app.test.js` drives the eight acceptance criteria over real HTTP |
| `docs/`, `demo/` | The earlier static marketing/demo apps, unchanged |

The business rules live in the database, not the app. Pools, FEFO, committed
locking, credit blocks and the audit trail are functions, constraints and RLS
policies — so a future mobile app, an integration, or someone with a psql
prompt gets the same answers as the web UI.

```bash
npm test               # all 68, on an ephemeral Postgres 16
```

## What the MVP deliberately leaves out

Payroll and HR (modelled in migration `0005`, not surfaced), purchase-order
workflows beyond reorder alerts, payment gateways, SMS/email notifications,
statutory tax filing, and multiple warehouses. Locations are modelled so more
can be added later.

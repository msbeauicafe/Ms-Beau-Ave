# Ms Beau Ave — Function Demo

A self-contained, **zero-dependency** demo of the platform functions described in
[`../Spec.md`](../Spec.md). Everything runs from an **in-memory store** — no
database, no migrations, no `npm install`. Restarting the server resets to fresh
seed data (our real product lines, batches with staggered expiry dates, customers,
promos, events).

## Run it

```bash
node demo/server.js
```

Then open:

| Surface | URL |
|---|---|
| **Back office** (Admin/Staff demo) | http://localhost:4200/ |
| **Public landing page** (dusty rose theme) | http://localhost:4200/landing.html |
| **Customer tracking link** | created per courier order, e.g. `/track/MBA…` |

Requires Node.js 18+ (only the standard library is used).

## Suggested demo script (~5 minutes)

1. **Dashboard** — sales by channel, near-expiry value at risk, low-stock alerts,
   courier performance, Bitrix24-style activity stream.
2. **Oversell protection** (Dashboard tab) — click *"Run simultaneous-checkout
   simulation"*: a POS sale and an online checkout race for the last units of the
   Retinoid Night Active. Exactly one succeeds; the other gets a friendly
   out-of-stock message. *(Spec acceptance check #1)*
3. **Inventory & FEFO** — the near-expiry radar shows the Peeling Toner lot on the
   store shelf expiring in ~45 days. Click **⚡ Flash sale** — a batch-scoped promo
   is created in one click. *(Acceptance check #3)*
4. **Orders & BOPIS** — place an online order for the *Retinoid-Acid Night Active*.
   The FEFO pick list tells staff to pull the earliest-expiring lot **from the Store
   Shelf**, even though the warehouse has stock. *(Acceptance check #2)*
   Advance the order through its status pipeline; a courier order gets a
   customer-visible **tracking link** with a status timeline. *(Check #5)*
5. **POS** — "scan" Ana Reyes' loyalty QR: her **online** purchase history appears
   at the counter with a complementary-product suggestion (bought Peeling Toner →
   suggest Day Cream Shield). *(Check #4)* Sell her a Glow Starter Set — note the
   bundle decrements component stock and points are earned/redeemable. *(Check #7)*
6. **Pricing & Promos** — one price book with store vs online prices side by side;
   the flash sale you created shows its **reason and end date** so counter staff
   can answer "why is it cheaper online?". *(Check #6)*
7. **Events & Bulletins** — publish a bulletin from the back office, then refresh
   the landing page: it's live immediately, no deploy. *(Check #8)*

## What's demonstrated vs. deferred

**Demonstrated:** unified stock ledger · FEFO batch allocation across locations ·
near-expiry radar with one-click promos · oversell protection · POS with loyalty
QR + omnichannel history + upsell suggestions · bundles decrementing component
stock · online orders with BOPIS and courier tracking links · unified price book +
promotions engine + staff promo panel · loyalty points earn/redeem on both
channels · CRM profiles with tags · CMS-lite bulletins/events · dashboards ·
activity stream · dusty-rose design system.

**Deferred to the real build (skipped for demo speed):** PostgreSQL schema &
transactions, authentication/RBAC, phone OTP, real payment/courier integrations,
push notifications, the mobile app, automated tests, and the full monorepo
scaffold from Spec.md §8.

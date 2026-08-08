# Ms Beau Ave — Omnichannel Skincare Commerce & Operations Platform

**Specification / Claude Code Prompt — v1.0**

> This document is the single source of truth for building the Ms Beau Ave platform.
> It describes WHO we are, WHAT problems we are solving, WHAT we are building, and HOW
> it should be built. Treat every section as a requirement unless marked *(Future)*.

---

## 1. Business Context

**Ms Beau Ave** is a small/medium enterprise (SME) skincare distributor operating:

- A **physical retail store** (walk-in counter sales).
- A growing **online channel**: Facebook page ("MS Beau Ave"), fast online orders, and
  direct customer chats.
- A possible **authorized reseller network** (distributors reselling our products online).

### Product Catalog (core lines)

| Product Line | Notes |
|---|---|
| Trendy skincare products & beauty soaps | General retail |
| Micro-exfoliating soap | |
| Clarifying / brightening soap | |
| Peeling Toner / Keratolytic Solution | Active product — expiry-sensitive |
| Photoprotectant / Day Cream Shield | |
| Retinoid-Acid Therapy / Night Active | Active product — expiry-sensitive, batch-critical |

Skincare actives (serums, retinoids, keratolytics) have **strict shelf lives**. Expiry
management is a first-class requirement, not an afterthought.

### Existing Tooling

The business already uses **Bitrix24** (all-in-one business platform: CRM, tasks, chat,
catalog). The team is familiar with its workflows. This system should **feel similar to
Bitrix24 in structure** (unified workspace: CRM + inventory + orders + activity stream +
chat-style notifications) while being purpose-built for our skincare
distribution/retail operations. Where practical, design integration points (webhooks /
REST) so Bitrix24 can be connected later.

---

## 2. Problems We Are Solving

### 2.1 Inventory & Operations
1. **Stock shortages** — popular sets sell out fast; buyers leave for competitors.
2. **Siloed stock** — physical shelves run empty while the online warehouse has stock
   (or vice versa) → missed sales, frustrated walk-ins.
3. **In-store expiry** — actives expire on physical shelves because online orders pull
   from a different batch.

### 2.2 Fulfillment
4. **Delivery delays** — courier mistakes cause late shipments; customers cancel or
   refuse to pay (COD losses).

### 2.3 Marketing & Customer Experience
5. **Pricing disconnect** — online flash sales / live-selling discounts / vouchers make
   store prices look expensive and confuse loyal walk-in buyers.
6. **Fragmented data** — online purchase histories are invisible to physical store
   staff, killing upsell opportunities during visits.

### 2.4 Brand Trust & Resellers
7. **Reseller price wars** — online resellers undercut our own physical store prices.
8. **Tester drain** — customers test in-store, then buy cheaper from unauthorized
   online sellers.

---

## 3. Solution Vision

One platform, three surfaces, one database:

1. **Back office (web, desktop-first)** — admin & staff sign in with **email +
   password**. Unified inventory, POS, orders, CRM, batch/expiry, pricing, reseller
   management, reports. This is the Bitrix24-like core.
2. **Customer mobile app + responsive web** — shop, track orders, loyalty points, view
   events/activities/promotions.
3. **Public landing page** — company bulletins & news, promotions, events, brand story.
   **Theme: dusty rose pink palette.**

### Solution pillars (mapped to problems)

| Pillar | Solves |
|---|---|
| **Unified real-time inventory** (omnichannel POS syncing store + online stock) | 1, 2 |
| **FEFO batch tracking** (First-Expired, First-Out across both channels; auto-flag near-expiry stock for flash sales / in-store promos) | 3 |
| **Smart stock planning** (sales-trend dashboards, low-stock alerts, reorder points) | 1 |
| **Courier integration & tracking links** (customer-visible package tracking; reliable partner management) | 4 |
| **Unified pricing & promotions engine** (one price book with channel rules; promos visible to store staff so they can match/explain) | 5 |
| **Shared customer profiles & loyalty** (single login via phone number or QR code; points earned & redeemed at counter or online) | 6 |
| **BOPIS — Buy Online, Pick Up In-Store** (drives online traffic into the store; staff upsell complementary items at pickup) | 1, 6 |
| **MAP policy enforcement** (Minimum Advertised Price contracts for resellers; monitoring & violation flags) | 7 |
| **Exclusive in-store experiences** (bookable free skin analysis / consultations promoted in-app) | 8 |

---

## 4. Users & Roles

### Back office (email + password sign-in)
| Role | Permissions |
|---|---|
| **Admin** | Everything: user management, pricing, price book, MAP contracts, reports, settings, refunds, stock adjustments |
| **Staff** | POS checkout, order processing, BOPIS pickup handling, stock counts/transfers, customer lookup, bookings — no pricing/user-management access |

Role-based access control (RBAC) must be enforced server-side. Design roles as
extensible (e.g., a future "Warehouse" or "Reseller portal" role).

### Customer-facing
| User | Access |
|---|---|
| **Customer** | Sign up / sign in with **phone number** (OTP) or email; loyalty QR code; orders; points; events |
| **Guest** | Browse landing page, catalog, promos; must register to order |

*(Future)* **Reseller** — authorized reseller portal with wholesale price list and MAP
contract acknowledgment.

---

## 5. Functional Requirements

### 5.1 Authentication & Accounts
- Back office: email + password sign-in (bcrypt/argon2 hashing, session or JWT auth,
  rate limiting, password reset via email). Admin can invite/deactivate staff.
- Customers: phone-number OTP or email + password. Each customer gets a **loyalty QR
  code** shown in the app and scannable at the POS counter.
- Every request authorized by role, server-side.

### 5.2 Product Catalog
- Products with: name, SKU, barcode, category (soap / toner / day cream / night
  active / set), brand, description, images, active-ingredient flags, shelf-life
  (months), storage notes.
- **Product sets/bundles** (popular sets are a stock-shortage driver — bundles must
  decrement component stock).
- Draft / published states; visibility per channel (in-store only, online only, both).

### 5.3 Inventory (the heart of the system)
- **Locations**: at minimum `Store Shelf` and `Online Warehouse`; extensible to more.
- **Single stock ledger**: every movement (receive, sell, transfer, adjust, return,
  expire/write-off) is an immutable ledger entry. On-hand = sum of ledger. No channel
  ever oversells because both channels decrement the same ledger in real time.
- **Batch/lot tracking**: every received unit belongs to a batch with lot number,
  received date, **expiry date**, cost.
- **FEFO allocation**: when an order (online or POS) reserves stock, the system
  allocates from the earliest-expiring batch across ALL locations, and tells staff
  which batch/shelf to pick.
- **Near-expiry radar**: dashboard + alerts for batches expiring within configurable
  windows (90/60/30 days) with one-click actions: "create flash-sale promo" or
  "create in-store promo" for that batch.
- **Transfers**: staff-initiated store⇄warehouse transfers with in-transit state.
- **Reorder planning**: per-product reorder point and target level; sales-velocity
  (e.g., 30-day average daily sales) drives a suggested-purchase report; low-stock
  alerts before sell-out.
- **Stock counts**: cycle-count workflow with variance report.

### 5.4 POS (in-store checkout)
- Fast keyboard/barcode-first checkout screen usable on desktop or tablet.
- Scan product barcode → FEFO batch suggestion → cart → payment (cash, card,
  GCash/e-wallet reference entry) → receipt (print/email).
- Scan customer loyalty QR (or look up by phone) → attach sale to profile → show
  **full omnichannel purchase history + suggested complementary products** (e.g.,
  bought Peeling Toner online → suggest Day Cream Shield sunscreen).
- Apply promos; POS displays current online promos so staff can explain/match pricing.
- Returns/exchanges with ledger reversal.

### 5.5 Online Orders & Fulfillment
- Storefront (mobile app + responsive web): browse, cart, checkout, pay
  (COD, e-wallet, card — pluggable payment adapters, start with COD + manual
  payment-reference confirmation).
- **Fulfillment methods**: courier delivery **and BOPIS**.
  - BOPIS flow: order → staff pick (FEFO) → "Ready for pickup" notification → customer
    shows QR at counter → staff verifies, hands over, upsells → completed.
- **Courier shipments**: create shipment, assign courier partner, enter/receive
  tracking number, generate **customer-visible tracking link**; status timeline
  (packed → handed to courier → in transit → out for delivery → delivered / failed).
  Courier partner directory with performance stats (late %, failed-delivery %) so we
  keep only reliable partners.
- Order statuses: `pending → confirmed → picking → packed → shipped/ready-for-pickup
  → completed / cancelled / refused`. Refused-COD tracking per customer.
- Chat-order intake: staff can create a **manual order** on behalf of a customer from
  Facebook/chat conversations in under a minute.

### 5.6 Pricing & Promotions
- **One price book**: base retail price per product; channel-level price rules
  (must be deliberate, visible, and time-bound — no accidental divergence).
- Promotions engine: percentage/amount off, product/bundle/batch-scoped, channel-scoped
  (online flash sale, in-store promo, both), scheduled start/end, voucher codes.
- Staff-facing "Why is it cheaper online?" panel: every active promo shows its reason
  and end date so counter staff can answer confidently or apply a match.

### 5.7 Loyalty
- Points earned per peso spent, same rate online and in-store, tied to one profile
  (phone/QR).
- Redemption at checkout (both channels). Tier perks and birthday gifts *(Future)*.
- Loyalty dashboard for customers in the app: points balance, history, available
  rewards.

### 5.8 CRM (Bitrix24-style)
- Unified customer record: contact info, channel of origin (walk-in / Facebook /
  app), full order history across channels, loyalty status, notes, tags
  (e.g., "sensitive skin", "retinoid user").
- Activity timeline per customer (orders, pickups, consultations, support notes).
- Staff task list / reminders (follow up on refused COD, restock call-backs).

### 5.9 Reseller & MAP Management *(phase 2, schema in phase 1)*
- Reseller directory: business name, contacts, channels (Shopee/Lazada/FB), signed
  **MAP contract** with per-product minimum advertised prices and effective dates.
- Violation log: staff record observed underpricing (screenshot URL, price, date);
  status workflow (warned → suspended → terminated).
- Wholesale price list per reseller tier.

### 5.10 Events, Activities & Bookings
- Admin creates **events/activities** (product launches, in-store promo days, free
  skin-analysis days) with title, banner image, date/time, location, description.
- Shown in the customer app ("Events & Activities" feed) and on the landing page.
- **Bookable in-store services**: free skin analysis / instant consultation slots;
  customers book in-app; staff see the day's bookings in back office.

### 5.11 Landing Page (public)
- Company bulletins & news, current promotions, upcoming events/activities, product
  highlights, store location/hours, Facebook page link, app download links.
- CMS-lite: admin manages bulletins/banners from back office — no code deploys for
  content changes.
- **Dusty rose pink theme** (see §7), fully responsive, fast (static-first rendering).

### 5.12 Dashboards & Reports
- Sales by day/channel/product/category; best-seller and slow-mover lists.
- Inventory health: stock on hand by location, near-expiry value at risk, write-offs.
- Stock-out incidents & suggested purchases.
- Courier performance; refused-COD rate.
- Loyalty engagement (active members, redemption rate).

### 5.13 Notifications
- In-app + push (mobile) for customers: order status, BOPIS ready, promos, events.
- Back office activity stream (Bitrix24-style): new orders, low stock, near-expiry,
  MAP violations, today's bookings.
- Email fallback for critical customer notices.

---

## 6. Non-Functional Requirements

- **Real-time stock**: a sale on either channel reflects on the other within ≤ 2s.
- **Concurrency-safe**: stock reservation uses DB transactions/row locks — two
  simultaneous checkouts can never oversell the last unit.
- **Audit trail**: all inventory adjustments, price changes, and refunds record who,
  when, and why.
- **Offline-tolerant POS** *(Future)*: queue sales locally if internet drops; sync on
  reconnect.
- **Performance**: POS checkout interactions < 200ms perceived; storefront pages < 2s
  on mid-range mobile.
- **Security**: HTTPS everywhere, hashed passwords, RBAC on every endpoint, input
  validation, OWASP top-10 hygiene, rate-limited auth, signed customer QR codes.
- **Privacy**: customer data access limited by role; exportable/deletable customer
  record (data-subject requests).
- **Backups**: daily automated DB backups.
- **Localization-ready**: currency ₱ (PHP), English first; copy centralized for future
  Tagalog support.

---

## 7. Design System — Dusty Rose Palette

Apply across landing page, customer app, and back office (back office may use a more
neutral surface with dusty-rose accents for long-shift eye comfort).

| Token | Hex | Use |
|---|---|---|
| `--rose-primary` | `#C08081` | Primary buttons, active nav, links |
| `--rose-deep` | `#9E5B5D` | Hover states, headings accent |
| `--rose-soft` | `#E8C4C4` | Cards, highlights, tags |
| `--rose-blush` | `#F6E7E7` | Page/background surfaces |
| `--rose-dust` | `#D8A7A7` | Secondary buttons, borders |
| `--neutral-ink` | `#3E2C2D` | Body text |
| `--neutral-warm` | `#FAF6F4` | App background |
| `--success` | `#5F8D6B` | Stock OK, delivered |
| `--warning` | `#C9963F` | Near-expiry, low stock |
| `--danger` | `#B04A4A` | Expired, failed delivery, MAP violation |

Typography: elegant serif for landing-page headings (e.g., Playfair Display / Cormorant),
clean sans (e.g., Inter) for UI and body. Rounded-soft components (8–12px radius),
generous whitespace, product photography forward.

---

## 8. Recommended Architecture

> Claude Code may adjust specifics with justification, but keep the monorepo shape and
> the single-database, ledger-based inventory model.

```
ms-beau-ave/
├── apps/
│   ├── api/          # Backend REST API (NestJS or Express + TypeScript)
│   ├── backoffice/   # Admin/staff web app (React + Vite + TypeScript)
│   ├── storefront/   # Customer web storefront + landing page (Next.js — SSG for landing/SEO)
│   └── mobile/       # Customer app (React Native / Expo — iOS + Android; shares API client)
├── packages/
│   ├── shared/       # Types, DTOs, validation schemas (zod), constants
│   └── ui/           # Shared design tokens (dusty rose) + component primitives
└── Spec.md
```

- **Database**: PostgreSQL (transactions + row locking for stock; one DB for all
  channels). ORM: Prisma or TypeORM.
- **Auth**: JWT access + refresh tokens; argon2 password hashing; OTP service
  abstraction for customer phone sign-in (stub SMS in dev).
- **Realtime**: WebSocket (or Server-Sent Events) channel for stock/order/activity
  stream updates to back office; push notifications via Expo/FCM for mobile.
- **Payments/Couriers**: adapter interfaces (`PaymentProvider`, `CourierProvider`)
  with manual/stub implementations first; real integrations plug in later without
  schema changes.
- **Bitrix24**: outbound webhooks on order/customer events + REST endpoints so
  Bitrix24 can be wired up later.
- **Desktop**: back office is a web app; package with Tauri/Electron *(Future)* if a
  native desktop shell is wanted — do not block on it.

### Core data model (minimum)

`User(role)`, `Customer(loyalty_qr, phone)`, `Product`, `Bundle`, `Batch(lot, expiry,
cost)`, `Location`, `StockLedgerEntry(type, qty, batch, location, ref)`,
`Order(channel, fulfillment_method, status)`, `OrderItem(batch_allocations)`,
`Shipment(courier, tracking_no, status_events)`, `CourierPartner(stats)`,
`PriceBookEntry`, `Promotion(scope, channel, window)`, `LoyaltyAccount`,
`LoyaltyTransaction`, `Reseller`, `MapContract`, `MapViolation`, `Event`,
`Booking`, `Bulletin`, `Notification`, `AuditLog`.

---

## 9. Build Phases

### Phase 1 — Core Operations (MVP)
1. Monorepo scaffold, DB schema, seed data (our product lines above).
2. Back office auth (email + password, Admin/Staff RBAC).
3. Product catalog + bundles.
4. Inventory: locations, batches, stock ledger, FEFO allocation, transfers,
   near-expiry radar, low-stock alerts.
5. POS checkout with barcode + loyalty QR lookup + FEFO pick guidance.
6. Online orders (manual/chat intake first, then storefront checkout) + BOPIS flow
   + courier shipments with tracking links.
7. Unified price book + promotions engine + staff promo panel.
8. Dashboards: sales, inventory health, suggested purchases.

### Phase 2 — Customer Experience
9. Customer accounts (phone OTP), loyalty points + QR, storefront web.
10. Landing page with CMS bulletins, promos, events (dusty rose theme).
11. Mobile app (Expo): shop, orders/tracking, loyalty, events & activities feed,
    push notifications.
12. Bookable in-store consultations / skin analysis.

### Phase 3 — Network & Scale
13. Reseller directory, MAP contracts & violation workflow, wholesale pricing.
14. Courier/payment real integrations; Bitrix24 webhook bridge.
15. Offline-tolerant POS; desktop shell; advanced forecasting.

Each phase must ship with: seed/demo data, automated tests for money- and
stock-touching logic (FEFO allocation, ledger integrity, promo math, points),
and a short README per app.

---

## 10. Acceptance Criteria (spot checks)

- [ ] Selling the last unit simultaneously at POS and online results in exactly one
      successful sale; the other gets a friendly out-of-stock response.
- [ ] An online order for Retinoid Night Active allocates the batch expiring soonest,
      even if it sits on the physical store shelf, and tells staff where to pick it.
- [ ] A batch entering its 60-day expiry window appears on the near-expiry radar and
      can be turned into a flash-sale promo in two clicks.
- [ ] Staff scanning a walk-in customer's QR sees her online purchase history and at
      least one complementary-product suggestion.
- [ ] A courier shipment gives the customer a working tracking link and status
      timeline.
- [ ] An online flash sale is visible in the POS promo panel with its end date.
- [ ] Points earned online are redeemable at the physical counter (and vice versa).
- [ ] Admin can post a bulletin + event that appear on the landing page and in the
      app feed without a deploy.
- [ ] Staff role cannot access user management or edit the price book.
- [ ] Landing page renders in the dusty rose palette and scores ≥ 90 Lighthouse
      performance on mobile.

---

## 11. Out of Scope (for now)

- Multi-store/franchise support (design location model to allow it later).
- Live-selling video integration.
- Automated marketplace price-crawling for MAP monitoring (manual logging first).
- Accounting/tax filing modules (export CSVs instead).

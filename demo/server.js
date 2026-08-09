#!/usr/bin/env node
/**
 * Ms Beau Ave — Demo Server
 *
 * Zero-dependency Node.js server that demonstrates the core platform functions
 * from Spec.md using an in-memory store (no database required).
 *
 * Run:  node demo/server.js   →  http://localhost:4200
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.PORT || 4200;
const PUBLIC_DIR = path.join(__dirname, 'public');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const DAY = 24 * 60 * 60 * 1000;
const now = () => Date.now();
const daysFromNow = (d) => new Date(now() + d * DAY).toISOString().slice(0, 10);
const peso = (n) => Math.round(n * 100) / 100;

let idCounter = 1000;
const nextId = (prefix) => `${prefix}-${++idCounter}`;

// ---------------------------------------------------------------------------
// Seed data (product lines from Spec.md §1)
// ---------------------------------------------------------------------------

const LOCATIONS = [
  { id: 'shelf', name: 'Store Shelf' },
  { id: 'warehouse', name: 'Online Warehouse' },
];

const products = [
  { id: 'p1', sku: 'MBA-SOAP-01', barcode: '4800001000011', name: 'Micro-Exfoliating Soap', category: 'soap', price: 180, active: false, shelfLifeMonths: 24 },
  { id: 'p2', sku: 'MBA-SOAP-02', barcode: '4800001000028', name: 'Clarifying Brightening Soap', category: 'soap', price: 195, active: false, shelfLifeMonths: 24 },
  { id: 'p3', sku: 'MBA-TONER-01', barcode: '4800001000035', name: 'Peeling Toner (Keratolytic Solution)', category: 'toner', price: 350, active: true, shelfLifeMonths: 12 },
  { id: 'p4', sku: 'MBA-DAY-01', barcode: '4800001000042', name: 'Day Cream Shield (Photoprotectant)', category: 'day-cream', price: 420, active: false, shelfLifeMonths: 18 },
  { id: 'p5', sku: 'MBA-NIGHT-01', barcode: '4800001000059', name: 'Retinoid-Acid Night Active', category: 'night-active', price: 480, active: true, shelfLifeMonths: 9 },
  { id: 'p6', sku: 'MBA-SET-01', barcode: '4800001000066', name: 'Glow Starter Set', category: 'set', price: 880, active: true, bundle: ['p1', 'p3', 'p4'], shelfLifeMonths: 9 },
];

// Each batch: lot, expiry, cost, stock per location.
const batches = [
  { id: 'b1', productId: 'p1', lot: 'SOAP1-2601', expiry: daysFromNow(400), cost: 90, stock: { shelf: 24, warehouse: 60 } },
  { id: 'b2', productId: 'p2', lot: 'SOAP2-2601', expiry: daysFromNow(420), cost: 95, stock: { shelf: 18, warehouse: 40 } },
  // Peeling Toner: one near-expiry batch ON THE STORE SHELF (problem 3 from spec)
  { id: 'b3', productId: 'p3', lot: 'TONER-2542', expiry: daysFromNow(45), cost: 170, stock: { shelf: 12, warehouse: 0 } },
  { id: 'b4', productId: 'p3', lot: 'TONER-2607', expiry: daysFromNow(280), cost: 170, stock: { shelf: 0, warehouse: 36 } },
  { id: 'b5', productId: 'p4', lot: 'DAY-2603', expiry: daysFromNow(320), cost: 210, stock: { shelf: 10, warehouse: 30 } },
  // Retinoid Night Active: earliest-expiring batch sits on the physical shelf —
  // FEFO must pick it even for an ONLINE order (acceptance criterion 2)
  { id: 'b6', productId: 'p5', lot: 'RET-2538', expiry: daysFromNow(25), cost: 240, stock: { shelf: 8, warehouse: 0 } },
  { id: 'b7', productId: 'p5', lot: 'RET-2551', expiry: daysFromNow(80), cost: 240, stock: { shelf: 0, warehouse: 20 } },
  { id: 'b8', productId: 'p5', lot: 'RET-2604', expiry: daysFromNow(200), cost: 235, stock: { shelf: 0, warehouse: 30 } },
];

const customers = [
  {
    id: 'c1', name: 'Ana Reyes', phone: '+63 917 555 0101', qr: 'MBA-CUST-0001',
    origin: 'facebook', points: 120, tags: ['retinoid user'],
    history: [
      { ts: daysFromNow(-14), channel: 'online', items: ['Peeling Toner (Keratolytic Solution)'], total: 350 },
      { ts: daysFromNow(-40), channel: 'online', items: ['Micro-Exfoliating Soap ×2'], total: 360 },
    ],
  },
  {
    id: 'c2', name: 'Bianca Cruz', phone: '+63 917 555 0202', qr: 'MBA-CUST-0002',
    origin: 'walk-in', points: 35, tags: ['sensitive skin'],
    history: [
      { ts: daysFromNow(-7), channel: 'store', items: ['Clarifying Brightening Soap'], total: 195 },
    ],
  },
  {
    id: 'c3', name: 'Carla Dizon', phone: '+63 917 555 0303', qr: 'MBA-CUST-0003',
    origin: 'app', points: 210, tags: [],
    history: [
      { ts: daysFromNow(-3), channel: 'online', items: ['Retinoid-Acid Night Active'], total: 480 },
    ],
  },
];

const couriers = [
  { id: 'jt', name: 'J&T Express', latePct: 4, failedPct: 1 },
  { id: 'lbc', name: 'LBC', latePct: 7, failedPct: 2 },
  { id: 'flash', name: 'Flash Express', latePct: 18, failedPct: 9 },
];

const promotions = [
  {
    id: 'promo1', name: 'Payday Flash Sale — Glow Starter Set', productId: 'p6',
    type: 'percent', value: 15, channel: 'online',
    reason: 'Online payday flash sale (Facebook live)', ends: daysFromNow(3), active: true,
  },
];

const events = [
  { id: 'e1', title: 'Free Skin Analysis Day', date: daysFromNow(10), location: 'Ms Beau Ave Store', description: 'Book a free 15-minute skin analysis with our consultants. Walk-ins welcome, app bookings prioritized.' },
  { id: 'e2', title: 'Retinoid Night Active — Launch Refresh', date: daysFromNow(21), location: 'Ms Beau Ave Store', description: 'New batch launch with in-store exclusive bundle pricing.' },
];

const bulletins = [
  { id: 'bl1', ts: daysFromNow(-2), title: 'Fresh Retinoid batch has arrived', body: 'A new batch of Retinoid-Acid Night Active is now in stock across both channels.' },
  { id: 'bl2', ts: daysFromNow(-5), title: 'BOPIS is here: order online, pick up in-store', body: 'Skip the shipping fee — order in the app and pick up at the counter, usually ready within 2 hours.' },
];

const bookings = [
  { id: 'bk1', customerId: 'c2', eventId: 'e1', slot: '10:30', status: 'confirmed' },
];

const ledger = [];   // immutable stock movement entries
const orders = [];   // online + POS orders
const shipments = [];
const activity = []; // Bitrix24-style activity stream

// Seed initial "receive" ledger entries so the ledger tells the whole story.
for (const b of batches) {
  for (const loc of LOCATIONS) {
    const qty = b.stock[loc.id];
    if (qty > 0) {
      ledger.push({
        id: nextId('led'), ts: new Date(now() - 30 * DAY).toISOString(),
        type: 'receive', productId: b.productId, batchId: b.id,
        locationId: loc.id, qty, ref: 'PO-INIT', note: `Received lot ${b.lot}`,
      });
    }
  }
}

function logActivity(kind, message) {
  activity.unshift({ id: nextId('act'), ts: new Date().toISOString(), kind, message });
  if (activity.length > 100) activity.pop();
}
logActivity('system', 'Demo instance started with seed data (in-memory, no database).');

// ---------------------------------------------------------------------------
// Core domain logic
// ---------------------------------------------------------------------------

const productById = (id) => products.find((p) => p.id === id);
const onHand = (batch) => batch.stock.shelf + batch.stock.warehouse;

function productOnHand(productId) {
  return batches
    .filter((b) => b.productId === productId)
    .reduce((acc, b) => ({ shelf: acc.shelf + b.stock.shelf, warehouse: acc.warehouse + b.stock.warehouse }),
      { shelf: 0, warehouse: 0 });
}

/**
 * FEFO allocation: allocate qty for a product from the earliest-expiring
 * batches across ALL locations. Returns allocations or throws if short.
 * (Single-threaded Node = the in-memory equivalent of a row-locked transaction:
 * two "simultaneous" checkouts are serialized, so the last unit sells once.)
 */
function fefoAllocate(productId, qty) {
  const candidates = batches
    .filter((b) => b.productId === productId && onHand(b) > 0)
    .sort((a, b) => a.expiry.localeCompare(b.expiry));

  const available = candidates.reduce((s, b) => s + onHand(b), 0);
  if (available < qty) {
    const err = new Error(`Out of stock: only ${available} unit(s) of ${productById(productId).name} left`);
    err.friendly = true;
    throw err;
  }

  const allocations = [];
  let remaining = qty;
  for (const b of candidates) {
    if (remaining <= 0) break;
    // Prefer the shelf first within a batch (clear physical stock before warehouse)
    for (const locId of ['shelf', 'warehouse']) {
      if (remaining <= 0) break;
      const take = Math.min(b.stock[locId], remaining);
      if (take > 0) {
        allocations.push({ batchId: b.id, lot: b.lot, expiry: b.expiry, locationId: locId, qty: take });
        remaining -= take;
      }
    }
  }
  return allocations;
}

function commitAllocations(productId, allocations, type, ref) {
  for (const a of allocations) {
    const batch = batches.find((b) => b.id === a.batchId);
    batch.stock[a.locationId] -= a.qty;
    ledger.push({
      id: nextId('led'), ts: new Date().toISOString(), type,
      productId, batchId: a.batchId, locationId: a.locationId,
      qty: -a.qty, ref, note: `FEFO pick lot ${a.lot} from ${a.locationId}`,
    });
  }
}

/** Expand bundles into component lines; plain products pass through. */
function expandItems(items) {
  const lines = [];
  for (const item of items) {
    const p = productById(item.productId);
    if (!p) throw new Error(`Unknown product ${item.productId}`);
    if (p.bundle) {
      for (const compId of p.bundle) lines.push({ productId: compId, qty: item.qty, viaBundle: p.id });
    } else {
      lines.push({ productId: p.id, qty: item.qty });
    }
  }
  return lines;
}

function activePromosFor(productId, channel) {
  const today = new Date().toISOString().slice(0, 10);
  return promotions.filter((pr) => pr.active && pr.ends >= today
    && (pr.channel === channel || pr.channel === 'both')
    && (pr.productId === productId || (pr.batchId && batches.find((b) => b.id === pr.batchId)?.productId === productId)));
}

function priceWithPromos(product, channel) {
  const promos = activePromosFor(product.id, channel);
  let price = product.price;
  const applied = [];
  for (const pr of promos) {
    const off = pr.type === 'percent' ? (product.price * pr.value) / 100 : pr.value;
    price -= off;
    applied.push({ id: pr.id, name: pr.name, off: peso(off), reason: pr.reason, ends: pr.ends });
  }
  return { price: peso(Math.max(0, price)), applied };
}

const POINTS_PER_PESO = 1 / 50; // 1 point per ₱50 spent — same rate on both channels

function checkout({ customerId, items, channel, fulfillment, payment, redeemPoints = 0, courierId }) {
  const customer = customers.find((c) => c.id === customerId || c.qr === customerId || c.phone === customerId) || null;
  const lines = [];
  let subtotal = 0;
  let discount = 0;

  // Price + allocate every line first (dry run), then commit — so a failed
  // line never leaves a half-written ledger.
  const expanded = [];
  for (const item of items) {
    const p = productById(item.productId);
    const { price, applied } = priceWithPromos(p, channel);
    subtotal += p.price * item.qty;
    discount += (p.price - price) * item.qty;
    const componentLines = expandItems([item]);
    const allocationsPerComponent = componentLines.map((cl) => ({
      ...cl, allocations: fefoAllocate(cl.productId, cl.qty),
    }));
    expanded.push({ item, product: p, unitPrice: price, applied, components: allocationsPerComponent });
  }

  const orderId = nextId('ord');
  for (const line of expanded) {
    for (const comp of line.components) {
      commitAllocations(comp.productId, comp.allocations, channel === 'store' ? 'sell-pos' : 'sell-online', orderId);
    }
    lines.push({
      productId: line.product.id, name: line.product.name, qty: line.item.qty,
      unitPrice: line.unitPrice, promosApplied: line.applied,
      pick: line.components.flatMap((c) => c.allocations.map((a) => ({
        product: productById(c.productId).name, lot: a.lot, expiry: a.expiry,
        location: LOCATIONS.find((l) => l.id === a.locationId).name, qty: a.qty,
      }))),
    });
  }

  let total = peso(subtotal - discount);
  let pointsRedeemed = 0;
  if (customer && redeemPoints > 0) {
    pointsRedeemed = Math.min(redeemPoints, customer.points, Math.floor(total)); // 1 pt = ₱1
    total = peso(total - pointsRedeemed);
    customer.points -= pointsRedeemed;
  }
  const pointsEarned = customer ? Math.floor(total * POINTS_PER_PESO) : 0;
  if (customer) {
    customer.points += pointsEarned;
    customer.history.unshift({
      ts: new Date().toISOString().slice(0, 10), channel: channel === 'store' ? 'store' : 'online',
      items: lines.map((l) => `${l.name}${l.qty > 1 ? ' ×' + l.qty : ''}`), total,
    });
  }

  const order = {
    id: orderId, ts: new Date().toISOString(), channel,
    customerId: customer ? customer.id : null,
    customerName: customer ? customer.name : 'Guest',
    lines, subtotal: peso(subtotal), discount: peso(discount),
    pointsRedeemed, pointsEarned, total,
    payment: payment || (channel === 'store' ? 'cash' : 'cod'),
    fulfillment: channel === 'store' ? 'counter' : (fulfillment || 'courier'),
    status: channel === 'store' ? 'completed' : 'pending',
    statusHistory: [{ status: channel === 'store' ? 'completed' : 'pending', ts: new Date().toISOString() }],
  };

  if (order.channel !== 'store' && order.fulfillment === 'courier') {
    const courier = couriers.find((c) => c.id === courierId) || couriers[0];
    const trackingNo = `MBA${String(Math.floor(1e9 + (idCounter * 7919) % 9e9))}`;
    const shipment = {
      id: nextId('shp'), orderId, courier: courier.name, trackingNo,
      trackingLink: `/track/${trackingNo}`,
      timeline: [{ status: 'packed', ts: null }, { status: 'handed to courier', ts: null },
        { status: 'in transit', ts: null }, { status: 'out for delivery', ts: null }, { status: 'delivered', ts: null }],
    };
    shipments.push(shipment);
    order.shipmentId = shipment.id;
    order.trackingNo = shipment.trackingNo;
    order.trackingLink = shipment.trackingLink;
  }

  orders.unshift(order);
  logActivity('order', `${channel === 'store' ? 'POS sale' : 'Online order'} ${orderId} — ${order.customerName} — ₱${total}${order.fulfillment === 'bopis' ? ' (BOPIS)' : ''}`);

  // Low-stock alert check (reorder point: 15 units total)
  for (const line of lines) {
    const oh = productOnHand(line.productId);
    if (oh.shelf + oh.warehouse <= 15) {
      logActivity('low-stock', `Low stock: ${line.name} down to ${oh.shelf + oh.warehouse} units — reorder suggested`);
    }
  }
  return order;
}

const ORDER_FLOW = {
  bopis: ['pending', 'confirmed', 'picking', 'packed', 'ready-for-pickup', 'completed'],
  courier: ['pending', 'confirmed', 'picking', 'packed', 'shipped', 'completed'],
};

function advanceOrder(orderId) {
  const order = orders.find((o) => o.id === orderId);
  if (!order) throw new Error('Order not found');
  const flow = ORDER_FLOW[order.fulfillment] || ORDER_FLOW.courier;
  const idx = flow.indexOf(order.status);
  if (idx < 0 || idx === flow.length - 1) return order;
  order.status = flow[idx + 1];
  order.statusHistory.push({ status: order.status, ts: new Date().toISOString() });

  if (order.shipmentId) {
    const shipment = shipments.find((s) => s.id === order.shipmentId);
    const shipIdx = { packed: 0, shipped: 2, completed: 4 }[order.status];
    if (shipIdx !== undefined) {
      for (let i = 0; i <= shipIdx; i++) if (!shipment.timeline[i].ts) shipment.timeline[i].ts = new Date().toISOString();
    }
  }
  if (order.status === 'ready-for-pickup') {
    logActivity('bopis', `Order ${order.id} ready for pickup — ${order.customerName} notified (app push + SMS)`);
  } else {
    logActivity('order', `Order ${order.id} → ${order.status}`);
  }
  return order;
}

function nearExpiry() {
  const today = new Date();
  return batches
    .filter((b) => onHand(b) > 0)
    .map((b) => {
      const days = Math.round((new Date(b.expiry) - today) / DAY);
      return { ...b, product: productById(b.productId).name, price: productById(b.productId).price,
        onHand: onHand(b), daysToExpiry: days, valueAtRisk: peso(onHand(b) * b.cost),
        window: days <= 30 ? 30 : days <= 60 ? 60 : days <= 90 ? 90 : null };
    })
    .filter((b) => b.window !== null)
    .sort((a, b) => a.daysToExpiry - b.daysToExpiry);
}

// ---------------------------------------------------------------------------
// HTTP plumbing
// ---------------------------------------------------------------------------

function sendJson(res, status, data) {
  const body = JSON.stringify(data, null, 2);
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(body);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', (c) => { data += c; if (data.length > 1e6) req.destroy(); });
    req.on('end', () => { try { resolve(data ? JSON.parse(data) : {}); } catch (e) { reject(e); } });
    req.on('error', reject);
  });
}

const MIME = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript', '.svg': 'image/svg+xml', '.png': 'image/png' };

const routes = {
  'GET /api/products': () => products.map((p) => ({
    ...p,
    onHand: p.bundle ? null : productOnHand(p.id),
    storePrice: priceWithPromos(p, 'store'),
    onlinePrice: priceWithPromos(p, 'online'),
  })),

  'GET /api/inventory': () => ({
    locations: LOCATIONS,
    batches: batches.map((b) => ({ ...b, product: productById(b.productId).name, onHand: onHand(b) })),
    byProduct: products.filter((p) => !p.bundle).map((p) => ({ id: p.id, name: p.name, ...productOnHand(p.id) })),
  }),

  'GET /api/ledger': () => [...ledger].reverse().slice(0, 50),

  'GET /api/near-expiry': () => nearExpiry(),

  'POST /api/promos/flash-sale': async (req) => {
    const { batchId, percent = 20, channel = 'online' } = await readBody(req);
    const batch = batches.find((b) => b.id === batchId);
    if (!batch) throw new Error('Batch not found');
    const p = productById(batch.productId);
    const promo = {
      id: nextId('promo'), name: `${channel === 'online' ? 'Flash Sale' : 'In-Store Promo'} — ${p.name} (lot ${batch.lot})`,
      productId: p.id, batchId, type: 'percent', value: percent, channel,
      reason: `Near-expiry clearance: lot ${batch.lot} expires ${batch.expiry}`,
      ends: batch.expiry, active: true,
    };
    promotions.push(promo);
    logActivity('promo', `Created ${promo.name} (−${percent}%) from near-expiry radar`);
    return promo;
  },

  'GET /api/promos': () => promotions.map((pr) => ({ ...pr, product: productById(pr.productId)?.name })),

  'GET /api/customers': () => customers,

  'GET /api/couriers': () => couriers,

  'GET /api/orders': () => orders,

  'GET /api/activity': () => activity,

  'GET /api/events': () => events,
  'GET /api/bulletins': () => bulletins,
  'GET /api/bookings': () => bookings.map((b) => ({
    ...b,
    customer: customers.find((c) => c.id === b.customerId)?.name,
    event: events.find((e) => e.id === b.eventId)?.title,
  })),

  'POST /api/bulletins': async (req) => {
    const { title, body } = await readBody(req);
    if (!title) throw new Error('Title required');
    const bulletin = { id: nextId('bl'), ts: new Date().toISOString().slice(0, 10), title, body: body || '' };
    bulletins.unshift(bulletin);
    logActivity('cms', `Bulletin published: "${title}" — live on landing page & app feed`);
    return bulletin;
  },

  'POST /api/pos/checkout': async (req) => {
    const body = await readBody(req);
    return checkout({ ...body, channel: 'store' });
  },

  'POST /api/orders': async (req) => {
    const body = await readBody(req);
    return checkout({ ...body, channel: 'online' });
  },

  'POST /api/orders/advance': async (req) => {
    const { orderId } = await readBody(req);
    return advanceOrder(orderId);
  },

  // Acceptance criterion 1: two "simultaneous" checkouts of the last unit —
  // exactly one succeeds, the other gets a friendly out-of-stock response.
  'POST /api/demo/race': async (req) => {
    const { productId = 'p5' } = await readBody(req);
    const oh = productOnHand(productId);
    const remaining = oh.shelf + oh.warehouse;
    const results = [];
    for (const buyer of [{ who: 'POS counter (walk-in)', channel: 'store' }, { who: 'Online storefront', channel: 'online' }]) {
      try {
        const order = checkout({ items: [{ productId, qty: remaining }], channel: buyer.channel, fulfillment: 'bopis' });
        results.push({ buyer: buyer.who, ok: true, orderId: order.id, qty: remaining });
      } catch (e) {
        results.push({ buyer: buyer.who, ok: false, message: e.message });
      }
    }
    return { unitsAtStake: remaining, results };
  },

  'GET /api/dashboard': () => {
    const sales = orders.filter((o) => o.status !== 'cancelled');
    const byChannel = { store: 0, online: 0 };
    for (const o of sales) byChannel[o.channel === 'store' ? 'store' : 'online'] += o.total;
    const ne = nearExpiry();
    return {
      salesToday: peso(byChannel.store + byChannel.online),
      byChannel,
      orderCount: sales.length,
      nearExpiryValueAtRisk: peso(ne.reduce((s, b) => s + b.valueAtRisk, 0)),
      nearExpiryBatches: ne.length,
      lowStock: products.filter((p) => !p.bundle).map((p) => ({ name: p.name, ...productOnHand(p.id) }))
        .filter((p) => p.shelf + p.warehouse <= 15),
      loyaltyMembers: customers.length,
      pointsOutstanding: customers.reduce((s, c) => s + c.points, 0),
      couriers,
    };
  },
};

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const key = `${req.method} ${url.pathname}`;

  try {
    // API routes
    if (routes[key]) {
      const result = await routes[key](req, url);
      return sendJson(res, 200, result);
    }

    // Customer lookup by id / QR / phone
    const custMatch = url.pathname.match(/^\/api\/customers\/(.+)$/);
    if (req.method === 'GET' && custMatch) {
      const q = decodeURIComponent(custMatch[1]);
      const c = customers.find((x) => x.id === q || x.qr === q || x.phone.replace(/\s/g, '').endsWith(q.replace(/\s/g, '')));
      if (!c) return sendJson(res, 404, { error: 'Customer not found' });
      // Complementary-product suggestion from omnichannel history (spec §5.4)
      const bought = c.history.flatMap((h) => h.items).join(' ');
      const suggestions = [];
      if (/Toner/i.test(bought) && !/Day Cream/i.test(bought)) suggestions.push('Day Cream Shield (Photoprotectant) — pairs with Peeling Toner: actives need daytime sun protection');
      if (/Night Active/i.test(bought) && !/Day Cream/i.test(bought)) suggestions.push('Day Cream Shield (Photoprotectant) — essential SPF partner for retinoid users');
      if (/Soap/i.test(bought) && !/Toner/i.test(bought)) suggestions.push('Peeling Toner — the natural next step after exfoliating soap');
      if (!suggestions.length) suggestions.push('Glow Starter Set — complete routine upgrade');
      return sendJson(res, 200, { ...c, suggestions });
    }

    // Customer-visible tracking page (spec §5.5)
    const trackMatch = url.pathname.match(/^\/track\/(.+)$/);
    if (req.method === 'GET' && trackMatch) {
      const s = shipments.find((x) => x.trackingNo === trackMatch[1]);
      if (!s) { res.writeHead(404, { 'Content-Type': 'text/html' }); return res.end('<h1>Tracking number not found</h1>'); }
      const order = orders.find((o) => o.id === s.orderId);
      const rows = s.timeline.map((t) => `<li class="${t.ts ? 'done' : ''}"><b>${t.status}</b>${t.ts ? ' — ' + new Date(t.ts).toLocaleString() : ''}</li>`).join('');
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      return res.end(`<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Track ${s.trackingNo} — Ms Beau Ave</title>
<style>body{font-family:Inter,system-ui,sans-serif;background:#F6E7E7;color:#3E2C2D;max-width:480px;margin:40px auto;padding:0 16px}
.card{background:#FAF6F4;border:1px solid #D8A7A7;border-radius:12px;padding:24px}h1{color:#9E5B5D;font-size:1.3rem}
ol{list-style:none;padding:0}li{padding:10px 0 10px 28px;border-left:3px solid #E8C4C4;margin-left:8px;position:relative;color:#a99}
li.done{color:#3E2C2D;border-left-color:#C08081}li.done:before{content:"✓";position:absolute;left:8px;color:#5F8D6B}</style>
<div class="card"><h1>📦 ${s.courier} — ${s.trackingNo}</h1>
<p>Order <b>${s.orderId}</b> for <b>${order.customerName}</b> · ₱${order.total}</p><ol>${rows}</ol>
<p style="color:#9E5B5D">Ms Beau Ave — thank you for your order! 🌸</p></div>`);
    }

    // Static files
    let filePath = url.pathname === '/' ? '/index.html' : url.pathname;
    filePath = path.normalize(filePath).replace(/^(\.\.[/\\])+/, '');
    const full = path.join(PUBLIC_DIR, filePath);
    if (full.startsWith(PUBLIC_DIR) && fs.existsSync(full) && fs.statSync(full).isFile()) {
      res.writeHead(200, { 'Content-Type': MIME[path.extname(full)] || 'application/octet-stream' });
      return res.end(fs.readFileSync(full));
    }

    sendJson(res, 404, { error: 'Not found' });
  } catch (e) {
    sendJson(res, e.friendly ? 409 : 400, { error: e.message });
  }
});

server.listen(PORT, () => {
  console.log(`\n  🌸 Ms Beau Ave demo running:`);
  console.log(`     Back office : http://localhost:${PORT}/`);
  console.log(`     Landing page: http://localhost:${PORT}/landing.html\n`);
});

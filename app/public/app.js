// MS BEAU AVE — unified operations app (Spec-MVP.md screens §7)
// Vanilla SPA: role-based tabs, short-polling refresh, plain-language errors.

const $ = (sel, el = document) => el.querySelector(sel);
const app = $('#app');
let USER = null;
let TAB = null;
let pollTimer = null;

// ---------- helpers ----------
const peso = (v) => '₱' + Number(v || 0).toLocaleString('en-PH', {
  minimumFractionDigits: 2, maximumFractionDigits: 2,
});
const num = (v) => Number(v || 0).toLocaleString('en-PH');
// The business runs on Manila time wherever the browser happens to be, so
// receipt numbers, cut-offs and due dates all agree.
const TZ = 'Asia/Manila';
const dt = (v) => v ? new Date(v).toLocaleString('en-PH',
  { dateStyle: 'medium', timeStyle: 'short', timeZone: TZ }) : '—';
const day = (v) => v ? new Date(v).toLocaleDateString('en-PH',
  { dateStyle: 'medium', timeZone: TZ }) : '—';
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[c]));

// Where the app is mounted, injected by the server into index.html. Empty at
// the site root; "/ops" when it runs beside another site on the same domain.
const BASE = window.__BASE__ || '';
const LOGO = `${BASE}/logo.jpg`;

async function api(path, opts = {}) {
  const res = await fetch(BASE + path, {
    headers: { 'Content-Type': 'application/json' },
    ...opts,
    body: opts.body ? JSON.stringify(opts.body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || `Request failed (${res.status})`);
  return data;
}
const get = (p) => api(p);
const post = (p, body) => api(p, { method: 'POST', body });
const put = (p, body) => api(p, { method: 'PUT', body });

function toast(msg, kind = '') {
  const t = document.createElement('div');
  t.className = `toast ${kind}`;
  t.textContent = msg;
  $('#toast').appendChild(t);
  setTimeout(() => t.remove(), kind === 'err' ? 6000 : 3500);
}
const oops = (e) => toast(e.message, 'err');

function modal(html) {
  closeModal();
  const bg = document.createElement('div');
  bg.className = 'modal-bg';
  bg.id = 'modal';
  bg.innerHTML = `<div class="modal">${html}</div>`;
  bg.addEventListener('click', (e) => { if (e.target === bg) closeModal(); });
  document.body.appendChild(bg);
  return bg;
}
const closeModal = () => $('#modal')?.remove();

// Delivery is a confirmation on top of dispatch, not a separate stock state.
const statusBadge = (o) => {
  if (o.delivered_at) return '<span class="badge green">Delivered</span>';
  const map = {
    PLACED: (o.invoice_status === 'OPEN' && o.tier === 1)
      ? ['Awaiting payment', 'amber'] : ['Committed', 'pink'],
    PICKING: ['Picking', 'amber'],
    FULFILLED: ['Dispatched', 'green'],
    CANCELLED: ['Cancelled', 'gray'],
  };
  const [label, color] = map[o.status] || [o.status, 'gray'];
  return `<span class="badge ${color}">${label}</span>`;
};
const tierBadge = (t) => `<span class="badge ${t === 3 ? 'green' : t === 2 ? 'pink' : 'gray'}">Tier ${t}</span>`;

// ---------- boot / auth ----------
async function boot() {
  try {
    const { user } = await get('/api/me');
    USER = user;
    if (user) renderShell(); else renderLogin();
  } catch {
    renderLogin();
  }
}

function renderLogin() {
  clearInterval(pollTimer);
  app.innerHTML = `
  <div class="login-wrap"><form class="login-card" id="loginForm">
    <img src="${LOGO}" alt="MS BEAU AVE" onerror="this.style.display='none'">
    <h1>MS BEAU AVE</h1>
    <div class="tag">Beauty &amp; skincare distribution — one system, one stock truth</div>
    <label>Username</label><input type="text" id="u" autocomplete="username" autofocus>
    <label>Password</label><input type="password" id="p" autocomplete="current-password">
    <div class="mt"><button class="btn" style="width:100%">Sign in</button></div>
  </form></div>`;
  $('#loginForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    try {
      const { user } = await post('/api/login', { username: $('#u').value, password: $('#p').value });
      USER = user;
      renderShell();
    } catch (err) { oops(err); }
  });
}

// ---------- shell ----------
const TABS = {
  OWNER_ADMIN: [
    ['dashboard', '🏠', 'Dashboard'], ['products', '🧴', 'Products & Batches'],
    ['receive', '📦', 'Receive Stock'], ['orders', '🚚', 'B2B Orders'],
    ['resellers', '🤝', 'Resellers'], ['returns', '↩️', 'Returns Queue'],
    ['rop', '📈', 'Reorder Points'], ['reports', '📊', 'Reports'],
    ['transfers', '🔀', 'Transfers & Counts'], ['users', '👥', 'Users'],
  ],
  WAREHOUSE: [
    ['pick', '📋', 'Pick & Fulfill'], ['receive', '📦', 'Receive Stock'],
    ['transfers', '🔀', 'Transfers & Counts'], ['restock', '🛎️', 'Restock Tasks'],
    ['rop', '📈', 'Reorder Points'],
  ],
  RETAIL_CASHIER: [
    ['pos', '🛍️', 'Point of Sale'], ['posreturns', '↩️', 'Returns'],
    ['eod', '🌙', 'End of Day'],
  ],
  RESELLER: [
    ['catalog', '🛒', 'Catalog & Cart'], ['myorders', '🚚', 'My Orders'],
    ['credit', '💳', 'Invoices & Credit'],
  ],
};

function renderShell() {
  const tabs = TABS[USER.role] || [];
  TAB = TAB && tabs.some(([id]) => id === TAB) ? TAB : tabs[0][0];
  app.innerHTML = `
  <div class="shell">
    <nav class="sidebar">
      <div class="brand"><img src="${LOGO}" onerror="this.style.display='none'"> MS BEAU AVE</div>
      ${tabs.map(([id, icon, label]) =>
        `<button class="nav-btn ${id === TAB ? 'active' : ''}" data-tab="${id}">${icon} ${label}</button>`).join('')}
      <div class="spacer"></div>
      <div class="who">${esc(USER.display)}<br><span class="badge pink">${roleLabel(USER.role)}</span></div>
      <button class="nav-btn" id="logout">🚪 Sign out</button>
    </nav>
    <main class="main" id="main"></main>
  </div>`;
  app.querySelectorAll('[data-tab]').forEach((b) =>
    b.addEventListener('click', () => { TAB = b.dataset.tab; renderShell(); }));
  $('#logout').addEventListener('click', async () => { await post('/api/logout'); USER = null; renderLogin(); });
  renderTab();
}

const roleLabel = (r) => ({
  OWNER_ADMIN: 'Admin', WAREHOUSE: 'Warehouse', RETAIL_CASHIER: 'Cashier', RESELLER: 'Reseller',
}[r] || r);

const VIEWS = {};
function renderTab() {
  clearInterval(pollTimer);
  closeModal();
  const view = VIEWS[TAB];
  if (view) view($('#main')).catch(oops);
}
function poll(fn, ms = 7000) {
  clearInterval(pollTimer);
  pollTimer = setInterval(() => { if (!$('#modal')) fn().catch(() => {}); }, ms);
}

// =========================================================================
// ADMIN — Dashboard
// =========================================================================
VIEWS.dashboard = async (main) => {
  const load = async () => {
    const d = await get('/api/dashboard');
    main.innerHTML = `
    <div class="topline"><h2>Dashboard</h2><span class="sub">Live — refreshes automatically</span></div>
    <div class="cards">
      <div class="card good"><div class="kpi">${peso(d.today_retail.total)}</div>
        <div class="kpi-label">Today's retail sales (${d.today_retail.sales} sale${d.today_retail.sales == 1 ? '' : 's'})</div></div>
      <div class="card"><div class="kpi">${d.pending_b2b}</div><div class="kpi-label">Pending B2B orders</div></div>
      <div class="card ${d.reorder_alerts.length ? 'danger' : 'good'}"><div class="kpi">${d.reorder_alerts.length}</div>
        <div class="kpi-label">ORDER NOW alerts</div></div>
      <div class="card ${d.overdue_invoices.length ? 'danger' : 'good'}"><div class="kpi">${d.overdue_invoices.length}</div>
        <div class="kpi-label">Overdue invoices</div></div>
      <div class="card ${d.aging_stock.length ? 'alert' : 'good'}"><div class="kpi">${d.aging_stock.length}</div>
        <div class="kpi-label">Aging batches (&lt;6 months)</div></div>
      <div class="card ${d.shelf_alerts.length ? 'alert' : 'good'}"><div class="kpi">${d.shelf_alerts.length}</div>
        <div class="kpi-label">Low retail shelf</div></div>
    </div>
    ${d.ar_exposure.length ? `<div class="warn-banner">⚠️ AR exposure: ${d.ar_exposure.map((e) =>
      `<b>${esc(e.name)}</b> holds ${(e.share * 100).toFixed(0)}% of receivables (${peso(e.outstanding)})`).join('; ')}</div>` : ''}
    ${d.cashier_variance.length ? `<div class="warn-banner">⚠️ Repeat cash variances: ${d.cashier_variance.map((v) =>
      `<b>${esc(v.cashier)}</b> — ${v.flagged_drops_90d} flagged drops, net ${peso(v.net_variance_90d)}`).join('; ')}</div>` : ''}
    <div class="two-col">
      <div class="panel"><h3>🔥 ORDER NOW</h3>${d.reorder_alerts.length ? `<div class="tbl-wrap"><table>
        <tr><th>Product</th><th class="num">Sellable</th><th class="num">ROP</th><th class="num">Suggested order</th></tr>
        ${d.reorder_alerts.map((a) => `<tr><td>${esc(a.name)}</td><td class="num">${num(a.sellable_stock)}</td>
          <td class="num">${num(a.rop)}</td><td class="num"><b>${num(Math.round(a.suggested_order_qty))}</b></td></tr>`).join('')}
        </table></div>` : '<div class="empty">Nothing at or below its reorder point 🌸</div>'}</div>
      <div class="panel"><h3>💸 Overdue invoices</h3>${d.overdue_invoices.length ? `<div class="tbl-wrap"><table>
        <tr><th>Reseller</th><th>Due</th><th class="num">Days late</th><th class="num">Balance</th></tr>
        ${d.overdue_invoices.map((i) => `<tr><td>${esc(i.name)}</td><td>${day(i.due_date)}</td>
          <td class="num">${i.days_overdue}</td><td class="num">${peso(i.balance)}</td></tr>`).join('')}
        </table></div>` : '<div class="empty">Everyone is paid up 🌸</div>'}</div>
      <div class="panel"><h3>⏳ Aging stock — clearance queue</h3>${d.aging_stock.length ? `<div class="tbl-wrap"><table>
        <tr><th>Product</th><th>Batch</th><th>Expiry</th><th class="num">Days left</th><th class="num">Qty</th><th class="num">₱ at risk</th></tr>
        ${d.aging_stock.map((a) => `<tr><td>${esc(a.name)}</td><td>${esc(a.batch_number)}</td><td>${day(a.expiry_date)}</td>
          <td class="num">${a.days_to_expiry}</td><td class="num">${num(a.qty_at_risk)}</td><td class="num">${peso(a.value_at_risk)}</td></tr>`).join('')}
        </table></div><div class="mut mt">Candidates for bundles, flash discounts or tester conversion.</div>`
        : '<div class="empty">No batches inside the 6-month window 🌸</div>'}</div>
      <div class="panel"><h3>🛎️ Storefront restock tasks</h3>${d.restock_requests.length ? `<div class="tbl-wrap"><table>
        <tr><th>Product</th><th>Note</th><th>Raised</th></tr>
        ${d.restock_requests.map((r) => `<tr><td>${esc(r.name)}</td><td class="mut">${esc(r.note || '')}</td><td>${dt(r.ts)}</td></tr>`).join('')}
        </table></div>` : '<div class="empty">Shelf is stocked 🌸</div>'}
        ${d.expired_stock.length ? `<div class="warn-banner mt">☠️ ${d.expired_stock.length} expired batch line(s) need write-off — see Transfers &amp; Counts.</div>` : ''}
      </div>
    </div>`;
  };
  await load();
  poll(load, 10000);
};

// =========================================================================
// Products & Batches (admin) / stock views
// =========================================================================
VIEWS.products = async (main) => {
  let q = '';
  const load = async () => {
    const rows = await get(`/api/products?q=${encodeURIComponent(q)}`);
    $('#prodTbl', main).innerHTML = rows.length ? `<table>
      <tr><th>SKU</th><th>Product</th><th>Brand</th><th class="num">B2B</th><th class="num">Shelf</th>
      <th class="num">Safety</th><th class="num">Committed</th><th class="num">Wholesale</th><th class="num">SRP</th>
      <th class="num">Retail</th><th>Split</th><th></th></tr>
      ${rows.map((p) => `<tr>
        <td class="mut">${esc(p.sku)}</td>
        <td><b>${esc(p.name)}</b>${p.active ? '' : ' <span class="badge gray">inactive</span>'}
          ${p.abc_class ? ` <span class="badge pink">${p.abc_class}</span>` : ''}</td>
        <td>${esc(p.brand || '')}</td>
        <td class="num">${num(p.b2b_avail)}</td><td class="num">${num(p.retail_avail)}</td>
        <td class="num">${num(p.safety_avail)}</td><td class="num">${num(p.b2b_committed)}</td>
        <td class="num">${peso(p.wholesale_price)}</td><td class="num">${peso(p.srp)}</td><td class="num">${peso(p.retail_price)}</td>
        <td class="mut">${Math.round(p.alloc_b2b * 100)}/${Math.round(p.alloc_retail * 100)}/${Math.round(p.alloc_safety * 100)}</td>
        <td><button class="btn small secondary" data-edit="${esc(p.sku)}">Edit</button>
            <button class="btn small ghost" data-batches="${esc(p.sku)}">Batches</button></td>
      </tr>`).join('')}</table>` : '<div class="empty">No products match your search.</div>';
    main.querySelectorAll('[data-edit]').forEach((b) =>
      b.addEventListener('click', () => editProduct(rows.find((p) => p.sku === b.dataset.edit))));
    main.querySelectorAll('[data-batches]').forEach((b) =>
      b.addEventListener('click', () => showBatches(b.dataset.batches, rows.find((p) => p.sku === b.dataset.batches))));
  };
  main.innerHTML = `
    <div class="topline"><h2>Products &amp; Batches</h2></div>
    <div class="searchbar">
      <input type="text" id="q" placeholder="Search SKU, name or brand…">
      <button class="btn" id="newProd">＋ New product</button>
    </div>
    <div class="panel tbl-wrap" id="prodTbl"></div>`;
  $('#q', main).addEventListener('input', (e) => { q = e.target.value; load().catch(oops); });
  $('#newProd', main).addEventListener('click', () => editProduct(null));
  await load();
  poll(load);

  function editProduct(p) {
    const isNew = !p;
    modal(`
      <h3>${isNew ? 'New product' : `Edit ${esc(p.name)}`}</h3>
      <div class="frow">
        <div><label>SKU code</label><input id="m_sku" type="text" value="${esc(p?.sku || '')}" ${isNew ? '' : 'disabled'}></div>
        <div style="flex:2"><label>Name</label><input id="m_name" type="text" value="${esc(p?.name || '')}"></div>
      </div>
      <div class="frow">
        <div><label>Brand</label><input id="m_brand" type="text" value="${esc(p?.brand || '')}"></div>
        <div><label>Category</label><input id="m_cat" type="text" value="${esc(p?.category || '')}"></div>
      </div>
      <div class="frow">
        <div><label>Unit cost ₱</label><input id="m_cost" type="number" step="0.01" value="${p?.unit_cost || 0}"></div>
        <div><label>Wholesale ₱</label><input id="m_ws" type="number" step="0.01" value="${p?.wholesale_price || 0}"></div>
        <div><label>SRP ₱</label><input id="m_srp" type="number" step="0.01" value="${p?.srp || 0}"></div>
        <div><label>Retail ₱</label><input id="m_rp" type="number" step="0.01" value="${p?.retail_price || 0}"></div>
      </div>
      <div class="frow">
        <div><label>Shelf life (months)</label><input id="m_sl" type="number" value="${p?.shelf_life_months || 24}"></div>
        <div><label>Reseller floor (months)</label><input id="m_floor" type="number" value="${p?.reseller_floor_months ?? 12}"></div>
        <div><label>Shelf min qty</label><input id="m_min" type="number" value="${p?.retail_min_qty || 0}"></div>
      </div>
      <h3 class="mt">Allocation split on receiving</h3>
      <div class="mut">Must add up to 100. Default is 70 / 20 / 10.</div>
      <div class="frow">
        <div><label>B2B %</label><input id="m_ab" type="number" value="${Math.round((p?.alloc_b2b ?? 0.7) * 100)}"></div>
        <div><label>Retail %</label><input id="m_ar" type="number" value="${Math.round((p?.alloc_retail ?? 0.2) * 100)}"></div>
        <div><label>Safety %</label><input id="m_as" type="number" value="${Math.round((p?.alloc_safety ?? 0.1) * 100)}"></div>
      </div>
      <div class="mt right">
        ${isNew ? '' : `<button class="btn secondary" id="m_toggle">${p.active ? 'Deactivate' : 'Reactivate'}</button>`}
        <button class="btn" id="m_save">Save</button>
      </div>`);
    $('#m_save').addEventListener('click', async () => {
      const ab = Number($('#m_ab').value) / 100;
      const ar = Number($('#m_ar').value) / 100;
      const as_ = Number($('#m_as').value) / 100;
      if (Math.abs(ab + ar + as_ - 1) > 0.001) return toast('The allocation split must add up to 100%.', 'err');
      const body = {
        name: $('#m_name').value, brand: $('#m_brand').value, category: $('#m_cat').value,
        unit_cost: +$('#m_cost').value, wholesale_price: +$('#m_ws').value,
        srp: +$('#m_srp').value, retail_price: +$('#m_rp').value,
        shelf_life_months: +$('#m_sl').value, reseller_floor_months: +$('#m_floor').value,
        retail_min_qty: +$('#m_min').value, alloc_b2b: ab, alloc_retail: ar, alloc_safety: as_,
      };
      try {
        if (isNew) await post('/api/products', { ...body, sku: $('#m_sku').value.trim() });
        else await put(`/api/products/${encodeURIComponent(p.sku)}`, body);
        toast('Saved 🌸', 'ok'); closeModal(); load();
      } catch (e) { oops(e); }
    });
    $('#m_toggle')?.addEventListener('click', async () => {
      try {
        await put(`/api/products/${encodeURIComponent(p.sku)}`, { active: !p.active });
        toast('Saved', 'ok'); closeModal(); load();
      } catch (e) { oops(e); }
    });
  }
};

async function showBatches(sku, p) {
  const rows = await get(`/api/products/${encodeURIComponent(sku)}/batches`);
  modal(`
    <h3>${esc(p?.name || sku)} — batches</h3>
    ${rows.length ? `<div class="tbl-wrap"><table>
      <tr><th>Batch</th><th>Expiry</th><th class="num">Days left</th><th>Flags</th><th class="num">B2B</th>
      <th class="num">Shelf</th><th class="num">Safety</th></tr>
      ${rows.map((b) => {
        const g = (pool) => b.pools[pool] ? `${b.pools[pool].on_hand - b.pools[pool].committed}` : '0';
        return `<tr><td>${esc(b.batch_number)}</td><td>${day(b.expiry_date)}</td>
        <td class="num">${b.days_to_expiry}</td>
        <td>${b.expired ? '<span class="badge red">expired</span>'
          : b.aging ? '<span class="badge amber">aging</span>' : ''}
          ${!b.expired && b.below_floor ? '<span class="badge amber">below B2B floor</span>' : ''}</td>
        <td class="num">${g('B2B_POOL')}</td><td class="num">${g('RETAIL_SHELF')}</td><td class="num">${g('SAFETY')}</td></tr>`;
      }).join('')}</table></div>
    <div class="mut mt">Figures are uncommitted units. "Below B2B floor" batches are excluded from reseller orders but retail may still sell them.</div>`
      : '<div class="empty">No batches received yet.</div>'}`);
}

// =========================================================================
// Receive stock (admin + warehouse)
// =========================================================================
VIEWS.receive = async (main) => {
  main.innerHTML = `
    <div class="topline"><h2>Receive Stock</h2>
      <span class="sub">Auto-splits into B2B / Retail / Safety per the product's allocation</span></div>
    <div class="panel">
      <div class="frow">
        <div style="flex:2"><label>SKU (type or scan)</label><input type="text" id="r_sku" list="skuList" placeholder="e.g. SER-001"></div>
        <div><label>Batch number</label><input type="text" id="r_batch"></div>
        <div><label>Expiry date</label><input type="date" id="r_exp"></div>
        <div><label>Quantity</label><input type="number" id="r_qty" min="1"></div>
        <div><button class="btn" id="r_go">Receive</button></div>
      </div>
      <datalist id="skuList"></datalist>
      <div id="r_result" class="mt"></div>
    </div>
    <div class="panel"><h3>Recent movements</h3><div class="tbl-wrap" id="r_ledger"></div></div>`;
  const fillSkus = async () => {
    const rows = await get('/api/products?q=');
    $('#skuList', main).innerHTML = rows.map((p) =>
      `<option value="${esc(p.sku)}">${esc(p.name)}</option>`).join('');
  };
  const loadLedger = async () => {
    const rows = await get('/api/reports/ledger?limit=25');
    $('#r_ledger', main).innerHTML = rows.length ? `<table>
      <tr><th>When</th><th>Product</th><th>Batch</th><th>Move</th><th class="num">Qty</th><th>Reason</th><th>By</th></tr>
      ${rows.map((m) => `<tr><td>${dt(m.ts)}</td><td>${esc(m.name)}</td><td class="mut">${esc(m.batch_number)}</td>
        <td>${esc(m.from_pool || '·')} → ${esc(m.to_pool || 'out')}</td><td class="num">${num(m.qty)}</td>
        <td class="mut">${esc(m.reason)}</td><td class="mut">${esc(m.actor)}</td></tr>`).join('')}</table>`
      : '<div class="empty">No stock movements yet.</div>';
  };
  $('#r_go', main).addEventListener('click', async () => {
    try {
      const r = await post('/api/receive', {
        sku: $('#r_sku', main).value.trim(), batch_number: $('#r_batch', main).value.trim(),
        expiry_date: $('#r_exp', main).value, qty: +$('#r_qty', main).value,
      });
      $('#r_result', main).innerHTML = `<div class="info-banner" style="background:#e7eee3;color:#5c7052">
        ✅ Batch received and allocated: ${r.allocation.map((a) =>
          `<b>${a.pool.replace('_', ' ')}</b> ${a.qty_on_hand}`).join(' · ')}</div>`;
      $('#r_batch', main).value = ''; $('#r_qty', main).value = '';
      loadLedger();
    } catch (e) { oops(e); }
  });
  await Promise.all([fillSkus(), loadLedger()]);
  poll(loadLedger, 10000);
};

// =========================================================================
// B2B Orders pipeline (admin) & Pick/Fulfill (warehouse)
// =========================================================================
async function orderDetailModal(id, reload) {
  const o = await get(`/api/orders/${id}`);
  const canAct = ['OWNER_ADMIN', 'WAREHOUSE'].includes(USER.role);
  modal(`
    <h3>Order #${o.id} — ${esc(o.reseller_name || 'retail')}</h3>
    <div class="pill-row">${statusBadge(o)} ${o.tier ? tierBadge(o.tier) : ''}
      ${o.invoice_id ? `<span class="badge ${o.invoice_status === 'PAID' ? 'green' : 'amber'}">
        Invoice ${o.invoice_status} · due ${day(o.due_date)}</span>` : ''}</div>
    <h3>FEFO pick list</h3>
    <div class="tbl-wrap"><table>
      <tr><th>Pick order</th><th>Product</th><th>Batch</th><th>Expiry</th><th class="num">Qty</th><th class="num">Price</th></tr>
      ${o.lines.map((l, i) => `<tr><td>${i + 1}</td><td>${esc(l.name)}</td><td><b>${esc(l.batch_number)}</b></td>
        <td>${day(l.expiry_date)}</td><td class="num">${num(l.qty)}</td><td class="num">${peso(l.unit_price)}</td></tr>`).join('')}
      <tr><td colspan="4"></td><td class="num"><b>Total</b></td><td class="num"><b>${peso(o.total)}</b></td></tr>
    </table></div>
    <div class="mt right">
      <button class="btn secondary" onclick="window.print()">🖨 Print packing slip</button>
      ${canAct && o.status === 'PLACED' ? `<button class="btn" id="od_pick">Start picking</button>` : ''}
      ${canAct && ['PLACED', 'PICKING'].includes(o.status) ? `
        <button class="btn good" id="od_ship">Dispatch</button>
        <button class="btn danger" id="od_cancel">Cancel order</button>` : ''}
      ${canAct && o.status === 'FULFILLED' && !o.delivered_at
        ? `<button class="btn good" id="od_deliver">Mark delivered</button>` : ''}
    </div>`);
  const act = (btn, path, okMsg) => $(btn)?.addEventListener('click', async () => {
    try { await post(`/api/orders/${id}/${path}`); toast(okMsg, 'ok'); closeModal(); reload(); }
    catch (e) { oops(e); }
  });
  act('#od_pick', 'picking', 'Picking started');
  act('#od_ship', 'fulfill', 'Dispatched — stock deducted');
  act('#od_cancel', 'cancel', 'Cancelled — stock released');
  act('#od_deliver', 'deliver', 'Delivered 🌸');
}

async function ordersView(main, title, sub) {
  let status = '';
  const load = async () => {
    const rows = await get(`/api/orders?status=${status}`);
    $('#ordTbl', main).innerHTML = rows.length ? `<table>
      <tr><th>#</th><th>Reseller</th><th>Status</th><th>Invoice</th><th class="num">Total</th><th>Placed</th><th></th></tr>
      ${rows.map((o) => `<tr><td>${o.id}</td><td><b>${esc(o.reseller_name || '')}</b> ${o.tier ? tierBadge(o.tier) : ''}</td>
        <td>${statusBadge(o)}</td>
        <td>${o.invoice_id ? `<span class="badge ${o.invoice_status === 'PAID' ? 'green'
          : (new Date(o.due_date) < new Date() && o.invoice_status === 'OPEN') ? 'red' : 'amber'}">
          ${o.invoice_status !== 'OPEN' ? o.invoice_status
            : o.invoice_balance == null
              // Warehouse pickers are shown payment state, never the amount.
              ? `unpaid · due ${day(o.due_date)}`
              : `${peso(o.invoice_balance)} due ${day(o.due_date)}`}</span>` : '—'}</td>
        <td class="num">${peso(o.total)}</td><td>${dt(o.created_at)}</td>
        <td><button class="btn small secondary" data-o="${o.id}">Open</button></td></tr>`).join('')}</table>`
      : '<div class="empty">No orders here yet.</div>';
    main.querySelectorAll('[data-o]').forEach((b) =>
      b.addEventListener('click', () => orderDetailModal(b.dataset.o, load).catch(oops)));
  };
  main.innerHTML = `
    <div class="topline"><h2>${title}</h2><span class="sub">${sub}</span></div>
    <div class="searchbar"><select id="st">
      <option value="">All statuses</option>
      <option value="PLACED">Committed</option><option value="PICKING">Picking</option>
      <option value="FULFILLED">Dispatched</option><option value="DELIVERED">Delivered</option>
      <option value="CANCELLED">Cancelled</option>
    </select></div>
    <div class="panel tbl-wrap" id="ordTbl"></div>`;
  $('#st', main).addEventListener('change', (e) => { status = e.target.value; load().catch(oops); });
  await load();
  poll(load);
}
VIEWS.orders = (main) => ordersView(main, 'B2B Orders', 'Committed stock is locked the moment an order is placed');
VIEWS.pick = (main) => ordersView(main, 'Pick & Fulfill', 'Pick in the printed FEFO order — earliest expiry first');

// =========================================================================
// Transfers & counts (warehouse/admin) + expired write-off + restock tasks
// =========================================================================
VIEWS.transfers = async (main) => {
  main.innerHTML = `
    <div class="topline"><h2>Transfers &amp; Counts</h2></div>
    <div class="two-col">
      <div class="panel"><h3>🔀 Pool-to-pool transfer</h3>
        <div class="frow">
          <div style="flex:2"><label>SKU</label><input id="t_sku" type="text" list="tSkus"></div>
          <div><button class="btn secondary" id="t_find">Find batches</button></div>
        </div>
        <datalist id="tSkus"></datalist>
        <div id="t_batches" class="mt"></div>
      </div>
      <div class="panel"><h3>🔢 Cycle count</h3>
        <div class="frow">
          <div style="flex:2"><label>SKU</label><input id="c_sku" type="text" list="tSkus"></div>
          <div><label>Counted qty (all pools)</label><input id="c_qty" type="number" min="0"></div>
          <div><button class="btn" id="c_go">Record count</button></div>
        </div>
        <div id="c_result" class="mt"></div>
        <div class="tbl-wrap mt" id="c_hist"></div>
      </div>
    </div>
    <div class="panel"><h3>☠️ Expired stock — write-off</h3><div id="x_list" class="tbl-wrap"></div></div>
    ${USER.role !== 'RETAIL_CASHIER' ? '<div class="panel"><h3>🛎️ Restock tasks</h3><div id="rs_list" class="tbl-wrap"></div></div>' : ''}`;

  get('/api/products?q=').then((rows) => {
    $('#tSkus', main).innerHTML = rows.map((p) => `<option value="${esc(p.sku)}">${esc(p.name)}</option>`).join('');
  });

  $('#t_find', main).addEventListener('click', async () => {
    const sku = $('#t_sku', main).value.trim();
    if (!sku) return;
    try {
      const rows = await get(`/api/products/${encodeURIComponent(sku)}/batches`);
      $('#t_batches', main).innerHTML = rows.length ? rows.map((b) => {
        const pools = Object.entries(b.pools).map(([pool, v]) =>
          `${pool}: ${v.on_hand - v.committed} free`).join(' · ');
        return `<div class="card mt"><b>${esc(b.batch_number)}</b> <span class="mut">exp ${day(b.expiry_date)} — ${pools}</span>
          <div class="frow mt">
            <div><label>From</label><select id="tf_${b.id}">
              <option>B2B_POOL</option><option>RETAIL_SHELF</option><option>SAFETY</option><option>WAREHOUSE_BULK</option></select></div>
            <div><label>To</label><select id="tt_${b.id}">
              <option>RETAIL_SHELF</option><option>B2B_POOL</option><option>SAFETY</option><option>WAREHOUSE_BULK</option></select></div>
            <div><label>Qty</label><input id="tq_${b.id}" type="number" min="1"></div>
            <div><button class="btn small" data-tr="${b.id}">Move</button></div>
          </div></div>`;
      }).join('') : '<div class="empty">No batches for that SKU.</div>';
      main.querySelectorAll('[data-tr]').forEach((btn) => btn.addEventListener('click', async () => {
        const id = btn.dataset.tr;
        try {
          await post('/api/transfer', {
            batch_id: +id, from_pool: $(`#tf_${id}`).value, to_pool: $(`#tt_${id}`).value,
            qty: +$(`#tq_${id}`).value,
          });
          toast('Stock moved 🌸', 'ok');
          $('#t_find', main).click();
        } catch (e) { oops(e); }
      }));
    } catch (e) { oops(e); }
  });

  const loadCounts = async () => {
    const rows = await get('/api/cycle-counts');
    $('#c_hist', main).innerHTML = rows.length ? `<table>
      <tr><th>Week</th><th>Product</th><th class="num">Counted</th><th class="num">System</th><th class="num">Variance</th><th>By</th></tr>
      ${rows.slice(0, 10).map((c) => `<tr><td>${esc(c.count_week)}</td><td>${esc(c.name)}</td>
        <td class="num">${num(c.counted_qty)}</td><td class="num">${num(c.system_qty)}</td>
        <td class="num">${c.variance == 0 ? '<span class="badge green">0</span>'
          : `<span class="badge red">${c.variance > 0 ? '+' : ''}${c.variance}</span>`}</td>
        <td class="mut">${esc(c.counted_by)}</td></tr>`).join('')}</table>` : '';
  };
  $('#c_go', main).addEventListener('click', async () => {
    try {
      const r = await post('/api/cycle-count', { sku: $('#c_sku', main).value.trim(), counted: +$('#c_qty', main).value });
      $('#c_result', main).innerHTML = `<div class="${r.variance == 0 ? 'info-banner' : 'warn-banner'}"
        style="${r.variance == 0 ? 'background:#e7eee3;color:#5c7052' : ''}">
        Counted ${r.counted_qty} vs system ${r.system_qty} — variance <b>${r.variance}</b>.
        ${r.variance != 0 ? 'Flagged for admin review before any adjustment.' : 'Perfect match 🌸'}</div>`;
      loadCounts();
    } catch (e) { oops(e); }
  });

  const loadExpired = async () => {
    const rows = await get('/api/expired');
    $('#x_list', main).innerHTML = rows.length ? `<table>
      <tr><th>Product</th><th>Batch</th><th>Expired</th><th>Pool</th><th class="num">Qty</th><th></th></tr>
      ${rows.map((x) => `<tr><td>${esc(x.name)}</td><td>${esc(x.batch_number)}</td><td>${day(x.expiry_date)}</td>
        <td class="mut">${esc(x.pool)}</td><td class="num">${num(x.qty)}</td>
        <td><button class="btn small danger" data-wo="${x.batch_id}">Write off</button></td></tr>`).join('')}</table>`
      : '<div class="empty">No expired stock on hand 🌸</div>';
    main.querySelectorAll('[data-wo]').forEach((b) => b.addEventListener('click', async () => {
      try {
        const r = await post('/api/write-off-expired', { batch_id: +b.dataset.wo });
        toast(`${r.units_written_off} unit(s) written off (reason: expired)`, 'ok');
        loadExpired();
      } catch (e) { oops(e); }
    }));
  };

  const loadRestock = async () => {
    if (!$('#rs_list', main)) return;
    const rows = await get('/api/restock-requests');
    $('#rs_list', main).innerHTML = rows.length ? `<table>
      <tr><th>Product</th><th>Note</th><th>Status</th><th>Raised</th><th></th></tr>
      ${rows.map((r) => `<tr><td>${esc(r.name)}</td><td class="mut">${esc(r.note || '')}</td>
        <td>${r.status === 'OPEN' ? '<span class="badge amber">open</span>' : '<span class="badge green">done</span>'}</td>
        <td>${dt(r.ts)}</td>
        <td>${r.status === 'OPEN' ? `<button class="btn small good" data-rs="${r.id}">Mark done</button>` : ''}</td></tr>`).join('')}</table>`
      : '<div class="empty">No restock requests.</div>';
    main.querySelectorAll('[data-rs]').forEach((b) => b.addEventListener('click', async () => {
      try { await post(`/api/restock-requests/${b.dataset.rs}/close`); toast('Done 🌸', 'ok'); loadRestock(); }
      catch (e) { oops(e); }
    }));
  };
  await Promise.all([loadCounts(), loadExpired(), loadRestock()]);
  poll(async () => { await loadExpired(); await loadRestock(); }, 12000);
};

VIEWS.restock = async (main) => {
  main.innerHTML = `<div class="topline"><h2>Restock Tasks</h2>
    <span class="sub">Move stock from the warehouse pools to the storefront</span></div>
    <div class="panel tbl-wrap" id="rs_list"></div>`;
  const load = async () => {
    const rows = await get('/api/restock-requests');
    $('#rs_list', main).innerHTML = rows.length ? `<table>
      <tr><th>Product</th><th>Note</th><th>Status</th><th>Raised</th><th></th></tr>
      ${rows.map((r) => `<tr><td><b>${esc(r.name)}</b> <span class="mut">${esc(r.sku)}</span></td>
        <td class="mut">${esc(r.note || '')}</td>
        <td>${r.status === 'OPEN' ? '<span class="badge amber">open</span>' : '<span class="badge green">done</span>'}</td>
        <td>${dt(r.ts)}</td>
        <td>${r.status === 'OPEN' ? `<button class="btn small good" data-rs="${r.id}">Mark done</button>` : ''}</td></tr>`).join('')}</table>`
      : '<div class="empty">Nothing to restock 🌸</div>';
    main.querySelectorAll('[data-rs]').forEach((b) => b.addEventListener('click', async () => {
      try { await post(`/api/restock-requests/${b.dataset.rs}/close`); toast('Done 🌸', 'ok'); load(); }
      catch (e) { oops(e); }
    }));
  };
  await load();
  poll(load);
};

// =========================================================================
// Resellers (admin)
// =========================================================================
VIEWS.resellers = async (main) => {
  let q = '';
  const load = async () => {
    const rows = (await get('/api/resellers')).filter((r) =>
      !q || r.name.toLowerCase().includes(q) || (r.email || '').toLowerCase().includes(q));
    $('#resTbl', main).innerHTML = rows.length ? `<table>
      <tr><th>Reseller</th><th>Tier</th><th>Status</th><th class="num">Credit limit</th>
      <th class="num">Outstanding</th><th>Signals</th><th></th></tr>
      ${rows.map((r) => `<tr>
        <td><b>${esc(r.name)}</b><br><span class="mut">${esc(r.email || '')}</span></td>
        <td>${tierBadge(r.tier)}</td>
        <td>${r.blocked || r.past_due ? '<span class="badge red">BLOCKED</span>'
          : r.status === 'ACTIVE' ? '<span class="badge green">active</span>'
          : `<span class="badge amber">${r.status.toLowerCase()}</span>`}
          ${r.docs_verified ? '' : ' <span class="badge gray">docs pending</span>'}</td>
        <td class="num">${peso(r.credit_limit)}</td>
        <td class="num">${peso(r.outstanding)}</td>
        <td class="mut">✅ ${r.on_time_paid} on-time · ${r.lates_this_quarter > 0
          ? `<span class="badge red">${r.lates_this_quarter} late this qtr</span>` : 'no lates this qtr'}</td>
        <td><button class="btn small secondary" data-r="${r.id}">Open</button></td></tr>`).join('')}</table>`
      : '<div class="empty">No resellers yet — add your first partner.</div>';
    main.querySelectorAll('[data-r]').forEach((b) =>
      b.addEventListener('click', () => resellerModal(+b.dataset.r, load).catch(oops)));
  };
  main.innerHTML = `
    <div class="topline"><h2>Resellers</h2>
      <span class="sub">Tier 1 prepaid → Tier 2 Net 15–30 → Tier 3 Net 30–60. Blocks are automatic.</span></div>
    <div class="searchbar">
      <input type="text" id="q" placeholder="Search name or email…">
      <button class="btn" id="newRes">＋ New reseller</button>
    </div>
    <div class="panel tbl-wrap" id="resTbl"></div>`;
  $('#q', main).addEventListener('input', (e) => { q = e.target.value.toLowerCase(); load().catch(oops); });
  $('#newRes', main).addEventListener('click', () => {
    modal(`<h3>New reseller application</h3>
      <div class="frow">
        <div style="flex:2"><label>Business name</label><input id="nr_name" type="text"></div>
        <div style="flex:2"><label>Email</label><input id="nr_email" type="text"></div>
      </div>
      <div class="frow">
        <div><label>Tier</label><select id="nr_tier"><option value="1">1 — New (prepaid)</option>
          <option value="2">2 — Established</option><option value="3">3 — Key account</option></select></div>
        <div><label>Credit limit ₱</label><input id="nr_limit" type="number" value="0"></div>
        <div><label>Terms (days)</label><input id="nr_terms" type="number" value="0"></div>
      </div>
      <div class="mut mt">New resellers start as PENDING — approve them from their page after checking documents.</div>
      <div class="mt right"><button class="btn" id="nr_save">Create</button></div>`);
    $('#nr_save').addEventListener('click', async () => {
      try {
        await post('/api/resellers', {
          name: $('#nr_name').value, email: $('#nr_email').value, tier: +$('#nr_tier').value,
          credit_limit: +$('#nr_limit').value, payment_terms_days: +$('#nr_terms').value,
        });
        toast('Reseller created 🌸', 'ok'); closeModal(); load();
      } catch (e) { oops(e); }
    });
  });
  await load();
  poll(load, 12000);
};

async function resellerModal(id, reload) {
  const r = await get(`/api/resellers/${id}`);
  modal(`
    <h3>${esc(r.name)}</h3>
    <div class="pill-row">${tierBadge(r.tier)}
      ${r.blocked || r.past_due ? '<span class="badge red">BLOCKED</span>'
        : `<span class="badge green">${r.status.toLowerCase()}</span>`}
      ${r.docs_verified ? '<span class="badge green">docs verified</span>' : '<span class="badge amber">docs pending</span>'}
      <span class="badge pink">limit ${peso(r.credit_limit)}</span>
      <span class="badge ${Number(r.outstanding) > 0 ? 'amber' : 'green'}">owes ${peso(r.outstanding)}</span></div>
    ${r.blocked || r.past_due ? `<div class="warn-banner">Blocked: ${esc(r.blocked_reason || 'past-due invoice(s)')} —
      unblocking without payment needs a logged override note below.</div>` : ''}
    ${r.status !== 'ACTIVE' || !r.docs_verified ? `
      <div class="frow"><div><button class="btn good" id="rm_verify">Approve application (docs verified → ACTIVE)</button></div></div>` : ''}
    <h3 class="mt">Credit settings</h3>
    <div class="frow">
      <div><label>Tier</label><select id="rm_tier">
        ${[1, 2, 3].map((t) => `<option value="${t}" ${t === r.tier ? 'selected' : ''}>Tier ${t}</option>`).join('')}</select></div>
      <div><label>Credit limit ₱</label><input id="rm_limit" type="number" value="${r.credit_limit}"></div>
      <div><label>Terms (days)</label><input id="rm_terms" type="number" value="${r.payment_terms_days}"></div>
      <div><button class="btn" id="rm_tier_save">Save tier</button></div>
    </div>
    ${r.blocked || r.past_due ? `<h3 class="mt">Admin override</h3>
      <div class="frow"><div style="flex:3"><label>Override reason (logged)</label><input id="rm_note" type="text"></div>
      <div><button class="btn danger" id="rm_unblock">Unblock</button></div></div>` : ''}
    <h3 class="mt">Documents</h3>
    ${r.documents.length ? `<div class="mut">${r.documents.map((d) =>
      `${esc(d.doc_type)}: ${esc(d.file_ref)} ${d.verified ? '✅' : '⏳'}`).join('<br>')}</div>` : '<div class="mut">None on file.</div>'}
    <div class="frow mt"><div><label>Type</label><select id="rm_dtype">
      <option>BUSINESS_LICENSE</option><option>TAX_DOCUMENT</option><option>AGREEMENT</option></select></div>
      <div style="flex:2"><label>File reference</label><input id="rm_dref" type="text" placeholder="drive link / filename"></div>
      <div><button class="btn secondary" id="rm_dadd">Attach</button></div></div>
    <h3 class="mt">Invoices</h3>
    ${r.invoices.length ? `<div class="tbl-wrap"><table>
      <tr><th>#</th><th>Issued</th><th>Due</th><th class="num">Amount</th><th class="num">Balance</th><th>Status</th><th></th></tr>
      ${r.invoices.map((i) => `<tr><td>${i.id}</td><td>${day(i.issued_at)}</td><td>${day(i.due_date)}</td>
        <td class="num">${peso(i.amount)}</td><td class="num">${peso(i.balance)}</td>
        <td>${i.status === 'PAID' ? '<span class="badge green">paid</span>'
          : i.status === 'VOID' ? '<span class="badge gray">void</span>'
          : i.overdue ? '<span class="badge red">overdue</span>' : '<span class="badge amber">open</span>'}</td>
        <td>${i.status === 'OPEN' ? `<button class="btn small" data-pay="${i.id}" data-bal="${i.balance}">Record payment</button>` : ''}</td>
      </tr>`).join('')}</table></div>` : '<div class="mut">No invoices yet.</div>'}
    <h3 class="mt">Recent events</h3>
    <div class="mut">${r.events.slice(0, 8).map((e) =>
      `${dt(e.ts)} — <b>${esc(e.event_type)}</b> ${esc(JSON.stringify(e.details || {}))}`).join('<br>') || 'None.'}</div>`);

  $('#rm_verify')?.addEventListener('click', async () => {
    try { await post(`/api/resellers/${id}/verify`); toast('Approved 🌸', 'ok'); closeModal(); reload(); }
    catch (e) { oops(e); }
  });
  $('#rm_tier_save').addEventListener('click', async () => {
    try {
      await post(`/api/resellers/${id}/tier`, {
        tier: +$('#rm_tier').value, credit_limit: +$('#rm_limit').value,
        payment_terms_days: +$('#rm_terms').value,
      });
      toast('Tier saved', 'ok'); closeModal(); reload();
    } catch (e) { oops(e); }
  });
  $('#rm_unblock')?.addEventListener('click', async () => {
    try {
      await post(`/api/resellers/${id}/unblock`, { note: $('#rm_note').value });
      toast('Unblocked — override logged', 'ok'); closeModal(); reload();
    } catch (e) { oops(e); }
  });
  $('#rm_dadd').addEventListener('click', async () => {
    try {
      await post(`/api/resellers/${id}/documents`, { doc_type: $('#rm_dtype').value, file_ref: $('#rm_dref').value });
      toast('Attached', 'ok'); resellerModal(id, reload);
    } catch (e) { oops(e); }
  });
  document.querySelectorAll('[data-pay]').forEach((b) => b.addEventListener('click', async () => {
    const amt = prompt(`Amount received (balance ${peso(b.dataset.bal)}):`, b.dataset.bal);
    if (amt == null) return;
    try {
      await post(`/api/invoices/${b.dataset.pay}/pay`, { amount: +amt });
      toast('Payment recorded — discounts & blocks update automatically', 'ok');
      resellerModal(id, reload);
    } catch (e) { oops(e); }
  }));
}

// =========================================================================
// Returns queue (admin)
// =========================================================================
VIEWS.returns = async (main) => {
  main.innerHTML = `<div class="topline"><h2>Returns Queue</h2>
    <span class="sub">Items sit in quarantine until you decide: restock, damaged or tester</span></div>
    <div class="panel tbl-wrap" id="rq"></div>`;
  const load = async () => {
    const rows = await get('/api/returns');
    $('#rq', main).innerHTML = rows.length ? `<table>
      <tr><th>Receipt</th><th>Product</th><th>Batch</th><th class="num">Qty</th><th>Reason</th><th>By</th><th>Status</th><th></th></tr>
      ${rows.map((r) => `<tr><td class="mut">${esc(r.receipt_no)}</td><td>${esc(r.name)}</td>
        <td class="mut">${esc(r.batch_number)}</td><td class="num">${r.qty}</td><td>${esc(r.reason)}</td>
        <td class="mut">${esc(r.requested_by)}</td>
        <td>${r.status === 'PENDING' ? '<span class="badge amber">quarantine</span>'
          : r.status === 'APPROVED' ? `<span class="badge green">${esc(r.disposition)}</span>`
          : '<span class="badge gray">rejected</span>'}</td>
        <td>${r.status === 'PENDING' ? `
          <button class="btn small good" data-d="${r.id}|RESTOCK">Restock</button>
          <button class="btn small secondary" data-d="${r.id}|DAMAGED">Damaged</button>
          <button class="btn small secondary" data-d="${r.id}|TESTER">Tester</button>
          <button class="btn small danger" data-rej="${r.id}">Reject</button>` : ''}</td></tr>`).join('')}</table>`
      : '<div class="empty">No returns waiting 🌸</div>';
    main.querySelectorAll('[data-d]').forEach((b) => b.addEventListener('click', async () => {
      const [id, disp] = b.dataset.d.split('|');
      try { await post(`/api/returns/${id}/decide`, { approve: true, disposition: disp }); toast(`Approved as ${disp}`, 'ok'); load(); }
      catch (e) { oops(e); }
    }));
    main.querySelectorAll('[data-rej]').forEach((b) => b.addEventListener('click', async () => {
      try { await post(`/api/returns/${b.dataset.rej}/decide`, { approve: false }); toast('Rejected', 'ok'); load(); }
      catch (e) { oops(e); }
    }));
  };
  await load();
  poll(load);
};

// =========================================================================
// ROP (admin + warehouse)
// =========================================================================
VIEWS.rop = async (main) => {
  main.innerHTML = `<div class="topline"><h2>Reorder Points</h2>
    <span class="sub">Lead time includes shipping + customs + FDA processing</span></div>
    <div class="panel tbl-wrap" id="ropTbl"></div>`;
  const load = async () => {
    const rows = await get('/api/rop');
    $('#ropTbl', main).innerHTML = `<table>
      <tr><th>Product</th><th class="num">Avg/day</th><th class="num">Max/day</th><th class="num">Avg lead</th>
      <th class="num">Max lead</th><th class="num">Safety stock</th><th class="num">ROP</th>
      <th class="num">Sellable</th><th>Status</th><th></th></tr>
      ${rows.map((r) => `<tr><td><b>${esc(r.name)}</b> ${r.abc_class ? `<span class="badge pink">${r.abc_class}</span>` : ''}</td>
        <td class="num">${r.avg_daily_sales ?? '—'}</td><td class="num">${r.max_daily_sales ?? '—'}</td>
        <td class="num">${r.avg_lead_days ?? '—'}</td><td class="num">${r.max_lead_days ?? '—'}</td>
        <td class="num">${r.safety_stock == null ? '—' : num(r.safety_stock)}</td>
        <td class="num">${r.rop == null ? '—' : `<b>${num(r.rop)}</b>`}</td>
        <td class="num">${r.sellable_stock == null ? '' : num(r.sellable_stock)}</td>
        <td>${r.shortfall != null ? `<span class="badge red">ORDER NOW — suggest ${num(Math.round(r.suggested_order_qty))}</span>`
          : r.rop != null ? '<span class="badge green">ok</span>' : '<span class="badge gray">not set</span>'}</td>
        <td><button class="btn small secondary" data-rop="${esc(r.sku)}">Set</button>
          ${r.rop != null ? `<button class="btn small ghost" data-recalc="${esc(r.sku)}">↻ 90-day recalc</button>` : ''}</td>
      </tr>`).join('')}</table>`;
    main.querySelectorAll('[data-rop]').forEach((b) => b.addEventListener('click', () => {
      const r = rows.find((x) => x.sku === b.dataset.rop);
      modal(`<h3>Reorder point — ${esc(r.name)}</h3>
        <div class="frow">
          <div><label>Avg daily sales</label><input id="rp_a" type="number" step="0.1" value="${r.avg_daily_sales ?? ''}"></div>
          <div><label>Max daily sales</label><input id="rp_m" type="number" step="0.1" value="${r.max_daily_sales ?? ''}"></div>
        </div>
        <div class="frow">
          <div><label>Avg lead time (days)</label><input id="rp_al" type="number" value="${r.avg_lead_days ?? ''}"></div>
          <div><label>Max lead time (days)</label><input id="rp_ml" type="number" value="${r.max_lead_days ?? ''}"></div>
          <div><label>Months of cover</label><input id="rp_c" type="number" value="${r.target_months_cover ?? 3}"></div>
        </div>
        <div class="mut mt">Safety stock = (max × max lead) − (avg × avg lead). ROP = avg × avg lead + safety stock.</div>
        <div class="mt right"><button class="btn" id="rp_save">Save &amp; compute</button></div>`);
      $('#rp_save').addEventListener('click', async () => {
        try {
          const out = await post(`/api/rop/${encodeURIComponent(r.sku)}`, {
            avg_daily: +$('#rp_a').value, max_daily: +$('#rp_m').value,
            avg_lead: +$('#rp_al').value, max_lead: +$('#rp_ml').value,
            target_months_cover: +$('#rp_c').value,
          });
          toast(`Safety stock ${num(out.safety_stock)}, ROP ${num(out.rop)}`, 'ok');
          closeModal(); load();
        } catch (e) { oops(e); }
      });
    }));
    main.querySelectorAll('[data-recalc]').forEach((b) => b.addEventListener('click', async () => {
      try {
        const out = await post(`/api/rop/${encodeURIComponent(b.dataset.recalc)}/recalc`);
        toast(`Recalculated from 90-day sales: avg ${out.avg_daily_sales}/day → ROP ${num(out.rop)}`, 'ok');
        load();
      } catch (e) { oops(e); }
    }));
  };
  await load();
};

// =========================================================================
// Reports (admin)
// =========================================================================
VIEWS.reports = async (main) => {
  const today = new Date().toISOString().slice(0, 10);
  const monthAgo = new Date(Date.now() - 30 * 864e5).toISOString().slice(0, 10);
  main.innerHTML = `
    <div class="topline"><h2>Reports</h2></div>
    <div class="pill-row">
      <button class="btn small" data-rep="sales">Sales</button>
      <button class="btn small secondary" data-rep="valuation">Stock valuation</button>
      <button class="btn small secondary" data-rep="aging">Aging stock</button>
      <button class="btn small secondary" data-rep="ar">AR aging</button>
      <button class="btn small secondary" data-rep="ledger">Movement ledger</button>
    </div>
    <div id="repBody"></div>`;
  const body = $('#repBody', main);
  const reps = {
    sales: async () => {
      body.innerHTML = `<div class="searchbar">
        <input type="date" id="s_from" value="${monthAgo}"><input type="date" id="s_to" value="${today}">
        <button class="btn small" id="s_go">Run</button></div><div id="s_out"></div>`;
      const run = async () => {
        const d = await get(`/api/reports/sales?from=${$('#s_from').value}&to=${$('#s_to').value}`);
        $('#s_out').innerHTML = `
          <div class="cards">${d.by_channel.map((c) => `<div class="card">
            <div class="kpi">${peso(c.revenue)}</div><div class="kpi-label">${c.channel} — ${c.orders} orders</div></div>`).join('')
            || '<div class="empty">No sales in this period.</div>'}</div>
          <div class="panel"><h3>By product</h3><div class="tbl-wrap"><table>
            <tr><th>Product</th><th class="num">Units</th><th class="num">Revenue</th></tr>
            ${d.by_product.map((p) => `<tr><td>${esc(p.name)}</td><td class="num">${num(p.units)}</td>
              <td class="num">${peso(p.revenue)}</td></tr>`).join('')}</table></div></div>
          <div class="panel"><h3>By day</h3><div class="tbl-wrap"><table>
            <tr><th>Day</th><th>Channel</th><th class="num">Revenue</th></tr>
            ${d.by_day.map((x) => `<tr><td>${day(x.day)}</td><td>${x.channel}</td>
              <td class="num">${peso(x.revenue)}</td></tr>`).join('')}</table></div></div>`;
      };
      $('#s_go').addEventListener('click', () => run().catch(oops));
      await run();
    },
    valuation: async () => {
      const rows = await get('/api/reports/valuation');
      const total = rows.reduce((s, r) => s + Number(r.value), 0);
      body.innerHTML = `<div class="cards"><div class="card good"><div class="kpi">${peso(total)}</div>
        <div class="kpi-label">Total stock at cost (unexpired)</div></div></div>
        <div class="panel tbl-wrap"><table><tr><th>Product</th><th class="num">Units</th>
        <th class="num">Unit cost</th><th class="num">Value</th></tr>
        ${rows.map((r) => `<tr><td>${esc(r.name)}</td><td class="num">${num(r.units)}</td>
          <td class="num">${peso(r.unit_cost)}</td><td class="num">${peso(r.value)}</td></tr>`).join('')}</table></div>`;
    },
    aging: async () => {
      const rows = await get('/api/reports/aging');
      body.innerHTML = `<div class="panel tbl-wrap">${rows.length ? `<table>
        <tr><th>Product</th><th>Batch</th><th>Expiry</th><th class="num">Days left</th>
        <th class="num">Qty at risk</th><th class="num">₱ at risk</th><th>B2B?</th></tr>
        ${rows.map((a) => `<tr><td>${esc(a.name)}</td><td>${esc(a.batch_number)}</td><td>${day(a.expiry_date)}</td>
          <td class="num">${a.days_to_expiry}</td><td class="num">${num(a.qty_at_risk)}</td>
          <td class="num">${peso(a.value_at_risk)}</td>
          <td>${a.below_reseller_floor ? '<span class="badge red">retail only</span>' : '<span class="badge green">ok</span>'}</td>
        </tr>`).join('')}</table>` : '<div class="empty">Nothing inside the 6-month window 🌸</div>'}</div>`;
    },
    ar: async () => {
      const d = await get('/api/reports/ar');
      body.innerHTML = `<div class="panel"><h3>AR aging</h3><div class="tbl-wrap">${d.aging.length ? `<table>
        <tr><th>Reseller</th><th>Tier</th><th class="num">Current</th><th class="num">1–30</th>
        <th class="num">31–60</th><th class="num">60+</th><th class="num">Total</th></tr>
        ${d.aging.map((a) => `<tr><td>${esc(a.name)}</td><td>${tierBadge(a.tier)}</td>
          <td class="num">${peso(a.current_due)}</td><td class="num">${peso(a.overdue_1_30)}</td>
          <td class="num">${peso(a.overdue_31_60)}</td><td class="num">${peso(a.overdue_60_plus)}</td>
          <td class="num"><b>${peso(a.total_outstanding)}</b></td></tr>`).join('')}</table>`
        : '<div class="empty">No open receivables 🌸</div>'}</div></div>
        <div class="panel"><h3>Exposure</h3><div class="tbl-wrap">${d.exposure.length ? `<table>
        <tr><th>Reseller</th><th class="num">Outstanding</th><th class="num">Share of AR</th><th></th></tr>
        ${d.exposure.map((e) => `<tr><td>${esc(e.name)}</td><td class="num">${peso(e.outstanding)}</td>
          <td class="num">${(e.share * 100).toFixed(1)}%</td>
          <td>${e.flagged ? '<span class="badge red">over 15% cap</span>' : ''}</td></tr>`).join('')}</table>`
        : '<div class="empty">No exposure.</div>'}</div></div>`;
    },
    ledger: async () => {
      body.innerHTML = `<div class="searchbar"><input type="text" id="l_q" placeholder="Filter by SKU, product or reason…">
        </div><div class="panel tbl-wrap" id="l_out"></div>`;
      const run = async () => {
        const rows = await get(`/api/reports/ledger?q=${encodeURIComponent($('#l_q').value || '')}`);
        $('#l_out').innerHTML = rows.length ? `<table>
          <tr><th>When</th><th>Product</th><th>Batch</th><th>From</th><th>To</th><th class="num">Qty</th><th>Reason</th><th>Actor</th></tr>
          ${rows.map((m) => `<tr><td>${dt(m.ts)}</td><td>${esc(m.name)}</td><td class="mut">${esc(m.batch_number)}</td>
            <td>${esc(m.from_pool || '·')}</td><td>${esc(m.to_pool || 'out')}</td><td class="num">${num(m.qty)}</td>
            <td class="mut">${esc(m.reason)}</td><td class="mut">${esc(m.actor)}</td></tr>`).join('')}</table>`
          : '<div class="empty">No matching movements.</div>';
      };
      $('#l_q').addEventListener('input', () => run().catch(oops));
      await run();
    },
  };
  main.querySelectorAll('[data-rep]').forEach((b) => b.addEventListener('click', () => {
    main.querySelectorAll('[data-rep]').forEach((x) => x.classList.add('secondary'));
    b.classList.remove('secondary');
    reps[b.dataset.rep]().catch(oops);
  }));
  await reps.sales();
};

// =========================================================================
// Users (admin)
// =========================================================================
VIEWS.users = async (main) => {
  const [users, resellers] = await Promise.all([get('/api/users'), get('/api/resellers')]);
  main.innerHTML = `
    <div class="topline"><h2>Users</h2></div>
    <div class="panel"><h3>Create login</h3><div class="frow">
      <div><label>Username</label><input id="u_name" type="text"></div>
      <div><label>Display name</label><input id="u_disp" type="text"></div>
      <div><label>Password</label><input id="u_pass" type="password"></div>
      <div><label>Role</label><select id="u_role">
        <option value="OWNER_ADMIN">Admin</option><option value="WAREHOUSE">Warehouse</option>
        <option value="RETAIL_CASHIER">Cashier</option><option value="RESELLER">Reseller</option></select></div>
      <div id="u_res_wrap" style="display:none"><label>Reseller</label><select id="u_res">
        ${resellers.map((r) => `<option value="${r.id}">${esc(r.name)}</option>`).join('')}</select></div>
      <div><button class="btn" id="u_go">Create</button></div>
    </div></div>
    <div class="panel tbl-wrap" id="u_tbl"></div>`;
  $('#u_role', main).addEventListener('change', (e) => {
    $('#u_res_wrap', main).style.display = e.target.value === 'RESELLER' ? '' : 'none';
  });
  const draw = (rows) => {
    $('#u_tbl', main).innerHTML = `<table>
      <tr><th>Username</th><th>Name</th><th>Role</th><th>Reseller</th><th>Status</th><th></th></tr>
      ${rows.map((u) => `<tr><td><b>${esc(u.username)}</b></td><td>${esc(u.display_name)}</td>
        <td><span class="badge pink">${roleLabel(u.role)}</span></td><td>${esc(u.reseller_name || '—')}</td>
        <td>${u.active ? '<span class="badge green">active</span>' : '<span class="badge gray">disabled</span>'}</td>
        <td><button class="btn small secondary" data-u="${u.id}" data-a="${u.active ? 0 : 1}">
          ${u.active ? 'Disable' : 'Enable'}</button></td></tr>`).join('')}</table>`;
    main.querySelectorAll('[data-u]').forEach((b) => b.addEventListener('click', async () => {
      try {
        await post(`/api/users/${b.dataset.u}/active`, { active: b.dataset.a === '1' });
        draw(await get('/api/users'));
      } catch (e) { oops(e); }
    }));
  };
  draw(users);
  $('#u_go', main).addEventListener('click', async () => {
    try {
      await post('/api/users', {
        username: $('#u_name', main).value.trim(), display_name: $('#u_disp', main).value,
        password: $('#u_pass', main).value, role: $('#u_role', main).value,
        reseller_id: $('#u_role', main).value === 'RESELLER' ? +$('#u_res', main).value : null,
      });
      toast('User created 🌸', 'ok');
      draw(await get('/api/users'));
    } catch (e) { oops(e); }
  });
};

// =========================================================================
// POS (cashier)
// =========================================================================
const cart = new Map();          // sku -> {sku, name, price, qty, shelf}

VIEWS.pos = async (main) => {
  let products = [];
  main.innerHTML = `
    <div class="topline"><h2>Point of Sale</h2><span class="sub">Retail shelf only — scans and search</span></div>
    <div class="pos-grid">
      <div>
        <div class="searchbar"><input type="text" id="pq" placeholder="Scan barcode / type SKU or name, Enter adds it…" autofocus></div>
        <div class="pos-products" id="pgrid"></div>
      </div>
      <div class="panel">
        <h3>🛒 Cart</h3><div id="cartBox"></div>
        <div class="pos-total" id="total">₱0.00</div>
        <div class="paybtns">
          <button class="btn" data-pay="CASH">💵 Cash</button>
          <button class="btn secondary" data-pay="GCASH">📱 GCash</button>
          <button class="btn secondary" data-pay="CARD">💳 Card</button>
        </div>
        <div id="payBox" class="mt"></div>
      </div>
    </div>`;

  const cartTotal = () => [...cart.values()].reduce((s, l) => s + l.price * l.qty, 0);
  const drawCart = () => {
    const box = $('#cartBox', main);
    box.innerHTML = cart.size ? [...cart.values()].map((l) => `
      <div class="cart-line"><span class="nm"><b>${esc(l.name)}</b><br><span class="mut">${peso(l.price)} each</span></span>
        <input type="number" min="1" value="${l.qty}" data-cq="${esc(l.sku)}">
        <button class="btn small danger" data-cx="${esc(l.sku)}">✕</button></div>`).join('')
      : '<div class="empty">Cart is empty — tap a product to add it.</div>';
    $('#total', main).textContent = peso(cartTotal());
    box.querySelectorAll('[data-cq]').forEach((i) => i.addEventListener('change', () => {
      const l = cart.get(i.dataset.cq);
      l.qty = Math.max(1, +i.value || 1);
      drawCart();
    }));
    box.querySelectorAll('[data-cx]').forEach((b) => b.addEventListener('click', () => {
      cart.delete(b.dataset.cx); drawCart();
    }));
  };

  const addToCart = (p) => {
    if (p.shelf_available <= 0) return;
    const l = cart.get(p.sku) || { sku: p.sku, name: p.name, price: Number(p.retail_price), qty: 0 };
    l.qty += 1;
    cart.set(p.sku, l);
    drawCart();
  };

  const drawGrid = () => {
    $('#pgrid', main).innerHTML = products.length ? products.map((p) => `
      <button class="pos-item ${p.shelf_available <= 0 ? 'out' : ''}" data-add="${esc(p.sku)}">
        <span class="nm">${esc(p.name)}</span>
        <span class="pr">${peso(p.retail_price)}</span>
        <span class="st">${p.shelf_available > 0 ? `${p.shelf_available} on shelf`
          : 'OUT OF STOCK'}</span>
        ${p.shelf_available <= 0 ? `<span><button class="btn small ghost" data-restock="${esc(p.sku)}">🛎 Request restock</button></span>` : ''}
      </button>`).join('') : '<div class="empty">No products match.</div>';
    main.querySelectorAll('[data-add]').forEach((b) => b.addEventListener('click', (e) => {
      if (e.target.closest('[data-restock]')) return;
      const p = products.find((x) => x.sku === b.dataset.add);
      if (p.shelf_available <= 0) toast('Out of stock on the shelf — request a restock instead.', 'err');
      else addToCart(p);
    }));
    main.querySelectorAll('[data-restock]').forEach((b) => b.addEventListener('click', async (e) => {
      e.stopPropagation();
      try {
        await post('/api/restock-requests', { sku: b.dataset.restock, note: 'Cashier requested from POS' });
        toast('Restock request sent to the warehouse 🌸', 'ok');
      } catch (err) { oops(err); }
    }));
  };

  const search = async () => {
    products = await get(`/api/pos/products?q=${encodeURIComponent($('#pq', main).value)}`);
    drawGrid();
  };
  $('#pq', main).addEventListener('input', () => search().catch(oops));
  $('#pq', main).addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {                          // barcode wedge: exact SKU + Enter
      const code = e.target.value.trim();
      const exact = products.find((p) => p.sku.toLowerCase() === code.toLowerCase());
      if (exact) { addToCart(exact); e.target.value = ''; search().catch(oops); }
    }
  });

  main.querySelectorAll('[data-pay]').forEach((b) => b.addEventListener('click', () => {
    if (!cart.size) return toast('Cart is empty.', 'err');
    const method = b.dataset.pay;
    const total = cartTotal();
    const box = $('#payBox', main);
    if (method === 'CASH') {
      box.innerHTML = `<div class="frow">
        <div><label>Cash tendered</label><input type="number" id="tender" step="0.01" min="0" autofocus></div>
        <div><label>Change</label><div class="kpi" id="chg">—</div></div>
        <div><button class="btn good" id="doPay">Complete sale</button></div></div>`;
      $('#tender').addEventListener('input', () => {
        const t = +$('#tender').value;
        $('#chg').textContent = t >= total ? peso(t - total) : '—';
      });
      $('#doPay').addEventListener('click', () => checkout('CASH', +$('#tender').value));
    } else {
      box.innerHTML = `<div class="frow"><div class="mut">Record a ${method} payment of <b>${peso(total)}</b> (no processing in MVP — record only).</div>
        <div><button class="btn good" id="doPay">Complete sale</button></div></div>`;
      $('#doPay').addEventListener('click', () => checkout(method, null));
    }
  }));

  async function checkout(method, tendered) {
    try {
      const r = await post('/api/pos/checkout', {
        lines: [...cart.values()].map((l) => ({ sku: l.sku, qty: l.qty })), method, tendered,
      });
      cart.clear(); drawCart(); $('#payBox', main).innerHTML = '';
      showReceipt(r);
      search().catch(() => {});
    } catch (e) { oops(e); search().catch(() => {}); }
  }

  function showReceipt(r) {
    modal(`<h3>Receipt ${esc(r.receipt_no)}</h3>
      <div class="receipt">MS BEAU AVE — Official Receipt
${esc(r.receipt_no)} · ${dt(r.ts)}
Cashier: ${esc(r.cashier)}
--------------------------------
${r.lines.map((l) => `${l.qty} × ${esc(l.name)}\n    batch ${esc(l.batch_number)}  ${peso(l.unit_price * l.qty)}`).join('\n')}
--------------------------------
TOTAL      ${peso(r.total)}
${r.method}${r.method === 'CASH' ? `   tendered ${peso(r.tendered)}\nCHANGE     ${peso(r.change)}` : ''}
--------------------------------
Salamat po! 🌸</div>
      <div class="mt right"><button class="btn secondary" onclick="window.print()">🖨 Print</button>
      <button class="btn" onclick="document.getElementById('modal').remove()">New sale</button></div>`);
  }

  await search();
  poll(search, 6000);
};

// =========================================================================
// POS returns + tester/damage (cashier)
// =========================================================================
VIEWS.posreturns = async (main) => {
  main.innerHTML = `
    <div class="topline"><h2>Returns &amp; Damage Log</h2></div>
    <div class="two-col">
      <div class="panel"><h3>↩️ Return against a receipt</h3>
        <div class="frow"><div style="flex:2"><label>Receipt number</label>
          <input id="ret_no" type="text" placeholder="OR-20260810-00001"></div>
          <div><button class="btn secondary" id="ret_find">Find</button></div></div>
        <div id="ret_body" class="mt"></div>
      </div>
      <div class="panel"><h3>🧪 Tester / damaged item</h3>
        <div class="mut">Deducts shelf stock with a signed ledger entry.</div>
        <div class="frow">
          <div style="flex:2"><label>SKU</label><input id="tl_sku" type="text"></div>
          <div><button class="btn secondary" id="tl_find">Find shelf batches</button></div>
        </div>
        <div id="tl_body" class="mt"></div>
      </div>
    </div>
    <div class="panel"><h3>My return requests</h3><div class="tbl-wrap" id="ret_list"></div></div>`;

  $('#ret_find', main).addEventListener('click', async () => {
    try {
      const r = await get(`/api/pos/receipt/${encodeURIComponent($('#ret_no', main).value.trim())}`);
      $('#ret_body', main).innerHTML = `
        <div class="mut">${dt(r.ts)} — ${peso(r.amount_due)} ${esc(r.payment_method)}</div>
        ${r.lines.map((l, i) => `<div class="card mt"><b>${esc(l.name)}</b>
          <span class="mut">batch ${esc(l.batch_number)} — bought ${l.qty}, returnable ${l.returnable}</span>
          ${Number(l.returnable) > 0 ? `<div class="frow mt">
            <div><label>Qty</label><input id="rq_${i}" type="number" min="1" max="${l.returnable}" value="1"></div>
            <div style="flex:2"><label>Reason</label><input id="rr_${i}" type="text" placeholder="e.g. allergic reaction, unopened"></div>
            <div><button class="btn small" data-ret="${i}" data-sku="${esc(l.sku)}" data-batch="${l.batch_id}">Send to quarantine</button></div>
          </div>` : ''}</div>`).join('')}`;
      main.querySelectorAll('[data-ret]').forEach((b) => b.addEventListener('click', async () => {
        const i = b.dataset.ret;
        try {
          await post('/api/pos/returns', {
            receipt_no: $('#ret_no', main).value.trim(), sku: b.dataset.sku,
            batch_id: +b.dataset.batch, qty: +$(`#rq_${i}`).value, reason: $(`#rr_${i}`).value || 'no reason given',
          });
          toast('Sent to quarantine — admin will decide restock vs write-off.', 'ok');
          loadList(); $('#ret_find', main).click();
        } catch (e) { oops(e); }
      }));
    } catch (e) { oops(e); }
  });

  $('#tl_find', main).addEventListener('click', async () => {
    try {
      const sku = $('#tl_sku', main).value.trim();
      const rows = await get(`/api/pos/shelf-batches/${encodeURIComponent(sku)}`);
      $('#tl_body', main).innerHTML = rows.length ? rows.map((b, i) => `
        <div class="card mt"><b>${esc(b.batch_number)}</b> <span class="mut">exp ${day(b.expiry_date)} — ${b.available} on shelf</span>
          <div class="frow mt">
            <div><label>Qty</label><input id="tq_${i}" type="number" min="1" max="${b.available}" value="1"></div>
            <div><label>Type</label><select id="tr_${i}"><option>TESTER</option><option>DAMAGED</option></select></div>
            <div><button class="btn small" data-tl="${i}" data-batch="${b.batch_id}">Log &amp; deduct</button></div>
          </div></div>`).join('') : '<div class="empty">Nothing on the shelf for that SKU.</div>';
      main.querySelectorAll('[data-tl]').forEach((btn) => btn.addEventListener('click', async () => {
        const i = btn.dataset.tl;
        try {
          await post('/api/pos/tester-log', {
            sku, batch_id: +btn.dataset.batch, qty: +$(`#tq_${i}`).value, reason: $(`#tr_${i}`).value,
          });
          toast('Logged and deducted 🌸', 'ok');
          $('#tl_find', main).click();
        } catch (e) { oops(e); }
      }));
    } catch (e) { oops(e); }
  });

  const loadList = async () => {
    const rows = await get('/api/pos/returns');
    $('#ret_list', main).innerHTML = rows.length ? `<table>
      <tr><th>Receipt</th><th>Product</th><th class="num">Qty</th><th>Reason</th><th>Status</th></tr>
      ${rows.map((r) => `<tr><td class="mut">${esc(r.receipt_no)}</td><td>${esc(r.name)}</td>
        <td class="num">${r.qty}</td><td>${esc(r.reason)}</td>
        <td>${r.status === 'PENDING' ? '<span class="badge amber">quarantine</span>'
          : r.status === 'APPROVED' ? `<span class="badge green">${esc(r.disposition)}</span>`
          : '<span class="badge gray">rejected</span>'}</td></tr>`).join('')}</table>`
      : '<div class="empty">No return requests yet.</div>';
  };
  await loadList();
  poll(loadList, 12000);
};

// =========================================================================
// End of day — blind reconciliation (cashier)
// =========================================================================
VIEWS.eod = async (main) => {
  main.innerHTML = `
    <div class="topline"><h2>End of Day</h2><span class="sub">Blind count — the expected total is hidden until you submit</span></div>
    <div class="two-col">
      <div class="panel"><h3>🌙 Submit blind cash count</h3>
        <div class="mut">Count the physical cash in your drawer and enter it below.
          You will only see the expected total after submitting.</div>
        <div class="frow mt">
          <div><label>Counted cash ₱</label><input id="e_amt" type="number" step="0.01" min="0"></div>
          <div><button class="btn" id="e_go">Submit count</button></div>
        </div>
        <div id="e_result" class="mt"></div>
      </div>
      <div class="panel"><h3>My past reconciliations</h3><div class="tbl-wrap" id="e_hist"></div></div>
    </div>`;
  const hist = async () => {
    const rows = await get('/api/pos/eod');
    $('#e_hist', main).innerHTML = rows.length ? `<table>
      <tr><th>Date</th><th class="num">Declared</th><th>Status</th></tr>
      ${rows.map((r) => `<tr><td>${day(r.business_date)}</td><td class="num">${peso(r.declared_amount)}</td>
        <td>${r.reconciled ? '<span class="badge green">reconciled</span>' : '<span class="badge amber">pending</span>'}</td></tr>`).join('')}
      </table>` : '<div class="empty">No reconciliations yet.</div>';
  };
  $('#e_go', main).addEventListener('click', async () => {
    try {
      const r = await post('/api/pos/eod', { declared: +$('#e_amt', main).value });
      const v = Number(r.variance);
      $('#e_result', main).innerHTML = `
        <div class="${v === 0 ? 'info-banner' : 'warn-banner'}" style="${v === 0 ? 'background:#e7eee3;color:#5c7052' : ''}">
          Declared <b>${peso(r.declared)}</b> · expected <b>${peso(r.expected)}</b> ·
          variance <b>${peso(r.variance)}</b>
          ${r.flagged ? '— flagged for admin review.' : v === 0 ? '— perfect 🌸' : '— within tolerance.'}
        </div>`;
      hist();
    } catch (e) { oops(e); }
  });
  await hist();
};

// =========================================================================
// Reseller portal
// =========================================================================
const bCart = new Map();

VIEWS.catalog = async (main) => {
  let credit = null;
  let rows = [];
  main.innerHTML = `
    <div class="topline"><h2>Wholesale Catalog</h2><span class="sub">Live availability from your allocated pool</span></div>
    <div id="blockBanner"></div>
    <div class="pos-grid">
      <div><div class="searchbar"><input type="text" id="cq" placeholder="Search products…"></div>
        <div class="tbl-wrap panel" id="cat"></div></div>
      <div class="panel"><h3>🛒 Order</h3><div id="bcart"></div>
        <div class="pos-total" id="btotal">₱0.00</div>
        <button class="btn" id="bsubmit" style="width:100%">Submit order</button>
        <div class="mut mt">Stock is reserved for you the moment the order goes through.</div></div>
    </div>`;

  const drawCart = () => {
    $('#bcart', main).innerHTML = bCart.size ? [...bCart.values()].map((l) => `
      <div class="cart-line"><span class="nm"><b>${esc(l.name)}</b><br>
        <span class="mut">${peso(l.price)} each</span></span>
        <input type="number" min="1" value="${l.qty}" data-bq="${esc(l.sku)}">
        <button class="btn small danger" data-bx="${esc(l.sku)}">✕</button></div>`).join('')
      : '<div class="empty">Nothing yet — add from the catalog.</div>';
    $('#btotal', main).textContent = peso([...bCart.values()].reduce((s, l) => s + l.price * l.qty, 0));
    main.querySelectorAll('[data-bq]').forEach((i) => i.addEventListener('change', () => {
      bCart.get(i.dataset.bq).qty = Math.max(1, +i.value || 1); drawCart();
    }));
    main.querySelectorAll('[data-bx]').forEach((b) => b.addEventListener('click', () => {
      bCart.delete(b.dataset.bx); drawCart();
    }));
  };

  const draw = () => {
    const q = ($('#cq', main).value || '').toLowerCase();
    const list = rows.filter((r) => !q || r.name.toLowerCase().includes(q) || r.sku.toLowerCase().includes(q));
    $('#cat', main).innerHTML = list.length ? `<table>
      <tr><th>Product</th><th class="num">Wholesale</th><th class="num">SRP</th><th class="num">Available</th><th></th></tr>
      ${list.map((r) => `<tr><td><b>${esc(r.name)}</b><br><span class="mut">${esc(r.brand || '')} ${esc(r.sku)}</span></td>
        <td class="num">${peso(r.wholesale_price)}</td><td class="num">${peso(r.srp)}</td>
        <td class="num">${r.available > 0 ? num(r.available) : '<span class="badge red">out</span>'}</td>
        <td>${r.available > 0 ? `<button class="btn small" data-badd="${esc(r.sku)}">Add</button>` : ''}</td>
      </tr>`).join('')}</table>` : '<div class="empty">No products match.</div>';
    main.querySelectorAll('[data-badd]').forEach((b) => b.addEventListener('click', () => {
      const r = rows.find((x) => x.sku === b.dataset.badd);
      const l = bCart.get(r.sku) || { sku: r.sku, name: r.name, price: Number(r.wholesale_price), qty: 0 };
      l.qty += 1; bCart.set(r.sku, l); drawCart();
    }));
  };

  const load = async () => {
    [rows, credit] = await Promise.all([get('/api/portal/catalog'), get('/api/portal/credit')]);
    $('#blockBanner', main).innerHTML = credit.blocked
      ? `<div class="warn-banner">🚫 ${esc(credit.blocked_reason)}</div>` : '';
    draw();
  };
  $('#cq', main).addEventListener('input', draw);
  $('#bsubmit', main).addEventListener('click', async () => {
    if (!bCart.size) return toast('Your cart is empty.', 'err');
    try {
      const r = await post('/api/portal/orders', {
        lines: [...bCart.values()].map((l) => ({ sku: l.sku, qty: l.qty })),
      });
      bCart.clear(); drawCart();
      toast(`Order #${r.order_id} submitted — stock reserved 🌸${r.invoice ? ` Invoice due ${day(r.invoice.due_date)}.` : ''}`, 'ok');
      load();
    } catch (e) { oops(e); load(); }
  });
  drawCart();
  await load();
  poll(load, 8000);
};

VIEWS.myorders = async (main) => {
  main.innerHTML = `<div class="topline"><h2>My Orders</h2></div><div class="panel tbl-wrap" id="mo"></div>`;
  const load = async () => {
    const rows = await get('/api/portal/orders');
    $('#mo', main).innerHTML = rows.length ? `<table>
      <tr><th>#</th><th>Placed</th><th>Items</th><th class="num">Total</th><th>Status</th><th>Invoice</th><th></th></tr>
      ${rows.map((o) => `<tr><td>${o.id}</td><td>${dt(o.created_at)}</td>
        <td class="mut">${o.lines.map((l) => `${l.qty}× ${esc(l.sku)}`).join(', ')}</td>
        <td class="num">${peso(o.total)}</td><td>${statusBadge(o)}</td>
        <td>${o.invoice_id ? (o.invoice_status === 'OPEN'
          ? `<span class="badge amber">${peso(o.invoice_balance)} due ${day(o.due_date)}</span>`
          : `<span class="badge ${o.invoice_status === 'PAID' ? 'green' : 'gray'}">${o.invoice_status}</span>`) : '—'}</td>
        <td>${['PLACED'].includes(o.status) ? `<button class="btn small danger" data-cx="${o.id}">Cancel</button>` : ''}</td>
      </tr>`).join('')}</table>` : '<div class="empty">You have not placed any orders yet.</div>';
    main.querySelectorAll('[data-cx]').forEach((b) => b.addEventListener('click', async () => {
      try { await post(`/api/portal/orders/${b.dataset.cx}/cancel`); toast('Cancelled — stock released.', 'ok'); load(); }
      catch (e) { oops(e); }
    }));
  };
  await load();
  poll(load);
};

VIEWS.credit = async (main) => {
  const load = async () => {
    const d = await get('/api/portal/credit');
    const r = d.reseller;
    main.innerHTML = `
      <div class="topline"><h2>Invoices &amp; Credit</h2></div>
      ${d.blocked ? `<div class="warn-banner">🚫 ${esc(d.blocked_reason)}</div>` : ''}
      <div class="cards">
        <div class="card"><div class="kpi">${tierBadge(r.tier)}</div><div class="kpi-label">
          ${r.tier === 1 ? 'Prepaid — pay before dispatch' : `Net ${r.payment_terms_days} terms`}</div></div>
        <div class="card"><div class="kpi">${peso(d.credit_limit)}</div><div class="kpi-label">Credit limit</div></div>
        <div class="card ${d.outstanding > 0 ? 'alert' : 'good'}"><div class="kpi">${peso(d.outstanding)}</div>
          <div class="kpi-label">Outstanding balance</div></div>
        <div class="card ${d.pay_to_unblock > 0 ? 'danger' : 'good'}"><div class="kpi">${peso(d.pay_to_unblock)}</div>
          <div class="kpi-label">Pay now to stay unblocked</div></div>
      </div>
      <div class="panel"><h3>Invoices</h3><div class="tbl-wrap">${d.invoices.length ? `<table>
        <tr><th>#</th><th>Issued</th><th>Due</th><th class="num">Amount</th><th class="num">Balance</th><th>Status</th></tr>
        ${d.invoices.map((i) => `<tr><td>${i.id}</td><td>${day(i.issued_at)}</td><td>${day(i.due_date)}</td>
          <td class="num">${peso(i.amount)}</td><td class="num">${peso(i.balance)}</td>
          <td>${i.status === 'PAID' ? `<span class="badge green">paid${Number(i.discount_applied) > 0 ? ' · early-pay −' + peso(i.discount_applied) : ''}</span>`
            : i.status === 'VOID' ? '<span class="badge gray">void</span>'
            : i.overdue ? '<span class="badge red">OVERDUE</span>' : '<span class="badge amber">open</span>'}</td>
        </tr>`).join('')}</table>` : '<div class="empty">No invoices yet.</div>'}</div>
      <div class="mut mt">💡 Pay a Net-30 invoice within 10 days of issue and 2% comes off automatically (2/10 net 30).</div></div>`;
  };
  await load();
  poll(load, 12000);
};

boot();

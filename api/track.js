// Customer-visible tracking page: ms-beau-ave.vercel.app/track/<trackingNo>
// Reads the order's shipment timeline from Supabase and renders the dusty-rose
// tracking page — a real, shareable URL (spec §5.5, acceptance check #5).
const SB = 'https://ihmselvxdpbkccwchqow.supabase.co/rest/v1';
const KEY = 'sb_publishable_SR4zrkB4SDH4T4yvWu19Nw_XSF5F_4c';
const STAGES = ['packed', 'handed to courier', 'in transit', 'out for delivery', 'delivered'];
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const page = (title, inner) => `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)} — Ms Beau Ave</title>
<style>body{font-family:Inter,system-ui,sans-serif;background:#F6E7E7;color:#3E2C2D;max-width:480px;margin:40px auto;padding:0 16px}
.card{background:#FAF6F4;border:1px solid #D8A7A7;border-radius:12px;padding:24px}h1{color:#9E5B5D;font-size:1.3rem}
ol{list-style:none;padding:0}li{padding:10px 0 10px 28px;border-left:3px solid #E8C4C4;margin-left:8px;position:relative;color:#a99a9a}
li.done{color:#3E2C2D;border-left-color:#C08081}li.done:before{content:"✓";position:absolute;left:8px;color:#5F8D6B}
.muted{color:#8a7374;font-size:.85rem}</style></head>
<body><div class="card">${inner}<p style="color:#9E5B5D;margin-top:14px">Ms Beau Ave — thank you for your order! 🌸</p></div></body></html>`;

export default async function handler(req, res) {
  const no = (req.query.no || '').toString();
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  if (!/^MBA\d{5,}$/.test(no)) {
    return res.status(400).send(page('Tracking', '<h1>Invalid tracking number</h1><p class="muted">Check the link from your order confirmation.</p>'));
  }
  const r = await fetch(`${SB}/orders?tracking_no=eq.${encodeURIComponent(no)}&select=order_no,customer_name,total,status,shipment`, {
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}` },
  });
  const rows = r.ok ? await r.json() : [];
  if (!rows.length) {
    return res.status(404).send(page('Tracking', `<h1>Tracking number not found</h1><p class="muted">No shipment found for ${esc(no)}. It may not be saved yet — ask the store to check your order.</p>`));
  }
  const o = rows[0];
  const courier = (o.shipment && o.shipment.courier) || 'Courier';
  const timeline = (o.shipment && o.shipment.timeline) || STAGES.map((st) => ({ status: st, ts: null }));
  const items = timeline.map((t) =>
    `<li class="${t.ts ? 'done' : ''}"><b>${esc(t.status)}</b>${t.ts ? ' — ' + new Date(t.ts).toLocaleString('en-PH', { timeZone: 'Asia/Manila' }) : ''}</li>`
  ).join('');
  res.setHeader('Cache-Control', 'no-store');
  return res.status(200).send(page(`Track ${no}`,
    `<h1>📦 ${esc(courier)} — ${esc(no)}</h1>
     <p>Order <b>${esc(o.order_no)}</b> for <b>${esc(o.customer_name)}</b> · ₱${esc(o.total)}</p>
     <ol>${items}</ol>`));
}

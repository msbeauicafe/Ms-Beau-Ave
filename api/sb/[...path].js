// Same-origin proxy to Supabase REST for the demo's two persistence tables.
// The browser talks only to ms-beau-ave.vercel.app, so client-side network
// filters can't break saving. The publishable key is already public in the
// static app; demo-grade RLS on the two tables is the actual guard.
const SB = 'https://ihmselvxdpbkccwchqow.supabase.co/rest/v1';
const KEY = 'sb_publishable_SR4zrkB4SDH4T4yvWu19Nw_XSF5F_4c';
const ALLOWED = /^(members|orders|promotions)$/;

export default async function handler(req, res) {
  const qIdx0 = req.url.indexOf('?');
  const pathname = qIdx0 >= 0 ? req.url.slice(0, qIdx0) : req.url;
  const path = decodeURIComponent(pathname.replace(/^\/api\/sb\/?/, '')).replace(/\/+$/, '');
  if (!ALLOWED.test(path)) return res.status(403).json({ error: 'table not allowed', got: path });
  if (!['GET', 'POST', 'PATCH'].includes(req.method)) return res.status(405).json({ error: 'method not allowed' });

  const qIdx = req.url.indexOf('?');
  const params = new URLSearchParams(qIdx >= 0 ? req.url.slice(qIdx + 1) : '');
  params.delete('path');
  params.delete('...path');
  const cleaned = params.toString();
  const qs = cleaned ? '?' + cleaned : '';

  const headers = { apikey: KEY, Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' };
  if (req.headers.prefer) headers.Prefer = req.headers.prefer;

  const upstream = await fetch(`${SB}/${path}${qs}`, {
    method: req.method,
    headers,
    body: ['POST', 'PATCH'].includes(req.method) ? JSON.stringify(req.body) : undefined,
  });

  if (upstream.status === 204) return res.status(204).end();
  const text = await upstream.text();
  res.status(upstream.status);
  res.setHeader('Content-Type', 'application/json');
  return res.send(text || 'null');
}

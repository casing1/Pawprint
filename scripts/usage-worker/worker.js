/**
 * Pawprint usage endpoint — a Cloudflare Worker backed by D1.
 *
 * Two routes:
 *   POST /ping   the app calls this once a day
 *   GET  /stats  aggregate counts, for scripts/stats.sh
 *
 * Runs comfortably inside Cloudflare's free tier: one row per install per day, and the app sends
 * at most one request each. See ../../docs/ANALYTICS.md for deployment.
 *
 * The rows deliberately cannot be joined into per-user histories. `day_hash` is
 * SHA256(installID + date) computed on the client, so the same install produces an unrelated
 * value tomorrow. Counting distinct hashes for a day gives daily actives; counting distinct
 * `month_hash` gives monthly actives. Nothing here can answer "when does this person use their
 * Mac", which is the point.
 *
 * No IP address is stored. Cloudflare sees one, as any HTTP service must, but it is never written
 * to the database and never logged.
 */

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

const SCHEMA = `
  CREATE TABLE IF NOT EXISTS pings (
    day        TEXT NOT NULL,
    day_hash   TEXT NOT NULL,
    month_hash TEXT NOT NULL,
    version    TEXT NOT NULL,
    os         TEXT NOT NULL,
    PRIMARY KEY (day, day_hash)
  );
`;

/** Rejects anything that isn't the exact shape the app sends. */
function clean(value, maxLength) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > maxLength) return null;
  // Hex hashes, dotted versions, plain integers — nothing else has any business being here.
  return /^[A-Za-z0-9._-]+$/.test(trimmed) ? trimmed : null;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') return new Response(null, { headers: CORS });

    await env.DB.prepare(SCHEMA).run();

    if (request.method === 'POST' && url.pathname === '/ping') {
      let body;
      try {
        body = await request.json();
      } catch {
        return new Response('bad json', { status: 400, headers: CORS });
      }

      const dayHash = clean(body.day, 64);
      const monthHash = clean(body.month, 64);
      const version = clean(body.version, 20);
      const os = clean(body.os, 10);
      if (!dayHash || !monthHash || !version || !os) {
        return new Response('bad payload', { status: 400, headers: CORS });
      }

      // The server picks the day, not the client: otherwise a bad clock (or anyone with curl)
      // could write rows into arbitrary dates.
      const day = new Date().toISOString().slice(0, 10);

      // OR IGNORE makes a duplicate ping a no-op rather than an inflated count.
      await env.DB.prepare(
        `INSERT OR IGNORE INTO pings (day, day_hash, month_hash, version, os)
         VALUES (?, ?, ?, ?, ?)`
      ).bind(day, dayHash, monthHash, version, os).run();

      return new Response('ok', { headers: CORS });
    }

    if (request.method === 'GET' && url.pathname === '/stats') {
      const today = new Date().toISOString().slice(0, 10);
      const month = today.slice(0, 7);

      const dau = await env.DB.prepare(
        `SELECT COUNT(*) AS n FROM pings WHERE day = ?`
      ).bind(today).first();

      const mau = await env.DB.prepare(
        `SELECT COUNT(DISTINCT month_hash) AS n FROM pings WHERE day LIKE ?`
      ).bind(month + '%').first();

      const daily = await env.DB.prepare(
        `SELECT day, COUNT(*) AS n FROM pings GROUP BY day ORDER BY day DESC LIMIT 30`
      ).all();

      const versions = await env.DB.prepare(
        `SELECT version, COUNT(DISTINCT month_hash) AS n FROM pings
         WHERE day LIKE ? GROUP BY version ORDER BY n DESC`
      ).bind(month + '%').all();

      return new Response(JSON.stringify({
        dau_today: dau?.n ?? 0,
        mau_month: mau?.n ?? 0,
        daily: (daily.results ?? []).map((r) => ({ day: r.day, count: r.n })),
        versions: (versions.results ?? []).map((r) => ({ version: r.version, count: r.n })),
      }, null, 2), { headers: { ...CORS, 'Content-Type': 'application/json' } });
    }

    return new Response('not found', { status: 404, headers: CORS });
  },
};

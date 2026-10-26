// Server-rendered landing page for the API root. No JavaScript: helmet's CSP
// blocks inline scripts, so all motion is CSS/SVG (inline styles are allowed)
// and the page refreshes itself with a meta tag to keep the numbers live.
const mongoose = require('mongoose');
const { version } = require('../package.json');

const APP_URL = 'https://ridify.onrender.com';
const REPO_URL = 'https://github.com/priyanshusharan-cmd/ridify';
const REFRESH_SECONDS = 30;
// Stop after this many reloads so a forgotten tab can't keep the free Render
// instance awake (it only sleeps after 15 min with no inbound requests).
const MAX_REFRESHES = 10;
const CHECK_TIMEOUT_MS = 2000;

function withTimeout(promise, ms) {
  return Promise.race([
    promise,
    new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), ms)),
  ]);
}

function formatUptime(seconds) {
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (d) return `${d}d ${h}h`;
  if (h) return `${h}h ${m}m`;
  if (m) return `${m}m ${s}s`;
  return `${s}s`;
}

// Runs the real checks. Each component gets state 'ok' | 'degraded' | 'down'.
async function collectStatus(io) {
  const started = Date.now();
  const components = {};

  // Database: actual round trip, not just the connection flag.
  let dbOk = false;
  if (mongoose.connection.readyState === 1) {
    try {
      const t = Date.now();
      await withTimeout(mongoose.connection.db.admin().ping(), CHECK_TIMEOUT_MS);
      const ms = Date.now() - t;
      dbOk = true;
      components.database = { state: ms > 500 ? 'degraded' : 'ok', value: `${ms} ms`, sub: 'MongoDB ping' };
    } catch {
      components.database = { state: 'down', value: 'Not responding', sub: 'MongoDB ping timed out' };
    }
  } else {
    const label = { 0: 'Disconnected', 2: 'Connecting', 3: 'Disconnecting' }[mongoose.connection.readyState] || 'Unavailable';
    components.database = { state: 'down', value: label, sub: 'MongoDB' };
  }

  // Realtime: Socket.IO engine state and live client count.
  if (io && io.engine) {
    const n = io.engine.clientsCount;
    components.realtime = { state: 'ok', value: `${n} online`, sub: `Socket.IO · ${n === 1 ? 'device' : 'devices'} connected` };
  } else {
    components.realtime = { state: 'down', value: 'Offline', sub: 'Socket.IO not running' };
  }

  // Rides: counts straight from the database.
  if (dbOk) {
    try {
      const Ride = require('../models/ride');
      const [live, open] = await withTimeout(Promise.all([
        Ride.countDocuments({ status: 'started' }),
        Ride.countDocuments({ status: { $in: ['available', 'accepted'] } }),
      ]), CHECK_TIMEOUT_MS);
      components.rides = { state: 'ok', value: `${live} on the road`, sub: `${open} open for booking` };
    } catch {
      components.rides = { state: 'degraded', value: 'Unknown', sub: 'Ride query failed' };
    }
  } else {
    components.rides = { state: 'down', value: 'Unknown', sub: 'Needs the database' };
  }

  // Users: registered accounts, verified drivers and this week's sign-ups.
  if (dbOk) {
    try {
      const User = require('../models/user');
      const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      const [total, verified, recent] = await withTimeout(Promise.all([
        User.estimatedDocumentCount(),
        User.countDocuments({ verificationStatus: 'verified' }),
        User.countDocuments({ createdAt: { $gte: weekAgo } }),
      ]), CHECK_TIMEOUT_MS);
      components.users = { state: 'ok', value: `${total} ${total === 1 ? 'member' : 'members'}`, sub: `${verified} verified · +${recent} this week` };
    } catch {
      components.users = { state: 'degraded', value: 'Unknown', sub: 'User query failed' };
    }
  } else {
    components.users = { state: 'down', value: 'Unknown', sub: 'Needs the database' };
  }

  const mem = process.memoryUsage().rss / 1024 / 1024;
  components.api = { state: 'ok', value: `v${version}`, sub: `Node ${process.version} · ${Date.now() - started} ms checks` };
  components.uptime = { state: 'ok', value: formatUptime(process.uptime()), sub: `${Math.round(mem)} MB memory` };

  return components;
}

const CARD_ORDER = [
  ['api', 'API'], ['database', 'Database'], ['realtime', 'Realtime'],
  ['rides', 'Rides'], ['users', 'Users'], ['uptime', 'Uptime'],
];
const ICONS = {
  api: '<polyline points="8 6 2 12 8 18"/><polyline points="16 6 22 12 16 18"/>',
  database: '<ellipse cx="12" cy="5" rx="8" ry="3"/><path d="M4 5v14c0 1.7 3.6 3 8 3s8-1.3 8-3V5"/><path d="M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3"/>',
  realtime: '<circle cx="12" cy="12" r="2"/><path d="M16.2 7.8a6 6 0 0 1 0 8.4M7.8 16.2a6 6 0 0 1 0-8.4M19 5a10 10 0 0 1 0 14M5 19A10 10 0 0 1 5 5"/>',
  rides: '<path d="M12 21s-6-5.5-6-10a6 6 0 0 1 12 0c0 4.5-6 10-6 10z"/><circle cx="12" cy="11" r="2"/>',
  users: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 14.5a6.5 6.5 0 0 1 3.5 5.5"/>',
  uptime: '<circle cx="12" cy="12" r="9"/><polyline points="12 7 12 12 15.5 14"/>',
};
const STATE_LABEL = { ok: 'Operational', degraded: 'Degraded', down: 'Down' };

function summary(components) {
  const bad = CARD_ORDER.filter(([k]) => components[k].state !== 'ok');
  if (!bad.length) return { state: 'ok', text: 'All systems operational' };
  const names = bad.map(([, label]) => label);
  const worst = bad.some(([k]) => components[k].state === 'down') ? 'down' : 'degraded';
  const list = names.length > 1 ? `${names.slice(0, -1).join(', ')} and ${names.at(-1)}` : names[0];
  const verb = worst === 'down' ? (names.length > 1 ? 'are down' : 'is down') : (names.length > 1 ? 'are degraded' : 'is degraded');
  return { state: worst, text: `${list} ${verb}` };
}

// Deterministic skyline so the page doesn't reshuffle on every refresh.
function skyline() {
  let seed = 7;
  const rand = () => (seed = (seed * 9301 + 49297) % 233280) / 233280;
  let out = '';
  for (let x = -10; x < 1290;) {
    const w = 44 + Math.floor(rand() * 60);
    const h = 16 + Math.floor(rand() * 26);
    const top = 300 - h;
    out += `<rect x="${x}" y="${top}" width="${w - 6}" height="${h}" fill="#141414"/>`;
    for (let wy = top + 10; wy < 290; wy += 12) {
      for (let wx = x + 8; wx < x + w - 14; wx += 12) {
        if (rand() < 0.22) {
          const d = (rand() * 3).toFixed(2);
          out += `<rect x="${wx}" y="${wy}" width="4" height="5" fill="#FFC107" opacity="${(0.15 + rand() * 0.2).toFixed(2)}" class="fl" style="animation-delay:-${d}s"/>`;
        }
      }
    }
    x += w;
  }
  return out;
}

function stars() {
  let seed = 3;
  const rand = () => (seed = (seed * 9301 + 49297) % 233280) / 233280;
  let out = '';
  for (let i = 0; i < 40; i++) {
    out += `<circle cx="${Math.floor(rand() * 1280)}" cy="${Math.floor(rand() * 170)}" r="${(0.6 + rand() * 0.8).toFixed(1)}" fill="#fff" class="tw" style="animation-delay:-${(rand() * 3).toFixed(2)}s;animation-duration:${(2 + rand() * 2.6).toFixed(1)}s"/>`;
  }
  return out;
}

const SKYLINE = skyline();
const STARS = stars();
const DASHES = Array.from({ length: 18 }, (_, i) =>
  `<rect x="${i * 80}" y="334" width="40" height="3" rx="1.5" fill="#E0E0E0" opacity=".35"/>`).join('');

function renderStatusPage(components, refreshCount = 0) {
  const count = Math.min(Math.max(parseInt(refreshCount, 10) || 0, 0), MAX_REFRESHES);
  const refreshing = count < MAX_REFRESHES;
  const overall = summary(components);
  const checkedAt = new Date().toUTCString().replace(' GMT', ' UTC');
  const year = new Date().getFullYear();

  const cardHtml = CARD_ORDER.map(([key, label], i) => {
    const c = components[key];
    return `
      <div class="card ${c.state}" style="animation-delay:${0.35 + i * 0.07}s">
        <div class="card-top">
          <span class="ico"><svg viewBox="0 0 24 24" aria-hidden="true">${ICONS[key]}</svg></span>
          <span class="label">${label}</span>
          <span class="badge ${c.state}" title="${STATE_LABEL[c.state]}"><i></i><b>${STATE_LABEL[c.state]}</b></span>
        </div>
        <div class="value">${c.value}</div>
        <div class="sub">${c.sub}</div>
      </div>`;
  }).join('');

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
${refreshing ? `<meta http-equiv="refresh" content="${REFRESH_SECONDS};url=/?r=${count + 1}">` : ''}
<meta name="robots" content="noindex">
<title>Ridify API · ${overall.state === 'ok' ? 'Operational' : 'Issues detected'}</title>
<link rel="icon" type="image/png" href="/static/favicon.png">
<link rel="apple-touch-icon" href="/static/logo.png">
<style>
  :root {
    --bg: #121212; --bg-deep: #050505; --surface: #1E1E1E; --surface-2: #2C2C2C; --line: #3A3A3A;
    --text: #FFFFFF; --muted: #9E9E9E; --faint: #616161;
    --ok: #4ADE80; --degraded: #FFC107; --down: #F44336;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    min-height: 100vh; color: var(--text);
    font-family: Roboto, 'Segoe UI', -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif;
    background: linear-gradient(180deg, var(--bg-deep), var(--bg) 60%);
    display: flex; flex-direction: column; align-items: center;
    padding: 40px 16px 28px;
  }
  body::before {
    content: ''; position: fixed; inset: 0; pointer-events: none;
    background-image: radial-gradient(rgba(158,158,158,.09) 1.1px, transparent 1.1px);
    background-size: 26px 26px;
  }
  main { width: 100%; max-width: 1040px; position: relative; }
  .rise { opacity: 0; animation: rise .7s cubic-bezier(.2,.7,.2,1) forwards; }
  @keyframes rise { from { opacity: 0; transform: translateY(14px); } to { opacity: 1; transform: none; } }

  /* Hero scene: same night road as the README banner */
  .hero { position: relative; border-radius: 28px; overflow: hidden; border: 1px solid var(--surface-2); background: #0A0A0A; }
  .scene { display: block; width: 100%; height: auto; }
  .hero-copy { position: absolute; left: 6.2%; top: 13%; right: 6%; }
  .eyebrow { display: flex; align-items: center; gap: 10px; font-size: clamp(9px, 1.25vw, 13px); font-weight: 700; letter-spacing: .28em; color: #BDBDBD; text-transform: uppercase; }
  .eyebrow img { width: clamp(22px, 3vw, 30px); height: clamp(22px, 3vw, 30px); border-radius: 8px; box-shadow: 0 0 0 1px var(--line); }
  h1 {
    margin-top: clamp(6px, 1.4vw, 14px); font-size: clamp(40px, 9vw, 104px); font-weight: 900; letter-spacing: -.035em; line-height: .95;
    background: linear-gradient(90deg, #fff 0%, #fff 42%, #8A8A8A 50%, #fff 58%, #fff 100%);
    background-size: 250% 100%; -webkit-background-clip: text; background-clip: text; color: transparent;
    animation: shimmer 6s linear infinite;
  }
  @keyframes shimmer { from { background-position: 100% 0; } to { background-position: -150% 0; } }
  @media (max-width: 640px) {
    .hero-copy { position: static; padding: 22px 20px 0; }
    .hero { display: flex; flex-direction: column-reverse; }
  }
  .tag { margin-top: clamp(6px, 1.2vw, 12px); font-size: clamp(13px, 2vw, 22px); font-weight: 500; color: #fff; }

  .tw { animation: tw 3s ease-in-out infinite; }
  @keyframes tw { 0%,100% { opacity: .15; } 50% { opacity: .9; } }
  .fl { animation: fl 2.6s steps(1) infinite; }
  @keyframes fl { 0%,100% { opacity: .75; } 40% { opacity: .2; } 55% { opacity: .75; } }
  .dash { animation: dash .55s linear infinite; }
  @keyframes dash { to { transform: translateX(-80px); } }
  .drive { animation: drive 9s linear infinite; }
  @keyframes drive { from { transform: translateX(-520px); } to { transform: translateX(1300px); } }
  .bob { animation: bob .45s ease-in-out infinite alternate; }
  @keyframes bob { to { transform: translateY(-1.6px); } }
  .tail { animation: blinkTail 1.1s ease-in-out infinite; }
  @keyframes blinkTail { 50% { opacity: .35; } }

  /* Overall status */
  .status-row { margin-top: 22px; display: flex; flex-wrap: wrap; align-items: center; justify-content: space-between; gap: 12px; }
  .status { display: inline-flex; align-items: center; gap: 10px; padding: 10px 18px 10px 14px; border-radius: 999px; background: var(--surface); border: 1px solid var(--surface-2); font-size: 15px; font-weight: 600; }
  .status.degraded { border-color: rgba(255,193,7,.45); }
  .status.down { border-color: rgba(244,67,54,.5); }
  .dot { position: relative; width: 10px; height: 10px; border-radius: 50%; background: var(--ok); }
  .dot.degraded { background: var(--degraded); } .dot.down { background: var(--down); }
  .dot::after { content: ''; position: absolute; inset: 0; border-radius: 50%; background: inherit; animation: ping 2s ease-out infinite; }
  @keyframes ping { from { transform: scale(1); opacity: .7; } to { transform: scale(2.8); opacity: 0; } }
  .checked { font-size: 12.5px; color: var(--faint); }
  .checked a { color: var(--muted); }
  .checked a:hover { color: #fff; }
  /* Skip the intro animation on auto-refreshes so the page doesn't flash */
  .settled .rise, .settled .card { opacity: 1; animation: none; }

  /* Component cards */
  .grid { margin-top: 16px; display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; }
  .card { min-width: 0; opacity: 0; animation: rise .6s cubic-bezier(.2,.7,.2,1) forwards; background: var(--surface); border: 1px solid var(--surface-2); border-radius: 18px; padding: 20px; transition: border-color .2s, transform .2s; }
  .card:hover { border-color: var(--line); transform: translateY(-2px); }
  .card.degraded { border-color: rgba(255,193,7,.4); }
  .card.down { border-color: rgba(244,67,54,.45); background: linear-gradient(180deg, rgba(244,67,54,.08), var(--surface)); }
  .card-top { display: flex; align-items: center; gap: 10px; }
  .ico { flex: none; width: 36px; height: 36px; border-radius: 10px; display: grid; place-items: center; background: var(--surface-2); color: #fff; }
  .ico svg { width: 18px; height: 18px; fill: none; stroke: currentColor; stroke-width: 1.8; stroke-linecap: round; stroke-linejoin: round; }
  .card.degraded .ico { color: var(--degraded); } .card.down .ico { color: var(--down); }
  .label { font-size: 12px; font-weight: 600; letter-spacing: .14em; text-transform: uppercase; color: var(--muted); min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .badge { margin-left: auto; flex: none; display: inline-flex; align-items: center; gap: 6px; padding: 4px 10px 4px 8px; border-radius: 999px; font-size: 11.5px; font-weight: 600; color: var(--ok); background: rgba(74,222,128,.1); }
  .badge b { font-weight: 600; }
  .badge i { width: 7px; height: 7px; border-radius: 50%; background: currentColor; box-shadow: 0 0 8px currentColor; }
  .badge.degraded { color: var(--degraded); background: rgba(255,193,7,.1); }
  .badge.down { color: var(--down); background: rgba(244,67,54,.12); }
  .value { margin-top: 18px; font-size: clamp(22px, 2.6vw, 30px); font-weight: 700; letter-spacing: -.01em; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .sub { margin-top: 6px; font-size: 13.5px; color: var(--muted); opacity: .8; }
  @media (max-width: 860px) { .grid { grid-template-columns: repeat(2, 1fr); } }
  @media (max-width: 480px) {
    .grid { gap: 10px; }
    .card { padding: 14px; border-radius: 16px; }
    .ico { width: 30px; height: 30px; border-radius: 9px; }
    .ico svg { width: 16px; height: 16px; }
    .label { font-size: 11px; letter-spacing: .1em; }
    .badge { padding: 0; background: none; }
    .badge b { display: none; }
    .value { margin-top: 12px; font-size: 20px; }
    .sub { font-size: 12px; }
  }

  .actions { margin-top: 24px; display: flex; flex-wrap: wrap; gap: 12px; }
  .btn { display: inline-flex; align-items: center; gap: 8px; padding: 13px 22px; border-radius: 12px; font-weight: 600; font-size: 15px; text-decoration: none; transition: transform .15s, background .2s; }
  .btn:hover { transform: translateY(-1px); }
  .btn.primary { background: #fff; color: #000; }
  .btn.primary:hover { background: #E0E0E0; }
  .btn.ghost { color: #fff; border: 1px solid var(--surface-2); }
  .btn.ghost:hover { background: var(--surface); }
  .btn .arrow { transition: transform .2s; }
  .btn:hover .arrow { transform: translateX(3px); }

  footer { margin-top: auto; padding-top: 40px; font-size: 13px; color: var(--faint); text-align: center; position: relative; }
  footer a { color: var(--muted); text-decoration: none; }
  footer a:hover { color: #fff; }

  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after { animation: none !important; transition: none !important; }
    .rise, .card { opacity: 1; }
    .drive { transform: translateX(380px); }
  }
</style>
</head>
<body${count > 0 ? ' class="settled"' : ''}>
<main>
  <section class="hero rise">
    <svg class="scene" viewBox="0 0 1280 400" aria-hidden="true">
      <defs>
        <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#050505"/><stop offset=".6" stop-color="#0E0E0E"/><stop offset="1" stop-color="#121212"/></linearGradient>
        <radialGradient id="glow" cx="1000" cy="120" r="420" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#fff" stop-opacity=".07"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
        <linearGradient id="beam" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stop-color="#fff" stop-opacity=".5"/><stop offset=".35" stop-color="#fff" stop-opacity=".18"/>
          <stop offset=".75" stop-color="#fff" stop-opacity=".04"/><stop offset="1" stop-color="#fff" stop-opacity="0"/>
        </linearGradient>
        <linearGradient id="road" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0A0A0A"/><stop offset="1" stop-color="#000"/></linearGradient>
      </defs>
      <rect width="1280" height="400" fill="url(#sky)"/>
      <rect width="1280" height="400" fill="url(#glow)"/>
      ${STARS}
      ${SKYLINE}
      <rect y="302" width="1280" height="98" fill="url(#road)"/>
      <line x1="0" y1="302.5" x2="1280" y2="302.5" stroke="#2C2C2C" stroke-opacity=".7"/>
      <g class="dash">${DASHES}</g>
      <g class="drive"><g class="bob">
        <polygon points="216,333 490,303 490,373" fill="url(#beam)" opacity=".75"/>
        <ellipse cx="115" cy="352" rx="106" ry="5" fill="#000" opacity=".55"/>
        <g opacity=".35" stroke="#fff" stroke-width="2" stroke-linecap="round">
          <line x1="-20" y1="321" x2="-90" y2="321"/><line x1="-38" y1="333" x2="-116" y2="333"/><line x1="-56" y1="345" x2="-142" y2="345"/>
        </g>
        <image href="/static/car.png" x="0" y="281" width="230" height="99"/>
        <g class="tail"><circle cx="8" cy="325" r="5" fill="#F44336" opacity=".9"/><circle cx="8" cy="325" r="14" fill="#F44336" opacity=".18"/></g>
      </g></g>
    </svg>
    <div class="hero-copy">
      <div class="eyebrow"><img src="/static/logo.png" alt="Ridify logo">Backend API</div>
      <h1>Ridify</h1>
      <p class="tag">Share the ride. Split the fare. Track it live.</p>
    </div>
  </section>

  <div class="status-row rise" style="animation-delay:.2s">
    <div class="status ${overall.state}" role="status"><span class="dot ${overall.state}"></span>${overall.text}</div>
    <div class="checked">Checked ${checkedAt} · ${refreshing ? `refreshes every ${REFRESH_SECONDS}s` : '<a href="/">Auto-refresh paused · reload to check again</a>'}</div>
  </div>

  <div class="grid">${cardHtml}
  </div>

  <div class="actions rise" style="animation-delay:.75s">
    <a class="btn primary" href="${APP_URL}">Open Ridify <span class="arrow">→</span></a>
    <a class="btn ghost" href="${REPO_URL}">View on GitHub</a>
  </div>
</main>
<footer>© ${year} Ridify · Built by <a href="${REPO_URL}">Priyanshu Sharan</a> · MIT License</footer>
</body>
</html>`;
}

module.exports = { collectStatus, renderStatusPage, summary };

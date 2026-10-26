// Server-rendered landing page for the API root. No JavaScript: helmet's CSP
// blocks inline scripts, so all motion is CSS/SVG (inline styles are allowed).
const { version } = require('../package.json');

const APP_URL = 'https://ridify.onrender.com';
const REPO_URL = 'https://github.com/priyanshusharan-cmd/ridify';

function formatUptime(seconds) {
  const d = Math.floor(seconds / 86400);
  const h = Math.floor((seconds % 86400) / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  if (d) return `${d}d ${h}h`;
  if (h) return `${h}h ${m}m`;
  return `${m}m`;
}

function renderStatusPage({ dbConnected, uptimeSeconds }) {
  const ok = dbConnected;
  const statusText = ok ? 'All systems operational' : 'Degraded: database reconnecting';
  const year = new Date().getFullYear();

  const cards = [
    ['API', `v${version}`, 'Express 5 · Node.js', true],
    ['Uptime', formatUptime(uptimeSeconds), 'since last deploy', true],
    ['Database', ok ? 'Connected' : 'Reconnecting', 'MongoDB', ok],
    ['Realtime', 'Active', 'Socket.IO · live GPS & chat', true],
  ];

  const cardHtml = cards.map(([label, value, sub, good], i) => `
      <div class="card" style="animation-delay:${0.35 + i * 0.08}s">
        <div class="card-top"><span class="label">${label}</span><span class="pip ${good ? 'ok' : 'warn'}"></span></div>
        <div class="value">${value}</div>
        <div class="sub">${sub}</div>
      </div>`).join('');

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Ridify API</title>
<style>
  :root {
    --bg: #121212; --bg-deep: #050505; --surface: #1E1E1E; --surface-2: #2C2C2C;
    --text: #FFFFFF; --muted: #9E9E9E; --faint: #616161;
    --live: #4ADE80; --warn: #FBBF24;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    min-height: 100vh; color: var(--text);
    font-family: Roboto, 'Segoe UI', -apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif;
    background:
      radial-gradient(circle at 80% 10%, rgba(255,255,255,.06), transparent 45%),
      radial-gradient(circle at 10% 20%, rgba(255,255,255,.03), transparent 40%),
      linear-gradient(180deg, var(--bg-deep), var(--bg) 60%);
    display: flex; flex-direction: column; align-items: center;
    padding: 56px 16px 32px;
  }
  body::before {
    content: ''; position: fixed; inset: 0; pointer-events: none;
    background-image: radial-gradient(rgba(158,158,158,.09) 1.1px, transparent 1.1px);
    background-size: 26px 26px;
  }
  main { width: 100%; max-width: 880px; position: relative; }
  .rise { opacity: 0; animation: rise .7s cubic-bezier(.2,.7,.2,1) forwards; }
  @keyframes rise { from { opacity: 0; transform: translateY(14px); } to { opacity: 1; transform: none; } }

  .brand { display: flex; align-items: center; gap: 12px; font-size: 13px; letter-spacing: .22em; color: var(--muted); text-transform: uppercase; }
  .brand svg { flex: none; }
  h1 {
    margin-top: 18px; font-size: clamp(44px, 9vw, 76px); font-weight: 800; letter-spacing: -.03em; line-height: 1;
    background: linear-gradient(90deg, #fff 0%, #fff 42%, #8A8A8A 50%, #fff 58%, #fff 100%);
    background-size: 250% 100%; -webkit-background-clip: text; background-clip: text; color: transparent;
    animation: shimmer 6s linear infinite;
  }
  @keyframes shimmer { from { background-position: 100% 0; } to { background-position: -150% 0; } }
  .tag { margin-top: 12px; font-size: 17px; color: var(--muted); }

  .status {
    margin-top: 28px; display: inline-flex; align-items: center; gap: 10px;
    padding: 10px 16px 10px 14px; border-radius: 999px;
    background: var(--surface); border: 1px solid var(--surface-2); font-size: 14px; font-weight: 500;
  }
  .dot { position: relative; width: 10px; height: 10px; border-radius: 50%; background: var(--live); }
  .dot::after { content: ''; position: absolute; inset: 0; border-radius: 50%; background: inherit; animation: ping 2s ease-out infinite; }
  .dot.warn { background: var(--warn); }
  @keyframes ping { from { transform: scale(1); opacity: .7; } to { transform: scale(2.8); opacity: 0; } }

  .road { margin-top: 36px; border-radius: 22px; overflow: hidden; border: 1px solid var(--surface-2); background: #0A0A0A; }
  .road svg { display: block; width: 100%; height: auto; }
  .car { animation: drive 7s cubic-bezier(.45,0,.55,1) infinite; }
  @keyframes drive { from { transform: translateX(-200px); } to { transform: translateX(1000px); } }
  .lane { animation: lane 1s linear infinite; }
  @keyframes lane { to { stroke-dashoffset: -48; } }
  .pin { animation: bob 2.4s ease-in-out infinite; transform-origin: center; }
  @keyframes bob { 50% { transform: translateY(-5px); } }

  .grid { margin-top: 20px; display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; }
  @media (max-width: 720px) { .grid { grid-template-columns: repeat(2, 1fr); } }
  .card { opacity: 0; animation: rise .6s cubic-bezier(.2,.7,.2,1) forwards; background: var(--surface); border: 1px solid var(--surface-2); border-radius: 16px; padding: 16px; transition: border-color .2s, transform .2s; }
  .card:hover { border-color: #3a3a3a; transform: translateY(-2px); }
  .card-top { display: flex; justify-content: space-between; align-items: center; }
  .label { font-size: 12px; letter-spacing: .12em; text-transform: uppercase; color: var(--muted); }
  .pip { width: 7px; height: 7px; border-radius: 50%; }
  .pip.ok { background: var(--live); box-shadow: 0 0 8px rgba(74,222,128,.6); }
  .pip.warn { background: var(--warn); box-shadow: 0 0 8px rgba(251,191,36,.6); }
  .value { margin-top: 10px; font-size: 22px; font-weight: 700; }
  .sub { margin-top: 4px; font-size: 12.5px; color: var(--faint); }

  .actions { margin-top: 28px; display: flex; flex-wrap: wrap; gap: 12px; }
  .btn { display: inline-flex; align-items: center; gap: 8px; padding: 13px 22px; border-radius: 12px; font-weight: 600; font-size: 15px; text-decoration: none; transition: transform .15s, background .2s; }
  .btn:hover { transform: translateY(-1px); }
  .btn.primary { background: #fff; color: #000; }
  .btn.primary:hover { background: #E0E0E0; }
  .btn.ghost { color: #fff; border: 1px solid var(--surface-2); background: transparent; }
  .btn.ghost:hover { background: var(--surface); }
  .btn .arrow { transition: transform .2s; }
  .btn:hover .arrow { transform: translateX(3px); }

  footer { margin-top: auto; padding-top: 48px; font-size: 13px; color: var(--faint); text-align: center; position: relative; }
  footer a { color: var(--muted); text-decoration: none; }
  footer a:hover { color: #fff; }

  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after { animation: none !important; transition: none !important; }
    .rise, .card { opacity: 1; }
    .car { transform: translateX(400px); }
  }
</style>
</head>
<body>
<main>
  <div class="brand rise">
    <svg width="28" height="28" viewBox="0 0 28 28" aria-hidden="true">
      <rect width="28" height="28" rx="8" fill="#fff"/>
      <path d="M7 17.5l1.6-4.3A2 2 0 0 1 10.5 12h7a2 2 0 0 1 1.9 1.2l1.6 4.3V20a1 1 0 0 1-1 1h-1a1 1 0 0 1-1-1v-.5H10.5v.5a1 1 0 0 1-1 1h-1a1 1 0 0 1-1-1z" fill="#000"/>
      <circle cx="10" cy="17.2" r="1" fill="#fff"/><circle cx="18" cy="17.2" r="1" fill="#fff"/>
    </svg>
    Backend API
  </div>
  <h1 class="rise" style="animation-delay:.05s">Ridify</h1>
  <p class="tag rise" style="animation-delay:.12s">Share the ride, split the fare, track it live.</p>

  <div class="status rise" style="animation-delay:.2s" role="status">
    <span class="dot ${ok ? '' : 'warn'}"></span>${statusText}
  </div>

  <div class="road rise" style="animation-delay:.28s">
    <svg viewBox="0 0 880 150" aria-hidden="true">
      <defs>
        <linearGradient id="beam" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stop-color="#fff" stop-opacity=".45"/>
          <stop offset=".4" stop-color="#fff" stop-opacity=".12"/>
          <stop offset="1" stop-color="#fff" stop-opacity="0"/>
        </linearGradient>
        <linearGradient id="fade" x1="0" y1="0" x2="1" y2="0">
          <stop offset="0" stop-color="#0A0A0A"/><stop offset=".08" stop-color="#0A0A0A" stop-opacity="0"/>
          <stop offset=".92" stop-color="#0A0A0A" stop-opacity="0"/><stop offset="1" stop-color="#0A0A0A"/>
        </linearGradient>
      </defs>
      <!-- route line -->
      <path d="M40 60 C 220 20, 330 100, 480 58 S 760 30, 840 56" fill="none" stroke="#2C2C2C" stroke-width="2" stroke-dasharray="2 8" stroke-linecap="round"/>
      <circle cx="40" cy="60" r="5" fill="#fff"/>
      <g class="pin">
        <path d="M840 34c-7 0-12 5-12 11.5 0 8.5 12 19.5 12 19.5s12-11 12-19.5C852 39 847 34 840 34z" fill="#4ADE80"/>
        <circle cx="840" cy="45.5" r="4" fill="#0A0A0A"/>
      </g>
      <!-- road -->
      <rect x="0" y="96" width="880" height="54" fill="#000"/>
      <line x1="0" y1="96" x2="880" y2="96" stroke="#1E1E1E"/>
      <line class="lane" x1="0" y1="123" x2="880" y2="123" stroke="#3a3a3a" stroke-width="3" stroke-dasharray="24 24"/>
      <!-- car -->
      <g class="car">
        <path d="M118 104 L330 92 L330 136 L118 124 Z" fill="url(#beam)"/>
        <g transform="translate(40 96)">
          <path d="M6 26 L14 12 Q17 7 23 7 L55 7 Q61 7 64 12 L72 26 Q78 27 78 32 L78 36 Q78 39 75 39 L3 39 Q0 39 0 36 L0 32 Q0 27 6 26 Z" fill="#fff"/>
          <path d="M18 24 L24 12 L38 12 L38 24 Z M42 12 L54 12 L60 24 L42 24 Z" fill="#121212"/>
          <circle cx="18" cy="39" r="7" fill="#121212" stroke="#fff" stroke-width="2"/>
          <circle cx="60" cy="39" r="7" fill="#121212" stroke="#fff" stroke-width="2"/>
          <rect x="72" y="29" width="6" height="4" rx="1" fill="#FFF7D6"/>
        </g>
      </g>
      <rect width="880" height="150" fill="url(#fade)"/>
    </svg>
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

module.exports = { renderStatusPage };

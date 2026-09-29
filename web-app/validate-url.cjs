'use strict';
const raw = process.env.BACKEND_URL || '';
try {
  const url = new URL(raw);
  const local = process.env.ALLOW_HTTP_LOCALHOST === '1' &&
    ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname) && url.protocol === 'http:';
  if ((url.protocol !== 'https:' && !local) || url.username || url.password ||
      url.search || url.hash || (url.pathname !== '/' && url.pathname !== '')) {
    throw new Error('Expected an HTTPS origin without credentials, path, query, or fragment.');
  }
  process.stdout.write(url.origin);
} catch {
  console.error('Invalid BACKEND_URL. Use https://your-backend.onrender.com (no /api). For local testing only, set ALLOW_HTTP_LOCALHOST=1.');
  process.exit(1);
}

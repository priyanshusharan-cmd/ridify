require('dotenv').config();
const os = require('os');
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const http = require('http');

const authRoutes = require('./routes/auth');
const rideRoutes = require('./routes/rides');

const app = express();
const server = http.createServer(app);

// ── Security headers ────────────────────────────────────────────────────────
app.use(helmet());

// ── CORS — only allow the configured origin ─────────────────────────────────
const allowedOrigin = process.env.ALLOWED_ORIGIN || '*';
app.use(cors({
  origin: allowedOrigin,
  methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'x-admin-email', 'x-admin-secret'],
}));

// ── Request logging ─────────────────────────────────────────────────────────
app.use(morgan('dev'));

// ── Body parsing — 1 MB is sufficient for route payloads ───────────────────
app.use(express.json({ limit: '1mb' }));

// ── Global rate limiter — 200 requests per minute per IP ───────────────────
const globalLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests, please slow down.' },
});
app.use(globalLimiter);

// ── Stricter limiter for auth endpoints ─────────────────────────────────────
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20,
  message: { error: 'Too many auth attempts, try again in 15 minutes.' },
});

// ── Setup Socket.IO ─────────────────────────────────────────────────────────
const { io } = require('./config/socket')(server, app);

const PORT = process.env.PORT || 5001;

// ── Connect to MongoDB ──────────────────────────────────────────────────────
require('./config/db')();

// ── Routes ──────────────────────────────────────────────────────────────────
app.get('/', (req, res) => { res.send('🚗 Ridify Backend API is running!'); });
app.use('/api/auth', authLimiter, authRoutes);
app.use('/api/rides', rideRoutes);

// ── Global error handler ────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// ── Graceful shutdown ───────────────────────────────────────────────────────
const shutdown = (signal) => {
  console.log(`${signal} received. Shutting down gracefully.`);
  server.close(() => {
    console.log('HTTP server closed.');
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10000);
};
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// ── Start ───────────────────────────────────────────────────────────────────
let localIp = 'localhost';
const networkInterfaces = os.networkInterfaces();
for (const name in networkInterfaces) {
  for (const iface of networkInterfaces[name]) {
    if (iface.family === 'IPv4' && !iface.internal) { localIp = iface.address; break; }
  }
  if (localIp !== 'localhost') break;
}
server.listen(PORT, '0.0.0.0', () =>
  console.log(`🚀 Server running on http://${localIp}:${PORT}`)
);
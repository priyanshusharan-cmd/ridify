require('dotenv').config();
const logger = require('./utils/logger');
const REQUIRED_ENV = ['JWT_SECRET', 'MONGO_URI', 'ADMIN_SECRET', 'ADMIN_EMAILS'];
const MISSING = REQUIRED_ENV.filter(k => !process.env[k] ||
  process.env[k].includes('your-') ||
  process.env[k].includes('example.com'));
if (MISSING.length > 0) {
  logger.error('FATAL: Missing or placeholder env vars:', MISSING.join(', '));
  process.exit(1);
}
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
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      objectSrc: ["'none'"],
      upgradeInsecureRequests: [],
    },
  },
  hsts: { maxAge: 31536000, includeSubDomains: true },
  noSniff: true,
  frameguard: { action: 'deny' },
}));

// ── CORS — strict check against ALLOWED_ORIGIN ──────────────────────────────
const allowedOrigins = (process.env.ALLOWED_ORIGIN || '').split(',').map(s => s.trim()).filter(Boolean);
app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes('*') || allowedOrigins.includes(origin)) return callback(null, true);
    callback(new Error(`CORS: Origin ${origin} not allowed`));
  },
  methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-admin-email', 'x-admin-secret'],
  credentials: true,
}));

// ── Request logging ─────────────────────────────────────────────────────────
app.use(morgan('dev', {
  skip: (req) => req.path === '/health',
}));

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
  windowMs: 15 * 60 * 1000,
  max: 10,
  keyGenerator: (req) => req.body?.email
    ? `${req.ip}_${req.body.email.toLowerCase()}`
    : req.ip,
  message: { error: 'Too many auth attempts. Please wait 15 minutes.' },
  standardHeaders: true,
  legacyHeaders: false,
});

const rideLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  keyGenerator: (req) => req.user?.email || req.ip,
  message: { error: 'Too many ride actions. Please slow down.' },
});

// ── Setup Socket.IO ─────────────────────────────────────────────────────────
const { io } = require('./config/socket')(server, app);

const PORT = process.env.PORT || 5001;

// ── Connect to MongoDB ──────────────────────────────────────────────────────
require('./config/db')();

// ── Routes ──────────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  const dbState = require('mongoose').connection.readyState;
  res.status(dbState === 1 ? 200 : 503).json({
    status: dbState === 1 ? 'ok' : 'degraded',
    db: ['disconnected','connected','connecting','disconnecting'][dbState] || 'unknown',
    uptime: process.uptime(),
  });
});
app.get('/', (req, res) => { res.send('🚗 Ridify Backend API is running!'); });
app.use('/api/auth', authLimiter, authRoutes);
app.use('/api/rides', rideLimiter, rideRoutes);

// ── Global error handler ────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', err.message || err);
  const status = err.status || err.statusCode || 500;
  res.status(status).json({
    error: process.env.NODE_ENV === 'production'
      ? 'Internal server error'
      : err.message,
  });
});

// ── Graceful shutdown ───────────────────────────────────────────────────────
const shutdown = (signal) => {
  logger.info(`${signal} received. Shutting down gracefully.`);
  server.close(() => {
    logger.info('HTTP server closed.');
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10000);
};
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('unhandledRejection', (reason, promise) => {
  logger.error('⚠️  Unhandled Promise Rejection:', reason);
});

process.on('uncaughtException', (error) => {
  logger.error('💥 Uncaught Exception:', error);
  process.exit(1);
});

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
  logger.info(`🚀 Server running on http://${localIp}:${PORT}`)
);
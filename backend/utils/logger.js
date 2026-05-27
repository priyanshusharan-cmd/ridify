const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || (process.env.NODE_ENV === 'production' ? 'warn' : 'debug'),
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    process.env.NODE_ENV === 'production'
      ? winston.format.json()
      : winston.format.colorize({ all: true }),
    process.env.NODE_ENV !== 'production'
      ? winston.format.simple()
      : winston.format.json()
  ),
  transports: [
    new winston.transports.Console(),
  ],
  // Prevent logging sensitive fields
  defaultMeta: { service: 'ridify-backend' },
});

// Sanitize: never log passwords or tokens
const originalLog = logger.log.bind(logger);
logger.log = (level, message, ...args) => {
  const sanitized = typeof message === 'string'
    ? message.replace(/(password|token|secret|Bearer\s+\S+)/gi, '[REDACTED]')
    : message;
  return originalLog(level, sanitized, ...args);
};

module.exports = logger;

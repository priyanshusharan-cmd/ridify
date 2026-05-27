require('dotenv').config();
const logger = require('../utils/logger');
const mongoose = require('mongoose');

const MAX_RETRIES = 5;
const BASE_DELAY_MS = 1000;

async function connectDB() {
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      await mongoose.connect(process.env.MONGO_URI, {
        serverSelectionTimeoutMS: 10000,
        socketTimeoutMS: 45000,
        connectTimeoutMS: 10000,
      });
      logger.info('✅ MongoDB Connected!');
      return;
    } catch (err) {
      logger.error(`❌ DB connection attempt ${attempt}/${MAX_RETRIES} failed:`, err.message);
      if (attempt === MAX_RETRIES) {
        logger.error('FATAL: Could not connect to MongoDB after max retries.');
        process.exit(1);
      }
      const delay = BASE_DELAY_MS * Math.pow(2, attempt - 1);
      logger.warn(`⏳ Retrying in ${delay}ms...`);
      await new Promise(r => setTimeout(r, delay));
    }
  }
}

module.exports = connectDB;

// Event listeners outside the function:
mongoose.connection.on('disconnected', () => {
  logger.warn('⚠️ MongoDB disconnected. Mongoose will auto-reconnect...');
});
mongoose.connection.on('error', (err) => {
  logger.error('❌ Mongoose runtime error:', err.message);
});

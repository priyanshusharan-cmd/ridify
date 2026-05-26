require('dotenv').config();
const mongoose = require('mongoose');

module.exports = () => {
  mongoose.connect(process.env.MONGO_URI, {
    serverSelectionTimeoutMS: 10000,
    socketTimeoutMS: 45000,
    connectTimeoutMS: 10000,
  })
    .then(() => console.log('✅ MongoDB Connected!'))
    .catch(err => {
      console.error('❌ DB Error:', err);
      process.exit(1);
    });

  mongoose.connection.on('disconnected', () =>
    console.warn('⚠️ MongoDB disconnected. Attempting to reconnect...')
  );
  mongoose.connection.on('error', (err) =>
    console.error('❌ Mongoose error:', err)
  );
};

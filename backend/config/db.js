require('dotenv').config();
const mongoose = require('mongoose');

module.exports = () => mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log("✅ MongoDB Connected!"))
  .catch(err => console.error("❌ DB Error:", err));

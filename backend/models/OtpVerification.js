const mongoose = require('mongoose');

const OtpVerificationSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    lowercase: true,
    trim: true,
  },
  otp: { type: String, required: true },
  createdAt: { type: Date, default: Date.now, expires: 600 }, // Automatically delete document after 10 minutes (600s)
  lastOtpSentAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model('OtpVerification', OtpVerificationSchema);

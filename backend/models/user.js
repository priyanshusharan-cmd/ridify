const mongoose = require('mongoose');
const MAX = parseInt(process.env.MAX_FIELD_LENGTH) || 500;

const UserSchema = new mongoose.Schema({
  name: { type: String, required: true, maxlength: MAX, trim: true },
  age:  { type: String, maxlength: 3 },
  email: {
    type: String,
    unique: true,
    required: true,
    lowercase: true,   // forces to lowercase before save
    trim: true,
    maxlength: MAX,
  },
  password: { type: String, select: false, required: true },
  isVerified: { type: Boolean, default: false },
  otp: { type: String, select: false },
  otpExpiry: { type: Date, select: false },
  otpAttempts: { type: Number, default: 0, select: false },
  lastOtpSentAt: { type: Date, select: false },
  refreshTokens: { type: [String], default: [], select: false },
  isBanned: { type: Boolean, default: false },
  documentsVerified: { type: Boolean, default: false },
  verificationStatus: { type: String, enum: ['none', 'pending', 'verified'], default: 'none' },
  idUrl: { type: String },
}, { timestamps: true });

UserSchema.index({ email: 1 }, { unique: true });
UserSchema.index({ createdAt: 1 });

module.exports = mongoose.model('User', UserSchema);

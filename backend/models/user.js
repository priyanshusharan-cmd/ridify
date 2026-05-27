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
}, { timestamps: true });

UserSchema.index({ email: 1 }, { unique: true });
UserSchema.index({ createdAt: 1 });

module.exports = mongoose.model('User', UserSchema);

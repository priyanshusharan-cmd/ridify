const mongoose = require('mongoose');

const SOSAlertSchema = new mongoose.Schema({
  userEmail: { type: String, required: true },
  location: {
    lat: { type: Number, required: true },
    lng: { type: Number, required: true }
  },
  status: { type: String, enum: ['active', 'resolved'], default: 'active' },
}, { timestamps: true });

module.exports = mongoose.model('SOSAlert', SOSAlertSchema);

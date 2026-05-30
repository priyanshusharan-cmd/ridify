const mongoose = require('mongoose');

const DisputeSchema = new mongoose.Schema({
  rideId: { type: mongoose.Schema.Types.ObjectId, ref: 'Ride', required: true },
  reporterEmail: { type: String, required: true },
  reason: { type: String, required: true },
  status: { type: String, enum: ['open', 'resolved'], default: 'open' },
}, { timestamps: true });

module.exports = mongoose.model('Dispute', DisputeSchema);

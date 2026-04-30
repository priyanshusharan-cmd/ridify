const mongoose = require('mongoose');

const RideSchema = new mongoose.Schema({
  riderName: String,
  pickupLocation: String,
  destination: String,
  departureTime: { type: String, default: "Immediate" }, 
  fare: Number,
  status: { type: String, default: 'pending' },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('Ride', RideSchema);
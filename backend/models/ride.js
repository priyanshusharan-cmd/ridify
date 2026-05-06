const mongoose = require('mongoose');

const RideSchema = new mongoose.Schema({
  riderName: String,
  pickupLocation: String,
  pickupLat: Number,
  pickupLng: Number,
  destination: String,
  destLat: Number,
  destLng: Number,
  pickupCoords: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], default: [0, 0] }
  },
  departureTime: String,
  expiresAt: Number,
  fare: Number,
  status: String,
  vehicleType: String,
  totalSeats: Number,
  availableSeats: Number,
  requests: { type: [String], default: [] },
  passengers: { type: [String], default: [] },
  boardedPassengers: { type: [String], default: [] },
  declined: { type: [String], default: [] },
  kicked: { type: [String], default: [] },
  seatAllocations: { type: Map, of: Number, default: {} },
  chatMessages: [{ sender: String, text: String, timestamp: String }]
});
RideSchema.index({ pickupCoords: "2dsphere" });

module.exports = mongoose.model('Ride', RideSchema);

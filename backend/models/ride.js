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
  routePath: [{ lat: Number, lng: Number }],
  totalDistance: Number,
  routePreference: { type: String, enum: ['flexible', 'shared_start', 'nonstop'], default: 'flexible' },
  riderDetails: {
    type: Map,
    of: new mongoose.Schema({
      pickupLat: Number,
      pickupLng: Number,
      destLat: Number,
      destLng: Number,
      fare: Number,
      distance: Number,
      seats: Number,
      startIndex: Number,
      endIndex: Number,
      paid: { type: Boolean, default: false }
    }),
    default: {}
  },
  requests: { type: [String], default: [] },
  passengers: { type: [String], default: [] },
  boardedPassengers: { type: [String], default: [] },
  droppedPassengers: { type: [String], default: [] },
  paidPassengers: { type: [String], default: [] },
  declined: { type: [String], default: [] },
  kicked: { type: [String], default: [] },
  seatAllocations: { type: Map, of: Number, default: {} },
  chatMessages: [{ sender: String, text: String, timestamp: String }]
});
RideSchema.index({ pickupCoords: "2dsphere" });

module.exports = mongoose.model('Ride', RideSchema);

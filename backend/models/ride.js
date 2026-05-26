const mongoose = require('mongoose');

const CHAT_MAX_LENGTH = parseInt(process.env.CHAT_MAX_LENGTH) || 1000;

const RideSchema = new mongoose.Schema({
  riderName: String,
  riderEmail: String,
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
  status: {
    type: String,
    enum: ['available', 'accepted', 'full', 'started', 'completed', 'cancelled'],
    default: 'available',
  },
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
      pickupLocation: String,
      destination: String,
      fare: Number,
      distance: Number,
      seats: Number,
      startIndex: Number,
      endIndex: Number,
      paid: { type: Boolean, default: false },
      riderName: String,
      boardedAt: Date,
      droppedAt: Date,
      kickedAt: Date
    }),
    default: {}
  },
  requests: { type: [String], default: [] },
  passengers: { type: [String], default: [] },
  boardedPassengers: { type: [String], default: [] },
  droppedPassengers: { type: [String], default: [] },
  paidPassengers: { type: [String], default: [] },
  arrivedAt: { type: [String], default: [] },
  declined: { type: [String], default: [] },
  kicked: { type: [String], default: [] },
  seatAllocations: { type: Map, of: Number, default: {} },
  chatMessages: {
    type: [{
      sender: { type: String, maxlength: 200 },
      senderEmail: { type: String, maxlength: 200 },
      text: { type: String, maxlength: CHAT_MAX_LENGTH },
      timestamp: String,
    }],
    validate: [arr => arr.length <= 500, 'Chat history limit reached (max 500 messages)'],
  },
  startedAt: Date,
  completedAt: Date
}, {
  timestamps: true,
  toJSON: {
    transform: (doc, ret) => {
      if (ret.riderDetails) {
        const decodedDetails = {};
        for (const [key, value] of Object.entries(ret.riderDetails)) {
          decodedDetails[key.replace(/_dot_/g, '.')] = value;
        }
        ret.riderDetails = decodedDetails;
      }
      if (ret.seatAllocations) {
        const decodedAllocations = {};
        for (const [key, value] of Object.entries(ret.seatAllocations)) {
          decodedAllocations[key.replace(/_dot_/g, '.')] = value;
        }
        ret.seatAllocations = decodedAllocations;
      }
      return ret;
    }
  }
});
RideSchema.index({ pickupCoords: "2dsphere" });

module.exports = mongoose.model('Ride', RideSchema);

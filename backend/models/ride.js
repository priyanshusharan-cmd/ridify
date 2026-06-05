const mongoose = require('mongoose');

const CHAT_MAX_LENGTH = parseInt(process.env.CHAT_MAX_LENGTH) || 1000;

const RideSchema = new mongoose.Schema({
  riderName:      { type: String, maxlength: 200, trim: true },
  riderEmail:     { type: String, required: true, lowercase: true, trim: true, maxlength: 500 },
  driverVerificationStatus: { type: String, enum: ['none', 'pending', 'verified'], default: 'none' },
  pickupLocation: { type: String, required: true, maxlength: 500, trim: true },
  pickupLat: Number,
  pickupLng: Number,
  destination:    { type: String, required: true, maxlength: 500, trim: true },
  destLat: Number,
  destLng: Number,
  pickupCoords: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], default: [0, 0] }
  },
  departureTime: String,
  expiresAt: Number,
  optimisticLock: { type: Number, default: 0 },
  fare:           { type: Number, required: true, min: 1 },
  status: {
    type: String,
    enum: ['available', 'accepted', 'full', 'started', 'completed', 'cancelled'],
    default: 'available',
  },
  vehicleType:    { type: String, required: true, enum: ['Bike', 'Sedan', 'SUV'] },
  totalSeats:     { type: Number, required: true, min: 1, max: 8 },
  availableSeats: Number,
  routePath:      { type: [{ lat: Number, lng: Number }], required: true },
  totalDistance: Number,
  routePreference:{ type: String, required: true, enum: ['flexible', 'shared_start', 'nonstop'], default: 'flexible' },
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
      verificationStatus: { type: String, enum: ['none', 'pending', 'verified'], default: 'none' },
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
      replyTo: {
        sender: String,
        text: String
      }
    }],
    validate: [arr => arr.length <= 500, 'Chat history limit reached (max 500 messages)'],
  },
  startedAt: Date,
  completedAt: Date
}, {
  timestamps: true,
  toJSON: {
    transform: (doc, ret) => {
      const { keyToEmail } = require('../utils/emailKey');
      if (ret.riderDetails) {
        const decodedDetails = {};
        for (const [key, value] of Object.entries(ret.riderDetails)) {
          decodedDetails[keyToEmail(key)] = value;
        }
        ret.riderDetails = decodedDetails;
      }
      if (ret.seatAllocations) {
        const decodedAllocations = {};
        for (const [key, value] of Object.entries(ret.seatAllocations)) {
          decodedAllocations[keyToEmail(key)] = value;
        }
        ret.seatAllocations = decodedAllocations;
      }
      return ret;
    }
  }
});

RideSchema.index({ pickupCoords: "2dsphere" });
RideSchema.index({ riderEmail: 1, status: 1 });
RideSchema.index({ passengers: 1 });
RideSchema.index({ requests: 1 });
RideSchema.index({ droppedPassengers: 1 });
RideSchema.index({ status: 1, expiresAt: 1 });
RideSchema.index({ status: 1, vehicleType: 1, departureTime: 1 });
// POLICY: Completed/cancelled rides are auto-deleted 30 days after last update.
// ACTION REQUIRED before production: implement archive job that copies to ride_archive collection.
RideSchema.index({ updatedAt: 1 }, {
  expireAfterSeconds: 30 * 24 * 3600,
  partialFilterExpression: { status: { $in: ['cancelled', 'completed'] } }
});

module.exports = mongoose.model('Ride', RideSchema);

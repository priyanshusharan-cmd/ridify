const express = require('express');
const adminOnly = require('../middleware/adminOnly');
const authenticate = require('../middleware/authenticate');
const {
  searchRides,
  getAllRides,
  getRideById,
  createRide,
  cancelRide,
  deleteAllRides,
  requestRide,
  acceptRider,
  declineRider,
  kickPassenger,
  driverArrived,
  boardPassenger,
  dropOffPassenger,
  passengerPays,
  startRide,
  endRide,
  sendChatMessage,
  getDriverStats
} = require('../controllers/rideController');

const router = express.Router();

// ── Search rides ─────────────────────────────────────────────────────────────
router.get('/search', searchRides);         // Public: needed to browse
router.get('/stats/driver', authenticate, getDriverStats);
router.get('/', authenticate, getAllRides);               // Will be scoped in controller
router.get('/:id', getRideById);            // Public read is acceptable

// ── Create ride — join driver into room ──────────────────────────────────────
router.post('/', authenticate, createRide);

// ── Cancel ride — PATCH with body (callerEmail + status) ─────────────────────
router.patch('/cancel/:id', authenticate, cancelRide);

// ── Wipe all — global broadcast (admin only) ────────────────────────────────
router.delete('/', authenticate, adminOnly, deleteAllRides);

// ── Request a ride — join requester + scoped emit ────────────────────────────
router.patch('/request/:id', authenticate, requestRide);

// ── Accept a rider — scoped emit ─────────────────────────────────────────────
router.patch('/accept/:id/:passengerEmail', authenticate, acceptRider);

// ── Decline — scoped emit ────────────────────────────────────────────────────
router.patch('/decline/:id/:passengerEmail', authenticate, declineRider);

// ── Kick passenger — scoped emit + targeted notify ──────────────────────────
router.patch('/kick/:id/:passengerEmail', authenticate, kickPassenger);

// ── Driver arrived — scoped emit ─────────────────────────────────────────────
router.patch('/arrive/:id/:passengerEmail', authenticate, driverArrived);

// ── Board passenger — scoped emit ────────────────────────────────────────────
router.patch('/board/:id/:passengerEmail', authenticate, boardPassenger);

// ── Drop-off passenger — scoped emit ─────────────────────────────────────────
router.patch('/dropoff/:id/:passengerEmail', authenticate, dropOffPassenger);

// ── Passenger pays — scoped emit ─────────────────────────────────────────────
router.patch('/pay/:id/:passengerEmail', authenticate, passengerPays);

// ── Start ride — scoped emit ─────────────────────────────────────────────────
router.patch('/start/:id', authenticate, startRide);

// ── End ride — scoped emit ───────────────────────────────────────────────────
router.patch('/end/:id', authenticate, endRide);

// ── Chat — scoped emit ──────────────────────────────────────────────────────
router.post('/:id/chat', authenticate, sendChatMessage);

module.exports = router;

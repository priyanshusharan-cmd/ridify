const express = require('express');
const adminOnly = require('../middleware/adminOnly');
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
  sendChatMessage
} = require('../controllers/rideController');

const router = express.Router();

// ── Search rides ─────────────────────────────────────────────────────────────
router.get('/search', searchRides);
router.get('/', getAllRides);
router.get('/:id', getRideById);

// ── Create ride — join driver into room ──────────────────────────────────────
router.post('/', createRide);

// ── Cancel ride — scoped to room ─────────────────────────────────────────────
router.delete('/:id', cancelRide);

// ── Wipe all — global broadcast (admin only) ────────────────────────────────
router.delete('/', adminOnly, deleteAllRides);

// ── Request a ride — join requester + scoped emit ────────────────────────────
router.patch('/request/:id', requestRide);

// ── Accept a rider — scoped emit ─────────────────────────────────────────────
router.patch('/accept/:id/:riderName', acceptRider);

// ── Decline — scoped emit ────────────────────────────────────────────────────
router.patch('/decline/:id/:riderName', declineRider);

// ── Kick passenger — scoped emit + targeted notify ──────────────────────────
router.patch('/kick/:id/:riderName', kickPassenger);

// ── Driver arrived — scoped emit ─────────────────────────────────────────────
router.patch('/arrive/:id/:riderName', driverArrived);

// ── Board passenger — scoped emit ────────────────────────────────────────────
router.patch('/board/:id/:riderName', boardPassenger);

// ── Drop-off passenger — scoped emit ─────────────────────────────────────────
router.patch('/dropoff/:id/:riderName', dropOffPassenger);

// ── Passenger pays — scoped emit ─────────────────────────────────────────────
router.patch('/pay/:id/:riderName', passengerPays);

// ── Start ride — scoped emit ─────────────────────────────────────────────────
router.patch('/start/:id', startRide);

// ── End ride — scoped emit ───────────────────────────────────────────────────
router.patch('/end/:id', endRide);

// ── Chat — scoped emit ──────────────────────────────────────────────────────
router.post('/:id/chat', sendChatMessage);

module.exports = router;

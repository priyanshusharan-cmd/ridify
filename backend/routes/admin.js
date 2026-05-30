const express = require('express');
const authenticate = require('../middleware/authenticate');
const adminOnly = require('../middleware/adminOnly');
const {
  listUsers,
  getUserById,
  createUser,
  updateUser,
  deleteUserById,
  bulkDeleteUsers,
  listRides,
  getRideById,
  deleteRide,
  forceCancelRide,
  getStats,
  wipeAllRides,
  banUser,
  unbanUser,
  verifyDocuments
} = require('../controllers/adminController');

const router = express.Router();

// All admin routes require authentication + admin check
router.use(authenticate, adminOnly);

// ── User Management ─────────────────────────────────────────────────────────
router.get('/users', listUsers);
router.get('/users/:id', getUserById);
router.post('/users/create', createUser);
router.patch('/users/:id', updateUser);
router.delete('/users/:id', deleteUserById);
router.post('/users/bulk-delete', bulkDeleteUsers);
router.post('/users/:id/ban', banUser);
router.post('/users/:id/unban', unbanUser);
router.patch('/users/:id/verify', verifyDocuments);

// ── Ride Management ─────────────────────────────────────────────────────────
router.get('/rides', listRides);
router.get('/rides/:id', getRideById);
router.delete('/rides/:id', deleteRide);
router.delete('/rides', wipeAllRides);
router.patch('/rides/:id/cancel', forceCancelRide);

// ── Platform Stats ──────────────────────────────────────────────────────────
router.get('/stats', getStats);

module.exports = router;

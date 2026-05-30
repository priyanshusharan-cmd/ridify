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
  banUser,
  unbanUser,
  verifyDocuments,
  createPromo,
  listPromos,
  deletePromo,
  getSettings,
  updateCommission,
  updateSurge,
  listDisputes,
  resolveDispute,
  listSOSAlerts,
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
router.patch('/rides/:id/cancel', forceCancelRide);

// ── Platform Stats ──────────────────────────────────────────────────────────
router.get('/stats', getStats);

// ── Promos ──────────────────────────────────────────────────────────────────
router.post('/promos', createPromo);
router.get('/promos', listPromos);
router.delete('/promos/:id', deletePromo);

// ── Platform Settings ───────────────────────────────────────────────────────
router.get('/settings', getSettings);
router.patch('/settings/commission', updateCommission);
router.patch('/settings/surge', updateSurge);

// ── Disputes & SOS ──────────────────────────────────────────────────────────
router.get('/disputes', listDisputes);
router.patch('/disputes/:id/resolve', resolveDispute);
router.get('/sos', listSOSAlerts);

module.exports = router;

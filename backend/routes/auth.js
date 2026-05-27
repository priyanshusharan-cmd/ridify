const express = require('express');
const adminOnly = require('../middleware/adminOnly');
const authenticate = require('../middleware/authenticate');
const { register, login, deleteUser, deleteAllUsers, refreshToken } = require('../controllers/authController');

const router = express.Router();

router.post('/register', register);
router.post('/login', login);
router.post('/refresh', refreshToken);
// authenticate middleware now secures delete routes
router.delete('/user/:email', authenticate, deleteUser);
router.delete('/users', authenticate, adminOnly, deleteAllUsers);

module.exports = router;

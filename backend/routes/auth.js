const express = require('express');
const adminOnly = require('../middleware/adminOnly');
const { register, login, deleteUser, deleteAllUsers } = require('../controllers/authController');

const router = express.Router();

router.post('/register', register);
router.post('/login', login);
router.delete('/user/:email', deleteUser);
router.delete('/users', adminOnly, deleteAllUsers);

module.exports = router;

const express = require('express');
const adminOnly = require('../middleware/adminOnly');
const authenticate = require('../middleware/authenticate');
const { requestSignupOtp, register, login, requestLoginOtp, deleteUser, deleteAllUsers, refreshToken, logout, changePassword } = require('../controllers/authController');

const router = express.Router();

router.post('/signup-otp-request', requestSignupOtp);
router.post('/register', register);
router.post('/login', login);
router.post('/login-otp-request', requestLoginOtp);
router.post('/refresh', refreshToken);
// authenticate middleware now secures delete routes
router.delete('/user/:email', authenticate, deleteUser);
router.delete('/users', authenticate, adminOnly, deleteAllUsers);
router.post('/logout', authenticate, logout);
router.patch('/change-password', authenticate, changePassword);

router.patch('/user/:email', authenticate, async (req, res) => {
  try {
    const targetEmail = req.params.email.trim().toLowerCase();
    if (req.user.email !== targetEmail) {
      return res.status(403).json({ error: 'You can only edit your own profile.' });
    }
    const { name, age } = req.body;
    if (name && (typeof name !== 'string' || name.trim().length === 0 || name.length > 200)) {
      return res.status(400).json({ error: 'Invalid name.' });
    }
    if (age && (typeof age !== 'string' || age.trim().length > 3)) {
      return res.status(400).json({ error: 'Invalid age.' });
    }
    const User = require('../models/user');
    const updateFields = {};
    if (name) updateFields.name = name.trim();
    if (age) updateFields.age = age.trim();
    const user = await User.findOneAndUpdate(
      { email: targetEmail }, { $set: updateFields }, { new: true }
    );
    if (!user) return res.status(404).json({ error: 'User not found.' });
    res.json({ user: { id: user._id, name: user.name, age: user.age, email: user.email } });
  } catch (err) {
    res.status(500).json({ error: 'Server error.' });
  }
});

module.exports = router;

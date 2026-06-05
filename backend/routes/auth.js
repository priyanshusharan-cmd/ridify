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

router.post('/user/:email/upload-id', authenticate, async (req, res) => {
  try {
    const targetEmail = req.params.email.trim().toLowerCase();
    if (req.user.email !== targetEmail) {
      return res.status(403).json({ error: 'You can only upload ID for your own profile.' });
    }
    const { base64, filename } = req.body;
    if (!base64 || !filename) {
      return res.status(400).json({ error: 'Base64 image data and filename are required.' });
    }

    const scriptUrl = process.env.GOOGLE_APPS_SCRIPT_URL;
    if (!scriptUrl) {
      return res.status(500).json({ error: 'Server misconfiguration: GOOGLE_APPS_SCRIPT_URL not set.' });
    }

    const User = require('../models/user');
    // Set status to pending immediately so it persists if the user closes the app while uploading
    await User.updateOne({ email: targetEmail }, { $set: { verificationStatus: 'pending' } });

    let response;
    try {
      // Call Google Apps Script from the backend
      response = await fetch(scriptUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename, base64 })
      });
    } catch (fetchErr) {
      await User.updateOne({ email: targetEmail }, { $set: { verificationStatus: 'none' } });
      return res.status(500).json({ error: 'Failed to connect to Google Drive.' });
    }

    if (!response.ok && response.status !== 302) {
      await User.updateOne({ email: targetEmail }, { $set: { verificationStatus: 'none' } });
      return res.status(500).json({ error: 'Failed to upload to Google Drive.' });
    }

    const data = await response.json();
    if (data.status !== 'success') {
      await User.updateOne({ email: targetEmail }, { $set: { verificationStatus: 'none' } });
      return res.status(500).json({ error: data.message || 'Failed to upload to Google Drive.' });
    }

    const idUrl = data.url;

    const user = await User.findOneAndUpdate(
      { email: targetEmail },
      { $set: { idUrl, verificationStatus: 'pending' } },
      { new: true }
    );
    if (!user) return res.status(404).json({ error: 'User not found.' });
    res.json({ message: 'ID uploaded successfully. Waiting for admin approval.', verificationStatus: user.verificationStatus });
  } catch (err) {
    try {
      const User = require('../models/user');
      await User.updateOne({ email: req.params.email.trim().toLowerCase() }, { $set: { verificationStatus: 'none' } });
    } catch (e) {}
    res.status(500).json({ error: 'Server error during upload.' });
  }
});

router.get('/user/:email/profile', authenticate, async (req, res) => {
  try {
    const targetEmail = req.params.email.trim().toLowerCase();
    if (req.user.email !== targetEmail) {
      return res.status(403).json({ error: 'Forbidden.' });
    }
    const User = require('../models/user');
    const user = await User.findOne({ email: targetEmail }, { name: 1, age: 1, verificationStatus: 1, idUrl: 1 });
    if (!user) return res.status(404).json({ error: 'User not found.' });
    res.json({ name: user.name, age: user.age, verificationStatus: user.verificationStatus || 'none', idUrl: user.idUrl || '' });
  } catch (err) {
    res.status(500).json({ error: 'Server error.' });
  }
});

module.exports = router;

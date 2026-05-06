const express = require('express');
const bcrypt = require('bcrypt');
const User = require('../models/user');
const Ride = require('../models/ride');

const router = express.Router();

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$/.test(String(email).trim());
}

const adminEmails = (process.env.ADMIN_EMAILS || '')
  .split(',')
  .map(e => e.trim().toLowerCase())
  .filter(Boolean);

function adminOnly(req, res, next) {
  const callerEmail = (req.headers['x-admin-email'] || '').trim().toLowerCase();
  if (!callerEmail || !adminEmails.includes(callerEmail)) {
    return res.status(403).json({ error: 'Forbidden: Admin access required.' });
  }
  next();
}

router.post('/register', async (req, res) => {
  try {
    const { name, age, email, password } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Name, email, and password are required.' });
    }
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ error: 'An account with this email already exists.' });
    }
    if (!isValidEmail(email)) {
      return res.status(400).json({ error: 'Please enter a valid email address.' });
    }
    if (password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters.' });
    }
    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = new User({ name, age, email, password: hashedPassword });
    await newUser.save();
    res.status(201).json({ success: true, user: { name: newUser.name, age: newUser.age, email: newUser.email, _id: newUser._id } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Email and password are required.' });
    if (!isValidEmail(email)) {
      return res.status(400).json({ error: 'Please enter a valid email address.' });
    }
    const user = await User.findOne({ email });
    if (!user) return res.status(401).json({ error: 'Invalid credentials' });

    let isMatch = false;
    const isBcryptHash = typeof user.password === 'string' && user.password.startsWith('$2');

    if (isBcryptHash) {
      isMatch = await bcrypt.compare(password, user.password);
    } else {
      isMatch = (password === user.password);
      if (isMatch) {
        const hashed = await bcrypt.hash(password, 10);
        await User.updateOne({ _id: user._id }, { password: hashed });
        console.log(`🔐 Migrated plain-text password to bcrypt for: ${email}`);
      }
    }

    if (!isMatch) return res.status(401).json({ error: 'Invalid credentials' });

    res.status(200).json({
      success: true,
      user: { name: user.name, age: user.age, email: user.email, _id: user._id },
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/user/:email', async (req, res) => {
  try {
    const user = await User.findOne({ email: req.params.email });
    if (user) {
      await Ride.updateMany({ riderName: user.name }, { status: 'cancelled' });
      await Ride.updateMany(
        { passengers: user.name },
        { $pull: { passengers: user.name, requests: user.name, boardedPassengers: user.name }, $inc: { availableSeats: 1 } }
      );
      await User.findOneAndDelete({ email: req.params.email });
      req.io.emit('ride_ended', {});
    }
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.delete('/users', adminOnly, async (req, res) => {
  try {
    await User.deleteMany({});
    await Ride.deleteMany({});
    req.io.emit('database_wiped');
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;

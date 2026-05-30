const bcrypt = require('bcrypt');
const User = require('../models/user');
const { isValidEmail, MAX_FIELD_LENGTH } = require('../utils/validators');
const { signAccessToken, signRefreshToken } = require('../utils/jwt');

const BCRYPT_ROUNDS = parseInt(process.env.BCRYPT_ROUNDS) || 12;
const ADMIN_EMAILS = (process.env.ADMIN_EMAILS || '').split(',').map(e => e.trim().toLowerCase()).filter(Boolean);

// ── Register ────────────────────────────────────────────────────────────────
const register = async (req, res) => {
  try {
    let { name, age, email, password } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Name, email, and password are required.' });
    }

    name = String(name).trim();
    email = String(email).trim().toLowerCase();
    password = String(password);
    age = age ? String(age).trim() : undefined;

    // Field length limits — also prevents bcrypt DoS from 1 MB passwords
    if (name.length > MAX_FIELD_LENGTH || email.length > MAX_FIELD_LENGTH || password.length > 200) {
      return res.status(400).json({ error: 'One or more fields exceed maximum length.' });
    }
    if (age && age.length > 3) {
      return res.status(400).json({ error: 'Invalid age.' });
    }

    if (!isValidEmail(email)) {
      return res.status(400).json({ error: 'Invalid email format.' });
    }

    const existing = await User.findOne({ email });
    if (existing) {
      return res.status(409).json({ error: 'Email already registered.' });
    }

    const hashedPassword = await bcrypt.hash(password, BCRYPT_ROUNDS);
    const user = await User.create({ name, age, email, password: hashedPassword });

    const isAdmin = ADMIN_EMAILS.includes(email);
    const accessToken = signAccessToken({ id: user._id, email: user.email });
    const refreshToken = signRefreshToken({ id: user._id, email: user.email });
    await User.findByIdAndUpdate(user._id, { $push: { refreshTokens: refreshToken } });
    res.status(201).json({
      user: { id: user._id, name: user.name, age: user.age, email: user.email, isAdmin },
      accessToken,
      refreshToken,
    });
  } catch (err) {
    console.error('Register Error:', err.message);
    res.status(500).json({ error: 'Server error during registration.' });
  }
};

// ── Login ───────────────────────────────────────────────────────────────────
const login = async (req, res) => {
  try {
    let { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required.' });
    }

    email = String(email).trim().toLowerCase();
    password = String(password);

    // Length limits
    if (email.length > MAX_FIELD_LENGTH || password.length > 200) {
      return res.status(400).json({ error: 'Invalid credentials.' });
    }

    // Must explicitly select password since User model has select:false
    const user = await User.findOne({ email }).select('+password');
    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const isAdmin = ADMIN_EMAILS.includes(email);
    const accessToken = signAccessToken({ id: user._id, email: user.email });
    const refreshToken = signRefreshToken({ id: user._id, email: user.email });
    await User.findByIdAndUpdate(user._id, { $push: { refreshTokens: refreshToken } });
    res.json({
      user: { id: user._id, name: user.name, age: user.age, email: user.email, isAdmin },
      accessToken,
      refreshToken,
    });
  } catch (err) {
    console.error('Login Error:', err.message);
    res.status(500).json({ error: 'Server error during login.' });
  }
};

// ── Delete User ─────────────────────────────────────────────────────────────
// Requires callerEmail in body. Only the user themselves or an admin can delete.
const deleteUser = async (req, res) => {
  try {
    // Caller is identified from JWT — not from request body
    const callerEmail = req.user.email; // set by authenticate middleware
    const targetEmail = decodeURIComponent(req.params.email || '').trim().toLowerCase();
    const isAdmin = ADMIN_EMAILS.includes(callerEmail);
    if (callerEmail !== targetEmail && !isAdmin) {
      return res.status(403).json({ error: 'You can only delete your own account.' });
    }

    const user = await User.findOneAndDelete({ email: targetEmail });
    if (!user) return res.status(404).json({ error: 'User not found.' });
    res.json({ message: `User ${targetEmail} deleted.` });
  } catch (err) {
    res.status(500).json({ error: 'Server error during user deletion.' });
  }
};

// ── Delete All Users (admin only) ───────────────────────────────────────────
const deleteAllUsers = async (req, res) => {
  try {
    await User.deleteMany({});
    res.json({ message: 'All users deleted.' });
  } catch (err) {
    res.status(500).json({ error: 'Server error.' });
  }
};

const refreshToken = async (req, res) => {
  const { refreshToken: token } = req.body;
  if (!token) return res.status(400).json({ error: 'Refresh token required.' });
  try {
    const { verifyRefreshToken, signAccessToken } = require('../utils/jwt');
    const payload = verifyRefreshToken(token);
    const user = await User.findById(payload.id).select('+refreshTokens');
    if (!user) return res.status(404).json({ error: 'User not found.' });
    if (!user.refreshTokens.includes(token)) {
      return res.status(401).json({ error: 'Refresh token has been revoked.' });
    }
    const newAccessToken = signAccessToken({ id: user._id, email: user.email });
    res.json({ accessToken: newAccessToken });
  } catch (err) {
    res.status(401).json({ error: 'Invalid or expired refresh token.' });
  }
};

const logout = async (req, res) => {
  try {
    const { refreshToken: token } = req.body;
    if (token) {
      await User.findOneAndUpdate(
        { email: req.user.email },
        { $pull: { refreshTokens: token } }
      );
    }
    res.json({ message: 'Logged out.' });
  } catch (err) {
    res.status(500).json({ error: 'Server error.' });
  }
};

module.exports = { register, login, deleteUser, deleteAllUsers, refreshToken, logout };

const bcrypt = require('bcrypt');
const User = require('../models/user');
const { isValidEmail, MAX_FIELD_LENGTH } = require('../utils/validators');
const { signAccessToken, signRefreshToken } = require('../utils/jwt');
const { sendOtpEmail } = require('../utils/emailjs');

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
      return res.status(409).json({ error: 'Email already registered. Please log in.' });
    }

    const hashedPassword = await bcrypt.hash(password, BCRYPT_ROUNDS);
    
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpExpiry = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    const user = await User.create({ 
      name, 
      age, 
      email, 
      password: hashedPassword,
      isVerified: false,
      otp,
      otpExpiry,
      lastOtpSentAt: new Date()
    });

    try {
      await sendOtpEmail(user.email, otp);
    } catch (emailError) {
      // Even if email fails, user is created. They can request a resend later.
      console.error('Failed to send initial OTP email:', emailError);
    }

    res.status(201).json({
      message: 'Registration successful. OTP sent to your email.',
      email: user.email
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

    const user = await User.findOne({ email }).select('+password +isVerified');
    if (!user) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    if (!user.isVerified) {
      return res.status(403).json({ 
        error: 'Please verify your email to log in.', 
        requireVerification: true,
        email: user.email
      });
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

// ── Request Login OTP ───────────────────────────────────────────────────────
const requestLoginOtp = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Email is required.' });
    }

    const user = await User.findOne({ email: String(email).trim().toLowerCase() }).select('+lastOtpSentAt');
    if (!user) {
      return res.status(404).json({ error: 'User not found. Please sign up first.' });
    }

    if (user.lastOtpSentAt && Date.now() - user.lastOtpSentAt.getTime() < 10 * 60 * 1000) {
      const waitMinutes = Math.ceil((10 * 60 * 1000 - (Date.now() - user.lastOtpSentAt.getTime())) / 60000);
      return res.status(429).json({ error: `Please wait ${waitMinutes} minute(s) before requesting another OTP.` });
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpExpiry = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    user.otp = otp;
    user.otpExpiry = otpExpiry;
    user.lastOtpSentAt = new Date();
    await user.save();

    await sendOtpEmail(user.email, otp);

    res.json({ message: 'Login OTP sent to your email.' });
  } catch (err) {
    console.error('Request Login OTP Error:', err.message);
    res.status(500).json({ error: 'Server error while sending Login OTP.' });
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

// ── OTP Verification ────────────────────────────────────────────────────────
const verifyOtp = async (req, res) => {
  try {
    const { email, otp } = req.body;
    if (!email || !otp) {
      return res.status(400).json({ error: 'Email and OTP are required.' });
    }

    const user = await User.findOne({ email: String(email).trim().toLowerCase() }).select('+otp +otpExpiry +isVerified');
    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }

    if (!user.otp || user.otp !== String(otp)) {
      return res.status(401).json({ error: 'Invalid OTP.' });
    }

    if (user.otpExpiry < new Date()) {
      return res.status(401).json({ error: 'OTP has expired. Please request a new one.' });
    }

    user.isVerified = true;
    user.otp = undefined;
    user.otpExpiry = undefined;
    
    const isAdmin = ADMIN_EMAILS.includes(user.email);
    const accessToken = signAccessToken({ id: user._id, email: user.email });
    const refreshToken = signRefreshToken({ id: user._id, email: user.email });
    
    await user.save();
    await User.findByIdAndUpdate(user._id, { $push: { refreshTokens: refreshToken } });

    res.json({
      message: 'Email verified successfully.',
      user: { id: user._id, name: user.name, age: user.age, email: user.email, isAdmin },
      accessToken,
      refreshToken,
    });
  } catch (err) {
    console.error('Verify OTP Error:', err.message);
    res.status(500).json({ error: 'Server error during OTP verification.' });
  }
};

// ── Resend OTP ──────────────────────────────────────────────────────────────
const resendOtp = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Email is required.' });
    }

    const user = await User.findOne({ email: String(email).trim().toLowerCase() }).select('+isVerified +lastOtpSentAt');
    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }

    if (user.isVerified) {
      return res.status(400).json({ error: 'User is already verified.' });
    }

    if (user.lastOtpSentAt && Date.now() - user.lastOtpSentAt.getTime() < 10 * 60 * 1000) {
      const waitMinutes = Math.ceil((10 * 60 * 1000 - (Date.now() - user.lastOtpSentAt.getTime())) / 60000);
      return res.status(429).json({ error: `Please wait ${waitMinutes} minute(s) before requesting another OTP.` });
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const otpExpiry = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    user.otp = otp;
    user.otpExpiry = otpExpiry;
    user.lastOtpSentAt = new Date();
    await user.save();

    await sendOtpEmail(user.email, otp);

    res.json({ message: 'A new OTP has been sent to your email.' });
  } catch (err) {
    console.error('Resend OTP Error:', err.message);
    res.status(500).json({ error: 'Server error while resending OTP.' });
  }
};

// ── Change Password ─────────────────────────────────────────────────────────
const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Current and new passwords are required.' });
    }

    if (newPassword.length < 8) {
      return res.status(400).json({ error: 'New password must be at least 8 characters.' });
    }

    const email = req.user.email; // from authenticate middleware
    const user = await User.findOne({ email }).select('+password');
    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch) {
      return res.status(401).json({ error: 'Incorrect current password.' });
    }

    user.password = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
    await user.save();

    res.json({ message: 'Password updated successfully.' });
  } catch (err) {
    console.error('Change Password Error:', err.message);
    res.status(500).json({ error: 'Server error while changing password.' });
  }
};

module.exports = { register, login, requestLoginOtp, verifyOtp, resendOtp, deleteUser, deleteAllUsers, refreshToken, logout, changePassword };

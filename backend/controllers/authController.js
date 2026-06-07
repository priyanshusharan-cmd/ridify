const logger = require('../utils/logger');
const bcrypt = require('bcrypt');
const User = require('../models/user');
const OtpVerification = require('../models/OtpVerification');
const { isValidEmail, MAX_FIELD_LENGTH } = require('../utils/validators');
const { signAccessToken, signRefreshToken } = require('../utils/jwt');
const { sendOtpEmail } = require('../utils/emailjs');
const { generateOtp } = require('../utils/otpGenerator');

const BCRYPT_ROUNDS = parseInt(process.env.BCRYPT_ROUNDS) || 12;
const ADMIN_EMAILS = (process.env.ADMIN_EMAILS || '').split(',').map(e => e.trim().toLowerCase()).filter(Boolean);

const crypto = require('crypto');
function hashOtp(otp) {
  return crypto.createHash('sha256').update(String(otp)).digest('hex');
}

// ── Request Signup OTP ──────────────────────────────────────────────────────
const requestSignupOtp = async (req, res) => {
  try {
    let { email } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Email is required.' });
    }
    email = String(email).trim().toLowerCase();

    if (!isValidEmail(email)) {
      return res.status(400).json({ error: 'Invalid email format.' });
    }

    const allowedDomain = process.env.ALLOWED_EMAIL_DOMAIN;
    if (allowedDomain && allowedDomain.trim() !== '') {
      if (!email.endsWith(`@${allowedDomain.trim().toLowerCase()}`)) {
        return res.status(403).json({ error: `Only emails from @${allowedDomain} are allowed.` });
      }
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(409).json({ error: 'Email already registered. Please log in.' });
    }

    const existingOtp = await OtpVerification.findOne({ email });
    if (existingOtp && existingOtp.lastOtpSentAt && Date.now() - existingOtp.lastOtpSentAt.getTime() < 10 * 60 * 1000) {
      const waitMinutes = Math.ceil((10 * 60 * 1000 - (Date.now() - existingOtp.lastOtpSentAt.getTime())) / 60000);
      return res.status(429).json({ error: `Please wait ${waitMinutes} minute(s) before requesting another OTP.` });
    }

    const otp = generateOtp();
    
    // Attempt to send the email FIRST
    await sendOtpEmail(email, otp);

    // Only update DB if email succeeds
    if (existingOtp) {
      existingOtp.otp = otp;
      existingOtp.lastOtpSentAt = new Date();
      await existingOtp.save();
    } else {
      await OtpVerification.create({ email, otp });
    }

    res.json({ message: 'Signup OTP sent to your email.' });
  } catch (err) {
    logger.error('Request Signup OTP Error:', err.message);
    res.status(500).json({ error: 'Server error while sending Signup OTP.' });
  }
};

// ── Register ────────────────────────────────────────────────────────────────
const register = async (req, res) => {
  try {
    let { name, age, email, password, otp } = req.body;
    if (!name || !email || !password || !otp) {
      return res.status(400).json({ error: 'Name, email, password, and OTP are required.' });
    }

    name = String(name).trim();
    email = String(email).trim().toLowerCase();
    password = String(password);
    otp = String(otp).trim();
    age = age ? String(age).trim() : undefined;

    // Field length limits
    if (name.length > MAX_FIELD_LENGTH || email.length > MAX_FIELD_LENGTH || password.length > 200 || password.length < 8) {
      return res.status(400).json({ error: 'One or more fields exceed maximum length or password is too short (min 8).' });
    }
    if (age && (age.length > 3 || isNaN(Number(age)) || Number(age) < 1)) {
      return res.status(400).json({ error: 'Invalid age.' });
    }

    if (!isValidEmail(email)) {
      return res.status(400).json({ error: 'Invalid email format.' });
    }

    const allowedDomain = process.env.ALLOWED_EMAIL_DOMAIN;
    if (allowedDomain && allowedDomain.trim() !== '') {
      if (!email.endsWith(`@${allowedDomain.trim().toLowerCase()}`)) {
        return res.status(403).json({ error: `Only emails from @${allowedDomain} are allowed.` });
      }
    }

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(409).json({ error: 'Email already registered. Please log in.' });
    }

    const otpRecord = await OtpVerification.findOne({ email });
    if (!otpRecord) {
      return res.status(401).json({ error: 'No OTP requested for this email. Please request an OTP first.' });
    }
    if (otpRecord.otp !== otp) {
      return res.status(401).json({ error: 'Invalid OTP.' });
    }

    const hashedPassword = await bcrypt.hash(password, BCRYPT_ROUNDS);
    
    const user = await User.create({ 
      name, 
      age, 
      email, 
      password: hashedPassword,
      isVerified: true, // Account is instantly verified upon creation
    });

    await OtpVerification.deleteOne({ email }); // Clear the used OTP

    const isAdmin = ADMIN_EMAILS.includes(email);
    const accessToken = signAccessToken({ id: user._id, email: user.email });
    const refreshToken = signRefreshToken({ id: user._id, email: user.email });
    await User.findByIdAndUpdate(user._id, { $push: { refreshTokens: refreshToken } });

    res.status(201).json({
      message: 'Registration successful.',
      user: { id: user._id, name: user.name, age: user.age, email: user.email, isAdmin, verificationStatus: 'none' },
      accessToken,
      refreshToken,
    });
  } catch (err) {
    logger.error('Register Error:', err.message);
    res.status(500).json({ error: 'Server error during registration.' });
  }
};

// ── Login ───────────────────────────────────────────────────────────────────
const login = async (req, res) => {
  try {
    let { email, password, otp } = req.body;
    if (!email) {
      return res.status(400).json({ error: 'Email is required.' });
    }
    if (!password && !otp) {
      return res.status(400).json({ error: 'Password or OTP is required.' });
    }

    email = String(email).trim().toLowerCase();
    password = password ? String(password) : undefined;
    otp = otp ? String(otp).trim() : undefined;

    // Length limits
    if (email.length > MAX_FIELD_LENGTH || (password && password.length > 200)) {
      return res.status(400).json({ error: 'Invalid credentials.' });
    }

    const user = await User.findOne({ email }).select('+password +otp +otpExpiry +otpAttempts');
    if (!user) {
      return res.status(404).json({ error: 'User not registered. Please sign up first.' });
    }

    if (user.isBanned) {
      return res.status(403).json({ error: 'Your account has been suspended. Contact support.', code: 'ACCOUNT_BANNED' });
    }

    if (otp) {
      // Brute force protection: max 5 wrong attempts
      if ((user.otpAttempts || 0) >= 5) {
        user.otp = undefined;
        user.otpExpiry = undefined;
        user.otpAttempts = 0;
        await user.save();
        return res.status(429).json({ error: 'Too many wrong attempts. Please request a new OTP.' });
      }
      const hashedInput = hashOtp(otp);
      if (!user.otp || user.otp !== hashedInput) {
        user.otpAttempts = (user.otpAttempts || 0) + 1;
        await user.save();
        const attemptsLeft = 5 - user.otpAttempts;
        return res.status(401).json({ error: `Invalid OTP. ${attemptsLeft} attempt(s) remaining.` });
      }
      if (user.otpExpiry < new Date()) {
        user.otp = undefined;
        user.otpExpiry = undefined;
        user.otpAttempts = 0;
        await user.save();
        return res.status(401).json({ error: 'OTP has expired. Please request a new one.' });
      }
      user.otp = undefined;
      user.otpExpiry = undefined;
      user.otpAttempts = 0;
      await user.save();
    } else {
      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) {
        return res.status(401).json({ error: 'Invalid email or password.' });
      }
    }

    const isAdmin = ADMIN_EMAILS.includes(email);
    const accessToken = signAccessToken({ id: user._id, email: user.email });
    const refreshToken = signRefreshToken({ id: user._id, email: user.email });
    await User.findByIdAndUpdate(user._id, { $push: { refreshTokens: refreshToken } });
    res.json({
      user: { id: user._id, name: user.name, age: user.age, email: user.email, isAdmin, verificationStatus: user.verificationStatus || 'none' },
      accessToken,
      refreshToken,
    });
  } catch (err) {
    logger.error('Login Error:', err.message);
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

    const GENERIC_RESPONSE = { message: 'If that email is registered, an OTP has been sent.' };

    const user = await User.findOne({ email: String(email).trim().toLowerCase() }).select('+lastOtpSentAt');
    if (!user) {
      return res.status(404).json({ error: 'User not registered. Please sign up first.' });
    }

    if (user.lastOtpSentAt && Date.now() - user.lastOtpSentAt.getTime() < 10 * 60 * 1000) {
      const waitMinutes = Math.ceil((10 * 60 * 1000 - (Date.now() - user.lastOtpSentAt.getTime())) / 60000);
      return res.status(429).json({ error: `Please wait ${waitMinutes} minute(s) before requesting another OTP.` });
    }

    const otp = generateOtp();
    const otpExpiry = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    // Attempt to send the email FIRST
    await sendOtpEmail(user.email, otp);

    user.otp = hashOtp(otp);
    user.otpExpiry = otpExpiry;
    user.otpAttempts = 0;
    user.lastOtpSentAt = new Date();
    await user.save();

    res.json(GENERIC_RESPONSE);
  } catch (err) {
    logger.error('Request Login OTP Error:', err.message);
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

    // Cancel any active rides this user was driving
    const Ride = require('../models/ride');
    const activeDriverRides = await Ride.find({
      riderEmail: targetEmail,
      status: { $in: ['available', 'accepted', 'full', 'started'] }
    });
    for (const ride of activeDriverRides) {
      ride.status = 'cancelled';
      // Notify all passengers on those rides
      const allParticipants = new Set([
        ...(ride.passengers || []),
        ...(ride.requests || []),
        ...(ride.boardedPassengers || [])
      ]);
      await ride.save();
      if (req.io) {
        req.io.to(ride._id.toString()).emit('ride_cancelled', {
          rideId: ride._id.toString(),
          ride: ride.toJSON(),
          reason: 'driver_account_deleted'
        });
      }
      for (const p of allParticipants) {
        if (req.emitToUser) req.emitToUser(p, 'ride_cancelled', {
          rideId: ride._id.toString(),
          ride: ride.toJSON(),
          reason: 'driver_account_deleted'
        });
      }
    }

    // Remove this user from pending requests in other rides
    await Ride.updateMany(
      { requests: targetEmail },
      { $pull: { requests: targetEmail } }
    );

    res.json({ message: `User ${targetEmail} deleted.` });
  } catch (err) {
    res.status(500).json({ error: 'Server error during user deletion.' });
  }
};

// ── Delete All Users (admin only) ───────────────────────────────────────────
const deleteAllUsers = async (req, res) => {
  try {
    const adminEmail = req.user ? req.user.email : null;
    if (!adminEmail) return res.status(401).json({ error: 'Unauthorized.' });

    logger.warn(`[${new Date().toISOString()}] Admin ${adminEmail} triggered deleteAllUsers`);

    // Delete all users EXCEPT the admin who is triggering the wipe
    const Ride = require('../models/ride');
    await User.deleteMany({ email: { $ne: adminEmail } });
    await Ride.deleteMany({});

    if (req.io) {
      req.io.emit('database_wiped', { success: true, excludedEmail: adminEmail });
    }

    res.json({ message: 'All other users and their rides deleted.' });
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
    if (user.isBanned) {
      return res.status(403).json({ error: 'Your account has been suspended.', code: 'ACCOUNT_BANNED' });
    }
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

// (verifyOtp and resendOtp removed as they are no longer needed)

// ── Change Password ─────────────────────────────────────────────────────────
const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
      return res.status(400).json({ error: 'Current and new passwords are required.' });
    }

    if (currentPassword === newPassword) {
      return res.status(400).json({ error: 'New password must be different.' });
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
    user.refreshTokens = [];
    await user.save();

    res.json({ message: 'Password updated successfully. All other sessions have been signed out.' });
  } catch (err) {
    logger.error('Change Password Error:', err.message);
    res.status(500).json({ error: 'Server error while changing password.' });
  }
};

module.exports = { requestSignupOtp, register, login, requestLoginOtp, deleteUser, deleteAllUsers, refreshToken, logout, changePassword };

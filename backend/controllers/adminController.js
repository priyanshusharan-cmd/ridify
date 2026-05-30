const bcrypt = require('bcrypt');
const User = require('../models/user');
const Ride = require('../models/ride');
const { isValidEmail, isValidObjectId, MAX_FIELD_LENGTH } = require('../utils/validators');

const BCRYPT_ROUNDS = parseInt(process.env.BCRYPT_ROUNDS) || 12;

// ── List All Users (with search & pagination) ───────────────────────────────
const listUsers = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;
    const search = req.query.search ? String(req.query.search).trim() : '';
    const sortField = req.query.sortBy === 'name' ? 'name' : 'createdAt';
    const sortOrder = req.query.order === 'asc' ? 1 : -1;

    let query = {};
    if (search) {
      // Escape regex special chars to prevent ReDoS
      const escaped = search.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      if (escaped.length > MAX_FIELD_LENGTH) {
        return res.status(400).json({ error: 'Search query too long.' });
      }
      query = {
        $or: [
          { name: { $regex: escaped, $options: 'i' } },
          { email: { $regex: escaped, $options: 'i' } },
        ],
      };
    }

    const [users, total] = await Promise.all([
      User.find(query, { password: 0, refreshTokens: 0 })
        .sort({ [sortField]: sortOrder })
        .skip(skip)
        .limit(limit)
        .lean(),
      User.countDocuments(query),
    ]);

    res.json({
      users,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
    });
  } catch (err) {
    console.error('Admin listUsers error:', err.message);
    res.status(500).json({ error: 'Server error fetching users.' });
  }
};

// ── Get Single User ─────────────────────────────────────────────────────────
const getUserById = async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid user ID format.' });
    }
    const user = await User.findById(req.params.id, { password: 0, refreshTokens: 0 }).lean();
    if (!user) return res.status(404).json({ error: 'User not found.' });

    // Fetch ride stats for this user
    const email = user.email;
    const [ridesAsDriver, ridesAsPassenger] = await Promise.all([
      Ride.countDocuments({ riderEmail: email }),
      Ride.countDocuments({ passengers: email }),
    ]);

    res.json({ user, stats: { ridesAsDriver, ridesAsPassenger } });
  } catch (err) {
    console.error('Admin getUserById error:', err.message);
    res.status(500).json({ error: 'Server error fetching user.' });
  }
};

// ── Create User (no verification required) ──────────────────────────────────
const createUser = async (req, res) => {
  try {
    let { name, email, age, password } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Name, email, and password are required.' });
    }

    name = String(name).trim();
    email = String(email).trim().toLowerCase();
    password = String(password);
    age = age ? String(age).trim() : undefined;

    // Field length limits
    if (name.length > MAX_FIELD_LENGTH || email.length > MAX_FIELD_LENGTH || password.length > 200) {
      return res.status(400).json({ error: 'One or more fields exceed maximum length.' });
    }
    if (name.length === 0) {
      return res.status(400).json({ error: 'Name cannot be empty.' });
    }
    if (password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters.' });
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

    // Return user without sensitive fields
    res.status(201).json({
      user: { id: user._id, name: user.name, age: user.age, email: user.email },
      message: 'User created successfully (no verification required).',
    });
  } catch (err) {
    console.error('Admin createUser error:', err.message);
    res.status(500).json({ error: 'Server error creating user.' });
  }
};

// ── Update User ─────────────────────────────────────────────────────────────
const updateUser = async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid user ID format.' });
    }

    const { name, age } = req.body;
    const updateFields = {};

    if (name !== undefined) {
      const trimmed = String(name).trim();
      if (trimmed.length === 0 || trimmed.length > MAX_FIELD_LENGTH) {
        return res.status(400).json({ error: 'Invalid name.' });
      }
      updateFields.name = trimmed;
    }
    if (age !== undefined) {
      const trimmed = String(age).trim();
      if (trimmed.length > 3) {
        return res.status(400).json({ error: 'Invalid age.' });
      }
      updateFields.age = trimmed;
    }

    if (Object.keys(updateFields).length === 0) {
      return res.status(400).json({ error: 'No fields to update.' });
    }

    const user = await User.findByIdAndUpdate(
      req.params.id,
      { $set: updateFields },
      { new: true, projection: { password: 0, refreshTokens: 0 } }
    );
    if (!user) return res.status(404).json({ error: 'User not found.' });

    res.json({ user, message: 'User updated successfully.' });
  } catch (err) {
    console.error('Admin updateUser error:', err.message);
    res.status(500).json({ error: 'Server error updating user.' });
  }
};

// ── Delete Specific User ────────────────────────────────────────────────────
const deleteUserById = async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid user ID format.' });
    }

    const user = await User.findByIdAndDelete(req.params.id);
    if (!user) return res.status(404).json({ error: 'User not found.' });

    res.json({ message: `User ${user.email} deleted successfully.` });
  } catch (err) {
    console.error('Admin deleteUserById error:', err.message);
    res.status(500).json({ error: 'Server error deleting user.' });
  }
};

// ── Bulk Delete Users ───────────────────────────────────────────────────────
const bulkDeleteUsers = async (req, res) => {
  try {
    const { ids } = req.body;
    if (!Array.isArray(ids) || ids.length === 0) {
      return res.status(400).json({ error: 'Provide a non-empty array of user IDs.' });
    }
    if (ids.length > 100) {
      return res.status(400).json({ error: 'Cannot delete more than 100 users at once.' });
    }

    // Validate all IDs
    const validIds = ids.filter(id => isValidObjectId(id));
    if (validIds.length === 0) {
      return res.status(400).json({ error: 'No valid user IDs provided.' });
    }

    // Prevent admin from deleting themselves
    const adminUser = await User.findOne({ email: req.user.email });
    if (adminUser && validIds.includes(adminUser._id.toString())) {
      return res.status(400).json({ error: 'Cannot delete your own admin account via bulk delete.' });
    }

    const result = await User.deleteMany({ _id: { $in: validIds } });
    res.json({ message: `${result.deletedCount} user(s) deleted.`, deletedCount: result.deletedCount });
  } catch (err) {
    console.error('Admin bulkDeleteUsers error:', err.message);
    res.status(500).json({ error: 'Server error during bulk delete.' });
  }
};

// ── List All Rides (with filters & pagination) ──────────────────────────────
const listRides = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;
    const status = req.query.status;
    const driverEmail = req.query.driverEmail ? String(req.query.driverEmail).trim().toLowerCase() : null;

    const query = {};
    if (status && ['available', 'accepted', 'full', 'started', 'completed', 'cancelled'].includes(status)) {
      query.status = status;
    }
    if (driverEmail) {
      if (driverEmail.length > MAX_FIELD_LENGTH) {
        return res.status(400).json({ error: 'Driver email filter too long.' });
      }
      query.riderEmail = driverEmail;
    }

    const [rides, total] = await Promise.all([
      Ride.find(query, { routePath: 0, chatMessages: 0 })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Ride.countDocuments(query),
    ]);

    // Decode map keys for riderDetails
    const { keyToEmail } = require('../utils/emailKey');
    rides.forEach(ride => {
      if (ride.riderDetails) {
        const decoded = {};
        for (const [key, value] of Object.entries(ride.riderDetails)) {
          decoded[keyToEmail(key)] = value;
        }
        ride.riderDetails = decoded;
      }
      if (ride.seatAllocations) {
        const decoded = {};
        for (const [key, value] of Object.entries(ride.seatAllocations)) {
          decoded[keyToEmail(key)] = value;
        }
        ride.seatAllocations = decoded;
      }
    });

    res.json({
      rides,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) },
    });
  } catch (err) {
    console.error('Admin listRides error:', err.message);
    res.status(500).json({ error: 'Server error fetching rides.' });
  }
};

// ── Get Ride Details (full, including chat) ─────────────────────────────────
const getRideById = async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid ride ID format.' });
    }
    const ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: 'Ride not found.' });
    res.json(ride);
  } catch (err) {
    console.error('Admin getRideById error:', err.message);
    res.status(500).json({ error: 'Server error fetching ride.' });
  }
};

// ── Delete Specific Ride ────────────────────────────────────────────────────
const deleteRide = async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid ride ID format.' });
    }
    const ride = await Ride.findByIdAndDelete(req.params.id);
    if (!ride) return res.status(404).json({ error: 'Ride not found.' });

    // Notify connected users
    if (req.io) {
      req.io.to(req.params.id).emit('ride_cancelled', { rideId: req.params.id, adminDeleted: true });
    }

    res.json({ message: 'Ride deleted successfully.' });
  } catch (err) {
    console.error('Admin deleteRide error:', err.message);
    res.status(500).json({ error: 'Server error deleting ride.' });
  }
};

// ── Wipe All Rides ──────────────────────────────────────────────────────────
const wipeAllRides = async (req, res) => {
  try {
    const adminEmail = req.admin?.email;
    if (!adminEmail) return res.status(401).json({ error: 'Unauthorized.' });

    await Ride.deleteMany({});
    console.log(`[WipeAllRides] Admin ${adminEmail} wiped all rides.`);

    if (req.io) {
      req.io.emit('all_rides_wiped');
    }

    res.json({ message: 'All rides have been permanently deleted.' });
  } catch (err) {
    console.error('Admin wipeAllRides error:', err.message);
    res.status(500).json({ error: 'Server error wiping rides.' });
  }
};

// ── Force Cancel Ride ───────────────────────────────────────────────────────
const forceCancelRide = async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid ride ID format.' });
    }
    const ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: 'Ride not found.' });

    if (['completed', 'cancelled'].includes(ride.status)) {
      return res.status(400).json({ error: `Ride is already ${ride.status}.` });
    }

    // Auto-decline all pending requests
    if (ride.requests && ride.requests.length > 0) {
      for (const requester of ride.requests) {
        if (!ride.declined.includes(requester)) {
          ride.declined.push(requester);
        }
        if (req.emitToUser) {
          req.emitToUser(requester, 'ride_cancelled', { rideId: req.params.id, ride: ride.toJSON() });
        }
      }
      ride.requests = [];
    }

    ride.status = 'cancelled';
    await ride.save();

    if (req.io) {
      req.io.to(req.params.id).emit('ride_cancelled', { rideId: req.params.id, ride: ride.toJSON(), adminCancelled: true });
    }

    res.json({ message: 'Ride force-cancelled by admin.', ride });
  } catch (err) {
    console.error('Admin forceCancelRide error:', err.message);
    res.status(500).json({ error: 'Server error cancelling ride.' });
  }
};

// ── Platform Statistics ─────────────────────────────────────────────────────
const getStats = async (req, res) => {
  try {
    const [
      totalUsers,
      totalRides,
      availableRides,
      acceptedRides,
      startedRides,
      completedRides,
      cancelledRides,
      fullRides,
      recentUsers,
    ] = await Promise.all([
      User.countDocuments(),
      Ride.countDocuments(),
      Ride.countDocuments({ status: 'available' }),
      Ride.countDocuments({ status: 'accepted' }),
      Ride.countDocuments({ status: 'started' }),
      Ride.countDocuments({ status: 'completed' }),
      Ride.countDocuments({ status: 'cancelled' }),
      Ride.countDocuments({ status: 'full' }),
      User.find({}, { password: 0, refreshTokens: 0 })
        .sort({ createdAt: -1 })
        .limit(5)
        .lean(),
    ]);

    res.json({
      users: { total: totalUsers, recent: recentUsers },
      rides: {
        total: totalRides,
        available: availableRides,
        accepted: acceptedRides,
        started: startedRides,
        completed: completedRides,
        cancelled: cancelledRides,
        full: fullRides,
        active: availableRides + acceptedRides + startedRides + fullRides,
      },
    });
  } catch (err) {
    console.error('Admin getStats error:', err.message);
    res.status(500).json({ error: 'Server error fetching stats.' });
  }
};

// ── User Trust & Moderation ───────────────────────────────────────────────────
const banUser = async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Invalid ID' });
    const user = await User.findByIdAndUpdate(req.params.id, { isBanned: true }, { new: true, projection: { password: 0 }});
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({ message: `User ${user.email} has been banned.`, user });
  } catch (err) { res.status(500).json({ error: 'Server error banning user' }); }
};

const unbanUser = async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Invalid ID' });
    const user = await User.findByIdAndUpdate(req.params.id, { isBanned: false }, { new: true, projection: { password: 0 }});
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({ message: `User ${user.email} has been unbanned.`, user });
  } catch (err) { res.status(500).json({ error: 'Server error unbanning user' }); }
};

const verifyDocuments = async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) return res.status(400).json({ error: 'Invalid ID' });
    const user = await User.findByIdAndUpdate(req.params.id, { documentsVerified: true }, { new: true, projection: { password: 0 }});
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({ message: `Documents for ${user.email} verified.`, user });
  } catch (err) { res.status(500).json({ error: 'Server error verifying docs' }); }
};

module.exports = {
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
  getStats,
  wipeAllRides
};

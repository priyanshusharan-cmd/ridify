const os = require('os');
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
const bcrypt = require('bcrypt');
require('dotenv').config();

// Strict email format validator — must have a local part, @, and a TLD (e.g. .com)
function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$/.test(String(email).trim());
}

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 5001;
const mongoURI = process.env.MONGO_URI;

mongoose.connect(mongoURI)
  .then(() => console.log("✅ MongoDB Connected!"))
  .catch(err => console.error("❌ DB Error:", err));

// =============================================
// SCHEMAS & MODELS
// =============================================

const UserSchema = new mongoose.Schema({
  name: String, age: String, email: { type: String, unique: true }, password: String
});
const User = mongoose.model('User', UserSchema);

const RideSchema = new mongoose.Schema({
  riderName: String,
  pickupLocation: String,
  pickupLat: Number,
  pickupLng: Number,
  destination: String,
  destLat: Number,
  destLng: Number,
  pickupCoords: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], default: [0, 0] }
  },
  departureTime: String,
  expiresAt: Number,
  fare: Number,
  status: String,
  vehicleType: String,
  totalSeats: Number,
  availableSeats: Number,
  requests: { type: [String], default: [] },
  passengers: { type: [String], default: [] },
  boardedPassengers: { type: [String], default: [] },
  declined: { type: [String], default: [] },
  kicked: { type: [String], default: [] },
  seatAllocations: { type: Map, of: Number, default: {} },
  chatMessages: [{ sender: String, text: String, timestamp: String }]
});
RideSchema.index({ pickupCoords: "2dsphere" });
const Ride = mongoose.model('Ride', RideSchema);



// =============================================
// ADMIN MIDDLEWARE
// =============================================

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

// =============================================
// SOCKET.IO
// =============================================

io.on('connection', (socket) => {
  console.log(`📡 Device connected: ${socket.id}`);

  socket.on('driver_location_update', (data) => {
    io.emit('driver_location_update', data);
  });
});

// =============================================
// AUTH ROUTES
// =============================================

// Register (bcrypt — no OTP required)
app.post('/api/auth/register', async (req, res) => {
  try {
    const { name, age, email, password } = req.body;

    // Field presence check
    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Name, email, and password are required.' });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ error: 'An account with this email already exists.' });
    }

    // Strict email format check
    if (!isValidEmail(email)) {
      return res.status(400).json({ error: 'Please enter a valid email address.' });
    }

    if (password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters.' });
    }

    // Hash password with bcrypt
    const hashedPassword = await bcrypt.hash(password, 10);

    const newUser = new User({ name, age, email, password: hashedPassword });
    await newUser.save();
    res.status(201).json({ success: true, user: { name: newUser.name, age: newUser.age, email: newUser.email, _id: newUser._id } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Login (bcrypt compare — with silent migration for legacy plain-text passwords)
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Email and password are required.' });

    // Strict email format check
    if (!isValidEmail(email)) {
      return res.status(400).json({ error: 'Please enter a valid email address.' });
    }

    const user = await User.findOne({ email });
    if (!user) return res.status(401).json({ error: 'Invalid credentials' });

    let isMatch = false;

    // Check if stored password looks like a bcrypt hash (starts with $2b$ or $2a$)
    const isBcryptHash = typeof user.password === 'string' && user.password.startsWith('$2');

    if (isBcryptHash) {
      // New path: secure bcrypt compare
      isMatch = await bcrypt.compare(password, user.password);
    } else {
      // Legacy path: plain-text password (pre-bcrypt migration)
      isMatch = (password === user.password);
      if (isMatch) {
        // Silently migrate to bcrypt now that we've confirmed the password
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


// Delete single user account
app.delete('/api/auth/user/:email', async (req, res) => {
  try {
    const user = await User.findOne({ email: req.params.email });
    if (user) {
      await Ride.updateMany({ riderName: user.name }, { status: 'cancelled' });
      await Ride.updateMany(
        { passengers: user.name },
        { $pull: { passengers: user.name, requests: user.name, boardedPassengers: user.name }, $inc: { availableSeats: 1 } }
      );
      await User.findOneAndDelete({ email: req.params.email });
      io.emit('ride_ended', {});
    }
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// 🔒 ADMIN ONLY: Wipe all users
app.delete('/api/auth/users', adminOnly, async (req, res) => {
  try {
    await User.deleteMany({});
    await Ride.deleteMany({});
    io.emit('database_wiped');
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// =============================================
// RIDE ROUTES
// =============================================

app.get('/api/rides/search', async (req, res) => {
  try {
    const { pickup, destination, seats, vehicle, lat, lng, date } = req.query;
    const currentTime = Date.now();

    const matchQuery = {
      status: { $in: ['available', 'accepted'] },
      $or: [{ expiresAt: { $gt: currentTime } }, { expiresAt: null }, { expiresAt: { $exists: false } }],
      availableSeats: { $gte: parseInt(seats) || 1 }
    };
    if (vehicle && vehicle !== 'Any') matchQuery.vehicleType = vehicle;
    if (date) {
      matchQuery.departureTime = { $regex: new RegExp(`^${date}`, 'i') };
    }

    if (lat && lng) {
      matchQuery.pickupCoords = {
        $near: {
          $geometry: {
            type: "Point",
            coordinates: [parseFloat(lng), parseFloat(lat)]
          },
          $maxDistance: 500
        }
      };
      if (destination) {
        matchQuery.destination = { $regex: new RegExp(destination, 'i') };
      }
    } else {
      matchQuery.pickupLocation = { $regex: new RegExp(pickup || '', 'i') };
      matchQuery.destination = { $regex: new RegExp(destination || '', 'i') };
    }

    res.status(200).json(await Ride.find(matchQuery));
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/api/rides', async (req, res) => {
  try {
    const currentTime = Date.now();
    const validRides = await Ride.find({
      $or: [
        { expiresAt: { $gt: currentTime } },
        { expiresAt: null },
        { expiresAt: { $exists: false } },
        { status: { $in: ['accepted', 'full', 'started', 'completed', 'cancelled'] } }
      ]
    });
    res.status(200).json(validRides);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/api/rides/:id', async (req, res) => {
  try { res.status(200).json(await Ride.findById(req.params.id)); } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/rides', async (req, res) => {
  try {
    const data = req.body;
    if (data.pickupLng != null && data.pickupLat != null) {
      data.pickupCoords = {
        type: 'Point',
        coordinates: [data.pickupLng, data.pickupLat]
      };
    }
    const newRide = new Ride(data);
    await newRide.save();
    res.status(201).json({ success: true, ride: newRide });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.delete('/api/rides/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(req.params.id, { status: 'cancelled' }, { returnDocument: 'after' });
    io.emit('ride_cancelled', updatedRide);
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// 🔒 ADMIN ONLY: Wipe all rides
app.delete('/api/rides', adminOnly, async (req, res) => {
  try {
    await Ride.deleteMany({});
    io.emit('database_wiped');
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/api/rides/request/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(
      req.params.id,
      { 
        $addToSet: { requests: req.body.riderName },
        $set: { [`seatAllocations.${req.body.riderName}`]: req.body.seats || 1 }
      },
      { returnDocument: 'after' }
    );
    io.emit('new_ride_request', updatedRide);
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/api/rides/accept/:id/:riderName', async (req, res) => {
  try {
    let rideData = await Ride.findById(req.params.id);
    let requestedSeats = rideData?.seatAllocations?.get(req.params.riderName) || 1;

    let ride = await Ride.findOneAndUpdate(
      { _id: req.params.id, availableSeats: { $gte: requestedSeats }, passengers: { $ne: req.params.riderName } },
      {
        $pull: { requests: req.params.riderName },
        $addToSet: { passengers: req.params.riderName },
        $inc: { availableSeats: -requestedSeats }
      },
      { new: true }
    );

    if (ride) {
      if (ride.availableSeats <= 0) {
        ride.status = 'full';
        if (ride.requests.length > 0) {
          ride.declined.push(...ride.requests);
          ride.requests = [];
        }
      } else if (ride.status === 'available') {
        ride.status = 'accepted';
      }
      await ride.save();
      io.emit('ride_accepted', ride);
      res.status(200).json(ride);
    } else {
      res.status(400).json({ error: "Seat unavailable or already booked." });
    }
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/api/rides/decline/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findByIdAndUpdate(
      req.params.id,
      {
        $pull: { requests: req.params.riderName },
        $addToSet: { declined: req.params.riderName }
      },
      { new: true }
    );
    if (ride.requests.length === 0 && ride.passengers.length === 0) {
      ride.status = 'available';
      await ride.save();
    }
    io.emit('ride_cancelled', ride);
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/api/rides/kick/:id/:riderName', async (req, res) => {
  try {
    let rideData = await Ride.findById(req.params.id);
    let requestedSeats = rideData?.seatAllocations?.get(req.params.riderName) || 1;

    let ride = await Ride.findByIdAndUpdate(
      req.params.id,
      {
        $pull: { passengers: req.params.riderName, boardedPassengers: req.params.riderName },
        $addToSet: { kicked: req.params.riderName },
        $inc: { availableSeats: requestedSeats }
      },
      { new: true }
    );

    if (ride) {
      if (ride.passengers.length === 0 && ride.requests.length === 0) {
        ride.status = 'available';
      } else if (ride.status === 'full') {
        ride.status = 'accepted';
      }
      await ride.save();
    }
    io.emit('passenger_kicked', { rideId: ride._id, kickedUser: req.params.riderName, ride });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/api/rides/board/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findByIdAndUpdate(
      req.params.id,
      { $addToSet: { boardedPassengers: req.params.riderName } },
      { returnDocument: 'after' }
    );
    io.emit('passenger_boarded', ride);
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/api/rides/start/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(
      req.params.id,
      { status: 'started', availableSeats: 0 },
      { new: true }
    );
    io.emit('ride_started', updatedRide);
    res.status(200).json(updatedRide);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/api/rides/end/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(req.params.id, { status: 'completed' }, { new: true });
    io.emit('ride_ended', {
        rideId: updatedRide._id,
        passengers: updatedRide.passengers,
        riderName: updatedRide.riderName,
        boardedPassengers: updatedRide.boardedPassengers
    });
    res.status(200).json(updatedRide);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/rides/:id/chat', async (req, res) => {
  try {
    const { sender, text, timestamp } = req.body;
    await Ride.findByIdAndUpdate(req.params.id, { $push: { chatMessages: { sender, text, timestamp } } });
    io.emit('receive_message', { rideId: req.params.id, sender, text, timestamp });
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// =============================================
// START SERVER
// =============================================

let localIp = 'localhost';
const networkInterfaces = os.networkInterfaces();
for (const interfaceName in networkInterfaces) {
  const interfaces = networkInterfaces[interfaceName];
  for (const iface of interfaces) {
    if (iface.family === 'IPv4' && !iface.internal) {
      localIp = iface.address;
      break;
    }
  }
  if (localIp !== 'localhost') break;
}

server.listen(PORT, '0.0.0.0', () => console.log(`🚀 Server running on Network: http://${localIp}:${PORT}`));
require('dotenv').config();
const os = require('os');
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');

const authRoutes = require('./routes/auth');
const rideRoutes = require('./routes/rides');
const Ride = require('./models/ride');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: "*" },
  pingInterval: 10000,
  pingTimeout: 5000,
});

app.use(cors());
app.use(express.json({ limit: '5mb' }));

// =============================================
// USER ↔ SOCKET TRACKING
// =============================================

// userEmail → Set<socketId>  (supports multiple devices per user)
const userSockets = new Map();

/**
 * Emit an event to a specific user across all their connected devices.
 */
function emitToUser(userEmail, event, data) {
  const sockets = userSockets.get(userEmail);
  if (sockets) {
    for (const sid of sockets) {
      io.to(sid).emit(event, data);
    }
  }
}

/**
 * Join all of a user's connected sockets into a ride room.
 */
function joinUserToRide(userEmail, rideId) {
  const sockets = userSockets.get(userEmail);
  if (sockets) {
    for (const sid of sockets) {
      const s = io.sockets.sockets.get(sid);
      if (s) s.join(rideId);
    }
  }
}

// Attach io + helpers to req so routes can use them
app.use((req, res, next) => {
  req.io = io;
  req.emitToUser = emitToUser;
  req.joinUserToRide = joinUserToRide;
  next();
});

const PORT = process.env.PORT || 5001;
const mongoURI = process.env.MONGO_URI;

mongoose.connect(mongoURI)
  .then(() => console.log("✅ MongoDB Connected!"))
  .catch(err => console.error("❌ DB Error:", err));

// =============================================
// SOCKET.IO — Room-based architecture
// =============================================

io.on('connection', (socket) => {
  console.log(`📡 Device connected: ${socket.id}`);

  // ── Register user identity ─────────────────────────────────────────
  // Client sends { userEmail } right after connecting.
  // Server maps the socket and auto-joins all active ride rooms.
  socket.on('register_user', async (data) => {
    const userEmail = data?.userEmail;
    if (!userEmail) return;

    socket.userEmail = userEmail;

    if (!userSockets.has(userEmail)) {
      userSockets.set(userEmail, new Set());
    }
    userSockets.get(userEmail).add(socket.id);

    // Auto-join rooms for every ride this user is involved in
    try {
      const rides = await Ride.find({
        status: { $in: ['available', 'accepted', 'full', 'started'] },
        $or: [
          { riderEmail: userEmail },
          { passengers: userEmail },
          { requests: userEmail },
        ],
      }, '_id');

      for (const ride of rides) {
        socket.join(ride._id.toString());
      }
      console.log(`👤 ${userEmail} registered, joined ${rides.length} rooms`);
    } catch (e) {
      console.error('Auto-join error:', e.message);
    }
  });

  // ── Explicit room management ───────────────────────────────────────
  socket.on('join_ride', (data) => {
    if (!socket.userEmail) return; // Must register first
    if (data?.rideId) {
      socket.join(data.rideId);
    }
  });

  socket.on('leave_ride', (data) => {
    if (data?.rideId) {
      socket.leave(data.rideId);
    }
  });

  // ── Driver location — scoped to ride room ──────────────────────────
  socket.on('driver_location_update', (data) => {
    if (!socket.userEmail) return; // Must register first
    if (data?.rideId) {
      // Broadcast to everyone in the room EXCEPT the sender
      socket.to(data.rideId).emit('driver_location_update', data);
    }
  });

  // ── Cleanup on disconnect ──────────────────────────────────────────
  socket.on('disconnect', () => {
    if (socket.userEmail && userSockets.has(socket.userEmail)) {
      userSockets.get(socket.userEmail).delete(socket.id);
      if (userSockets.get(socket.userEmail).size === 0) {
        userSockets.delete(socket.userEmail);
      }
    }
    console.log(`📡 Device disconnected: ${socket.id}`);
  });
});

// =============================================
// ROUTES
// =============================================

app.get('/', (req, res) => { res.send('🚗 Ridify Backend API is running successfully!'); });

app.use('/api/auth', authRoutes);
app.use('/api/rides', rideRoutes);

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
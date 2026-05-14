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

// userName → Set<socketId>  (supports multiple devices per user)
const userSockets = new Map();

/**
 * Emit an event to a specific user across all their connected devices.
 */
function emitToUser(userName, event, data) {
  const sockets = userSockets.get(userName);
  if (sockets) {
    for (const sid of sockets) {
      io.to(sid).emit(event, data);
    }
  }
}

/**
 * Join all of a user's connected sockets into a ride room.
 */
function joinUserToRide(userName, rideId) {
  const sockets = userSockets.get(userName);
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
  // Client sends { userName } right after connecting.
  // Server maps the socket and auto-joins all active ride rooms.
  socket.on('register_user', async (data) => {
    const userName = data?.userName;
    if (!userName) return;

    socket.userName = userName;

    if (!userSockets.has(userName)) {
      userSockets.set(userName, new Set());
    }
    userSockets.get(userName).add(socket.id);

    // Auto-join rooms for every ride this user is involved in
    try {
      const rides = await Ride.find({
        status: { $in: ['available', 'accepted', 'full', 'started'] },
        $or: [
          { riderName: userName },
          { passengers: userName },
          { requests: userName },
        ],
      }, '_id');

      for (const ride of rides) {
        socket.join(ride._id.toString());
      }
      console.log(`👤 ${userName} registered, joined ${rides.length} rooms`);
    } catch (e) {
      console.error('Auto-join error:', e.message);
    }
  });

  // ── Explicit room management ───────────────────────────────────────
  socket.on('join_ride', (data) => {
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
    if (data?.rideId) {
      // Broadcast to everyone in the room EXCEPT the sender
      socket.to(data.rideId).emit('driver_location_update', data);
    }
  });

  // ── Cleanup on disconnect ──────────────────────────────────────────
  socket.on('disconnect', () => {
    if (socket.userName && userSockets.has(socket.userName)) {
      userSockets.get(socket.userName).delete(socket.id);
      if (userSockets.get(socket.userName).size === 0) {
        userSockets.delete(socket.userName);
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
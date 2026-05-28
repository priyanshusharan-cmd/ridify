const { Server } = require('socket.io');
const Ride = require('../models/ride');
const { verifyAccessToken } = require('../utils/jwt');

function initSocket(server, app) {
  const io = new Server(server, {
    cors: { origin: process.env.ALLOWED_ORIGIN || '*' },
    pingInterval: parseInt(process.env.SOCKET_PING_INTERVAL) || 10000,
    pingTimeout: parseInt(process.env.SOCKET_PING_TIMEOUT) || 5000,
  });

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

  // =============================================
  // SOCKET AUTH MIDDLEWARE
  // =============================================
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token || typeof token !== 'string' || token.trim() === '') {
      return next(new Error('Authentication required: provide a JWT token in handshake auth.token'));
    }
    try {
      const payload = verifyAccessToken(token);
      socket.userEmail = payload.email.trim().toLowerCase();
      socket.userId = payload.id;
      next();
    } catch (err) {
      return next(new Error('Invalid or expired token. Please re-authenticate.'));
    }
  });

  // =============================================
  // SOCKET.IO — Room-based architecture
  // =============================================

  io.on('connection', async (socket) => {
    console.log(`📡 Device connected: ${socket.id}`);

    // userEmail is now guaranteed by middleware — no event needed
    const userEmail = socket.userEmail;
    if (!userSockets.has(userEmail)) userSockets.set(userEmail, new Set());
    userSockets.get(userEmail).add(socket.id);

    // Auto-join rooms for every ride this user is involved in
    try {
      const lowerUserEmail = userEmail ? userEmail.toLowerCase() : '';
      const rides = await Ride.find({
        status: { $in: ['available', 'accepted', 'full', 'started'] },
        $or: [
          { riderEmail: userEmail },
          { riderEmail: lowerUserEmail },
          { passengers: lowerUserEmail },
          { requests: lowerUserEmail },
        ],
      }, '_id');

      for (const ride of rides) {
        socket.join(ride._id.toString());
      }
      console.log(`👤 ${userEmail} registered, joined ${rides.length} rooms`);
    } catch (e) {
      console.error('Auto-join error:', e.message);
    }

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

    // ── Driver location — verify the emitter is actually the driver ────
    socket.on('driver_location_update', async (data) => {
      if (!socket.userEmail || !data?.rideId) return;
      try {
        const ride = await Ride.findById(data.rideId, 'riderEmail').lean();
        if (!ride || ride.riderEmail !== socket.userEmail) return; // not the driver
        socket.to(data.rideId).emit('driver_location_update', data);
      } catch (_) {}
    });

    socket.on('request_driver_location', (data) => {
      if (!data?.rideId) return;
      socket.to(data.rideId).emit('request_driver_location', data);
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

  return { io, emitToUser, joinUserToRide };
}

module.exports = initSocket;

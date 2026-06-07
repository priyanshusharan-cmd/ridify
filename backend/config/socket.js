const { Server } = require('socket.io');
const Ride = require('../models/ride');
const { verifyAccessToken } = require('../utils/jwt');
const logger = require('../utils/logger');

function initSocket(server, app) {
  const allowedOrigin = process.env.ALLOWED_ORIGIN;
  if (process.env.NODE_ENV === 'production' && !allowedOrigin) { throw new Error('FATAL: ALLOWED_ORIGIN must be set in production'); }

  const io = new Server(server, {
    cors: { origin: allowedOrigin ? allowedOrigin : '*' },
    pingInterval: parseInt(process.env.SOCKET_PING_INTERVAL) || 25000, // 25s for mobile data tolerance
    pingTimeout: parseInt(process.env.SOCKET_PING_TIMEOUT) || 20000, // 20s timeout (more forgiving for mobile)
  });

  // =============================================
  // USER ↔ SOCKET TRACKING
  // =============================================

  /**
   * Emit an event to a specific user across all their connected devices
   * by leveraging their personal socket.io room.
   */
  function emitToUser(userEmail, event, data) {
    if (userEmail) {
      io.to(userEmail.toLowerCase()).emit(event, data);
    }
  }

  /**
   * Join all of a user's connected sockets into a ride room.
   */
  function joinUserToRide(userEmail, rideId) {
    if (userEmail && rideId) {
      io.in(userEmail.toLowerCase()).socketsJoin(rideId.toString());
    }
  }

  /**
   * Remove all of a user's connected sockets from a ride room.
   */
  function removeUserFromRide(userEmail, rideId) {
    if (userEmail && rideId) {
      io.in(userEmail.toLowerCase()).socketsLeave(rideId.toString());
    }
  }

  // Attach io + helpers to req so routes can use them
  app.use((req, res, next) => {
    req.io = io;
    req.emitToUser = emitToUser;
    req.joinUserToRide = joinUserToRide;
    req.removeUserFromRide = removeUserFromRide;
    next();
  });

  // =============================================
  // SOCKET AUTH MIDDLEWARE
  // =============================================
  io.use(async (socket, next) => {
    const token = socket.handshake.auth?.token;
    if (!token || typeof token !== 'string' || token.trim() === '') {
      return next(new Error('Authentication required: provide a JWT token in handshake auth.token'));
    }
    try {
      const payload = verifyAccessToken(token);
      const User = require('../models/user');
      const user = await User.findById(payload.id).select('isBanned email').lean();
      if (!user) {
        return next(new Error('User account not found. Please re-authenticate.'));
      }
      if (user.isBanned) {
        return next(new Error('Your account has been suspended. Contact support.'));
      }
      socket.userEmail = user.email.trim().toLowerCase();
      socket.userId = payload.id;
      next();
    } catch (err) {
      return next(new Error('Invalid or expired token. Please re-authenticate.'));
    }
  });

  // =============================================
  // SOCKET.IO — Room-based architecture
  // =============================================

  const locationUpdateCooldowns = new Map();

  // Rate limiting removed per user request to allow connections from all networks

  io.on('connection', async (socket) => {
    // Per-socket event rate limiter
    const eventTimestamps = {};
    function isRateLimited(eventName, limitMs) {
      const now = Date.now();
      const last = eventTimestamps[eventName] || 0;
      if (now - last < limitMs) return true;
      eventTimestamps[eventName] = now;
      return false;
    }
    logger.info(`Socket connected: ${socket.id}`);

    // userEmail is now guaranteed by middleware — no event needed
    const userEmail = socket.userEmail;
    
    // Join a personal room for this user to allow cross-device emits without maps
    if (userEmail) {
      socket.join(userEmail);
    }

    // Auto-join rooms for every ride this user is involved in
    try {
      const lowerUserEmail = userEmail ? userEmail.toLowerCase() : '';
      const rides = await Ride.find({
        status: { $in: ['available', 'accepted', 'full', 'started'] },
        $or: [
          { riderEmail: lowerUserEmail },
          { passengers: lowerUserEmail },
          { requests: lowerUserEmail },
        ],
      }, '_id');

      for (const ride of rides) {
        socket.join(ride._id.toString());
      }
      logger.info(`User ${userEmail} registered, joined ${rides.length} rooms`);
    } catch (e) {
      logger.error('Socket auto-join error:', e.message);
    }

    // ── Explicit room management ───────────────────────────────────────
    socket.on('join_ride', (data) => {
      if (!socket.userEmail) return;
      if (isRateLimited('join_ride', 500)) return; // max 2 per second
      if (data?.rideId) {
        socket.join(data.rideId);
      }
    });

    socket.on('leave_ride', (data) => {
      if (isRateLimited('leave_ride', 500)) return; // max 2 per second
      if (data?.rideId) {
        socket.leave(data.rideId);
      }
    });

    // ── Driver location — verify the emitter is actually the driver ────
    socket.on('driver_location_update', async (data) => {
      if (!socket.userEmail || !data?.rideId) return;
      const now = Date.now();
      const cooldownKey = `loc_${socket.userEmail}`;
      const lastUpdate = locationUpdateCooldowns.get(cooldownKey) || 0;
      if (now - lastUpdate < 1500) return; // max ~1 update per 1.5 seconds
      locationUpdateCooldowns.set(cooldownKey, now);
      try {
        const ride = await Ride.findById(data.rideId, 'riderEmail').lean();
        if (!ride || ride.riderEmail !== socket.userEmail) return; // not the driver
        socket.to(data.rideId).emit('driver_location_update', data);
      } catch (_) {}
    });

    // ── Application-level heartbeat — echo pong so client detects zombies ──
    socket.on('app_ping', (data) => {
      if (isRateLimited('app_ping', 5000)) return; // max once per 5 seconds
      socket.emit('app_pong', data || {});
    });

    socket.on('request_driver_location', (data) => {
      if (!data?.rideId) return;
      if (isRateLimited('request_driver_location', 2000)) return; // max once per 2 seconds
      socket.to(data.rideId).emit('request_driver_location', data);
    });

    // ── Cleanup on disconnect ──────────────────────────────────────────
    socket.on('disconnect', () => {
      locationUpdateCooldowns.delete(`loc_${socket.userEmail}`);
      logger.info(`Socket disconnected: ${socket.id}`);
    });
  });

  return { io, emitToUser, joinUserToRide, removeUserFromRide };
}

module.exports = initSocket;

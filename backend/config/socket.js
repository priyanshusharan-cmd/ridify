const { Server } = require('socket.io');
const Ride = require('../models/ride');
const { verifyAccessToken } = require('../utils/jwt');
const logger = require('../utils/logger');
const { viewRideFor, isRideMember, parseCoords } = require('../utils/rideHelpers');

// Live location is only shared while a ride is in progress. Before the driver
// starts the ride nobody's position leaves their phone.
const LIVE_STATUS = 'started';
const LOCATION_MIN_INTERVAL_MS = 1500;
const RIDE_LOOKUP_FIELDS = 'riderEmail passengers boardedPassengers droppedPassengers requests status';

/** Attach a per-viewer view of payload.ride (if present). */
function viewPayloadFor(payload, viewerEmail) {
  if (!payload || typeof payload !== 'object' || !payload.ride) return payload;
  return { ...payload, ride: viewRideFor(payload.ride, viewerEmail) };
}

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
      const email = userEmail.toLowerCase();
      io.to(email).emit(event, viewPayloadFor(data, email));
    }
  }

  /**
   * Emit a ride event to everyone in the ride room, giving each socket only
   * the view of the ride it is allowed to see (see viewRideFor).
   */
  function emitRideEvent(rideId, event, payload) {
    if (!rideId) return;
    // Synchronous so that a removeUserFromRide() right after still lets the
    // removed user receive this event (same semantics as io.to(room).emit).
    const ids = io.sockets.adapter.rooms.get(rideId.toString());
    if (!ids) return;
    for (const id of ids) {
      const s = io.sockets.sockets.get(id);
      if (s) s.emit(event, viewPayloadFor(payload, s.data?.userEmail));
    }
  }

  /**
   * Emit a ride event to the search room with no per-rider location data.
   * Members of the ride room are skipped; they get their own view above.
   */
  function emitRidePublic(rideId, event, payload) {
    const room = io.to('global_search_room');
    const target = rideId ? room.except(rideId.toString()) : room;
    target.emit(event, viewPayloadFor(payload, null));
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
    req.emitRideEvent = emitRideEvent;
    req.emitRidePublic = emitRidePublic;
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
      socket.data.userEmail = socket.userEmail;
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
    // Only people who are part of the ride may join its room.
    socket.on('join_ride', async (data) => {
      const rideId = data?.rideId;
      if (!socket.userEmail || !rideId || typeof rideId !== 'string') return;
      try {
        const ride = await Ride.findById(rideId, RIDE_LOOKUP_FIELDS).lean();
        if (ride && isRideMember(ride, socket.userEmail)) socket.join(rideId);
      } catch (_) { /* invalid id */ }
    });

    socket.on('leave_ride', (data) => {
      if (data?.rideId) {
        socket.leave(data.rideId);
      }
    });

    // ── Global Search Room Management ──────────────────────────────────
    socket.on('join_global_search_room', () => {
      socket.join('global_search_room');
    });

    socket.on('leave_global_search_room', () => {
      socket.leave('global_search_room');
    });

    // ── Live location (only while the ride is started) ─────────────────
    const throttled = (kind) => {
      const key = `${kind}_${socket.userEmail}`;
      const now = Date.now();
      if (now - (locationUpdateCooldowns.get(key) || 0) < LOCATION_MIN_INTERVAL_MS) return true;
      locationUpdateCooldowns.set(key, now);
      return false;
    };

    const loadLiveRide = async (rideId) => {
      if (!rideId || typeof rideId !== 'string') return null;
      try {
        const ride = await Ride.findById(rideId, RIDE_LOOKUP_FIELDS).lean();
        return ride && ride.status === LIVE_STATUS ? ride : null;
      } catch (_) { return null; }
    };

    const ridingPassengers = (ride) =>
      (ride.passengers || []).filter((p) => !(ride.droppedPassengers || []).includes(p));

    // Driver → every passenger still on the trip (never requesters or strangers).
    socket.on('driver_location_update', async (data) => {
      if (!socket.userEmail || throttled('drv')) return;
      const coords = parseCoords(data?.lat, data?.lng);
      if (!coords) return;
      const ride = await loadLiveRide(data?.rideId);
      if (!ride || ride.riderEmail !== socket.userEmail) return;
      const out = { rideId: data.rideId, ...coords, ts: Date.now() };
      const heading = Number(data?.heading);
      if (Number.isFinite(heading)) out.heading = heading;
      for (const p of ridingPassengers(ride)) emitToUser(p, 'driver_location_update', out);
    });

    // Passenger → driver only, until they are picked up.
    socket.on('passenger_location_update', async (data) => {
      if (!socket.userEmail || throttled('pax')) return;
      const coords = parseCoords(data?.lat, data?.lng);
      if (!coords) return;
      const ride = await loadLiveRide(data?.rideId);
      if (!ride) return;
      const me = socket.userEmail;
      const waiting = (ride.passengers || []).includes(me) &&
        !(ride.boardedPassengers || []).includes(me) &&
        !(ride.droppedPassengers || []).includes(me);
      if (!waiting) return;
      emitToUser(ride.riderEmail, 'passenger_location_update', { rideId: data.rideId, email: me, ...coords, ts: Date.now() });
    });

    // A passenger opening the map asks the driver for a fresh fix.
    socket.on('request_driver_location', async (data) => {
      if (!socket.userEmail) return;
      const ride = await loadLiveRide(data?.rideId);
      if (!ride || !ridingPassengers(ride).includes(socket.userEmail)) return;
      emitToUser(ride.riderEmail, 'request_driver_location', { rideId: data.rideId });
    });

    // The driver opening the map asks waiting passengers for a fresh fix.
    socket.on('request_passenger_location', async (data) => {
      if (!socket.userEmail) return;
      const ride = await loadLiveRide(data?.rideId);
      if (!ride || ride.riderEmail !== socket.userEmail) return;
      for (const p of ridingPassengers(ride)) {
        if (!(ride.boardedPassengers || []).includes(p)) emitToUser(p, 'request_passenger_location', { rideId: data.rideId });
      }
    });

    // ── Cleanup on disconnect ──────────────────────────────────────────
    socket.on('disconnect', () => {
      locationUpdateCooldowns.delete(`drv_${socket.userEmail}`);
      locationUpdateCooldowns.delete(`pax_${socket.userEmail}`);
      logger.info(`Socket disconnected: ${socket.id}`);
    });
  });

  return { io, emitToUser, joinUserToRide, removeUserFromRide, emitRideEvent, emitRidePublic };
}

module.exports = initSocket;

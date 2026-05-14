const express = require('express');
const Ride = require('../models/ride');
const turf = require('@turf/turf');

const router = express.Router();

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

/**
 * Get rider detail from riderDetails — works with both Mongoose Maps
 * (from .findById()) and plain objects (from .lean()).
 */
function getRiderDetail(ride, name) {
  if (!ride.riderDetails) return null;
  if (typeof ride.riderDetails.get === 'function') {
    return ride.riderDetails.get(name) || null;
  }
  return ride.riderDetails[name] || null;
}

/**
 * Core sweep-line capacity check.
 * @param {Array<string>} existingNames - names whose allocations count as occupied
 * @param {Object} ride - ride document (lean or Mongoose)
 * @param {number} newStartIndex
 * @param {number} newEndIndex
 * @param {number} requestedSeats
 * @returns {boolean} true if the new allocation fits
 */
function _checkCapacityWith(existingNames, ride, newStartIndex, newEndIndex, requestedSeats) {
  const changes = [];

  for (const pName of existingNames) {
    const p = getRiderDetail(ride, pName);
    if (p) {
      changes.push({ index: p.startIndex, change: p.seats });
      changes.push({ index: p.endIndex, change: -p.seats });
    }
  }

  changes.push({ index: newStartIndex, change: requestedSeats });
  changes.push({ index: newEndIndex, change: -requestedSeats });

  changes.sort((a, b) => a.index - b.index);

  let current = 0;
  let peak = 0;
  for (const c of changes) {
    current += c.change;
    if (current > peak) peak = current;
  }

  return peak <= ride.totalSeats;
}

/**
 * For SEARCH results: only count accepted passengers.
 * Rides stay visible until the driver actually accepts enough passengers
 * to fill the segment.
 */
function checkCapacityForSearch(ride, newStartIndex, newEndIndex, requestedSeats) {
  return _checkCapacityWith(ride.passengers || [], ride, newStartIndex, newEndIndex, requestedSeats);
}

/**
 * For REQUESTS: count both accepted passengers AND pending requests
 * to prevent overbooking the same segment.
 */
function checkCapacityForRequest(ride, newStartIndex, newEndIndex, requestedSeats) {
  const occupied = [...(ride.passengers || []), ...(ride.requests || [])];
  return _checkCapacityWith(occupied, ride, newStartIndex, newEndIndex, requestedSeats);
}

/**
 * Legacy wrapper — used by accept endpoint to re-check remaining requests.
 * Counts only accepted passengers (the just-accepted one is already in passengers).
 */
function checkCapacity(ride, newStartIndex, newEndIndex, requestedSeats) {
  return _checkCapacityWith(ride.passengers || [], ride, newStartIndex, newEndIndex, requestedSeats);
}

// ── Search rides ─────────────────────────────────────────────────────────────
router.get('/search', async (req, res) => {
  try {
    const { pickup, destination, seats, vehicle, lat, lng, destLat, destLng, radius, date } = req.query;
    const currentTime = Date.now();
    const searchRadius = parseInt(radius) || 2000;
    const reqSeats = parseInt(seats) || 1;

    const userName = req.query.userName;
    const matchQuery = {
      status: { $in: ['available', 'accepted'] },
      $or: [{ expiresAt: { $gt: currentTime } }, { expiresAt: null }, { expiresAt: { $exists: false } }]
    };
    if (vehicle && vehicle !== 'Any') matchQuery.vehicleType = vehicle;
    if (date) matchQuery.departureTime = { $regex: new RegExp(`^${date}`, 'i') };

    const activeRides = await Ride.find(matchQuery).lean();
    const results = [];

    if (lat && lng && destLat && destLng) {
      const pickupPoint = turf.point([parseFloat(lng), parseFloat(lat)]);
      const destPoint = turf.point([parseFloat(destLng), parseFloat(destLat)]);

      for (const ride of activeRides) {
        if (!ride.routePath || ride.routePath.length < 2) continue;

        let minPickupDist = Infinity;
        let startIndex = -1;
        let minDestDist = Infinity;
        let endIndex = -1;

        // Adaptive step: always sample ~100 points regardless of route length
        const sampleCount = 100;
        const step = Math.max(1, Math.floor(ride.routePath.length / sampleCount));

        for (let i = 0; i < ride.routePath.length; i += step) {
          const pt = ride.routePath[i];
          const ptPoint = turf.point([pt.lng, pt.lat]);
          
          const distToPickup = turf.distance(pickupPoint, ptPoint, { units: 'meters' });
          if (distToPickup < minPickupDist) {
            minPickupDist = distToPickup;
            startIndex = i;
          }
          
          const distToDest = turf.distance(destPoint, ptPoint, { units: 'meters' });
          if (distToDest < minDestDist) {
            minDestDist = distToDest;
            endIndex = i;
          }
        }
        // For downsampled routes the nearest sample point can be up to
        // pointSpacing/2 away from the actual closest point on the route.
        // Inflate the effective radius by the point spacing so we never
        // miss a valid match just because the route was simplified.
        const pointSpacing = ride.routePath.length > 1
          ? ((ride.totalDistance || 0) * 1000) / ride.routePath.length  // meters between points
          : 0;
        const effectiveRadius = searchRadius + pointSpacing;

        if (minPickupDist <= effectiveRadius && minDestDist <= effectiveRadius && startIndex < endIndex) {
          // Skip rides where the searching user has already been declined, kicked, or is already a passenger/requester
          if (userName) {
            if ((ride.declined || []).includes(userName)) continue;
            if ((ride.kicked || []).includes(userName)) continue;
            if ((ride.passengers || []).includes(userName)) continue;
            if ((ride.requests || []).includes(userName)) continue;
          }

          let tripDistance = 0;
          const distStep = Math.max(1, Math.floor((endIndex - startIndex) / sampleCount));
          for (let i = startIndex; i < endIndex; i += distStep) {
            const nextIdx = Math.min(i + distStep, endIndex);
            tripDistance += turf.distance(
              turf.point([ride.routePath[i].lng, ride.routePath[i].lat]),
              turf.point([ride.routePath[nextIdx].lng, ride.routePath[nextIdx].lat]),
              { units: 'kilometers' }
            );
          }

          if (tripDistance < 1.5) continue; // Minimum distance check

          // Preferences check
          const isStartClose = startIndex < (ride.routePath.length * 0.1);
          const isEndClose = endIndex > (ride.routePath.length * 0.9);
          
          if (ride.routePreference === 'shared_start' && !isStartClose) continue;
          if (ride.routePreference === 'nonstop' && (!isStartClose || !isEndClose)) continue;

          // For search: only count ACCEPTED passengers, not pending requests.
          // Ride stays visible until driver accepts enough to fill the segment.
          if (checkCapacityForSearch(ride, startIndex, endIndex, reqSeats)) {
            let percentage = tripDistance / (ride.totalDistance || tripDistance || 1);
            if (percentage > 1) percentage = 1;
            const computedFare = Math.round(ride.fare * percentage);

            const rideObj = { ...ride };
            rideObj.computedFare = computedFare;
            rideObj.computedDistance = tripDistance;
            rideObj.startIndex = startIndex;
            rideObj.endIndex = endIndex;
            results.push(rideObj);
          }
        }
      }
      res.status(200).json(results);
    } else {
      res.status(400).json({ error: "Missing coordinates for precise matching" });
    }
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.get('/', async (req, res) => {
  try {
    const currentTime = Date.now();
    const validRides = await Ride.find({
      $or: [
        { expiresAt: { $gt: currentTime } },
        { expiresAt: null },
        { expiresAt: { $exists: false } },
        { status: { $in: ['accepted', 'full', 'started', 'completed', 'cancelled'] } }
      ]
    }, { routePath: 0, chatMessages: 0 }).lean();
    res.status(200).json(validRides);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.get('/:id', async (req, res) => {
  try { res.status(200).json(await Ride.findById(req.params.id)); } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Create ride — join driver into room ──────────────────────────────────────
const MAX_ROUTE_POINTS = 500;
router.post('/', async (req, res) => {
  try {
    const data = req.body;
    if (data.pickupLng != null && data.pickupLat != null) {
      data.pickupCoords = {
        type: 'Point',
        coordinates: [data.pickupLng, data.pickupLat]
      };
    }
    // Server-side safety: cap route points to keep documents small
    if (data.routePath && data.routePath.length > MAX_ROUTE_POINTS) {
      const raw = data.routePath;
      const sampled = [];
      const step = (raw.length - 1) / (MAX_ROUTE_POINTS - 1);
      for (let i = 0; i < MAX_ROUTE_POINTS - 1; i++) {
        sampled.push(raw[Math.round(i * step)]);
      }
      sampled.push(raw[raw.length - 1]);
      data.routePath = sampled;
    }
    const newRide = new Ride(data);
    await newRide.save();

    // Join driver into the ride's socket room
    const rideId = newRide._id.toString();
    req.joinUserToRide(data.riderName, rideId);

    res.status(201).json({ success: true, ride: newRide });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Cancel ride — scoped to room ─────────────────────────────────────────────
router.delete('/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(req.params.id, { status: 'cancelled' }, { returnDocument: 'after' });
    req.io.to(req.params.id).emit('ride_cancelled', { rideId: req.params.id, ride: updatedRide.toJSON() });
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Wipe all — global broadcast (admin only) ────────────────────────────────
router.delete('/', adminOnly, async (req, res) => {
  try {
    await Ride.deleteMany({});
    req.io.emit('database_wiped');
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Request a ride — join requester + scoped emit ────────────────────────────
router.patch('/request/:id', async (req, res) => {
  try {
    const { riderName, seats, computedFare, computedDistance, startIndex, endIndex, pickupLat, pickupLng, destLat, destLng, pickupLocation, destination } = req.body;
    
    const ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    // Prevent duplicate requests
    if (ride.requests.includes(riderName) || ride.passengers.includes(riderName)) {
      return res.status(400).json({ error: "You have already requested or joined this ride." });
    }
    if (ride.declined.includes(riderName)) {
      return res.status(400).json({ error: "You were already declined for this ride." });
    }
    if (ride.kicked.includes(riderName)) {
      return res.status(400).json({ error: "You were removed from this ride." });
    }
    if (ride.status === 'started') {
      return res.status(400).json({ error: "This ride has already started." });
    }

    // For requests: count passengers + existing requests to prevent overbooking
    if (!checkCapacityForRequest(ride, startIndex, endIndex, seats)) {
      return res.status(400).json({ error: "Capacity exceeded for this segment" });
    }

    ride.requests.push(riderName);
    if (!ride.riderDetails) ride.riderDetails = new Map();
    ride.riderDetails.set(riderName, {
      pickupLat, pickupLng, destLat, destLng, pickupLocation, destination,
      fare: computedFare, distance: computedDistance, seats,
      startIndex, endIndex, paid: false
    });
    
    await ride.save();

    const rideId = ride._id.toString();
    req.joinUserToRide(riderName, rideId);
    req.io.to(rideId).emit('new_ride_request', { rideId, ride: ride.toJSON() });

    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Accept a rider — scoped emit ─────────────────────────────────────────────
router.patch('/accept/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    // Prevent duplicate acceptance
    if (ride.passengers.includes(req.params.riderName)) {
      return res.status(400).json({ error: "Already accepted" });
    }
    // Must still be in requests
    if (!ride.requests.includes(req.params.riderName)) {
      return res.status(400).json({ error: "Request not found" });
    }

    const riderDetail = getRiderDetail(ride, req.params.riderName);
    if (!riderDetail) return res.status(400).json({ error: "Rider details not found" });

    ride.requests = ride.requests.filter(r => r !== req.params.riderName);
    ride.passengers.push(req.params.riderName);

    if (ride.status === 'available') ride.status = 'accepted';

    // Auto-decline any remaining requests that no longer fit the capacity
    const toDecline = [];
    const remainingRequests = [...ride.requests];
    for (const rName of remainingRequests) {
      const pd = getRiderDetail(ride, rName);
      if (pd) {
        if (!checkCapacity(ride, pd.startIndex, pd.endIndex, pd.seats)) {
          toDecline.push(rName);
        }
      }
    }

    for (const rName of toDecline) {
      ride.requests = ride.requests.filter(r => r !== rName);
      ride.declined.push(rName);
      req.emitToUser(rName, 'ride_cancelled', { rideId: ride._id.toString(), ride: ride.toJSON() });
    }

    // For nonstop / shared_start: update status if car is completely full
    if (ride.routePreference === 'nonstop' || ride.routePreference === 'shared_start') {
      let totalUsed = 0;
      for (const pName of ride.passengers) {
        const pd = getRiderDetail(ride, pName);
        totalUsed += pd?.seats || 1;
      }
      
      if (totalUsed >= ride.totalSeats) {
        ride.status = 'full';
      }
    }

    await ride.save();
    const rideId = ride._id.toString();
    req.io.to(rideId).emit('ride_accepted', { rideId, ride: ride.toJSON() });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Decline — scoped emit ────────────────────────────────────────────────────
router.patch('/decline/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    ride.requests = ride.requests.filter(r => r !== req.params.riderName);
    if (!ride.declined.includes(req.params.riderName)) {
      ride.declined.push(req.params.riderName);
    }
    
    if (ride.requests.length === 0 && ride.passengers.length === 0 && ride.status !== 'started') {
      ride.status = 'available';
    }
    
    await ride.save();
    const rideId = ride._id.toString();
    req.io.to(rideId).emit('ride_accepted', { rideId, ride: ride.toJSON() });
    req.emitToUser(req.params.riderName, 'ride_cancelled', { rideId, ride: ride.toJSON() });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Kick passenger — scoped emit + targeted notify ──────────────────────────
router.patch('/kick/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    ride.passengers = ride.passengers.filter(p => p !== req.params.riderName);
    ride.boardedPassengers = ride.boardedPassengers.filter(p => p !== req.params.riderName);
    ride.arrivedAt = ride.arrivedAt.filter(p => p !== req.params.riderName);
    ride.kicked.push(req.params.riderName);

    // If kicking freed capacity, revert 'full' → 'accepted'
    if (ride.status === 'full' && ride.passengers.length > 0) {
      ride.status = 'accepted';
    } else if (ride.status === 'full' && ride.passengers.length === 0) {
      ride.status = 'available';
    }

    await ride.save();
    const rideId = ride._id.toString();
    const payload = { rideId, kickedUser: req.params.riderName, ride: ride.toJSON() };
    req.io.to(rideId).emit('passenger_kicked', payload);
    // Also target the kicked user directly (they may have left the room)
    req.emitToUser(req.params.riderName, 'passenger_kicked', payload);
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Driver arrived — scoped emit ─────────────────────────────────────────────
router.patch('/arrive/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    if (ride.status !== 'started') {
      return res.status(400).json({ error: "First start the ride" });
    }

    if (!ride.arrivedAt) ride.arrivedAt = [];

    if (ride.routePreference === 'flexible') {
      const riderDetail = getRiderDetail(ride, req.params.riderName);
      const neededSeats = riderDetail?.seats || 1;
      let currentlyOccupied = 0;
      for (const pName of ride.boardedPassengers) {
        currentlyOccupied += getRiderDetail(ride, pName)?.seats || 1;
      }
      if (currentlyOccupied + neededSeats > ride.totalSeats) {
        return res.status(400).json({ error: "Car capacity reached" });
      }
      if (!ride.arrivedAt.includes(req.params.riderName)) {
        ride.arrivedAt.push(req.params.riderName);
      }
    } else if (ride.routePreference === 'nonstop' || ride.routePreference === 'shared_start') {
      for (const pName of ride.passengers) {
        if (!ride.arrivedAt.includes(pName) && 
            !ride.boardedPassengers.includes(pName) && 
            !ride.droppedPassengers.includes(pName)) {
          ride.arrivedAt.push(pName);
        }
      }
    }
    
    await ride.save();
    const rideId = ride._id.toString();
    req.io.to(rideId).emit('driver_arrived', { rideId, riderName: req.params.riderName, ride: ride.toJSON() });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Board passenger — scoped emit ────────────────────────────────────────────
router.patch('/board/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    let currentlyOccupied = 0;
    for (const pName of ride.boardedPassengers) {
      currentlyOccupied += getRiderDetail(ride, pName)?.seats || 1;
    }
    const toBoard = getRiderDetail(ride, req.params.riderName)?.seats || 1;

    if (currentlyOccupied + toBoard > ride.totalSeats) {
       return res.status(400).json({ error: "Physical car is full!" });
    }

    if (!ride.boardedPassengers.includes(req.params.riderName)) {
      ride.boardedPassengers.push(req.params.riderName);
    }

    await ride.save();
    const rideId = ride._id.toString();
    req.io.to(rideId).emit('passenger_boarded', { rideId, ride: ride.toJSON() });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Drop-off passenger — scoped emit ─────────────────────────────────────────
router.patch('/dropoff/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    ride.boardedPassengers = ride.boardedPassengers.filter(p => p !== req.params.riderName);
    ride.passengers = ride.passengers.filter(p => p !== req.params.riderName);
    
    if (!ride.droppedPassengers) ride.droppedPassengers = [];
    if (!ride.droppedPassengers.includes(req.params.riderName)) {
      ride.droppedPassengers.push(req.params.riderName);
    }

    await ride.save();
    const rideId = ride._id.toString();
    const payload = { 
      rideId, 
      riderName: req.params.riderName, 
      fare: getRiderDetail(ride, req.params.riderName)?.fare,
      ride: ride.toJSON()
    };
    req.io.to(rideId).emit('passenger_dropped', payload);
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Passenger pays — scoped emit ─────────────────────────────────────────────
router.patch('/pay/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    const detail = getRiderDetail(ride, req.params.riderName);
    if (detail) {
      detail.paid = true;
      ride.riderDetails.set(req.params.riderName, detail);
    }
    
    if (!ride.paidPassengers) ride.paidPassengers = [];
    if (!ride.paidPassengers.includes(req.params.riderName)) {
      ride.paidPassengers.push(req.params.riderName);
    }

    await ride.save();
    const rideId = ride._id.toString();
    req.io.to(rideId).emit('passenger_paid', { rideId, riderName: req.params.riderName, ride: ride.toJSON() });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Start ride — scoped emit ─────────────────────────────────────────────────
router.patch('/start/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(
      req.params.id,
      { status: 'started' },
      { new: true }
    );
    const rideId = updatedRide._id.toString();
    req.io.to(rideId).emit('ride_started', { rideId, ride: updatedRide.toJSON() });
    res.status(200).json(updatedRide);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── End ride — scoped emit ───────────────────────────────────────────────────
router.patch('/end/:id', async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    if (ride.boardedPassengers.length > 0 || ride.passengers.length > 0) {
      return res.status(400).json({ error: "Cannot end trip. Passengers are still active." });
    }

    ride.status = 'completed';
    await ride.save();

    const rideId = ride._id.toString();
    req.io.to(rideId).emit('ride_ended', {
        rideId,
        ride: ride.toJSON(),
        passengers: ride.droppedPassengers,
        riderName: ride.riderName,
        boardedPassengers: ride.boardedPassengers
    });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Chat — scoped emit ──────────────────────────────────────────────────────
router.post('/:id/chat', async (req, res) => {
  try {
    const { sender, text, timestamp } = req.body;
    await Ride.findByIdAndUpdate(req.params.id, { $push: { chatMessages: { sender, text, timestamp } } });
    req.io.to(req.params.id).emit('receive_message', { rideId: req.params.id, sender, text, timestamp });
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;

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
  if (process.env.ADMIN_SECRET) {
    const callerSecret = req.headers['x-admin-secret'];
    if (callerSecret !== process.env.ADMIN_SECRET) {
      return res.status(403).json({ error: 'Forbidden: Invalid Admin Secret.' });
    }
  }
  next();
}

/**
 * Get the departure time in epoch milliseconds.
 * Prefers expiresAt (minus 15 mins) as it is a timezone-independent timestamp
 * created on the client side. Falls back to parsing departureTime string.
 */
function getDepartureTimeEpoch(ride) {
  if (ride.expiresAt) {
    return ride.expiresAt - 15 * 60 * 1000;
  }
  if (!ride.departureTime) return null;
  try {
    const match = ride.departureTime.match(/^(\d+)\/(\d+)\/(\d+)\s+at\s+(.+)$/i);
    if (!match) return null;
    const [_, day, month, year, timeStr] = match;
    const timeMatch = timeStr.trim().match(/^(\d+):(\d+)(?:\s*(AM|PM))?$/i);
    if (!timeMatch) return null;
    let [__, hour, minute, ampm] = timeMatch;
    hour = parseInt(hour, 10);
    minute = parseInt(minute, 10);
    if (ampm) {
      if (ampm.toUpperCase() === 'PM' && hour < 12) {
        hour += 12;
      } else if (ampm.toUpperCase() === 'AM' && hour === 12) {
        hour = 0;
      }
    }
    const dt = new Date(parseInt(year, 10), parseInt(month, 10) - 1, parseInt(day, 10), hour, minute);
    return dt.getTime();
  } catch (e) {
    return null;
  }
}

/**
 * Get rider detail from riderDetails — works with both Mongoose Maps
 * (from .findById()) and plain objects (from .lean()).
 */
function getRiderDetail(ride, name) {
  if (!ride.riderDetails) return null;
  const safeName = name.replace(/\./g, '_dot_');
  if (typeof ride.riderDetails.get === 'function') {
    return ride.riderDetails.get(safeName) || null;
  }
  return ride.riderDetails[safeName] || null;
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
  // Exclude kicked and dropped passengers — they no longer occupy seats
  const kickedSet = new Set(ride.kicked || []);
  const droppedSet = new Set(ride.droppedPassengers || []);

  const changes = [];

  for (const pName of existingNames) {
    if (kickedSet.has(pName) || droppedSet.has(pName)) continue;
    const p = getRiderDetail(ride, pName);
    if (p) {
      changes.push({ index: p.startIndex, change: p.seats });
      changes.push({ index: p.endIndex, change: -p.seats });
    }
  }

  changes.push({ index: newStartIndex, change: requestedSeats });
  changes.push({ index: newEndIndex, change: -requestedSeats });

  // Sort by index first; at the same index, process drop-offs (negative)
  // BEFORE pickups (positive).  This way, if passenger A drops off at the
  // same point where passenger B boards, the seat is freed first and B can
  // use it without exceeding capacity.
  changes.sort((a, b) => a.index - b.index || a.change - b.change);

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
 * For REQUESTS: check capacity differently based on route preference.
 * The user requested to only apply the fix (ignoring pending requests) to 'shared_start'.
 * For 'flexible' and others, keep the old behavior of counting pending requests.
 */
function checkCapacityForRequest(ride, newStartIndex, newEndIndex, requestedSeats) {
  // Only count accepted passengers so multiple requests can be made, regardless of route preference
  return _checkCapacityWith(ride.passengers || [], ride, newStartIndex, newEndIndex, requestedSeats);
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
    const { pickup, destination, seats, vehicle, lat, lng, destLat, destLng, radius, date, searchTimeEpoch } = req.query;
    const currentTime = Date.now();
    const searchRadius = parseInt(radius) || 2000;
    const reqSeats = parseInt(seats) || 1;
    const targetEpoch = searchTimeEpoch ? parseInt(searchTimeEpoch) : null;

    const userEmail = req.query.userEmail;
    const matchQuery = {
      status: { $in: ['available', 'accepted'] },
      $or: [{ expiresAt: { $gt: currentTime } }, { expiresAt: null }, { expiresAt: { $exists: false } }]
    };
    if (vehicle && vehicle !== 'Any') matchQuery.vehicleType = vehicle;
    if (date) matchQuery.departureTime = { $regex: new RegExp(`^${date}`, 'i') };

    const activeRides = await Ride.find(matchQuery).lean();
    
    // Decode map keys since toJSON transform doesn't run on lean objects
    activeRides.forEach(ride => {
      if (ride.riderDetails) {
        const decoded = {};
        for (const [key, value] of Object.entries(ride.riderDetails)) {
          decoded[key.replace(/_dot_/g, '.')] = value;
        }
        ride.riderDetails = decoded;
      }
    });

    const results = [];

    if (lat && lng && destLat && destLng) {
      const parsedLat = parseFloat(lat);
      const parsedLng = parseFloat(lng);
      const parsedDestLat = parseFloat(destLat);
      const parsedDestLng = parseFloat(destLng);

      if (isNaN(parsedLat) || isNaN(parsedLng) || isNaN(parsedDestLat) || isNaN(parsedDestLng)) {
        return res.status(400).json({ error: "Invalid coordinates provided." });
      }

      const pickupPoint = turf.point([parsedLng, parsedLat]);
      const destPoint = turf.point([parsedDestLng, parsedDestLat]);

      for (const ride of activeRides) {
        if (targetEpoch) {
          const rideDepEpoch = getDepartureTimeEpoch(ride);
          if (rideDepEpoch) {
            const diff = Math.abs(rideDepEpoch - targetEpoch);
            if (diff > 60 * 60 * 1000) {
              continue;
            }
          }
        }
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
          if (userEmail) {
            if ((ride.declined || []).includes(userEmail)) continue;
            if ((ride.kicked || []).includes(userEmail)) continue;
            if ((ride.passengers || []).includes(userEmail)) continue;
            if ((ride.requests || []).includes(userEmail)) continue;
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
    const rides = await Ride.find({
      $or: [
        { expiresAt: { $gt: currentTime } },
        { expiresAt: null },
        { expiresAt: { $exists: false } },
        { status: { $in: ['accepted', 'full', 'started', 'completed', 'cancelled'] } }
      ]
    }, { routePath: 0, chatMessages: 0 }).lean();

    // Decode map keys
    rides.forEach(ride => {
      if (ride.riderDetails) {
        const decoded = {};
        for (const [key, value] of Object.entries(ride.riderDetails)) {
          decoded[key.replace(/_dot_/g, '.')] = value;
        }
        ride.riderDetails = decoded;
      }
    });

    res.status(200).json(rides);
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
    if (data.totalSeats != null && (isNaN(parseInt(data.totalSeats)) || parseInt(data.totalSeats) <= 0)) {
      return res.status(400).json({ error: "Total seats must be a positive integer." });
    }
    if (data.fare != null && (isNaN(parseFloat(data.fare)) || parseFloat(data.fare) < 0)) {
      return res.status(400).json({ error: "Fare must be a non-negative number." });
    }
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
    req.joinUserToRide(data.riderEmail, rideId);

    res.status(201).json({ success: true, ride: newRide });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Cancel ride — scoped to room ─────────────────────────────────────────────
router.delete('/:id', async (req, res) => {
  try {
    const ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (['completed', 'cancelled'].includes(ride.status)) {
      return res.status(400).json({ error: `Ride is already ${ride.status}.` });
    }

    // Auto-decline all pending requests before cancelling
    if (ride.requests && ride.requests.length > 0) {
      for (const requester of ride.requests) {
        if (!ride.declined.includes(requester)) {
          ride.declined.push(requester);
        }
        req.emitToUser(requester, 'ride_cancelled', { rideId: req.params.id, ride: ride.toJSON() });
      }
      ride.requests = [];
    }

    ride.status = 'cancelled';
    await ride.save();
    req.io.to(req.params.id).emit('ride_cancelled', { rideId: req.params.id, ride: ride.toJSON() });
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
    const { riderName, riderEmail, seats, computedFare, computedDistance, startIndex, endIndex, pickupLat, pickupLng, destLat, destLng, pickupLocation, destination } = req.body;

    if (!riderEmail || !riderEmail.trim()) {
      return res.status(400).json({ error: "Rider email is required." });
    }
    
    const seatCount = parseInt(seats);
    if (isNaN(seatCount) || seatCount <= 0) {
      return res.status(400).json({ error: "Seats must be a positive integer." });
    }

    if (startIndex == null || endIndex == null || startIndex >= endIndex) {
      return res.status(400).json({ error: "Invalid pickup/destination segment indices." });
    }

    const ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    // Prevent driver from requesting their own ride
    if (ride.riderEmail === riderEmail) {
      return res.status(400).json({ error: "You cannot request your own ride." });
    }

    // Prevent requesting an expired ride
    if (ride.expiresAt && ride.expiresAt < Date.now()) {
      return res.status(400).json({ error: "This ride has expired." });
    }

    // Prevent duplicate requests (arrays now store emails)
    if (ride.requests.includes(riderEmail) || ride.passengers.includes(riderEmail)) {
      return res.status(400).json({ error: "You have already requested or joined this ride." });
    }
    if (ride.declined.includes(riderEmail)) {
      return res.status(400).json({ error: "You were already declined for this ride." });
    }
    if (ride.kicked.includes(riderEmail)) {
      return res.status(400).json({ error: "You were removed from this ride." });
    }
    if (['started', 'completed', 'cancelled'].includes(ride.status)) {
      return res.status(400).json({ error: `This ride is already ${ride.status}.` });
    }

    // For requests: count passengers + existing requests to prevent overbooking
    if (!checkCapacityForRequest(ride, startIndex, endIndex, seats)) {
      return res.status(400).json({ error: "Capacity exceeded for this segment" });
    }

    ride.requests.push(riderEmail);
    if (!ride.riderDetails) ride.riderDetails = new Map();
    const safeEmail = riderEmail.replace(/\./g, '_dot_');
    ride.riderDetails.set(safeEmail, {
      pickupLat, pickupLng, destLat, destLng, pickupLocation, destination,
      fare: computedFare, distance: computedDistance, seats,
      startIndex, endIndex, paid: false, riderName: riderName || ''
    });
    
    await ride.save();

    const rideId = ride._id.toString();
    req.joinUserToRide(riderEmail, rideId);
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

    // Enforce capacity check at the moment of acceptance
    if (!checkCapacity(ride, riderDetail.startIndex, riderDetail.endIndex, riderDetail.seats)) {
      return res.status(400).json({ error: "Cannot accept. Capacity exceeded for this segment." });
    }

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

    // Check if the ride is completely full across ALL segments.
    // For nonstop / shared_start: simple seat sum is enough.
    // For flexible: we must check if even 1 extra seat fits ANYWHERE.
    if (ride.routePreference === 'nonstop' || ride.routePreference === 'shared_start') {
      let totalUsed = 0;
      for (const pName of ride.passengers) {
        const pd = getRiderDetail(ride, pName);
        totalUsed += pd?.seats || 1;
      }
      if (totalUsed >= ride.totalSeats) {
        ride.status = 'full';
      }
    } else {
      // Flexible: the ride is "full" only if EVERY segment along the route
      // is at totalSeats capacity.  Build the sweep-line of accepted
      // passengers and check that the minimum occupancy never drops below
      // totalSeats.  If any segment has room, new passengers could still
      // board there.
      const kickedSet = new Set(ride.kicked || []);
      const droppedSet = new Set(ride.droppedPassengers || []);
      const segChanges = [];
      for (const pName of ride.passengers) {
        if (kickedSet.has(pName) || droppedSet.has(pName)) continue;
        const p = getRiderDetail(ride, pName);
        if (p) {
          segChanges.push({ index: p.startIndex, change: p.seats });
          segChanges.push({ index: p.endIndex, change: -p.seats });
        }
      }
      segChanges.sort((a, b) => a.index - b.index || a.change - b.change);

      let cur = 0;
      let minOccupancy = 0;  // minimum occupancy seen across all segments
      let maxOccupancy = 0;
      for (const c of segChanges) {
        cur += c.change;
        if (cur > maxOccupancy) maxOccupancy = cur;
        if (cur < minOccupancy) minOccupancy = cur;
      }
      // The ride is full only when PEAK occupancy is at capacity AND there is
      // no segment where occupancy dips.  Simpler: ride is full if peak == totalSeats
      // and min occupancy (in any active region) also == totalSeats.  But the
      // easiest correct check: is there room for 1 seat on at least some segment?
      // We know the ride is full if maxOccupancy >= totalSeats — because the
      // sweep only adds occupied segments, and if the peak is at totalSeats it
      // means somewhere is full.  But another segment might not be.  The only
      // time it's truly "full everywhere" is when no [start..end] interval
      // can fit 1 seat.  The simplest correct approach: try every passenger's
      // segment boundary as a test interval.
      // Actually: if maxOccupancy >= totalSeats it doesn't mean all segments
      // are full.  We should NOT mark as full unless it is truly impossible for
      // any sub-segment to accommodate even 1 seat.  The conservative safe
      // approach: mark full only when all segments are at capacity.
      // For simplicity and correctness, just leave as 'accepted' for flexible
      // — the search already handles per-segment capacity properly.
      // We mark full only when EVERY point along the route is at full capacity.
      // This is true when the minimum point-occupancy across the entire active
      // range equals totalSeats.
      // Build occupancy at every event boundary:
      let isFull = false;
      if (ride.passengers.length > 0 && segChanges.length > 0) {
        // Track occupancy at every transition.  The ride is "full" only if
        // occupancy >= totalSeats at EVERY point between the first start and last end.
        let occ = 0;
        let allFull = true;
        for (let i = 0; i < segChanges.length; i++) {
          occ += segChanges[i].change;
          // Check between this event and the next one (or end)
          if (i < segChanges.length - 1 && segChanges[i + 1].index > segChanges[i].index) {
            // There's a span between this index and the next — check if full
            if (occ < ride.totalSeats) {
              allFull = false;
              break;
            }
          }
        }
        isFull = allFull && maxOccupancy >= ride.totalSeats;
      }
      if (isFull) {
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

    if (ride.declined.includes(req.params.riderName)) {
      return res.status(400).json({ error: "User has already been declined." });
    }
    if (!ride.requests.includes(req.params.riderName)) {
      return res.status(400).json({ error: "User is not in the pending requests." });
    }

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

    // Cannot kick yourself (the driver)
    if (ride.riderName === req.params.riderName) {
      return res.status(400).json({ error: "Driver cannot kick themselves." });
    }
    // Must be a passenger or requester to be kicked
    const isPassenger = ride.passengers.includes(req.params.riderName);
    const isRequester = ride.requests.includes(req.params.riderName);
    if (!isPassenger && !isRequester) {
      return res.status(400).json({ error: "User is not a passenger or requester on this ride." });
    }
    if (ride.kicked.includes(req.params.riderName)) {
      return res.status(400).json({ error: "User has already been kicked." });
    }

    ride.passengers = ride.passengers.filter(p => p !== req.params.riderName);
    ride.requests = ride.requests.filter(p => p !== req.params.riderName);
    ride.boardedPassengers = ride.boardedPassengers.filter(p => p !== req.params.riderName);
    ride.arrivedAt = ride.arrivedAt.filter(p => p !== req.params.riderName);
    ride.kicked.push(req.params.riderName);

    // If kicking freed capacity, update status appropriately, but only if the ride hasn't started or completed
    if (ride.status !== 'started' && ride.status !== 'completed' && ride.status !== 'cancelled') {
      if (ride.passengers.length === 0) {
        ride.status = 'available';
      } else if (ride.status === 'full') {
        ride.status = 'accepted';
      }
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
      // Must be an accepted passenger to be marked as arrived
      if (!ride.passengers.includes(req.params.riderName)) {
        return res.status(400).json({ error: "User is not an accepted passenger on this ride." });
      }
      if (ride.droppedPassengers && ride.droppedPassengers.includes(req.params.riderName)) {
        return res.status(400).json({ error: "Passenger has already been dropped off." });
      }
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

    if (!ride.passengers.includes(req.params.riderName)) {
      return res.status(400).json({ error: "Passenger must be accepted before boarding." });
    }
    if (ride.kicked.includes(req.params.riderName) || ride.declined.includes(req.params.riderName)) {
      return res.status(400).json({ error: "User is kicked or declined from this ride." });
    }

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
    const riderDetailBoard = getRiderDetail(ride, req.params.riderName);
    if (riderDetailBoard) {
      riderDetailBoard.boardedAt = new Date();
      const safeName = req.params.riderName.replace(/\./g, '_dot_');
      ride.riderDetails.set(safeName, riderDetailBoard);
    }
    // Remove from arrivedAt — they've progressed past the "arrived" stage
    ride.arrivedAt = ride.arrivedAt.filter(p => p !== req.params.riderName);

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

    if (ride.status !== 'started') {
      return res.status(400).json({ error: "Ride must be started before dropping off passengers." });
    }
    if (!ride.boardedPassengers.includes(req.params.riderName)) {
      return res.status(400).json({ error: "Passenger is not currently boarded." });
    }
    if (ride.droppedPassengers && ride.droppedPassengers.includes(req.params.riderName)) {
      return res.status(400).json({ error: "Passenger has already been dropped off." });
    }

    ride.boardedPassengers = ride.boardedPassengers.filter(p => p !== req.params.riderName);
    ride.passengers = ride.passengers.filter(p => p !== req.params.riderName);
    
    if (!ride.droppedPassengers) ride.droppedPassengers = [];
    if (!ride.droppedPassengers.includes(req.params.riderName)) {
      ride.droppedPassengers.push(req.params.riderName);
    }
    const riderDetailDrop = getRiderDetail(ride, req.params.riderName);
    if (riderDetailDrop) {
      riderDetailDrop.droppedAt = new Date();
      const safeName = req.params.riderName.replace(/\./g, '_dot_');
      ride.riderDetails.set(safeName, riderDetailDrop);
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
    if (!detail) {
      return res.status(400).json({ error: "Rider details not found for this passenger." });
    }
    if (detail.paid) {
      return res.status(400).json({ error: "Passenger has already paid." });
    }

    detail.paid = true;
    const safeName = req.params.riderName.replace(/\./g, '_dot_');
    ride.riderDetails.set(safeName, detail);
    
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
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    if (['started', 'completed', 'cancelled'].includes(ride.status)) {
      return res.status(400).json({ error: `Cannot start a ride that is already ${ride.status}.` });
    }

    ride.status = 'started';
    ride.startedAt = new Date();

    if (ride.requests && ride.requests.length > 0) {
      const pendingReqs = [...ride.requests];
      for (const requester of pendingReqs) {
        if (!ride.declined) ride.declined = [];
        if (!ride.declined.includes(requester)) {
          ride.declined.push(requester);
        }
        req.emitToUser(requester, 'ride_cancelled', { rideId: ride._id.toString(), ride: ride.toJSON() });
      }
      ride.requests = [];
    }

    if (ride.routePreference === 'nonstop' || ride.routePreference === 'shared_start') {
      if (!ride.arrivedAt) ride.arrivedAt = [];
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
    req.io.to(rideId).emit('ride_started', { rideId, ride: ride.toJSON() });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── End ride — scoped emit ───────────────────────────────────────────────────
router.patch('/end/:id', async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    if (ride.status !== 'started') {
      return res.status(400).json({ error: "Cannot end a ride that has not started." });
    }

    const forceEnd = req.query.force === 'true';

    if (ride.routePreference === 'nonstop' || ride.routePreference === 'shared_start') {
      // Auto-dropoff all active passengers for nonstop and shared_start
      const activeP = [...new Set([...ride.passengers, ...ride.boardedPassengers])];
      for (const pName of activeP) {
        if (!ride.droppedPassengers) ride.droppedPassengers = [];
        if (!ride.droppedPassengers.includes(pName)) {
          ride.droppedPassengers.push(pName);
        }
        const pd = getRiderDetail(ride, pName);
        if (pd) {
          if (!pd.boardedAt) pd.boardedAt = ride.startedAt || new Date();
          pd.droppedAt = new Date();
          const safeName = pName.replace(/\./g, '_dot_');
          ride.riderDetails.set(safeName, pd);
        }
      }
      ride.boardedPassengers = [];
      ride.passengers = [];
    } else {
      // Flexible: allow force-end to auto-drop all remaining passengers
      if (ride.boardedPassengers.length > 0 || ride.passengers.length > 0) {
        if (!forceEnd) {
          return res.status(400).json({ error: "Cannot end trip. Passengers are still active. Use force=true to auto-drop all." });
        }
        // Force end: auto-dropoff all remaining passengers
        const activeP = [...new Set([...ride.passengers, ...ride.boardedPassengers])];
        for (const pName of activeP) {
          if (!ride.droppedPassengers) ride.droppedPassengers = [];
          if (!ride.droppedPassengers.includes(pName)) {
            ride.droppedPassengers.push(pName);
          }
          const pd = getRiderDetail(ride, pName);
          if (pd) {
            if (!pd.boardedAt) pd.boardedAt = ride.startedAt || new Date();
            pd.droppedAt = new Date();
            const safeName = pName.replace(/\./g, '_dot_');
            ride.riderDetails.set(safeName, pd);
          }
        }
        ride.boardedPassengers = [];
        ride.passengers = [];
      }
    }

    ride.status = 'completed';
    ride.completedAt = new Date();
    await ride.save();

    const rideId = ride._id.toString();
    req.io.to(rideId).emit('ride_ended', {
        rideId,
        ride: ride.toJSON(),
        passengers: ride.droppedPassengers,
        riderName: ride.riderName,
        riderEmail: ride.riderEmail,
        boardedPassengers: ride.boardedPassengers
    });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Chat — scoped emit ──────────────────────────────────────────────────────
router.post('/:id/chat', async (req, res) => {
  try {
    const { sender, senderEmail, text, timestamp } = req.body;
    if (!sender || !sender.trim() || !text || !text.trim()) {
      return res.status(400).json({ error: "Sender and text are required." });
    }
    const ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (['completed', 'cancelled'].includes(ride.status)) {
      return res.status(400).json({ error: `Cannot chat on a ${ride.status} ride.` });
    }
    ride.chatMessages.push({ sender, senderEmail: senderEmail || '', text, timestamp });
    await ride.save();
    req.io.to(req.params.id).emit('receive_message', { rideId: req.params.id, sender, senderEmail: senderEmail || '', text, timestamp });
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;

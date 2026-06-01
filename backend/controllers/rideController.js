const logger = require('../utils/logger');
const Ride = require('../models/ride');
const turf = require('@turf/turf');
const { isValidEmail, isValidObjectId } = require('../utils/validators');
const { emailToKey, keyToEmail } = require('../utils/emailKey');
const asyncHandler = require('../utils/asyncHandler');
const sanitizeHtml = require('sanitize-html');
const { 
  getDepartureTimeEpoch, 
  getRiderDetail, 
  checkCapacityForSearch, 
  checkCapacityForRequest, 
  checkCapacity,
  decodeRiderDetailsForSocket,
  sanitizeRideForBroadcast
} = require('../utils/rideHelpers');

// ── Environment-configurable constants ──────────────────────────────────────
const MAX_ROUTE_POINTS = parseInt(process.env.MAX_ROUTE_POINTS) || 500;
const MIN_RIDE_DISTANCE_KM = parseFloat(process.env.MIN_RIDE_DISTANCE_KM) || 1.5;
const DEFAULT_RADIUS = parseInt(process.env.SEARCH_RADIUS_DEFAULT_M) || 2000;
const SEARCH_TIME_WINDOW = parseInt(process.env.SEARCH_TIME_WINDOW_MS) || 60 * 60 * 1000;
const CHAT_MAX_LENGTH = parseInt(process.env.CHAT_MAX_LENGTH) || 1000;

// ── Search rides ─────────────────────────────────────────────────────────────
exports.searchRides = async (req, res) => {
  try {
    const { pickup, destination, seats, vehicle, lat, lng, destLat, destLng, radius, date, searchTimeEpoch } = req.query;
    const currentTime = Date.now();
    const searchRadius = parseInt(radius) || DEFAULT_RADIUS;
    const reqSeats = parseInt(seats) || 1;
    const targetEpoch = searchTimeEpoch ? parseInt(searchTimeEpoch) : null;

    const userEmail = req.user?.email;
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
          decoded[keyToEmail(key)] = value;
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
            if (diff > SEARCH_TIME_WINDOW) {
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
          // Skip rides where the searching user is the driver, or has been declined, kicked, or is already a passenger/requester
          if (userEmail) {
            if (ride.riderEmail === userEmail) continue;
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

          if (tripDistance < MIN_RIDE_DISTANCE_KM) continue; // Minimum distance check

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
            // If percentage is >= 0.99, charge full fare to avoid rounding losses
            const computedFare = percentage >= 0.99 ? ride.fare : Math.round(ride.fare * percentage);

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
};

exports.getAllRides = async (req, res) => {
  try {
    const userEmail = req.user?.email;
    const ADMIN_EMAILS = (process.env.ADMIN_EMAILS || '').split(',').map(e => e.trim().toLowerCase()).filter(Boolean);
    const lowerUserEmail = userEmail ? userEmail.toLowerCase() : '';
    const query = ADMIN_EMAILS.includes(lowerUserEmail) ? {} : {
      $or: [
        { riderEmail: lowerUserEmail },
        { passengers: lowerUserEmail },
        { requests: lowerUserEmail },
        { droppedPassengers: lowerUserEmail },
        { declined: lowerUserEmail },
        { kicked: lowerUserEmail },
      ]
    };

    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, parseInt(req.query.limit) || 20);
    const skip = (page - 1) * limit;

    const [rides, total] = await Promise.all([
      Ride.find(query, { routePath: 0, chatMessages: 0 })
        .sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      Ride.countDocuments(query)
    ]);

    // Decode map keys
    rides.forEach(ride => {
      if (ride.riderDetails) {
        const decoded = {};
        for (const [key, value] of Object.entries(ride.riderDetails)) {
          decoded[keyToEmail(key)] = value;
        }
        ride.riderDetails = decoded;
      }
    });

    res.status(200).json({
      rides,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) }
    });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

exports.getRideById = async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid ride ID format.' });
    }
    const ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: 'Ride not found.' });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── Create ride — join driver into room ──────────────────────────────────────
// MAX_ROUTE_POINTS defined at top of file from env
exports.createRide = async (req, res) => {
  try {
    const data = req.body;
    data.riderEmail = req.user.email.trim().toLowerCase();
    
    if (data.riderName) {
      data.riderName = String(data.riderName).trim().replace(/<[^>]*>/g, '').substring(0, 200);
    }

    if (!data.routePath || !Array.isArray(data.routePath) || data.routePath.length < 2) {
      return res.status(400).json({ error: "Invalid routePath." });
    }
    
    const validCoord = (p) =>
      p !== null && typeof p === 'object' &&
      isFinite(p.lat) && isFinite(p.lng) &&
      p.lat >= -90 && p.lat <= 90 && p.lng >= -180 && p.lng <= 180;

    if (!data.routePath.every(validCoord)) {
      return res.status(400).json({ error: "routePath contains one or more invalid coordinates." });
    }
    
    const isValidCoord = (lat, lng) => isFinite(lat) && isFinite(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
    if (!isValidCoord(data.pickupLat, data.pickupLng) || !isValidCoord(data.destLat, data.destLng)) {
      return res.status(400).json({ error: "Invalid coordinates." });
    }

    if (data.totalSeats != null && (!Number.isInteger(Number(data.totalSeats)) || data.totalSeats < 1 || data.totalSeats > 8)) {
      return res.status(400).json({ error: "Total seats must be an integer between 1 and 8." });
    }
    
    if (!['Bike', 'Sedan', 'SUV'].includes(data.vehicleType)) {
      return res.status(400).json({ error: "Invalid vehicle type." });
    }
    
    if (!['flexible', 'shared_start', 'nonstop'].includes(data.routePreference)) {
      return res.status(400).json({ error: "Invalid route preference." });
    }

    const fare = parseInt(data.fare);
    if (isNaN(fare) || fare < 1 || fare > parseInt(process.env.MAX_FARE || 9999)) {
      return res.status(400).json({ error: `Fare must be between ₹1 and ₹${process.env.MAX_FARE || 9999}.` });
    }
    data.fare = fare;

    const departureEpoch = data.expiresAt; // keep for reference if provided
    let depEpoch = departureEpoch && typeof departureEpoch === 'number'
      ? departureEpoch : Date.now() + (2 * 60 * 60 * 1000);
    const now = Date.now();
    depEpoch = Math.max(depEpoch, now + 5 * 60 * 1000);
    depEpoch = Math.min(depEpoch, now + 7 * 24 * 60 * 60 * 1000);
    data.expiresAt = depEpoch + (15 * 60 * 1000);
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
};

// ── Cancel ride — scoped to room ─────────────────────────────────────────────
exports.cancelRide = async (req, res) => {
  try {
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid ride ID.' });
    }
    const ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    // Ownership check: only the driver (or admin) can cancel
    const ADMIN_EMAILS = (process.env.ADMIN_EMAILS || '').split(',').map(e => e.trim().toLowerCase()).filter(Boolean);
    if (req.user.email !== ride.riderEmail && !ADMIN_EMAILS.includes(req.user.email)) {
      return res.status(403).json({ error: 'Only the ride driver can cancel this ride.' });
    }

    if (['completed', 'cancelled'].includes(ride.status)) {
      return res.status(400).json({ error: `Ride is already ${ride.status}.` });
    }

    // Auto-decline all pending requests before cancelling
    const notifiedRequesters = [];
    if (ride.requests && ride.requests.length > 0) {
      for (const requester of ride.requests) {
        if (!ride.declined.includes(requester)) {
          ride.declined.push(requester);
        }
        notifiedRequesters.push(requester);
        req.removeUserFromRide(requester, req.params.id);
      }
      ride.requests = [];
    }

    ride.status = 'cancelled';
    await ride.save();
    
    const finalPayload = { rideId: req.params.id, ride: decodeRiderDetailsForSocket(ride.toJSON()) };
    
    for (const requester of notifiedRequesters) {
      req.emitToUser(requester, 'ride_cancelled', finalPayload);
    }
    req.io.to(req.params.id).emit('ride_cancelled', finalPayload);
    req.io.emit('ride_cancelled_global', finalPayload); // Broadcast globally for search screens
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── Wipe all — global broadcast (admin only) ────────────────────────────────
exports.deleteAllRides = async (req, res) => {
  try {
    await Ride.deleteMany({});
    req.io.emit('database_wiped');
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── Request a ride — join requester + scoped emit ────────────────────────────
exports.requestRide = async (req, res) => {
  let retries = 5;
  while (retries > 0) {
    try {
      const { riderName, seats, computedFare, computedDistance, startIndex, endIndex, pickupLat, pickupLng, destLat, destLng, pickupLocation, destination } = req.body;
      const riderEmail = req.user.email;
      
      const seatCount = parseInt(seats);
      if (isNaN(seatCount) || seatCount <= 0 || seatCount > 8) {
        return res.status(400).json({ error: "Seats must be an integer between 1 and 8." });
      }

      if (startIndex == null || endIndex == null || startIndex >= endIndex) {
        return res.status(400).json({ error: "Invalid pickup/destination segment indices." });
      }
      // Bounds check: indices must be within the route
      const parsedStart = parseInt(startIndex);
      const parsedEnd = parseInt(endIndex);

      const ride = await Ride.findById(req.params.id);
      if (!ride) return res.status(404).json({ error: "Ride not found" });

      if (
        isNaN(parsedStart) || isNaN(parsedEnd) ||
        parsedStart < 0 || parsedEnd <= 0 ||
        parsedStart >= parsedEnd ||
        parsedEnd >= ride.routePath.length
      ) {
        return res.status(400).json({ error: "Invalid segment indices. Must be within route bounds." });
      }

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
      const safeEmail = emailToKey(riderEmail);
      // Server-side fare recalculation to prevent client-side manipulation
      let serverFare = computedFare;
      if (ride.routePath && ride.routePath.length >= 2 && parsedEnd <= ride.routePath.length) {
        let tripDist = 0;
        const sampleCount = 100;
        const distStep = Math.max(1, Math.floor((parsedEnd - parsedStart) / sampleCount));
        for (let i = parsedStart; i < parsedEnd; i += distStep) {
          const nextIdx = Math.min(i + distStep, parsedEnd);
          tripDist += turf.distance(
            turf.point([ride.routePath[i].lng, ride.routePath[i].lat]),
            turf.point([ride.routePath[nextIdx].lng, ride.routePath[nextIdx].lat]),
            { units: 'kilometers' }
          );
        }
        let percentage = tripDist / (ride.totalDistance || tripDist || 1);
        if (percentage > 1) percentage = 1;
        serverFare = percentage >= 0.99 ? ride.fare : Math.round(ride.fare * percentage);
      }
      if (serverFare < 1) serverFare = 1;
      
      ride.riderDetails.set(safeEmail, {
        pickupLat, pickupLng, destLat, destLng, pickupLocation, destination,
        fare: serverFare, distance: computedDistance, seats: seatCount,
        startIndex: parsedStart, endIndex: parsedEnd, paid: false, riderName: riderName || ''
      });
      
      const updateResult = await Ride.findOneAndUpdate(
        { _id: ride._id, optimisticLock: ride.optimisticLock },
        {
          $set: {
            requests: [...ride.requests],
            riderDetails: ride.riderDetails
          },
          $inc: { optimisticLock: 1 }
        },
        { new: true }
      );

      if (!updateResult) {
        retries--;
        if (retries === 0) {
          return res.status(409).json({
            error: 'Concurrent modification detected. Please retry.',
            code: 'OPTIMISTIC_LOCK_CONFLICT'
          });
        }
        // Random jitter between 20ms and 100ms
        await new Promise(r => setTimeout(r, Math.random() * 80 + 20));
        continue;
      }

      const rideId = updateResult._id.toString();
      req.joinUserToRide(riderEmail, rideId);
      
      const ridePayload = decodeRiderDetailsForSocket(updateResult.toJSON());
      req.io.to(rideId).emit('new_ride_request', { rideId, ride: ridePayload });
      req.emitToUser(ride.riderEmail, 'new_ride_request', { rideId, ride: ridePayload });

      return res.status(200).json({ success: true });
    } catch (err) { 
      return res.status(500).json({ error: err.message }); 
    }
  }
};

// ── Accept a rider — scoped emit ─────────────────────────────────────────────
exports.acceptRider = async (req, res) => {
  let retries = 5;
  while (retries > 0) {
    try {
      const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
      let ride = await Ride.findById(req.params.id);
      if (!ride) return res.status(404).json({ error: "Ride not found" });
      if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });

      // Prevent duplicate acceptance
      if (ride.passengers.includes(passengerEmail)) {
        return res.status(400).json({ error: "Already accepted" });
      }
      // Must still be in requests
      if (!ride.requests.includes(passengerEmail)) {
        return res.status(400).json({ error: "Request not found" });
      }

      const riderDetail = getRiderDetail(ride, passengerEmail);
      if (!riderDetail) {
        return res.status(400).json({ error: "Rider details not found" });
      }

      // Final capacity check (sweep-line check)
      if (!checkCapacity(ride, riderDetail.startIndex, riderDetail.endIndex, riderDetail.seats)) {
        return res.status(400).json({ error: "Not enough capacity" });
      }

      // Move from requests to passengers
      ride.requests = ride.requests.filter(r => r !== passengerEmail);
      ride.passengers.push(passengerEmail);
      
      // Update paid status if needed (though driver accept usually doesn't set paid = true)
      // riderDetail is updated inside the Map indirectly if we use set
      ride.riderDetails.set(emailToKey(passengerEmail), riderDetail);

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
        req.emitToUser(rName, 'ride_cancelled', { rideId: ride._id.toString(), ride: decodeRiderDetailsForSocket(ride.toJSON()) });
        req.removeUserFromRide(rName, ride._id.toString());
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
          const routeLength = (ride.routePath || []).length;
          // The first event is the earliest passenger pickup index.
          // If it's > 0, the segment [0, firstEvent) has 0 occupancy → not full.
          const firstEventIndex = segChanges[0].index;
          // After processing all events, occupancy returns to 0.
          // The last event is the latest drop-off. If it's before the route end,
          // the segment [lastEvent, routeEnd) has 0 occupancy → not full.
          const lastEventIndex = segChanges[segChanges.length - 1].index;

          if (firstEventIndex > 0 || lastEventIndex < routeLength - 1) {
            // There are uncovered segments at the start/end of the route
            // where occupancy is 0, so the ride is NOT full.
            isFull = false;
          } else {
            // All events span the entire route — check each segment between events
            let occ = 0;
            let allFull = true;
            for (let i = 0; i < segChanges.length; i++) {
              occ += segChanges[i].change;
              if (i < segChanges.length - 1 && segChanges[i + 1].index > segChanges[i].index) {
              if (occ < ride.totalSeats) {
                allFull = false;
                break;
              }
            }
          }
          isFull = allFull && maxOccupancy >= ride.totalSeats;
        }
      }
      if (isFull) {
        ride.status = 'full';
      }
    }

    const updateResult = await Ride.findOneAndUpdate(
      {
        _id: ride._id,
        optimisticLock: ride.optimisticLock,
        requests: passengerEmail
      },
      {
        $set: {
          status: ride.status,
          passengers: ride.passengers,
          requests: ride.requests,
          declined: ride.declined,
          riderDetails: ride.riderDetails,
        },
        $inc: { optimisticLock: 1 }
      },
      { new: true }
    );

    if (!updateResult) {
      retries--;
      if (retries === 0) {
        return res.status(409).json({
          error: 'Concurrent modification detected. The ride state changed. Please retry.',
          code: 'OPTIMISTIC_LOCK_CONFLICT'
        });
      }
      await new Promise(r => setTimeout(r, Math.random() * 80 + 20));
      continue;
    }

    const rideId = updateResult._id.toString();
    const decodedFullRide = decodeRiderDetailsForSocket(updateResult.toJSON());
    
    const participants = new Set([
      decodedFullRide.riderEmail,
      ...(decodedFullRide.passengers || []),
      ...(decodedFullRide.requests || [])
    ]);

    for (const p of participants) {
      req.emitToUser(p, 'ride_accepted', {
        rideId,
        ride: sanitizeRideForBroadcast(decodedFullRide, p)
      });
    }
    
    // Also broadcast to the ride room so that active listeners (e.g. LiveTrackingScreen) update immediately
    req.io.to(rideId).emit('ride_updated', { rideId, ride: decodedFullRide });
    req.io.emit('ride_updated_global', { rideId, ride: decodedFullRide }); // Broadcast for search screens

    return res.status(200).json(updateResult);
    } catch (err) { 
      return res.status(500).json({ error: err.message }); 
    }
  }
};

// ── Decline — scoped emit ────────────────────────────────────────────────────
exports.declineRider = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail && req.user.email !== passengerEmail) {
      return res.status(403).json({ error: 'Only the driver or the requester can perform this action.' });
    }

    if (ride.declined.includes(passengerEmail)) {
      return res.status(400).json({ error: "User has already been declined." });
    }
    if (!ride.requests.includes(passengerEmail)) {
      return res.status(400).json({ error: "User is not in the pending requests." });
    }

    ride.requests = ride.requests.filter(r => r !== passengerEmail);
    if (!ride.declined.includes(passengerEmail)) {
      ride.declined.push(passengerEmail);
    }
    
    if (ride.requests.length === 0 && ride.passengers.length === 0 && ride.status !== 'started') {
      ride.status = 'available';
    }
    
    await ride.save();
    const rideId = ride._id.toString();
    const ridePayload = decodeRiderDetailsForSocket(ride.toJSON());
    // Fix: Emit 'ride_cancelled' to the declined requester. Note: we do NOT emit 'ride_accepted' 
    // to the room to avoid false UI updates for others.
    req.emitToUser(passengerEmail, 'ride_cancelled', { rideId, ride: ridePayload });
    // Notify the ride room (driver + other participants) so their UI updates in real-time
    req.io.to(rideId).emit('ride_updated', { rideId, ride: ridePayload });
    req.removeUserFromRide(passengerEmail, rideId);
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── Kick passenger — scoped emit + targeted notify ──────────────────────────
exports.kickPassenger = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });

    // Cannot kick yourself (the driver)
    if (ride.riderEmail === passengerEmail) {
      return res.status(400).json({ error: "Driver cannot kick themselves." });
    }
    // Must be a passenger or requester to be kicked
    const isPassenger = ride.passengers.includes(passengerEmail);
    const isRequester = ride.requests.includes(passengerEmail);
    if (!isPassenger && !isRequester) {
      return res.status(400).json({ error: "User is not a passenger or requester on this ride." });
    }
    if (ride.kicked.includes(passengerEmail)) {
      return res.status(400).json({ error: "User has already been kicked." });
    }

    ride.passengers = ride.passengers.filter(p => p !== passengerEmail);
    ride.requests = ride.requests.filter(p => p !== passengerEmail);
    ride.boardedPassengers = ride.boardedPassengers.filter(p => p !== passengerEmail);
    ride.arrivedAt = ride.arrivedAt.filter(p => p !== passengerEmail);
    ride.kicked.push(passengerEmail);

    // Save kickedAt timestamp in riderDetails for duration calculation
    const riderDetail = getRiderDetail(ride, passengerEmail);
    if (riderDetail) {
      riderDetail.kickedAt = new Date();
      const safeName = emailToKey(passengerEmail);
      ride.riderDetails.set(safeName, riderDetail);
    }

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
    const payload = { rideId, kickedUser: passengerEmail, ride: decodeRiderDetailsForSocket(ride.toJSON()) };
    req.io.to(rideId).emit('passenger_kicked', payload);
    // Also target the kicked user directly (they may have left the room)
    req.emitToUser(passengerEmail, 'passenger_kicked', payload);
    req.removeUserFromRide(passengerEmail, rideId);
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── Driver arrived — scoped emit ─────────────────────────────────────────────
exports.driverArrived = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });

    if (ride.status !== 'started') {
      return res.status(400).json({ error: "First start the ride" });
    }

    const arrivedAt = [...(ride.arrivedAt || [])];

    if (ride.routePreference === 'flexible') {
      if (!ride.passengers.includes(passengerEmail)) {
        return res.status(400).json({ error: "User is not an accepted passenger on this ride." });
      }
      if (ride.droppedPassengers && ride.droppedPassengers.includes(passengerEmail)) {
        return res.status(400).json({ error: "Passenger has already been dropped off." });
      }
      if (arrivedAt.includes(passengerEmail)) {
        return res.status(400).json({ error: "Already marked as arrived." });
      }
      const riderDetail = getRiderDetail(ride, passengerEmail);
      const neededSeats = riderDetail?.seats || 1;
      let currentlyOccupied = 0;
      for (const pName of ride.boardedPassengers) {
        currentlyOccupied += getRiderDetail(ride, pName)?.seats || 1;
      }
      if (currentlyOccupied + neededSeats > ride.totalSeats) {
        return res.status(400).json({ error: "Car capacity reached" });
      }
      arrivedAt.push(passengerEmail);
    } else if (ride.routePreference === 'nonstop' || ride.routePreference === 'shared_start') {
      for (const pName of ride.passengers) {
        if (!arrivedAt.includes(pName) && 
            !ride.boardedPassengers.includes(pName) && 
            !ride.droppedPassengers.includes(pName)) {
          arrivedAt.push(pName);
        }
      }
    }
    
    const updateResult = await Ride.findOneAndUpdate(
      {
        _id: ride._id,
        optimisticLock: ride.optimisticLock,
      },
      {
        $set: { arrivedAt },
        $inc: { optimisticLock: 1 }
      },
      { new: true }
    );

    if (!updateResult) {
      return res.status(409).json({
        error: 'Concurrent modification detected. Please retry.',
        code: 'OPTIMISTIC_LOCK_CONFLICT'
      });
    }

    const rideId = updateResult._id.toString();
    req.io.to(rideId).emit('driver_arrived', { rideId, riderName: passengerEmail, ride: decodeRiderDetailsForSocket(updateResult.toJSON()) });
    res.status(200).json(updateResult);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── Board passenger — scoped emit ────────────────────────────────────────────
exports.boardPassenger = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (ride.status !== 'started') {
      return res.status(400).json({ error: "Passenger must be accepted before boarding." });
    }
    if (ride.kicked.includes(passengerEmail) || ride.declined.includes(passengerEmail)) {
      return res.status(400).json({ error: "User is kicked or declined from this ride." });
    }
    if (ride.boardedPassengers.includes(passengerEmail)) {
      return res.status(400).json({ error: "Passenger is already boarded." });
    }

    let currentlyOccupied = 0;
    for (const pName of ride.boardedPassengers) {
      currentlyOccupied += getRiderDetail(ride, pName)?.seats || 1;
    }
    const toBoard = getRiderDetail(ride, passengerEmail)?.seats || 1;

    if (currentlyOccupied + toBoard > ride.totalSeats) {
       return res.status(400).json({ error: "Physical car is full!" });
    }

    // Prepare updated fields
    const boardedPassengers = [...ride.boardedPassengers, passengerEmail];
    const riderDetailBoard = getRiderDetail(ride, passengerEmail);
    if (riderDetailBoard) {
      riderDetailBoard.boardedAt = new Date();
      const safeName = emailToKey(passengerEmail);
      ride.riderDetails.set(safeName, riderDetailBoard);
    }
    const arrivedAt = (ride.arrivedAt || []).filter(p => p !== passengerEmail);

    const updateResult = await Ride.findOneAndUpdate(
      {
        _id: ride._id,
        optimisticLock: ride.optimisticLock,
        boardedPassengers: { $ne: passengerEmail } // atomic guard: not already boarded
      },
      {
        $set: {
          boardedPassengers,
          arrivedAt,
          riderDetails: ride.riderDetails,
        },
        $inc: { optimisticLock: 1 }
      },
      { new: true }
    );

    if (!updateResult) {
      return res.status(409).json({
        error: 'Action already processed or concurrent modification. Please retry.',
        code: 'OPTIMISTIC_LOCK_CONFLICT'
      });
    }

    const rideId = updateResult._id.toString();
    req.io.to(rideId).emit('passenger_boarded', { rideId, riderName: passengerEmail, ride: decodeRiderDetailsForSocket(updateResult.toJSON()) });
    res.status(200).json(updateResult);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── Drop-off passenger — scoped emit ─────────────────────────────────────────
exports.dropOffPassenger = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });

    if (ride.status !== 'started') {
      return res.status(400).json({ error: "Ride must be started before dropping off passengers." });
    }
    if (!ride.boardedPassengers.includes(passengerEmail)) {
      return res.status(400).json({ error: "Passenger is not currently boarded." });
    }
    if (ride.droppedPassengers && ride.droppedPassengers.includes(passengerEmail)) {
      return res.status(400).json({ error: "Passenger has already been dropped off." });
    }

    const boardedPassengers = ride.boardedPassengers.filter(p => p !== passengerEmail);
    const passengers = ride.passengers.filter(p => p !== passengerEmail);
    
    const droppedPassengers = [...(ride.droppedPassengers || [])];
    if (!droppedPassengers.includes(passengerEmail)) {
      droppedPassengers.push(passengerEmail);
    }
    const riderDetailDrop = getRiderDetail(ride, passengerEmail);
    if (riderDetailDrop) {
      riderDetailDrop.droppedAt = new Date();
      const safeName = emailToKey(passengerEmail);
      ride.riderDetails.set(safeName, riderDetailDrop);
    }

    const updateResult = await Ride.findOneAndUpdate(
      {
        _id: ride._id,
        optimisticLock: ride.optimisticLock,
        droppedPassengers: { $ne: passengerEmail } // atomic guard: not already dropped
      },
      {
        $set: {
          boardedPassengers,
          passengers,
          droppedPassengers,
          riderDetails: ride.riderDetails,
        },
        $inc: { optimisticLock: 1 }
      },
      { new: true }
    );

    if (!updateResult) {
      return res.status(409).json({
        error: 'Action already processed or concurrent modification. Please retry.',
        code: 'OPTIMISTIC_LOCK_CONFLICT'
      });
    }

    const rideId = updateResult._id.toString();
    const fare = getRiderDetail(updateResult, passengerEmail)?.fare;
    const payload = { 
      rideId, 
      riderName: passengerEmail, 
      fare,
      ride: decodeRiderDetailsForSocket(updateResult.toJSON())
    };
    req.io.to(rideId).emit('passenger_dropped', payload);
    req.removeUserFromRide(passengerEmail, rideId);
    res.status(200).json(updateResult);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── Passenger pays — scoped emit ─────────────────────────────────────────────
exports.passengerPays = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== passengerEmail) return res.status(403).json({ error: 'You can only mark yourself as paid.' });

    const detail = getRiderDetail(ride, passengerEmail);
    if (!detail) {
      return res.status(400).json({ error: "Rider details not found for this passenger." });
    }
    if (detail.paid) {
      return res.status(400).json({ error: "Passenger has already paid." });
    }

    detail.paid = true;
    const safeName = emailToKey(passengerEmail);
    ride.riderDetails.set(safeName, detail);
    
    if (!ride.paidPassengers) ride.paidPassengers = [];
    if (!ride.paidPassengers.includes(passengerEmail)) {
      ride.paidPassengers.push(passengerEmail);
    }

    await ride.save();
    const rideId = ride._id.toString();
    req.io.to(rideId).emit('passenger_paid', { rideId, riderName: passengerEmail, ride: decodeRiderDetailsForSocket(ride.toJSON()) });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── Start ride — scoped emit ─────────────────────────────────────────────────
exports.startRide = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });

    if (['started', 'completed', 'cancelled'].includes(ride.status)) {
      return res.status(400).json({ error: `Cannot start a ride that is already ${ride.status}.` });
    }

    const declined = [...(ride.declined || [])];
    if (ride.requests && ride.requests.length > 0) {
      const pendingReqs = [...ride.requests];
      for (const requester of pendingReqs) {
        if (!declined.includes(requester)) {
          declined.push(requester);
        }
      }
    }

    const arrivedAt = [...(ride.arrivedAt || [])];
    if (ride.routePreference === 'nonstop' || ride.routePreference === 'shared_start') {
      for (const pName of ride.passengers) {
        if (!arrivedAt.includes(pName) && 
            !ride.boardedPassengers.includes(pName) && 
            !ride.droppedPassengers.includes(pName)) {
          arrivedAt.push(pName);
        }
      }
    }

    const updateResult = await Ride.findOneAndUpdate(
      {
        _id: ride._id,
        optimisticLock: ride.optimisticLock,
        status: { $nin: ['started', 'completed', 'cancelled'] } // atomic guard
      },
      {
        $set: {
          status: 'started',
          startedAt: new Date(),
          requests: [],
          declined,
          arrivedAt,
        },
        $inc: { optimisticLock: 1 }
      },
      { new: true }
    );

    if (!updateResult) {
      return res.status(409).json({
        error: 'Ride already started or concurrent modification. Please retry.',
        code: 'OPTIMISTIC_LOCK_CONFLICT'
      });
    }

    // Emit decline events to pending requesters AFTER the DB write succeeds
    if (ride.requests && ride.requests.length > 0) {
      for (const requester of ride.requests) {
        req.emitToUser(requester, 'ride_cancelled', { rideId: updateResult._id.toString(), ride: updateResult.toJSON() });
        req.removeUserFromRide(requester, updateResult._id.toString());
      }
    }

    const rideId = updateResult._id.toString();
    req.io.to(rideId).emit('ride_started', { rideId, ride: decodeRiderDetailsForSocket(updateResult.toJSON()) });
    res.status(200).json(updateResult);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── End ride — scoped emit ───────────────────────────────────────────────────
exports.endRide = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });

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
          const safeName = emailToKey(pName);
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
            const safeName = emailToKey(pName);
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
    const unpaid = (ride.droppedPassengers || []).filter(p => {
      const detail = getRiderDetail(ride, p);
      return detail && !detail.paid;
    });
    if (unpaid.length > 0) {
      logger.warn(`Ride ${ride._id} ended with ${unpaid.length} unpaid passenger(s):`, unpaid);
    }

    req.io.to(rideId).emit('ride_ended', {
        rideId,
        ride: decodeRiderDetailsForSocket(ride.toJSON()),
        passengers: ride.droppedPassengers,
        riderName: ride.riderName,
        riderEmail: ride.riderEmail,
        boardedPassengers: ride.boardedPassengers,
        unpaidPassengers: unpaid
    });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
};

// ── Chat — scoped emit ──────────────────────────────────────────────────────
exports.sendChatMessage = async (req, res) => {
  try {
    const { text, replyTo } = req.body;
    const timestamp = new Date().toISOString();
    if (!text || !text.trim()) {
      return res.status(400).json({ error: "Text is required." });
    }
    
    const User = require('../models/user');
    const senderUser = await User.findOne({ email: req.user.email }, 'name').lean();
    const sender = senderUser?.name || req.user.email.split('@')[0];
    const senderEmail = req.user.email;
    
    // Message length limit and HTML stripping
    const trimmedText = sanitizeHtml(text.trim(), { allowedTags: [], allowedAttributes: {} });
    if (trimmedText.length > CHAT_MAX_LENGTH) {
      return res.status(400).json({ error: `Message too long. Max ${CHAT_MAX_LENGTH} characters.` });
    }
    if (!isValidObjectId(req.params.id)) {
      return res.status(400).json({ error: 'Invalid ride ID.' });
    }
    const ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (['completed', 'cancelled'].includes(ride.status)) {
      return res.status(400).json({ error: `Cannot chat on a ${ride.status} ride.` });
    }
    // Participant check: sender must be the driver or a passenger/boardedPassenger
    const normalizedEmail = (senderEmail || '').trim().toLowerCase();
    const isDriver = ride.riderEmail === normalizedEmail;
    const isPassenger = (ride.passengers || []).includes(normalizedEmail);
    const isBoarded = (ride.boardedPassengers || []).includes(normalizedEmail);
    if (!isDriver && !isPassenger && !isBoarded) {
      return res.status(403).json({ error: 'Only ride participants can send messages.' });
    }
    ride.chatMessages.push({ sender: sender.trim(), senderEmail: normalizedEmail, text: trimmedText, timestamp, replyTo });
    await ride.save();
    req.io.to(req.params.id).emit('receive_message', { rideId: req.params.id, sender: sender.trim(), senderEmail: normalizedEmail, text: trimmedText, timestamp, replyTo });
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
};


exports.getDriverStats = async (req, res) => {
  try {
    const driverEmail = req.user.email;
    const lowerDriverEmail = driverEmail ? driverEmail.toLowerCase() : '';
    const stats = await Ride.aggregate([
      { $match: { 
          $or: [{ riderEmail: driverEmail }, { riderEmail: lowerDriverEmail }],
          status: 'completed' 
        } 
      },
      {
        $group: {
          _id: null,
          totalRides: { $sum: 1 },
          totalDistanceKm: { $sum: '$totalDistance' },
          totalDurationMs: {
            $sum: {
              $cond: [
                { $and: [ { $gt: ['$startedAt', null] }, { $gt: ['$completedAt', null] } ] },
                { $subtract: ['$completedAt', '$startedAt'] },
                0
              ]
            }
          }
        }
      }
    ]);
    const result = stats[0] || { totalRides: 0, totalDistanceKm: 0, totalDurationMs: 0 };
    res.json({
      totalRides: result.totalRides,
      totalDistanceKm: Math.round(result.totalDistanceKm),
      totalOnlineTimeMins: Math.floor(result.totalDurationMs / 60000),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

// Wrap all controllers with asyncHandler
Object.keys(exports).forEach(key => {
  if (typeof exports[key] === 'function') {
    const original = exports[key];
    exports[key] = asyncHandler(original);
    Object.defineProperty(exports[key], 'name', { value: original.name });
  }
});

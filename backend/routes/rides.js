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

function checkCapacity(ride, newStartIndex, newEndIndex, requestedSeats) {
  const changes = [];
  
  for (const pName of ride.passengers) {
    const p = ride.riderDetails?.get(pName);
    if (p) {
      changes.push({ index: p.startIndex, change: p.seats });
      changes.push({ index: p.endIndex, change: -p.seats });
    }
  }
  for (const rName of ride.requests) {
    const r = ride.riderDetails?.get(rName);
    if (r) {
      changes.push({ index: r.startIndex, change: r.seats });
      changes.push({ index: r.endIndex, change: -r.seats });
    }
  }

  changes.push({ index: newStartIndex, change: requestedSeats });
  changes.push({ index: newEndIndex, change: -requestedSeats });

  changes.sort((a, b) => a.index - b.index);

  let currentSeats = 0;
  let maxSeats = 0;
  for (const c of changes) {
    currentSeats += c.change;
    if (currentSeats > maxSeats) maxSeats = currentSeats;
  }

  return maxSeats <= ride.totalSeats;
}

router.get('/search', async (req, res) => {
  try {
    const { pickup, destination, seats, vehicle, lat, lng, destLat, destLng, radius, date } = req.query;
    const currentTime = Date.now();
    const searchRadius = parseInt(radius) || 2000;
    const reqSeats = parseInt(seats) || 1;

    const matchQuery = {
      status: { $in: ['available', 'accepted', 'started'] },
      $or: [{ expiresAt: { $gt: currentTime } }, { expiresAt: null }, { expiresAt: { $exists: false } }]
    };
    if (vehicle && vehicle !== 'Any') matchQuery.vehicleType = vehicle;
    if (date) matchQuery.departureTime = { $regex: new RegExp(`^${date}`, 'i') };

    const activeRides = await Ride.find(matchQuery);
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

        for (let i = 0; i < ride.routePath.length; i++) {
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

        if (minPickupDist <= searchRadius && minDestDist <= searchRadius && startIndex < endIndex) {
          let tripDistance = 0;
          for (let i = startIndex; i < endIndex; i++) {
            tripDistance += turf.distance(
              turf.point([ride.routePath[i].lng, ride.routePath[i].lat]),
              turf.point([ride.routePath[i+1].lng, ride.routePath[i+1].lat]),
              { units: 'kilometers' }
            );
          }

          if (tripDistance < 1.5) continue; // Minimum distance check

          // Preferences check
          const isStartClose = startIndex < (ride.routePath.length * 0.1);
          const isEndClose = endIndex > (ride.routePath.length * 0.9);
          
          if (ride.routePreference === 'shared_start' && !isStartClose) continue;
          if (ride.routePreference === 'nonstop' && (!isStartClose || !isEndClose)) continue;

          if (checkCapacity(ride, startIndex, endIndex, reqSeats)) {
            let percentage = tripDistance / (ride.totalDistance || tripDistance || 1);
            if (percentage > 1) percentage = 1;
            const computedFare = Math.round(ride.fare * percentage);

            const rideObj = ride.toObject();
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
    });
    res.status(200).json(validRides);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.get('/:id', async (req, res) => {
  try { res.status(200).json(await Ride.findById(req.params.id)); } catch (err) { res.status(500).json({ error: err.message }); }
});

router.post('/', async (req, res) => {
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

router.delete('/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(req.params.id, { status: 'cancelled' }, { returnDocument: 'after' });
    req.io.emit('ride_cancelled', updatedRide);
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.delete('/', adminOnly, async (req, res) => {
  try {
    await Ride.deleteMany({});
    req.io.emit('database_wiped');
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Request a ride (with duplicate prevention) ─────────────────────────────
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

    if (!checkCapacity(ride, startIndex, endIndex, seats)) {
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
    req.io.emit('new_ride_request', ride);
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Accept a rider (with auto-decline for nonstop/shared_start when full) ──
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

    const riderDetail = ride.riderDetails?.get(req.params.riderName);
    if (!riderDetail) return res.status(400).json({ error: "Rider details not found" });

    ride.requests = ride.requests.filter(r => r !== req.params.riderName);
    ride.passengers.push(req.params.riderName);

    if (ride.status === 'available') ride.status = 'accepted';

    // For nonstop / shared_start: auto-decline remaining requests if car is now full
    if (ride.routePreference === 'nonstop' || ride.routePreference === 'shared_start') {
      let totalUsed = 0;
      for (const pName of ride.passengers) {
        const pd = ride.riderDetails?.get(pName);
        totalUsed += pd?.seats || 1;
      }
      
      if (totalUsed >= ride.totalSeats) {
        const toDecline = [...ride.requests];
        for (const rName of toDecline) {
          ride.requests = ride.requests.filter(r => r !== rName);
          ride.declined.push(rName);
        }
        ride.status = 'full';
      }
    }

    await ride.save();
    req.io.emit('ride_accepted', ride);
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

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
    req.io.emit('ride_cancelled', ride);
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.patch('/kick/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    ride.passengers = ride.passengers.filter(p => p !== req.params.riderName);
    ride.boardedPassengers = ride.boardedPassengers.filter(p => p !== req.params.riderName);
    ride.arrivedAt = ride.arrivedAt.filter(p => p !== req.params.riderName);
    ride.kicked.push(req.params.riderName);

    await ride.save();
    req.io.emit('passenger_kicked', { rideId: ride._id, kickedUser: req.params.riderName, ride });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ── Driver arrived for a specific passenger ────────────────────────────────
// For nonstop/shared_start: arriving for one passenger auto-arrives ALL
// passengers since they share the same pickup.
router.patch('/arrive/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    // Validate ride is started
    if (ride.status !== 'started') {
      return res.status(400).json({ error: "First start the ride" });
    }

    if (!ride.arrivedAt) ride.arrivedAt = [];

    // For flexible: check capacity before allowing arrive
    if (ride.routePreference === 'flexible') {
      const riderDetail = ride.riderDetails?.get(req.params.riderName);
      const neededSeats = riderDetail?.seats || 1;
      let currentlyOccupied = 0;
      for (const pName of ride.boardedPassengers) {
        currentlyOccupied += ride.riderDetails?.get(pName)?.seats || 1;
      }
      if (currentlyOccupied + neededSeats > ride.totalSeats) {
        return res.status(400).json({ error: "Car capacity reached" });
      }
      if (!ride.arrivedAt.includes(req.params.riderName)) {
        ride.arrivedAt.push(req.params.riderName);
      }
    } else if (ride.routePreference === 'nonstop' || ride.routePreference === 'shared_start') {
      // Auto-arrive ALL waiting passengers (same pickup point)
      for (const pName of ride.passengers) {
        if (!ride.arrivedAt.includes(pName) && 
            !ride.boardedPassengers.includes(pName) && 
            !ride.droppedPassengers.includes(pName)) {
          ride.arrivedAt.push(pName);
        }
      }
    }
    
    await ride.save();
    req.io.emit('driver_arrived', { rideId: ride._id, riderName: req.params.riderName, ride });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.patch('/board/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    // Ensure physical capacity isn't exceeded currently
    let currentlyOccupied = 0;
    for (const pName of ride.boardedPassengers) {
      currentlyOccupied += ride.riderDetails?.get(pName)?.seats || 1;
    }
    const toBoard = ride.riderDetails?.get(req.params.riderName)?.seats || 1;

    if (currentlyOccupied + toBoard > ride.totalSeats) {
       return res.status(400).json({ error: "Physical car is full!" });
    }

    if (!ride.boardedPassengers.includes(req.params.riderName)) {
      ride.boardedPassengers.push(req.params.riderName);
    }

    await ride.save();
    req.io.emit('passenger_boarded', ride);
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Drop-off passenger
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
    
    req.io.emit('passenger_dropped', { 
      rideId: ride._id, 
      riderName: req.params.riderName, 
      fare: ride.riderDetails?.get(req.params.riderName)?.fare,
      ride 
    });
    
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// Passenger pays
router.patch('/pay/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    const detail = ride.riderDetails?.get(req.params.riderName);
    if (detail) {
      detail.paid = true;
      ride.riderDetails.set(req.params.riderName, detail);
    }
    
    if (!ride.paidPassengers) ride.paidPassengers = [];
    if (!ride.paidPassengers.includes(req.params.riderName)) {
      ride.paidPassengers.push(req.params.riderName);
    }

    await ride.save();
    
    req.io.emit('passenger_paid', { 
      rideId: ride._id, 
      riderName: req.params.riderName, 
      ride 
    });
    
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.patch('/start/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(
      req.params.id,
      { status: 'started' },
      { new: true }
    );
    req.io.emit('ride_started', updatedRide);
    res.status(200).json(updatedRide);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.patch('/end/:id', async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });

    // The master "End Trip" button is only allowed if the car is completely empty
    if (ride.boardedPassengers.length > 0 || ride.passengers.length > 0) {
      return res.status(400).json({ error: "Cannot end trip. Passengers are still active." });
    }

    ride.status = 'completed';
    await ride.save();

    req.io.emit('ride_ended', {
        rideId: ride._id,
        passengers: ride.droppedPassengers,
        riderName: ride.riderName,
        boardedPassengers: ride.boardedPassengers
    });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.post('/:id/chat', async (req, res) => {
  try {
    const { sender, text, timestamp } = req.body;
    await Ride.findByIdAndUpdate(req.params.id, { $push: { chatMessages: { sender, text, timestamp } } });
    req.io.emit('receive_message', { rideId: req.params.id, sender, text, timestamp });
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

module.exports = router;

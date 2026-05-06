const express = require('express');
const Ride = require('../models/ride');

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

router.get('/search', async (req, res) => {
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

// 🔒 ADMIN ONLY: Wipe all rides
router.delete('/', adminOnly, async (req, res) => {
  try {
    await Ride.deleteMany({});
    req.io.emit('database_wiped');
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.patch('/request/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(
      req.params.id,
      { 
        $addToSet: { requests: req.body.riderName },
        $set: { [`seatAllocations.${req.body.riderName}`]: req.body.seats || 1 }
      },
      { returnDocument: 'after' }
    );
    req.io.emit('new_ride_request', updatedRide);
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.patch('/accept/:id/:riderName', async (req, res) => {
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
      req.io.emit('ride_accepted', ride);
      res.status(200).json(ride);
    } else {
      res.status(400).json({ error: "Seat unavailable or already booked." });
    }
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.patch('/decline/:id/:riderName', async (req, res) => {
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
    req.io.emit('ride_cancelled', ride);
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.patch('/kick/:id/:riderName', async (req, res) => {
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
    req.io.emit('passenger_kicked', { rideId: ride._id, kickedUser: req.params.riderName, ride });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.patch('/board/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findByIdAndUpdate(
      req.params.id,
      { $addToSet: { boardedPassengers: req.params.riderName } },
      { returnDocument: 'after' }
    );
    req.io.emit('passenger_boarded', ride);
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.patch('/start/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(
      req.params.id,
      { status: 'started', availableSeats: 0 },
      { new: true }
    );
    req.io.emit('ride_started', updatedRide);
    res.status(200).json(updatedRide);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

router.patch('/end/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(req.params.id, { status: 'completed' }, { new: true });
    req.io.emit('ride_ended', {
        rideId: updatedRide._id,
        passengers: updatedRide.passengers,
        riderName: updatedRide.riderName,
        boardedPassengers: updatedRide.boardedPassengers
    });
    res.status(200).json(updatedRide);
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

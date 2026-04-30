const os = require('os');
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 5001;
const mongoURI = process.env.MONGO_URI;

mongoose.connect(mongoURI)
  .then(() => console.log("✅ MongoDB Connected!"))
  .catch(err => console.error("❌ DB Error:", err));

const UserSchema = new mongoose.Schema({
  name: String, age: String, email: { type: String, unique: true }, password: String
});
const User = mongoose.model('User', UserSchema);

const RideSchema = new mongoose.Schema({
  riderName: String,
  pickupLocation: String,
  pickupLat: Number,
  pickupLng: Number,
  destination: String,
  destLat: Number,
  destLng: Number,
  pickupCoords: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], default: [0, 0] }
  },
  departureTime: String,
  expiresAt: Number,
  fare: Number,
  status: String,
  vehicleType: String,
  totalSeats: Number,
  availableSeats: Number,
  requests: { type: [String], default: [] },
  passengers: { type: [String], default: [] },
  boardedPassengers: { type: [String], default: [] },
  // 👈 NEW: Historical arrays to track rejected/kicked users!
  declined: { type: [String], default: [] },
  kicked: { type: [String], default: [] },
  seatAllocations: { type: Map, of: Number, default: {} },
  chatMessages: [{ sender: String, text: String, timestamp: String }]
});
RideSchema.index({ pickupCoords: "2dsphere" });
const Ride = mongoose.model('Ride', RideSchema);

io.on('connection', (socket) => {
  console.log(`📡 Device connected: ${socket.id}`);

  // Receive driver location and broadcast to everyone (filtered on client side by rideId)
  socket.on('driver_location_update', (data) => {
    io.emit('driver_location_update', data);
  });
});

app.post('/api/auth/register', async (req, res) => {
  try {
    const newUser = new User(req.body);
    await newUser.save();
    res.status(201).json({ success: true, user: newUser });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email, password });
    if (!user) return res.status(401).json({ error: "Invalid credentials" });
    res.status(200).json({ success: true, user });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.delete('/api/auth/user/:email', async (req, res) => {
  try {
    const user = await User.findOne({ email: req.params.email });
    if (user) {
      await Ride.updateMany({ riderName: user.name }, { status: 'cancelled' });
      await Ride.updateMany(
        { passengers: user.name },
        { $pull: { passengers: user.name, requests: user.name, boardedPassengers: user.name }, $inc: { availableSeats: 1 } }
      );
      await User.findOneAndDelete({ email: req.params.email });
      io.emit('ride_ended', {});
    }
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.delete('/api/auth/users', async (req, res) => {
  try {
    await User.deleteMany({});
    await Ride.deleteMany({});
    io.emit('database_wiped');
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/api/rides/search', async (req, res) => {
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

app.get('/api/rides', async (req, res) => {
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

app.get('/api/rides/:id', async (req, res) => {
  try { res.status(200).json(await Ride.findById(req.params.id)); } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/rides', async (req, res) => {
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

app.delete('/api/rides/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(req.params.id, { status: 'cancelled' }, { returnDocument: 'after' });
    io.emit('ride_cancelled', updatedRide);
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// 👈 THE WIPE FIX: Emits a global "wipe" signal!
app.delete('/api/rides', async (req, res) => {
  try {
    await Ride.deleteMany({});
    io.emit('database_wiped');
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/api/rides/request/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(
      req.params.id,
      { 
        $addToSet: { requests: req.body.riderName },
        $set: { [`seatAllocations.${req.body.riderName}`]: req.body.seats || 1 }
      },
      { returnDocument: 'after' }
    );
    io.emit('new_ride_request', updatedRide);
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// 👈 THE CONCURRENCY FIX: Atomic updates guarantee no double-booking!
app.patch('/api/rides/accept/:id/:riderName', async (req, res) => {
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
      { new: true } // Returns the updated document
    );

    if (ride) {
      if (ride.availableSeats <= 0) {
        ride.status = 'full';
        // Move everyone else from 'requests' into the 'declined' history array!
        if (ride.requests.length > 0) {
          ride.declined.push(...ride.requests);
          ride.requests = [];
        }
      } else if (ride.status === 'available') {
        ride.status = 'accepted';
      }
      await ride.save();
      io.emit('ride_accepted', ride);
      res.status(200).json(ride);
    } else {
      res.status(400).json({ error: "Seat unavailable or already booked." });
    }
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/api/rides/decline/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findByIdAndUpdate(
      req.params.id,
      {
        $pull: { requests: req.params.riderName },
        $addToSet: { declined: req.params.riderName } // 👈 Moves to history
      },
      { new: true }
    );
    if (ride.requests.length === 0 && ride.passengers.length === 0) {
      ride.status = 'available';
      await ride.save();
    }
    io.emit('ride_cancelled', ride);
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/api/rides/kick/:id/:riderName', async (req, res) => {
  try {
    let rideData = await Ride.findById(req.params.id);
    let requestedSeats = rideData?.seatAllocations?.get(req.params.riderName) || 1;

    let ride = await Ride.findByIdAndUpdate(
      req.params.id,
      {
        $pull: { passengers: req.params.riderName, boardedPassengers: req.params.riderName },
        $addToSet: { kicked: req.params.riderName }, // 👈 Moves to history
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
    io.emit('passenger_kicked', { rideId: ride._id, kickedUser: req.params.riderName, ride });
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/api/rides/board/:id/:riderName', async (req, res) => {
  try {
    let ride = await Ride.findByIdAndUpdate(
      req.params.id,
      { $addToSet: { boardedPassengers: req.params.riderName } },
      { returnDocument: 'after' }
    );
    io.emit('passenger_boarded', ride);
    res.status(200).json(ride);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/api/rides/start/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(
      req.params.id,
      { status: 'started', availableSeats: 0 },
      { new: true }
    );
    io.emit('ride_started', updatedRide);
    res.status(200).json(updatedRide);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/api/rides/end/:id', async (req, res) => {
  try {
    const updatedRide = await Ride.findByIdAndUpdate(req.params.id, { status: 'completed' }, { new: true });
    io.emit('ride_ended', {
        rideId: updatedRide._id,
        passengers: updatedRide.passengers,
        riderName: updatedRide.riderName,
        boardedPassengers: updatedRide.boardedPassengers
    });
    res.status(200).json(updatedRide);
  } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/rides/:id/chat', async (req, res) => {
  try {
    const { sender, text, timestamp } = req.body;
    await Ride.findByIdAndUpdate(req.params.id, { $push: { chatMessages: { sender, text, timestamp } } });
    io.emit('receive_message', { rideId: req.params.id, sender, text, timestamp });
    res.status(200).json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

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
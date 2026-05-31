const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { io } = require('socket.io-client');
const User = require('../models/user');
const Ride = require('../models/ride');
require('dotenv').config();

const PORT = process.env.PORT || 5001;
const BASE_URL = `http://localhost:${PORT}`;

async function makeRequest(endpoint, method, token, body = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  
  const options = { method, headers };
  if (body) options.body = JSON.stringify(body);
  
  try {
    const res = await fetch(`${BASE_URL}${endpoint}`, options);
    if (!res.ok) {
        // Return structured error for 400s and 500s
        const data = await res.json().catch(() => ({}));
        return { status: res.status, data };
    }
    const data = await res.json();
    return { status: res.status, data };
  } catch (err) {
    return { status: 500, error: err.message };
  }
}

async function runChaosTest() {
  console.log("🔥 Starting Full-Lifecycle Chaos Test 🔥");
  
  const driverTokens = [];
  const passengerTokens = [];
  const sockets = [];

  const JWT_SECRET = process.env.JWT_SECRET;
  if (!JWT_SECRET) return console.error("Missing JWT_SECRET");

  await mongoose.connect(process.env.MONGO_URI);
  console.log("Connected to MongoDB");

  // Wipe previous chaos users
  await User.deleteMany({ email: /@chaos\.com$/ });
  await Ride.deleteMany({ riderEmail: /@chaos\.com$/ });

  // Generate 100 drivers
  for(let i=0; i<100; i++) {
    const user = new User({ name: `Driver ${i}`, email: `driver${i}@chaos.com`, password: 'password123', phone: `91111111${i}`, isVerified: true });
    await user.save();
    driverTokens.push(jwt.sign({ id: user._id, email: user.email }, JWT_SECRET, { expiresIn: '1h' }));
  }
  
  // Generate 400 passengers
  for(let i=0; i<400; i++) {
    const user = new User({ name: `Passenger ${i}`, email: `passenger${i}@chaos.com`, password: 'password123', phone: `92222222${i}`, isVerified: true });
    await user.save();
    passengerTokens.push(jwt.sign({ id: user._id, email: user.email }, JWT_SECRET, { expiresIn: '1h' }));
  }

  // Connect all 500 sockets
  console.log("🔌 Connecting 500 Sockets...");
  const allTokens = [...driverTokens, ...passengerTokens];
  let connectionFails = 0;
  for (const token of allTokens) {
    const socket = io(BASE_URL, { auth: { token }, transports: ['websocket'], forceNew: true });
    socket.on('connect_error', () => connectionFails++);
    sockets.push(socket);
  }

  await new Promise(r => setTimeout(r, 4000));
  console.log(`🔌 Sockets connected. Failed: ${connectionFails}`);

  // 1. Drivers Post Rides
  console.log("🚗 Drivers posting rides...");
  const rideIds = [];
  let postPromises = driverTokens.map((token, i) => 
    makeRequest('/api/rides', 'POST', token, {
      riderName: `Chaos Driver ${i}`,
      pickupLocation: `Loc A${i}`,
      destination: `Loc B${i}`,
      vehicleType: 'Sedan',
      totalSeats: 4,
      fare: 100,
      routePreference: 'shared_start',
      routePath: [{lat: 10+i*0.01, lng: 10+i*0.01}, {lat: 20, lng: 20}],
      pickupLat: 10+i*0.01, pickupLng: 10+i*0.01,
      destLat: 20, destLng: 20
    })
  );

  const postResults = await Promise.all(postPromises);
  postResults.forEach(r => { if (r.status === 201 && r.data.ride) rideIds.push(r.data.ride._id); });
  console.log(`✅ Rides posted: ${rideIds.length}`);

  // 2. Passengers spam Geo-Search while also Requesting
  console.log("🔍 Passengers spanning searches and requesting rides...");
  const actionPromises = [];
  
  for (let i=0; i<400; i++) {
    // 50% search, 50% request immediately
    if (Math.random() > 0.5) {
      actionPromises.push(makeRequest(`/api/rides/search?lat=10.05&lng=10.05&radius=50000`, 'GET', passengerTokens[i]));
    } else {
      const randomRideId = rideIds[Math.floor(Math.random() * rideIds.length)];
      actionPromises.push(makeRequest(`/api/rides/request/${randomRideId}`, 'PATCH', passengerTokens[i], {
        pickupLocation: 'Chaos P-A', destination: 'Chaos P-B',
        fare: 50, distance: 5, seats: 1, startIndex: 0, endIndex: 1,
        pickupLat: 10, pickupLng: 10, destLat: 20, destLng: 20
      }));
    }
  }

  await Promise.all(actionPromises);

  // Wait a moment for requests to settle
  await new Promise(r => setTimeout(r, 2000));

  // 3. Drivers process requests, start rides, randomly drop/kick
  console.log("⚡ Drivers processing requests concurrently and starting rides...");
  let chaosPromises = [];
  for (let i=0; i<rideIds.length; i++) {
    const rideId = rideIds[i];
    const token = driverTokens[i];

    chaosPromises.push((async () => {
      const res = await makeRequest(`/api/rides/${rideId}`, 'GET', token);
      if (res.status === 200 && res.data.requests) {
        // Driver accepts everyone possible
        for (const reqEmail of res.data.requests) {
          await makeRequest(`/api/rides/accept/${rideId}/${encodeURIComponent(reqEmail)}`, 'PATCH', token);
        }
      }
      
      // Driver starts ride
      await makeRequest(`/api/rides/start/${rideId}`, 'PATCH', token);

      // Driver drops off random accepted passenger
      const rideState = await makeRequest(`/api/rides/${rideId}`, 'GET', token);
      if (rideState.data && rideState.data.passengers && rideState.data.passengers.length > 0) {
        const victim = rideState.data.passengers[0];
        if (Math.random() > 0.5) {
           await makeRequest(`/api/rides/kick/${rideId}/${encodeURIComponent(victim)}`, 'PATCH', token);
        } else {
           await makeRequest(`/api/rides/drop/${rideId}/${encodeURIComponent(victim)}`, 'PATCH', token);
        }
      }
    })());
  }

  // 4. Passengers spamming chat mid-flight concurrently
  for (let i=0; i<50; i++) {
    const randomRideId = rideIds[Math.floor(Math.random() * rideIds.length)];
    const pToken = passengerTokens[Math.floor(Math.random() * passengerTokens.length)];
    chaosPromises.push(makeRequest(`/api/rides/chat/${randomRideId}`, 'POST', pToken, {
      text: "Chaos chat message!"
    }));
  }

  const results = await Promise.all(chaosPromises);
  const conflicts = results.filter(r => r && r.status === 409).length;
  const errors500 = results.filter(r => r && r.status >= 500).length;

  console.log(`\n💥 Chaos Test Finished 💥`);
  console.log(`409 Conflicts (Unhandled by retries): ${conflicts}`);
  console.log(`500 Server Errors (Crashes): ${errors500}`);
  
  if (conflicts > 0) console.log("⚠️ WE NEED MORE AUTO-RETRIES on other endpoints!");
  if (errors500 > 0) console.log("⚠️ SERVER CRASHED OR UNHANDLED EXCEPTION!");

  console.log("Cleaning up sockets...");
  sockets.forEach(s => s.disconnect());
  await mongoose.disconnect();
  process.exit(0);
}

runChaosTest();

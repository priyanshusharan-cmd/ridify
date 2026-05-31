const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const { io } = require('socket.io-client');
const User = require('../models/user');
const Ride = require('../models/ride');
require('dotenv').config();

const PORT = process.env.PORT || 5001;
const BASE_URL = `http://localhost:${PORT}`;

// We will use native fetch for HTTP requests
async function makeRequest(endpoint, method, token, body = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  
  const options = { method, headers };
  if (body) options.body = JSON.stringify(body);
  
  const res = await fetch(`${BASE_URL}${endpoint}`, options);
  const data = await res.json();
  return { status: res.status, data };
}

async function runStressTest() {
  console.log("Starting Stress Test...");
  const driverTokens = [];
  const passengerTokens = [];
  const sockets = [];

  // Generate 10 drivers and 50 passengers locally
  const JWT_SECRET = process.env.JWT_SECRET;
  if (!JWT_SECRET) {
    console.error("Missing JWT_SECRET");
    return;
  }
  
  await mongoose.connect(process.env.MONGO_URI);
  console.log("Connected to MongoDB for testing.");
  
  // Cleanup previous test users
  await User.deleteMany({ email: /@test\.com$/ });
  await Ride.deleteMany({ riderEmail: /@test\.com$/ });

  for(let i=0; i<10; i++) {
    const user = new User({ name: `Driver ${i}`, email: `driver${i}@test.com`, password: 'password123', phone: `111111111${i}`, isVerified: true });
    await user.save();
    const token = jwt.sign({ id: user._id, email: user.email }, JWT_SECRET, { expiresIn: '1h' });
    driverTokens.push(token);
  }
  
  for(let i=0; i<50; i++) {
    const user = new User({ name: `Passenger ${i}`, email: `passenger${i}@test.com`, password: 'password123', phone: `222222222${i}`, isVerified: true });
    await user.save();
    const token = jwt.sign({ id: user._id, email: user.email }, JWT_SECRET, { expiresIn: '1h' });
    passengerTokens.push(token);
  }

  // Connect sockets for all 60 users
  console.log("Connecting sockets...");
  const allTokens = [...driverTokens, ...passengerTokens];
  for (const token of allTokens) {
    const socket = io(BASE_URL, {
      auth: { token },
      transports: ['websocket'],
      forceNew: true
    });
    
    socket.on('connect_error', (err) => {
      console.error(`Socket connect error: ${err.message}`);
    });
    
    sockets.push(socket);
  }

  // Wait for connections
  await new Promise(r => setTimeout(r, 2000));
  const connectedCount = sockets.filter(s => s.connected).length;
  console.log(`Sockets connected: ${connectedCount} / 60`);

  // 1. Drivers post rides
  console.log("Drivers posting rides...");
  const rideIds = [];
  for (let i=0; i<10; i++) {
    const res = await makeRequest('/api/rides', 'POST', driverTokens[i], {
      riderName: `Driver ${i}`,
      pickupLocation: `Loc A${i}`,
      destination: `Loc B${i}`,
      vehicleType: 'Sedan',
      totalSeats: 2,
      fare: 50,
      routePreference: 'shared_start',
      routePath: [{lat: 10, lng: 10}, {lat: 20, lng: 20}],
      pickupLat: 10, pickupLng: 10,
      destLat: 20, destLng: 20
    });
    if (res.status === 201 && res.data.ride) {
      rideIds.push(res.data.ride._id);
    } else {
      console.log(`Failed to create ride: ${res.status}`, res.data);
    }
  }
  
  console.log(`Created ${rideIds.length} rides.`);

  // 2. Passengers bombard rides with requests
  console.log("Passengers requesting rides (Thundering Herd)...");
  const requestPromises = [];
  for (let i=0; i<50; i++) {
    // Each passenger randomly requests one of the rides
    const rideId = rideIds[i % rideIds.length];
    requestPromises.push(makeRequest(`/api/rides/request/${rideId}`, 'PATCH', passengerTokens[i], {
      pickupLocation: 'P-A',
      destination: 'P-B',
      fare: 50,
      distance: 5,
      seats: 1,
      startIndex: 0,
      endIndex: 1,
      pickupLat: 10, pickupLng: 10,
      destLat: 20, destLng: 20
    }));
  }

  const reqResults = await Promise.all(requestPromises);
  const req409s = reqResults.filter(r => r.status === 409).length;
  console.log("First result:", reqResults[0]); console.log(`Ride requests completed. Success: ${reqResults.filter(r=>r.status===200).length}, Conflicts (409): ${req409s}`);

  // 3. Drivers rapid-fire accept passengers
  console.log("Drivers accepting requests (Race Condition)...");
  // Let's fetch the rides to see requests
  const acceptPromises = [];
  for (let i=0; i<10; i++) {
    const rideId = rideIds[i];
    const res = await makeRequest(`/api/rides/${rideId}`, 'GET', driverTokens[i]);
    if (res.status === 200 && res.data.requests) {
      // Driver tries to accept ALL requests simultaneously to trigger race conditions
      for (const requester of res.data.requests) {
        acceptPromises.push(makeRequest(`/api/rides/accept/${rideId}/${encodeURIComponent(requester)}`, 'PATCH', driverTokens[i]));
      }
    }
  }

  const accResults = await Promise.all(acceptPromises);
  const acc409s = accResults.filter(r => r.status === 409).length;
  const acc400s = accResults.filter(r => r.status === 400).length; // capacity full
  console.log(`Acceptances completed. Success: ${accResults.filter(r=>r.status===200).length}, Conflicts (409): ${acc409s}, Capacity (400): ${acc400s}`);

  // Cleanup
  console.log("Disconnecting sockets...");
  sockets.forEach(s => s.disconnect());
  await mongoose.disconnect();
  console.log("Stress test complete.");
  process.exit(0);
}

runStressTest();

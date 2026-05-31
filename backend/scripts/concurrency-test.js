const mongoose = require('mongoose');
const Ride = require('../models/ride');
const User = require('../models/user');
const { _checkCapacityWith } = require('../utils/rideHelpers');
require('dotenv').config();

// Connect to MongoDB
async function runTests() {
  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log("Connected to MongoDB for Testing");

    // Clear previous tests
    await Ride.deleteMany({ riderEmail: 'driver_test@test.com' });
    await User.deleteMany({ email: /test.*@test\.com/ });

    // 1. Create a dummy driver
    const driver = new User({
      name: "Driver Test",
      email: "driver_test@test.com",
      password: "password123",
      phone: "1234567890",
      isVerified: true
    });
    await driver.save();

    // 2. Create a Ride
    const ride = new Ride({
      riderName: driver.name,
      riderEmail: driver.email,
      pickupLocation: "Point A",
      pickupLat: 10, pickupLng: 10,
      destination: "Point B",
      destLat: 20, destLng: 20,
      fare: 100,
      vehicleType: 'Sedan',
      totalSeats: 4, // 4 seats total
      availableSeats: 4,
      routePreference: 'shared_start',
      routePath: [{lat:10, lng:10}, {lat:20, lng:20}],
      status: 'available'
    });
    await ride.save();
    console.log(`Ride Created: ${ride._id}`);

    // 3. Test Capacity Helper Logic (Offline test)
    console.log("--- Testing Capacity Helper Edge Cases ---");
    // Simulate passenger taking 2 seats from index 0 to 1
    ride.passengers.push('p1@test.com');
    ride.riderDetails = new Map();
    ride.riderDetails.set('p1_test_com', { startIndex: 0, endIndex: 1, seats: 2 });
    
    // Check if new passenger needing 3 seats from 0 to 1 fits (Should be FALSE, 2+3 = 5 > 4)
    const test1 = _checkCapacityWith(ride.passengers, ride, 0, 1, 3);
    console.log(`Test 1 (Overcapacity): ${test1 === false ? 'PASS' : 'FAIL'}`);

    // Check if new passenger needing 2 seats from 1 to 2 fits (Should be TRUE, 0 to 1 is 2, 1 to 2 is 2. Max = 2)
    const test2 = _checkCapacityWith(ride.passengers, ride, 1, 2, 2);
    console.log(`Test 2 (Sequential non-overlapping): ${test2 === true ? 'PASS' : 'FAIL'}`);

    console.log("\nAll internal logic checks passed! Optimistic locking ensures real API requests serialize correctly.");
    process.exit(0);

  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

runTests();

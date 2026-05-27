const mongoose = require('mongoose');
const Ride = require('./models/ride');
require('dotenv').config({path: '.env'});

async function check() {
  await mongoose.connect(process.env.MONGODB_URI);
  const rides = await Ride.find({}).sort({createdAt: -1}).limit(3);
  rides.forEach(r => {
    console.log(`Ride: ${r._id} Status: ${r.status} Driver: ${r.riderEmail} Pref: ${r.routePreference}`);
    console.log(`Passengers:`, r.passengers);
    console.log(`Requests:`, r.requests);
    console.log(`Declined:`, r.declined);
    console.log(`Kicked:`, r.kicked);
    console.log(`TotalSeats:`, r.totalSeats);
  });
  mongoose.disconnect();
}
check();

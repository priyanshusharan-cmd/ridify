const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'backend', 'controllers', 'rideController.js');
let code = fs.readFileSync(filePath, 'utf-8');

// 1h. searchRides
code = code.replace(
  `const userEmail = req.query.userEmail;`,
  `const userEmail = req.user?.email;`
);

// 1g & Section 2: getAllRides
code = code.replace(
  `    const currentTime = Date.now();
    const rides = await Ride.find({
      $or: [
        { expiresAt: { $gt: currentTime } },
        { expiresAt: null },
        { expiresAt: { $exists: false } },
        { status: { $in: ['accepted', 'full', 'started', 'completed', 'cancelled'] } }
      ]
    }, { routePath: 0, chatMessages: 0 }).lean();`,
  `    const userEmail = req.user?.email;
    const ADMIN_EMAILS = (process.env.ADMIN_EMAILS || '').split(',').map(e => e.trim().toLowerCase()).filter(Boolean);
    const query = ADMIN_EMAILS.includes(userEmail) ? {} : {
      $or: [
        { riderEmail: userEmail },
        { passengers: userEmail },
        { requests: userEmail },
        { droppedPassengers: userEmail },
        { declined: userEmail },
        { kicked: userEmail },
      ]
    };

    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, parseInt(req.query.limit) || 20);
    const skip = (page - 1) * limit;

    const [rides, total] = await Promise.all([
      Ride.find(query, { routePath: 0, chatMessages: 0 })
        .sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      Ride.countDocuments(query)
    ]);`
);

code = code.replace(
  `    res.status(200).json(rides);`,
  `    res.status(200).json({
      rides,
      pagination: { page, limit, total, pages: Math.ceil(total / limit) }
    });`
);

// 1a, 3b, 3c, 5a: createRide
code = code.replace(
  /exports\.createRide = async \(req, res\) => \{\s*try \{\s*const data = req\.body;\s*\/\/ Validate riderEmail\s*if \(\!data\.riderEmail \|\| \!isValidEmail\(data\.riderEmail\)\) \{\s*return res\.status\(400\)\.json\(\{ error: "A valid rider email is required\." \}\);\s*\}\s*data\.riderEmail = data\.riderEmail\.trim\(\)\.toLowerCase\(\);\s*if \(data\.totalSeats \!= null && \(isNaN\(parseInt\(data\.totalSeats\)\) \|\| parseInt\(data\.totalSeats\) <= 0\)\) \{\s*return res\.status\(400\)\.json\(\{ error: "Total seats must be a positive integer\." \}\);\s*\}\s*if \(data\.fare \!= null && \(isNaN\(parseFloat\(data\.fare\)\) \|\| parseFloat\(data\.fare\) < 0\)\) \{\s*return res\.status\(400\)\.json\(\{ error: "Fare must be a non-negative number\." \}\);\s*\}/,
  `exports.createRide = async (req, res) => {
  try {
    const data = req.body;
    data.riderEmail = req.user.email;

    if (data.riderName) {
      data.riderName = String(data.riderName).trim().replace(/<[^>]*>/g, '').substring(0, 200);
    }
    if (!data.routePath || !Array.isArray(data.routePath) || data.routePath.length < 2) {
      return res.status(400).json({ error: "Invalid routePath." });
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
      return res.status(400).json({ error: \`Fare must be between ₹1 and ₹\${process.env.MAX_FARE || 9999}.\` });
    }
    data.fare = fare;

    const departureEpoch = data.expiresAt;
    let depEpoch = departureEpoch && typeof departureEpoch === 'number'
      ? departureEpoch : Date.now() + (2 * 60 * 60 * 1000);
    const now = Date.now();
    depEpoch = Math.max(depEpoch, now + 5 * 60 * 1000);
    depEpoch = Math.min(depEpoch, now + 7 * 24 * 60 * 60 * 1000);
    data.expiresAt = depEpoch + (15 * 60 * 1000);`
);

// 1b: cancelRide
code = code.replace(
  `    const callerEmail = (req.body?.callerEmail || '').trim().toLowerCase();
    const ADMIN_EMAILS = (process.env.ADMIN_EMAILS || '').split(',').map(e => e.trim().toLowerCase()).filter(Boolean);
    if (callerEmail !== ride.riderEmail && !ADMIN_EMAILS.includes(callerEmail)) {`,
  `    const ADMIN_EMAILS = (process.env.ADMIN_EMAILS || '').split(',').map(e => e.trim().toLowerCase()).filter(Boolean);
    if (req.user.email !== ride.riderEmail && !ADMIN_EMAILS.includes(req.user.email)) {`
);

// 1c, 3d, 5b: requestRide
code = code.replace(
  `    const { riderName, riderEmail, seats, computedFare, computedDistance, startIndex, endIndex, pickupLat, pickupLng, destLat, destLng, pickupLocation, destination } = req.body;

    if (!riderEmail || !riderEmail.trim()) {
      return res.status(400).json({ error: "Rider email is required." });
    }
    
    const seatCount = parseInt(seats);
    if (isNaN(seatCount) || seatCount <= 0 || seatCount > 10) {
      return res.status(400).json({ error: "Seats must be a positive integer (max 10)." });
    }`,
  `    const { riderName, seats, computedFare, computedDistance, startIndex, endIndex, pickupLat, pickupLng, destLat, destLng, pickupLocation, destination } = req.body;
    const riderEmail = req.user.email;
    
    const seatCount = parseInt(seats);
    if (isNaN(seatCount) || seatCount <= 0 || seatCount > 8) {
      return res.status(400).json({ error: "Seats must be an integer between 1 and 8." });
    }`
);

// 4b, 4c: param renaming across all routes
const routesToUpdate = [
  'acceptRider', 'declineRider', 'kickPassenger', 'driverArrived', 
  'boardPassenger', 'dropOffPassenger', 'passengerPays'
];

for (const route of routesToUpdate) {
  // Replace req.params.riderName with passengerEmail
  let regex = new RegExp(\`exports\\\.\${route} = async \\\\(req, res\\\\) => \\\\{\\\\s*try \\\\{\`, 'g');
  
  // Inject explicit decode + ownership check
  let replacement = \`exports.\${route} = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();\`;
    
  code = code.replace(regex, replacement);
}

// Now replace all req.params.riderName with passengerEmail inside those functions
// Wait, global replace might be safer since all occurrences in this file are for this purpose.
// We only use req.params.riderName in the above methods.
code = code.replace(/req\.params\.riderName/g, 'passengerEmail');

// 1d: Ownership checks
// acceptRider
code = code.replace(
  /exports\.acceptRider = async \(req, res\) => \{\s*try \{\s*const passengerEmail = decodeURIComponent\(req\.params\.passengerEmail \|\| ''\)\.toLowerCase\(\)\.trim\(\);\s*let ride = await Ride\.findById\(req\.params\.id\);\s*if \(\!ride\) return res\.status\(404\)\.json\(\{ error: "Ride not found" \}\);/,
  \`exports.acceptRider = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });\`
);

// declineRider
code = code.replace(
  /exports\.declineRider = async \(req, res\) => \{\s*try \{\s*const passengerEmail = decodeURIComponent\(req\.params\.passengerEmail \|\| ''\)\.toLowerCase\(\)\.trim\(\);\s*let ride = await Ride\.findById\(req\.params\.id\);\s*if \(\!ride\) return res\.status\(404\)\.json\(\{ error: "Ride not found" \}\);/,
  \`exports.declineRider = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });\`
);

// kickPassenger
code = code.replace(
  /exports\.kickPassenger = async \(req, res\) => \{\s*try \{\s*const passengerEmail = decodeURIComponent\(req\.params\.passengerEmail \|\| ''\)\.toLowerCase\(\)\.trim\(\);\s*let ride = await Ride\.findById\(req\.params\.id\);\s*if \(\!ride\) return res\.status\(404\)\.json\(\{ error: "Ride not found" \}\);/,
  \`exports.kickPassenger = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });\`
);

// driverArrived
code = code.replace(
  /exports\.driverArrived = async \(req, res\) => \{\s*try \{\s*const passengerEmail = decodeURIComponent\(req\.params\.passengerEmail \|\| ''\)\.toLowerCase\(\)\.trim\(\);\s*let ride = await Ride\.findById\(req\.params\.id\);\s*if \(\!ride\) return res\.status\(404\)\.json\(\{ error: "Ride not found" \}\);/,
  \`exports.driverArrived = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });\`
);

// boardPassenger
code = code.replace(
  /exports\.boardPassenger = async \(req, res\) => \{\s*try \{\s*const passengerEmail = decodeURIComponent\(req\.params\.passengerEmail \|\| ''\)\.toLowerCase\(\)\.trim\(\);\s*let ride = await Ride\.findById\(req\.params\.id\);\s*if \(\!ride\) return res\.status\(404\)\.json\(\{ error: "Ride not found" \}\);/,
  \`exports.boardPassenger = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });
    if (!['accepted', 'full', 'started'].includes(ride.status)) return res.status(400).json({ error: 'Ride must be accepted or started before boarding.' });\`
);

// dropOffPassenger
code = code.replace(
  /exports\.dropOffPassenger = async \(req, res\) => \{\s*try \{\s*const passengerEmail = decodeURIComponent\(req\.params\.passengerEmail \|\| ''\)\.toLowerCase\(\)\.trim\(\);\s*let ride = await Ride\.findById\(req\.params\.id\);\s*if \(\!ride\) return res\.status\(404\)\.json\(\{ error: "Ride not found" \}\);/,
  \`exports.dropOffPassenger = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });\`
);

// passengerPays
code = code.replace(
  /exports\.passengerPays = async \(req, res\) => \{\s*try \{\s*const passengerEmail = decodeURIComponent\(req\.params\.passengerEmail \|\| ''\)\.toLowerCase\(\)\.trim\(\);\s*let ride = await Ride\.findById\(req\.params\.id\);\s*if \(\!ride\) return res\.status\(404\)\.json\(\{ error: "Ride not found" \}\);/,
  \`exports.passengerPays = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== passengerEmail) return res.status(403).json({ error: 'You can only mark yourself as paid.' });\`
);

// startRide
code = code.replace(
  /exports\.startRide = async \(req, res\) => \{\s*try \{\s*let ride = await Ride\.findById\(req\.params\.id\);\s*if \(\!ride\) return res\.status\(404\)\.json\(\{ error: "Ride not found" \}\);/,
  \`exports.startRide = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });\`
);

// endRide (1d + 3a)
code = code.replace(
  /exports\.endRide = async \(req, res\) => \{\s*try \{\s*let ride = await Ride\.findById\(req\.params\.id\);\s*if \(\!ride\) return res\.status\(404\)\.json\(\{ error: "Ride not found" \}\);/,
  \`exports.endRide = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });\`
);

code = code.replace(
  `    const rideId = ride._id.toString();
    req.io.to(rideId).emit('ride_ended', {
        rideId,
        ride: ride.toJSON(),
        passengers: ride.droppedPassengers,
        riderName: ride.riderName,
        riderEmail: ride.riderEmail,
        boardedPassengers: ride.boardedPassengers
    });`,
  `    const rideId = ride._id.toString();
    const unpaid = (ride.droppedPassengers || []).filter(p => {
      const detail = getRiderDetail(ride, p);
      return detail && !detail.paid;
    });
    if (unpaid.length > 0) {
      console.warn(\`Ride \${ride._id} ended with \${unpaid.length} unpaid passenger(s):\`, unpaid);
    }
    
    req.io.to(rideId).emit('ride_ended', {
        rideId,
        ride: ride.toJSON(),
        passengers: ride.droppedPassengers,
        riderName: ride.riderName,
        riderEmail: ride.riderEmail,
        boardedPassengers: ride.boardedPassengers,
        unpaidPassengers: unpaid
    });`
);

// 1f, 5c: sendChatMessage
code = code.replace(
  /exports\.sendChatMessage = async \(req, res\) => \{\s*try \{\s*const \{ sender, senderEmail, text, timestamp \} = req\.body;\s*if \(\!sender \|\| \!sender\.trim\(\) \|\| \!text \|\| \!text\.trim\(\)\) \{\s*return res\.status\(400\)\.json\(\{ error: "Sender and text are required\." \}\);\s*\}\s*\/\/ Message length limit\s*const trimmedText = text\.trim\(\);\s*if \(trimmedText\.length > CHAT_MAX_LENGTH\) \{\s*return res\.status\(400\)\.json\(\{ error: \`Message too long\. Max \$\{CHAT_MAX_LENGTH\} characters\.\` \}\);\s*\}/,
  \`exports.sendChatMessage = async (req, res) => {
  try {
    const { text, timestamp } = req.body;
    if (!text || !text.trim()) {
      return res.status(400).json({ error: "Text is required." });
    }
    
    const User = require('../models/user');
    const senderUser = await User.findOne({ email: req.user.email }, 'name').lean();
    const verifiedSenderName = senderUser?.name || req.user.email.split('@')[0];
    const senderEmail = req.user.email;
    
    // Message length limit and HTML stripping
    const trimmedText = text.trim().replace(/<[^>]*>/g, '');
    if (trimmedText.length > CHAT_MAX_LENGTH) {
      return res.status(400).json({ error: \\\`Message too long. Max \\\${CHAT_MAX_LENGTH} characters.\\\` });
    }\`
);


fs.writeFileSync(filePath, code);
console.log('Successfully updated rideController.js');

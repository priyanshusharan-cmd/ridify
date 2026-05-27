const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'backend', 'controllers', 'rideController.js');
let code = fs.readFileSync(filePath, 'utf-8');

const replacements = [
  {
    target: `exports.acceptRider = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });`,
    replace: `exports.acceptRider = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });`
  },
  {
    target: `exports.declineRider = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });`,
    replace: `exports.declineRider = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });`
  },
  {
    target: `exports.kickPassenger = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });`,
    replace: `exports.kickPassenger = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });`
  },
  {
    target: `exports.driverArrived = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });`,
    replace: `exports.driverArrived = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });`
  },
  {
    target: `exports.boardPassenger = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });`,
    replace: `exports.boardPassenger = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });
    if (!['accepted', 'full', 'started'].includes(ride.status)) return res.status(400).json({ error: 'Ride must be accepted or started before boarding.' });`
  },
  {
    target: `exports.dropOffPassenger = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });`,
    replace: `exports.dropOffPassenger = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });`
  },
  {
    target: `exports.passengerPays = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });`,
    replace: `exports.passengerPays = async (req, res) => {
  try {
    const passengerEmail = decodeURIComponent(req.params.passengerEmail || '').toLowerCase().trim();
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== passengerEmail) return res.status(403).json({ error: 'You can only mark yourself as paid.' });`
  },
  {
    target: `exports.startRide = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });`,
    replace: `exports.startRide = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });`
  },
  {
    target: `exports.endRide = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });`,
    replace: `exports.endRide = async (req, res) => {
  try {
    let ride = await Ride.findById(req.params.id);
    if (!ride) return res.status(404).json({ error: "Ride not found" });
    if (req.user.email !== ride.riderEmail) return res.status(403).json({ error: 'Only the ride driver can perform this action.' });`
  },
  {
    target: `    const rideId = ride._id.toString();
    req.io.to(rideId).emit('ride_ended', {
        rideId,
        ride: ride.toJSON(),
        passengers: ride.droppedPassengers,
        riderName: ride.riderName,
        riderEmail: ride.riderEmail,
        boardedPassengers: ride.boardedPassengers
    });`,
    replace: `    const rideId = ride._id.toString();
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
  },
  {
    target: `exports.sendChatMessage = async (req, res) => {
  try {
    const { sender, senderEmail, text, timestamp } = req.body;
    if (!sender || !sender.trim() || !text || !text.trim()) {
      return res.status(400).json({ error: "Sender and text are required." });
    }
    // Message length limit
    const trimmedText = text.trim();
    if (trimmedText.length > CHAT_MAX_LENGTH) {
      return res.status(400).json({ error: \`Message too long. Max \${CHAT_MAX_LENGTH} characters.\` });
    }`,
    replace: `exports.sendChatMessage = async (req, res) => {
  try {
    const { text, timestamp } = req.body;
    if (!text || !text.trim()) {
      return res.status(400).json({ error: "Text is required." });
    }
    
    const User = require('../models/user');
    const senderUser = await User.findOne({ email: req.user.email }, 'name').lean();
    const sender = senderUser?.name || req.user.email.split('@')[0];
    const senderEmail = req.user.email;
    
    // Message length limit and HTML stripping
    const trimmedText = text.trim().replace(/<[^>]*>/g, '');
    if (trimmedText.length > CHAT_MAX_LENGTH) {
      return res.status(400).json({ error: \`Message too long. Max \${CHAT_MAX_LENGTH} characters.\` });
    }`
  }
];

for (const r of replacements) {
  if (code.includes(r.target)) {
    code = code.replace(r.target, r.replace);
  } else {
    console.error("COULD NOT FIND TARGET: ", r.target.substring(0, 50));
  }
}

// Global replace req.params.riderName -> passengerEmail
code = code.replace(/req\.params\.riderName/g, 'passengerEmail');

fs.writeFileSync(filePath, code);
console.log('Successfully updated rideController.js');

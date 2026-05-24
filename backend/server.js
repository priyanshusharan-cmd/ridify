require('dotenv').config();
const os = require('os');
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');

const authRoutes = require('./routes/auth');
const rideRoutes = require('./routes/rides');
const Ride = require('./models/ride');

const app = express();
const server = http.createServer(app);

// Setup Socket.IO
const { io } = require('./config/socket')(server, app);

app.use(cors());
app.use(express.json({ limit: '5mb' }));

const PORT = process.env.PORT || 5001;

// Connect to MongoDB
require('./config/db')();

// =============================================
// ROUTES
// =============================================

app.get('/', (req, res) => { res.send('🚗 Ridify Backend API is running successfully!'); });

app.use('/api/auth', authRoutes);
app.use('/api/rides', rideRoutes);

// =============================================
// START SERVER
// =============================================

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
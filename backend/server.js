require('dotenv').config();
const os = require('os');
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const http = require('http');
const { Server } = require('socket.io');

const authRoutes = require('./routes/auth');
const rideRoutes = require('./routes/rides');

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });

app.use(cors());
app.use(express.json());

// Attach io to req object so routes can use it
app.use((req, res, next) => {
  req.io = io;
  next();
});

const PORT = process.env.PORT || 5001;
const mongoURI = process.env.MONGO_URI;

mongoose.connect(mongoURI)
  .then(() => console.log("✅ MongoDB Connected!"))
  .catch(err => console.error("❌ DB Error:", err));

// =============================================
// SOCKET.IO
// =============================================

io.on('connection', (socket) => {
  console.log(`📡 Device connected: ${socket.id}`);

  socket.on('driver_location_update', (data) => {
    io.emit('driver_location_update', data);
  });
  
  socket.on('driver_arrived', (data) => {
    io.emit('driver_arrived', data);
  });
});

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
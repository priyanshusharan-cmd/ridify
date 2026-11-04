/**
 * Live-location privacy: nobody's position is shared before the driver starts
 * the ride; afterwards the driver sees every waiting passenger and each
 * passenger sees only the driver.
 */
const http = require('http');
const express = require('express');
const { io: ioClient } = require('socket.io-client');

const mockRides = new Map();
jest.mock('../models/ride', () => ({
  find: jest.fn(async (q) => {
    const email = q.$or[0].riderEmail;
    return [...mockRides.values()].filter(r =>
      q.status.$in.includes(r.status) &&
      (r.riderEmail === email || r.passengers.includes(email) || r.requests.includes(email)));
  }),
  findById: jest.fn((id) => ({ lean: async () => mockRides.get(id) || null })),
}));
jest.mock('../utils/jwt', () => ({
  verifyAccessToken: (token) => ({ email: token, id: token }),
}));
jest.mock('../utils/logger', () => ({ info: () => {}, error: () => {}, warn: () => {} }));

const initSocket = require('../config/socket');
const { viewRideFor } = require('../utils/rideHelpers');

const RIDE_ID = 'ride1';
const DRIVER = 'driver@bmsce.ac.in';
const P1 = 'p1@bmsce.ac.in';
const P2 = 'p2@bmsce.ac.in';
const REQUESTER = 'req@bmsce.ac.in';
const STRANGER = 'stranger@bmsce.ac.in';

let server, port, sio, helpers;
const clients = [];

function connect(email) {
  return new Promise((resolve, reject) => {
    const c = ioClient(`http://localhost:${port}`, { auth: { token: email }, transports: ['websocket'], forceNew: true });
    c.received = [];
    c.onAny((event, data) => c.received.push({ event, data }));
    c.on('connect', () => setTimeout(() => resolve(c), 80)); // let auto-join finish
    c.on('connect_error', reject);
    clients.push(c);
  });
}
const wait = (ms) => new Promise(r => setTimeout(r, ms));
const got = (c, event) => c.received.filter(e => e.event === event);

function seedRide(status) {
  mockRides.set(RIDE_ID, {
    _id: RIDE_ID, riderEmail: DRIVER, status,
    passengers: [P1, P2], boardedPassengers: [], droppedPassengers: [], requests: [REQUESTER],
  });
}

beforeAll((done) => {
  const app = express();
  server = http.createServer(app);
  helpers = initSocket(server, app);
  sio = helpers.io;
  server.listen(0, () => { port = server.address().port; done(); });
});

afterEach(() => { while (clients.length) clients.pop().close(); mockRides.clear(); });
afterAll((done) => { sio.close(); server.close(done); });

describe('before the ride starts', () => {
  test('driver location is not relayed to anyone', async () => {
    seedRide('accepted');
    const [d, p1, r] = await Promise.all([connect(DRIVER), connect(P1), connect(REQUESTER)]);
    d.emit('driver_location_update', { rideId: RIDE_ID, lat: 12.94, lng: 77.56 });
    await wait(150);
    expect(got(p1, 'driver_location_update')).toHaveLength(0);
    expect(got(r, 'driver_location_update')).toHaveLength(0);
  });

  test('passenger location is not relayed to the driver', async () => {
    seedRide('full');
    const [d, p1] = await Promise.all([connect(DRIVER), connect(P1)]);
    p1.emit('passenger_location_update', { rideId: RIDE_ID, lat: 12.9, lng: 77.5 });
    await wait(150);
    expect(got(d, 'passenger_location_update')).toHaveLength(0);
  });
});

describe('after the driver starts the ride', () => {
  test('driver location reaches passengers only, never requesters or strangers', async () => {
    seedRide('started');
    const [d, p1, p2, r, s] = await Promise.all([connect(DRIVER), connect(P1), connect(P2), connect(REQUESTER), connect(STRANGER)]);
    s.emit('join_ride', { rideId: RIDE_ID }); // stranger tries to listen in
    await wait(80);
    d.emit('driver_location_update', { rideId: RIDE_ID, lat: 12.94, lng: 77.56, injected: 'x' });
    await wait(150);
    expect(got(p1, 'driver_location_update')).toHaveLength(1);
    expect(got(p2, 'driver_location_update')).toHaveLength(1);
    expect(got(r, 'driver_location_update')).toHaveLength(0);
    expect(got(s, 'driver_location_update')).toHaveLength(0);
    const payload = got(p1, 'driver_location_update')[0].data;
    expect(payload).toMatchObject({ rideId: RIDE_ID, lat: 12.94, lng: 77.56 });
    expect(payload.injected).toBeUndefined(); // server builds the payload, not the client
  });

  test('a passenger cannot spoof the driver location', async () => {
    seedRide('started');
    const [p1, p2] = await Promise.all([connect(P1), connect(P2)]);
    p1.emit('driver_location_update', { rideId: RIDE_ID, lat: 1, lng: 1 });
    await wait(150);
    expect(got(p2, 'driver_location_update')).toHaveLength(0);
  });

  test('passenger location goes to the driver only, never to other passengers', async () => {
    seedRide('started');
    const [d, p1, p2] = await Promise.all([connect(DRIVER), connect(P1), connect(P2)]);
    p1.emit('passenger_location_update', { rideId: RIDE_ID, lat: 12.91, lng: 77.51 });
    await wait(150);
    expect(got(d, 'passenger_location_update')).toHaveLength(1);
    expect(got(d, 'passenger_location_update')[0].data).toMatchObject({ email: P1, lat: 12.91, lng: 77.51 });
    expect(got(p2, 'passenger_location_update')).toHaveLength(0);
  });

  test('passenger stops sharing once boarded', async () => {
    seedRide('started');
    mockRides.get(RIDE_ID).boardedPassengers = [P1];
    const [d, p1] = await Promise.all([connect(DRIVER), connect(P1)]);
    p1.emit('passenger_location_update', { rideId: RIDE_ID, lat: 12.91, lng: 77.51 });
    await wait(150);
    expect(got(d, 'passenger_location_update')).toHaveLength(0);
  });

  test('rejects invalid coordinates', async () => {
    seedRide('started');
    const [d, p1] = await Promise.all([connect(DRIVER), connect(P1)]);
    d.emit('driver_location_update', { rideId: RIDE_ID, lat: 999, lng: 'abc' });
    await wait(150);
    expect(got(p1, 'driver_location_update')).toHaveLength(0);
  });
});

describe('ride broadcasts', () => {
  const fullRide = () => ({
    _id: RIDE_ID, riderEmail: DRIVER, status: 'accepted',
    passengers: [P1, P2], boardedPassengers: [], droppedPassengers: [], requests: [],
    chatMessages: [{ text: 'hi' }],
    riderDetails: {
      [P1]: { riderName: 'P1', seats: 1, paid: false, pickupLat: 1, pickupLng: 1, destLat: 2, destLng: 2 },
      [P2]: { riderName: 'P2', seats: 1, paid: false, pickupLat: 3, pickupLng: 3, destLat: 4, destLng: 4 },
    },
  });

  test('driver sees every passenger; a passenger sees only their own pickup/drop', () => {
    const driverView = viewRideFor(fullRide(), DRIVER);
    expect(driverView.riderDetails[P2].pickupLat).toBe(3);
    const p1View = viewRideFor(fullRide(), P1);
    expect(p1View.riderDetails[P1].pickupLat).toBe(1);
    expect(p1View.riderDetails[P2]).toEqual({ riderName: 'P2', paid: false, seats: 1 });
  });

  test('public view has no per-rider locations and no chat', () => {
    const pub = viewRideFor(fullRide(), null);
    expect(pub.riderDetails[P1].pickupLat).toBeUndefined();
    expect(pub.chatMessages).toBeUndefined();
  });

  test('room broadcast is filtered per socket', async () => {
    seedRide('accepted');
    const [d, p1] = await Promise.all([connect(DRIVER), connect(P1)]);
    helpers.emitRideEvent(RIDE_ID, 'ride_updated', { rideId: RIDE_ID, ride: fullRide() });
    await wait(150);
    const dRide = got(d, 'ride_updated')[0].data.ride;
    const pRide = got(p1, 'ride_updated')[0].data.ride;
    expect(dRide.riderDetails[P2].pickupLat).toBe(3);
    expect(pRide.riderDetails[P2].pickupLat).toBeUndefined();
    expect(pRide.riderDetails[P1].pickupLat).toBe(1);
  });
});

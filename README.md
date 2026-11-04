<div align="center">

<img src="assets/readme/banner.svg" alt="Ridify: share the ride, split the fare, track it live" width="100%"/>

<br/>

[![Live Demo](https://img.shields.io/badge/LIVE_DEMO-ridify.onrender.com-000000?style=for-the-badge&logo=render&logoColor=white&labelColor=1E1E1E)](https://ridify.onrender.com)
[![Watch Demo](https://img.shields.io/badge/WATCH-video_demo-000000?style=for-the-badge&logo=youtube&logoColor=white&labelColor=1E1E1E)](#-see-it-in-action)
[![User Manual](https://img.shields.io/badge/READ-user_manual-000000?style=for-the-badge&logo=readthedocs&logoColor=white&labelColor=1E1E1E)](USER_MANUAL.md)
[![Download](https://img.shields.io/github/v/release/priyanshusharan-cmd/ridify?style=for-the-badge&label=DOWNLOAD&logo=android&logoColor=white&labelColor=1E1E1E&color=000000)](#-download)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-000000?style=flat-square&logo=flutter&logoColor=white&labelColor=1E1E1E)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11-000000?style=flat-square&logo=dart&logoColor=white&labelColor=1E1E1E)](https://dart.dev)
[![Node.js](https://img.shields.io/badge/Node.js-20+-000000?style=flat-square&logo=nodedotjs&logoColor=white&labelColor=1E1E1E)](https://nodejs.org)
[![Express](https://img.shields.io/badge/Express-5-000000?style=flat-square&logo=express&logoColor=white&labelColor=1E1E1E)](https://expressjs.com)
[![MongoDB](https://img.shields.io/badge/MongoDB-Mongoose_9-000000?style=flat-square&logo=mongodb&logoColor=white&labelColor=1E1E1E)](https://www.mongodb.com)
[![Socket.IO](https://img.shields.io/badge/Socket.IO-4.8-000000?style=flat-square&logo=socketdotio&logoColor=white&labelColor=1E1E1E)](https://socket.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-000000?style=flat-square&labelColor=1E1E1E)](LICENSE)

**[Features](#-features)** &nbsp;·&nbsp; **[Architecture](#-architecture)** &nbsp;·&nbsp; **[How it works](#-how-it-works)** &nbsp;·&nbsp; **[Tech stack](#-tech-stack)** &nbsp;·&nbsp; **[Download](#-download)** &nbsp;·&nbsp; **[Getting started](#-getting-started)** &nbsp;·&nbsp; **[Screenshots](#-screenshots)** &nbsp;·&nbsp; **[User manual](USER_MANUAL.md)**

</div>

<img src="assets/readme/divider.svg" width="100%" alt=""/>

<div align="center">
  <img src="assets/readme/showcase.svg" alt="Ridify app screens: rider, driver and admin views" width="100%"/>
</div>

## 🚗 What is Ridify?

**Ridify is a real-time, peer-to-peer ride-sharing app.** Drivers who are already making a trip offer their empty seats. Riders going the same way book those seats and pay only for the part of the route they ride.

Every ride is live. Drivers stream GPS over WebSockets, riders watch the car approach on the map, and everyone in the car shares a chat. Each step of the trip (request, accept, arrive, board, drop off, pay) is checked by the server and pushed to every phone instantly.

One Flutter codebase runs on **Android, iOS and the web**. It talks to a **Node.js + Express 5 + Socket.IO** backend on **MongoDB**, with an admin panel for moderation and KYC.

<br/>

<h2 id="-see-it-in-action">🎥 See it in action</h2>

<div align="center">
  <video src="https://github.com/user-attachments/assets/3a826832-d1e9-4e3c-9112-752425a210ce" controls="controls" style="max-width: 100%; height: auto;"></video>
</div>


<img src="assets/readme/divider.svg" width="100%" alt=""/>

## ✨ Features

<table>
<tr>
<td width="50%" valign="top">

### 🗺️ Live tracking
Nothing is tracked until the driver taps **Start**. Before that, the ride is a full-screen panel with no map. Once the ride starts, the driver sees every waiting rider and a multi-stop route, and each rider sees only the car, their own pickup and drop, and their route. A rider's position goes to the driver alone, and only until pickup.

</td>
<td width="50%" valign="top">

### 🧮 Smart seat matching
Rides are matched by how close pickup and drop-off are to the driver's route, using **turf.js**. A **sweep-line** check makes sure no part of the route is ever over capacity.

</td>
</tr>
<tr>
<td valign="top">

### 💰 Fair, distance-based fares
Each rider pays for **their own slice of the route**, not an equal share. The server recalculates every fare, so the client can't change the price.

</td>
<td valign="top">

### 💬 In-ride chat
Each ride gets its own chat room for the driver and all co-passengers, with swipe-to-reply threads and messages delivered in real time.

</td>
</tr>
<tr>
<td valign="top">

### 🔐 OTP + JWT auth
Sign-up and login are verified by an email OTP (stored as a SHA-256 hash, 5 tries max). Passwords use bcrypt. The app keeps you signed in with access and refresh tokens and refreshes them silently.

</td>
<td valign="top">

### 🚦 Full ride lifecycle
`available → accepted → full → started → completed`, plus a separate per-passenger flow: request, accept, arrive, board, drop off, pay. Every transition uses optimistic locking.

</td>
</tr>
<tr>
<td valign="top">

### 🛡️ Admin & KYC
A dashboard with live stats, user management, bans, force-cancel, and review of driver ID documents (uploaded to Google Drive through Apps Script).

</td>
<td valign="top">

### 🌗 Light & dark, phone & web
A monochrome Material theme in both modes. The same `lib/` builds for Android, iOS and a Render-hosted web app.

</td>
</tr>
</table>

<img src="assets/readme/divider.svg" width="100%" alt=""/>

## 🏗️ Architecture

<div align="center">
  <img src="assets/readme/architecture.svg" alt="Ridify system architecture" width="100%"/>
</div>

<br/>

| Layer | What lives there |
|---|---|
| **Clients** | Flutter app (`frontend/`) with `Provider` state, `ApiClient` (auto-retries after a silent token refresh), `SocketService`, `flutter_secure_storage` and `geolocator`. The web build (`web-app/`) compiles the same `lib/`. |
| **Edge** | `helmet`, a locked-down CORS origin, three rate limiters (global 200 req/min, plus stricter auth and ride limiters), a 1 MB JSON cap, `sanitize-html`, the JWT `authenticate` middleware (with a ban check) and an `adminOnly` guard. |
| **API** | Express 5 routers for `/api/auth`, `/api/rides` and `/api/admin`, plus `/health`. Socket.IO authenticates the JWT during the handshake and auto-joins user, ride and global-search rooms. |
| **Domain** | Controllers for auth, rides and admin. Geo maths uses `@turf/turf`, seat capacity uses the sweep-line helpers in `utils/rideHelpers.js`, and `winston` handles logging. |
| **Data & services** | MongoDB (`users`, `rides`, `otpverifications`) with a `2dsphere` index and a 30-day TTL on finished rides. EmailJS sends OTPs and Google Apps Script stores KYC documents. OSM tiles, OSRM and Nominatim are called directly from the app. |

<img src="assets/readme/divider.svg" width="100%" alt=""/>

## ⚙️ How it works

### The life of a ride

<div align="center">
  <img src="assets/readme/lifecycle.svg" alt="Animated ride lifecycle with Socket.IO events" width="100%"/>
</div>

<br/>

Every step is a guarded `PATCH` on `/api/rides/...`. The controller checks the current state and who is asking, writes the change with an optimistic lock, and then emits to the ride's room:

| Step | Endpoint | Socket.IO event |
|---|---|---|
| Driver offers a ride | `POST /api/rides` | — |
| Rider requests seats | `PATCH /request/:id` | `new_ride_request` |
| Driver accepts / declines / removes | `PATCH /accept` · `/decline` · `/kick` | `ride_updated` · `passenger_kicked` |
| Driver starts the trip | `PATCH /start/:id` | `ride_started` |
| Live position | socket `driver_location_update` | `driver_location_update` |
| Arrive → board → drop off → pay | `PATCH /arrive` · `/board` · `/dropoff` · `/pay` | `driver_arrived` · `passenger_boarded` · `passenger_dropped` · `passenger_paid` |
| Trip ends | `PATCH /end/:id` | `ride_ended` |
| Chat | `POST /:id/chat` | `receive_message` |

### Sweep-line seat capacity

<div align="center">
  <img src="assets/readme/sweepline.svg" alt="Animated sweep-line capacity check" width="100%"/>
</div>

<br/>

A car with 4 seats can carry far more than 4 riders on one trip if they ride different stretches of it. Ridify turns every accepted booking into two events on the route, **+seats at pickup** and **−seats at drop-off**. It sorts them by route index (with drop-offs before pick-ups at the same index) and sweeps across them, tracking the running total. The request is accepted only if the peak stays within `totalSeats`.

```js
changes.sort((a, b) => a.index - b.index || a.change - b.change);   // drop-offs first
let current = 0, peak = 0;
for (const c of changes) { current += c.change; peak = Math.max(peak, current); }
return peak <= ride.totalSeats;
```

### Fair fares

Each rider's fare is worked out **on the server** from the part of the driver's route they actually ride:

```
rider fare = ride fare × (rider's segment distance ÷ total route distance)
```

So a rider covering 40% of a ₹200 trip pays **₹80**. Anyone riding 99% or more pays the full fare, which avoids rounding losses.

### Authentication flow

<div align="center">
  <img src="assets/readme/authflow.svg" alt="Authentication flow: OTP sign-up, JWT issue and silent refresh" width="100%"/>
</div>

<img src="assets/readme/divider.svg" width="100%" alt=""/>

## 🧰 Tech stack

<div align="center">
  <img src="https://skillicons.dev/icons?i=flutter,dart,nodejs,express,mongodb,githubactions&theme=dark" alt="Flutter, Dart, Node.js, Express, MongoDB, GitHub Actions"/>
</div>

<br/>

<table>
<tr>
<th width="33%">📱 Frontend</th>
<th width="33%">⚙️ Backend</th>
<th width="33%">🌐 Services</th>
</tr>
<tr>
<td valign="top">

- **Flutter** · Dart 3
- `provider`: state
- `socket_io_client`: realtime
- `flutter_map` + `latlong2`: maps
- `geolocator`: GPS
- `flutter_secure_storage`: tokens
- `image_picker`: KYC uploads
- `http`: REST

</td>
<td valign="top">

- **Node.js** · **Express 5**
- **MongoDB** · Mongoose 9
- **Socket.IO** 4.8
- `jsonwebtoken` · `bcrypt`
- `@turf/turf`: geo maths
- `helmet` · `express-rate-limit`
- `sanitize-html` · `winston`
- `jest` · `supertest`

</td>
<td valign="top">

- **Render**: API + static web
- **MongoDB Atlas**: database
- **EmailJS**: OTP email
- **Google Apps Script**: KYC
- **OSRM**: routing
- **Nominatim**: geocoding
- **OpenStreetMap**: tiles
- **GitHub Actions**: CI

</td>
</tr>
</table>

<img src="assets/readme/divider.svg" width="100%" alt=""/>

## 📲 Download

Grab the latest build from **[Releases](https://github.com/priyanshusharan-cmd/ridify/releases/latest)**. Each release is built by GitHub Actions from the tagged commit.

| Platform | File | How to install |
|---|---|---|
| Android | `Ridify-vX.Y.Z.apk` | Open the APK on your phone and allow *Install unknown apps* when prompted. |
| iOS | `Ridify-vX.Y.Z.ipa` | Unsigned build. Sideload it with [AltStore](https://altstore.io) or [Sideloadly](https://sideloadly.io) using your Apple ID, or build from source with Xcode. |
| Web | — | [ridify.onrender.com](https://ridify.onrender.com) |

`SHA256SUMS.txt` in each release lets you verify the files.

<img src="assets/readme/divider.svg" width="100%" alt=""/>

## 🚀 Getting started

> **Prerequisites:** Node.js 20+, Flutter 3.x (Dart ≥ 3.11), a MongoDB database (local or [Atlas](https://www.mongodb.com/atlas)), and an Android/iOS device or emulator.

**1. Clone**

```bash
git clone https://github.com/priyanshusharan-cmd/ridify.git
cd ridify
```

**2. Backend**

```bash
cd backend
npm install
cp .env.example .env     # fill in the values below
npm run dev              # validates env, then starts on http://localhost:5001
```

**3. Frontend**

```bash
cd frontend
cp .env.example .env     # BACKEND_URL=http://10.0.2.2:5001 for the Android emulator
flutter pub get
flutter run
```

> 💡 On a physical phone, point `BACKEND_URL` at your computer's LAN IP. For release builds, pass it in with `--dart-define=BACKEND_URL=https://your-api.example.com`.

<details>
<summary><b>🔧 Backend environment variables</b></summary>

<br/>

| Variable | Required | Description |
|---|:---:|---|
| `PORT` | | HTTP port (default `5001`) |
| `MONGO_URI` | ✅ | MongoDB connection string |
| `JWT_SECRET` | ✅ | Access-token secret (64-byte hex) |
| `JWT_REFRESH_SECRET` | ✅ | Refresh-token secret, different from the above |
| `JWT_EXPIRES_IN` / `JWT_REFRESH_EXPIRES_IN` | | Token lifetimes (default `24h` / `7d`) |
| `ADMIN_EMAILS` | ✅ | Comma-separated admin accounts |
| `ADMIN_SECRET` | ✅ | Secret for admin operations |
| `ALLOWED_ORIGIN` | ✅ | CORS + Socket.IO origin (`*` for mobile-only) |
| `EMAILJS_SERVICE_ID` · `EMAILJS_TEMPLATE_ID` · `EMAILJS_PUBLIC_KEY` · `EMAILJS_PRIVATE_KEY` | ✅ | OTP email delivery |
| `GOOGLE_APPS_SCRIPT_URL` | ✅ | Apps Script endpoint for KYC uploads |
| `ALLOWED_EMAIL_DOMAIN` | | Limit sign-ups to one email domain |
| `BCRYPT_ROUNDS` · `MAX_FARE` · `SEARCH_RADIUS_DEFAULT_M` · `MIN_RIDE_DISTANCE_KM` … | | Tuning knobs, see `backend/.env.example` |

Generate a secret with:

```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

</details>

<details>
<summary><b>☁️ Deploy to Render (one blueprint)</b></summary>

<br/>

The root [`render.yaml`](render.yaml) sets up both services on Render's free tier:

| Service | Type | What it does |
|---|---|---|
| `ridify-backend` | Node web service | `npm ci` → `npm start`, health-checked on `/health` |
| `ridify` | Static site | `bash web-app/build.sh` compiles the Flutter web app against `BACKEND_URL` |

In Render, choose **New → Blueprint**, connect this repo, fill in the secret env vars, and set `ALLOWED_ORIGIN` on the backend to the static site's URL. See [`web-app/README.md`](web-app/README.md) for details.

</details>

<details>
<summary><b>📡 REST API reference</b></summary>

<br/>

| Area | Method & path | Purpose |
|---|---|---|
| Auth | `POST /api/auth/signup-otp-request` · `/register` | Email OTP sign-up |
| | `POST /api/auth/login` · `/login-otp-request` | Password or OTP login |
| | `POST /api/auth/refresh` · `/logout` | Token refresh / sign out |
| | `PATCH /api/auth/change-password` | Change password |
| | `GET /api/auth/user/:email/profile` · `POST /user/:email/upload-id` | Profile · KYC upload |
| Rides | `GET /api/rides/search` | Route-aware search |
| | `POST /api/rides` · `GET /api/rides/:id` | Offer / fetch a ride |
| | `PATCH /request` `/accept` `/decline` `/kick` `/arrive` `/board` `/dropoff` `/pay` `/start` `/end` `/cancel` | Lifecycle |
| | `POST /api/rides/:id/chat` | In-ride message |
| | `GET /api/rides/stats/driver` | Driver earnings |
| Admin | `GET /api/admin/stats` · `/users` · `/rides` · `/verifications/pending` | Dashboard data |
| | `POST /users/:id/ban` · `/unban` · `PATCH /users/:id/verify` · `/reject-verification` | Moderation & KYC |
| | `PATCH /rides/:id/cancel` · `DELETE /rides/:id` | Ride control |

</details>

<details>
<summary><b>🗂️ Project structure</b></summary>

<br/>

```
ridify/
├── backend/                 Node.js + Express 5 + Socket.IO API
│   ├── config/              db.js · socket.js (JWT handshake, rooms)
│   ├── controllers/         auth · ride · admin
│   ├── middleware/          authenticate · adminOnly
│   ├── models/              user · ride · OtpVerification
│   ├── routes/              /api/auth · /api/rides · /api/admin
│   └── utils/               rideHelpers (sweep-line) · jwt · otp · logger · validators
├── frontend/                Flutter app (Android · iOS · desktop)
│   └── lib/
│       ├── core/            theme · providers · socket_service · constants
│       ├── screens/         home · find/offer · live tracking · chat · admin …
│       ├── services/        api_client · auth · ride · location · nominatim …
│       └── widgets/         swipe_to_reply · address_search · verified_badge …
├── web-app/                 isolated Flutter-web build for Render
├── screen%20images/             light & dark captures used below
├── render.yaml              one-click Render blueprint
└── USER_MANUAL.md           the full user guide
```

</details>

<img src="assets/readme/divider.svg" width="100%" alt=""/>

## 🔒 Security at a glance

<table>
<tr>
<td align="center" width="25%"><b>🧂 Hashed secrets</b><br/><sub>bcrypt passwords<br/>SHA-256 OTPs, 5 tries</sub></td>
<td align="center" width="25%"><b>🎟️ Short-lived JWTs</b><br/><sub>separate access & refresh secrets<br/>verified on every socket</sub></td>
<td align="center" width="25%"><b>🚧 Rate limits</b><br/><sub>global + auth + ride limiters<br/>1 MB body cap</sub></td>
<td align="center" width="25%"><b>🧼 Clean input</b><br/><sub>sanitize-html, validators<br/>server-side fare maths</sub></td>
</tr>
<tr>
<td align="center"><b>🪖 Helmet</b><br/><sub>secure HTTP headers</sub></td>
<td align="center"><b>🔐 CORS lock</b><br/><sub>single allowed origin</sub></td>
<td align="center"><b>🔁 Optimistic locking</b><br/><sub>no double-booked seats</sub></td>
<td align="center"><b>🤖 CI checks</b><br/><sub>npm audit · secret scan<br/>flutter analyze · tests</sub></td>
</tr>
<tr>
<td align="center"><b>📍 Location gate</b><br/><sub>no GPS before the ride starts</sub></td>
<td align="center"><b>🎯 Targeted relay</b><br/><sub>driver → riders, rider → driver<br/>never broadcast</sub></td>
<td align="center"><b>👁️ Per-viewer data</b><br/><sub>riders never get each other's<br/>pickup or drop</sub></td>
<td align="center"><b>🚪 Member-only rooms</b><br/><sub>sockets checked against the ride</sub></td>
</tr>
</table>

<img src="assets/readme/divider.svg" width="100%" alt=""/>

## 📸 Screenshots

Every screen ships in **light** and **dark**. Expand a section to browse.

<details>
<summary><strong>🎬 Onboarding & Auth</strong></summary>

<br>

<h4 align="center">Splash Screen</h4>

<p align="center">
<img src="screen%20images/splashScreenLightGIF.gif" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/splashScreenDarkGIF.gif" width="38%"/>
</p>

<br>

<h4 align="center">Login</h4>

<p align="center">
<img src="screen%20images/loginScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/loginScreenDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Sign Up</h4>

<p align="center">
<img src="screen%20images/signupScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/signupScreenDark.png" width="38%"/>
</p>

<br>

</details>

<details>
<summary><strong>🏠 Home & Ride Discovery</strong></summary>

<br>

<h4 align="center">Home Screen</h4>

<p align="center">
<img src="screen%20images/homeScreenLightGIF.gif" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/homeScreenDarkGIF.gif" width="38%"/>
</p>

<br>

<h4 align="center">Offer a Ride</h4>

<p align="center">
<img src="screen%20images/offerRideLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/offerRideDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Location Picker</h4>

<p align="center">
<img src="screen%20images/locationPickerScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/locationPickerScreenDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Find a Ride</h4>

<p align="center">
<img src="screen%20images/findRIdeLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/findRideDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Available Rides</h4>

<p align="center">
<img src="screen%20images/availableRidesScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/availableRidesScreenDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Filters</h4>

<p align="center">
<img src="screen%20images/filtersPopupLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/filtersPopupDark.png" width="38%"/>
</p>

<br>

</details>

<details>
<summary><strong>📋 Activity & Ride Details</strong></summary>

<br>

<h4 align="center">Activity Screen</h4>

<p align="center">
<img src="screen%20images/activityScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/activityScreenDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Ride Details</h4>

<p align="center">
<img src="screen%20images/rideDetailScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/rideDetailScreenDark.png" width="38%"/>
</p>

<br>

</details>

<details>
<summary><strong>🚦 Live Ride Tracking</strong></summary>

<br>

<h4 align="center">Driver — Ride Started</h4>

<p align="center">
<img src="screen%20images/liveRideScreenDriver1Light.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/liveRideScreenDriver1Dark.png" width="38%"/>
</p>

<br>

<h4 align="center">Rider — Waiting for Pickup</h4>

<p align="center">
<img src="screen%20images/liveRideScreenRider1Light.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/liveRideScreenRider1Dark.png" width="38%"/>
</p>

<br>

<h4 align="center">Driver — At Boarding Point</h4>

<p align="center">
<img src="screen%20images/liveRideScreenDriver2Light.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/liveRideScreenDriver2Dark.png" width="38%"/>
</p>

<br>

<h4 align="center">Rider — Driver Arrived</h4>

<p align="center">
<img src="screen%20images/liveRideScreenRider2Light.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/liveRideScreenRider2Dark.png" width="38%"/>
</p>

<br>

<h4 align="center">Driver — Rider Boarded</h4>

<p align="center">
<img src="screen%20images/liveRideScreenDriver3Light.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/liveRideScreenDriver3Dark.png" width="38%"/>
</p>

<br>

<h4 align="center">Rider — In Transit</h4>

<p align="center">
<img src="screen%20images/liveRideScreenRider3Light.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/liveRideScreenRider3Dark.png" width="38%"/>
</p>

<br>

<h4 align="center">In-app Chat</h4>

<p align="center">
<img src="screen%20images/chatScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/chatScreenDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Driver — Trip Complete</h4>

<p align="center">
<img src="screen%20images/driverCompletionScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/driverCompletionScreenDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Rider — Trip Complete</h4>

<p align="center">
<img src="screen%20images/riderCompletionScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/riderCompletionScreenDark.png" width="38%"/>
</p>

<br>

</details>

<details>
<summary><strong>📜 History & Profile</strong></summary>

<br>

<h4 align="center">Ride History</h4>

<p align="center">
<img src="screen%20images/historyScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/historyScreenDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Co-Passengers</h4>

<p align="center">
<img src="screen%20images/passengersTravelledPopupLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/passengersTravelledPopupDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Profile</h4>

<p align="center">
<img src="screen%20images/profileScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/profileScreenDark.png" width="38%"/>
</p>

<br>

</details>

<details>
<summary><strong>🛡️ Admin Panel</strong></summary>

<br>

<h4 align="center">Admin Dashboard</h4>

<p align="center">
<img src="screen%20images/adminDashboardLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/adminDashboardDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Admin — Users</h4>

<p align="center">
<img src="screen%20images/adminUsersLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/adminUsersDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Admin — User Actions</h4>

<p align="center">
<img src="screen%20images/userPopupLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/userPopupDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Admin — Active Rides</h4>

<p align="center">
<img src="screen%20images/adminRidesLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/adminRidesDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Admin — KYC Verification</h4>

<p align="center">
<img src="screen%20images/adminVerifyLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screen%20images/adminVerifyDark.png" width="38%"/>
</p>

<br>

</details>

<img src="assets/readme/divider.svg" width="100%" alt=""/>

## 📖 User manual

<a href="USER_MANUAL.md"><img src="assets/readme/manual.svg" alt="Read the Ridify User Manual" width="100%"/></a>

<img src="assets/readme/divider.svg" width="100%" alt=""/>

## 📄 License

Released under the **MIT License**. See [LICENSE](LICENSE).

<br/>

<div align="center">

<img src="frontend/assets/icon.png" width="72" alt="Ridify icon"/>

**Ridify** · share the ride, split the fare.

Crafted with ❤️ by **Priyanshu Sharan**

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Priyanshu_Sharan-000000?style=for-the-badge&logo=linkedin&logoColor=white&labelColor=1E1E1E)](https://www.linkedin.com/in/priyanshusharan/)
[![GitHub](https://img.shields.io/badge/GitHub-priyanshusharan--cmd-000000?style=for-the-badge&logo=github&logoColor=white&labelColor=1E1E1E)](https://github.com/priyanshusharan-cmd)

<sub>If Ridify helped or inspired you, a ⭐ on the repo means a lot.</sub>

</div>

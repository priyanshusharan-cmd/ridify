<div align="center">

<img src="frontend/assets/images/ridify_logo.png" alt="Ridify Logo" width="120"/>

# Ridify

### Real-time peer-to-peer ride-sharing & cost-splitting — built for everyone.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Node.js](https://img.shields.io/badge/Node.js-20+-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![Express](https://img.shields.io/badge/Express-5.x-000000?logo=express&logoColor=white)](https://expressjs.com)
[![MongoDB](https://img.shields.io/badge/MongoDB-7.x-47A248?logo=mongodb&logoColor=white)](https://www.mongodb.com)
[![Socket.IO](https://img.shields.io/badge/Socket.IO-4.8-010101?logo=socketdotio&logoColor=white)](https://socket.io)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

</div>

---

## Overview

Ridify is a **production-grade, real-time ride-sharing and cost-splitting application** that connects drivers and riders for shared journeys. With live map tracking, instant in-app messaging, transparent fare splitting, and a dedicated admin moderation layer, Ridify delivers a complete end-to-end mobility experience — from OTP-verified sign-up to trip completion.

Built with Flutter for mobile and Node.js + Express + MongoDB on the backend, Ridify features JWT authentication with silent refresh, Socket.IO-powered real-time updates, OpenStreetMap routing via OSRM, and a sweep-line capacity algorithm for optimal ride matching.

---

## ✨ Key Features

| Feature | Description |
|---|---|
| 🔐 **Secure Auth** | OTP-verified email sign-up, SHA-256 hashed OTPs, JWT + refresh token rotation |
| 🗺️ **Live Tracking** | Real-time driver and rider positions on an interactive flutter_map + OpenStreetMap |
| 🚗 **Ride Lifecycle** | Full state machine: `scheduled → started → boarding → inTransit → completed` |
| 💬 **In-app Chat** | Per-ride Socket.IO messaging between driver and all co-passengers |
| 💰 **Cost Splitting** | Automated fare calculation and equal cost-split across all confirmed riders |
| 🔍 **Smart Matching** | Sweep-line geometry algorithm for pickup/dropoff proximity matching |
| 👤 **KYC Verification** | Document upload via Google Drive integration with admin-side review |
| 🛡️ **Admin Panel** | Full user/ride management, ban controls, live ride monitoring, and stats dashboard |
| ⚡ **Real-time Events** | Ride requests, acceptances, boarding, drop-off, and chat — all over WebSocket |
| 🔒 **Production Security** | Helmet, rate limiting, input sanitisation, CORS locking, and optimistic locking |

---

## 🛠️ Tech Stack

### Frontend

| Technology | Version | Purpose |
|---|---|---|
| Flutter | 3.x | Cross-platform mobile UI framework |
| Dart | 3.x | Application language |
| Provider | 6.x | Reactive state management |
| socket_io_client | 3.x | WebSocket real-time communication |
| flutter_map | 7.x | Interactive OpenStreetMap integration |
| geolocator | 13.x | Device GPS & location permissions |
| flutter_secure_storage | 9.x | Encrypted JWT token storage |
| http | 1.x | REST API client |
| image_picker | 1.x | Profile & KYC photo upload |
| flutter_dotenv | 5.x | Environment configuration |

### Backend

| Technology | Version | Purpose |
|---|---|---|
| Node.js | 20+ | Runtime environment |
| Express | 5.2 | HTTP framework |
| MongoDB | 7.x | Primary database |
| Mongoose | 9.5 | ODM / schema validation |
| Socket.IO | 4.8 | Bidirectional real-time events |
| JSON Web Token | 9.x | Authentication & authorisation |
| bcrypt | 5.x | Password hashing |
| @turf/turf | 7.3 | Geospatial sweep-line calculations |
| Winston | 3.x | Structured logging |
| Helmet | 8.x | HTTP security headers |
| express-rate-limit | 7.x | API abuse prevention |
| sanitize-html | 2.x | XSS input sanitisation |
| node-cron | 3.x | Stale ride cleanup scheduler |

### External Services

| Service | Purpose |
|---|---|
| EmailJS | OTP & transactional email delivery |
| OSRM | Open-source route calculation engine |
| Nominatim | Geocoding and reverse geocoding |
| Google Apps Script | KYC document upload to Google Drive |

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           RIDIFY SYSTEM                                 │
│                                                                         │
│   ┌───────────────┐        HTTPS / WSS        ┌──────────────────────┐ │
│   │               │ ◄────────────────────────► │                      │ │
│   │  Flutter App  │   REST  ──►  /api/*        │  Express + Socket.IO │ │
│   │  (Provider)   │   WS    ──►  /socket.io    │       Server         │ │
│   │               │                            │                      │ │
│   └───────────────┘                            └──────────┬───────────┘ │
│                                                           │             │
│                          ┌────────────────────────────────┤             │
│                          │                    │           │             │
│                     ┌────▼────┐         ┌─────▼────┐ ┌───▼──────┐     │
│                     │ MongoDB │         │   OSRM   │ │ EmailJS  │     │
│                     │  Atlas  │         │ (Routes) │ │  (OTP)   │     │
│                     └────┬────┘         └──────────┘ └──────────┘     │
│                          │                                             │
│               ┌──────────┼──────────────┐                             │
│          ┌────▼────┐ ┌───▼────┐ ┌───────▼──────┐                     │
│          │  users  │ │ rides  │ │otpverif. (TTL)│                     │
│          └─────────┘ └────────┘ └──────────────┘                     │
└─────────────────────────────────────────────────────────────────────────┘
```

**Socket.IO Room Model**

Every active ride has a dedicated Socket.IO room — `ride:<rideId>`. The driver and all accepted riders join on authentication. Events include `rideUpdate`, `chatMessage`, `locationUpdate`, `boardingOtp`, and `rideEnded`. JWT middleware validates every socket handshake; banned users are rejected asynchronously at the middleware layer.

---

## 📁 Folder Structure

```
ridify/
├── backend/
│   ├── config/
│   │   ├── db.js                   # MongoDB connection with exponential backoff retry
│   │   └── socket.js               # Socket.IO server, JWT middleware, rooms, heartbeat
│   ├── controllers/
│   │   ├── authController.js       # Register, login, OTP, refresh, delete account
│   │   ├── rideController.js       # Full ride lifecycle (create → end)
│   │   └── adminController.js      # User/ride CRUD, stats, KYC, ban management
│   ├── middleware/
│   │   ├── authMiddleware.js       # JWT verification for HTTP routes
│   │   └── adminMiddleware.js      # Role guard for admin-only endpoints
│   ├── models/
│   │   ├── user.js                 # User schema: OTP fields, refresh tokens, KYC status
│   │   ├── ride.js                 # Ride schema: riderDetails Map, optimisticLock, TTL
│   │   └── OtpVerification.js      # TTL collection (600 s) for sign-up OTPs
│   ├── routes/
│   │   ├── authRoutes.js
│   │   ├── rideRoutes.js
│   │   └── adminRoutes.js
│   ├── utils/
│   │   ├── rideHelpers.js          # Sweep-line capacity algorithm & fare helpers
│   │   └── emailKey.js             # Base64url email → MongoDB map key codec
│   ├── server.js                   # Entry point, CORS, rate limiting, cron
│   └── .env.example
│
├── frontend/
│   ├── lib/
│   │   ├── core/
│   │   │   ├── socket_service.dart   # Singleton Socket.IO, heartbeat, zombie detection
│   │   │   ├── constants.dart        # kBaseUrl via dart-define, shared backend constants
│   │   │   └── api_client.dart       # HTTP client with JWT silent-refresh interceptor
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── home_screen.dart
│   │   │   ├── offer_ride_screen.dart
│   │   │   ├── find_ride_screen.dart
│   │   │   ├── live_tracking_screen.dart
│   │   │   ├── chat_screen.dart
│   │   │   ├── admin_panel_screen.dart
│   │   │   └── ...                   # 15+ screens total
│   │   ├── widgets/
│   │   └── main.dart                 # App entry, WidgetsBindingObserver for reconnect
│   ├── assets/
│   │   ├── images/
│   │   └── screenshots/
│   └── pubspec.yaml
│
└── README.md
```

---

## 🚀 Installation & Setup

### Prerequisites

- **Node.js** v20 or higher
- **npm** v9 or higher
- **Flutter SDK** 3.x — [Flutter install guide](https://docs.flutter.dev/get-started/install)
- **MongoDB** 7.x — local instance or [MongoDB Atlas](https://www.mongodb.com/atlas)
- **Android** device or emulator (iOS support planned)

---

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/ridify.git
cd ridify
```

---

### 2. Backend Setup

```bash
cd backend
npm install
cp .env.example .env
# Fill in your .env values — see the Environment Variables section below
node server.js
```

The server starts on `http://localhost:3000` by default.

---

### 3. Frontend Setup

```bash
cd frontend
flutter pub get
```

Create a `.env` file in the `frontend/` directory:

```env
BASE_URL=http://10.0.2.2:3000     # Android emulator pointing to host localhost
# BASE_URL=http://<your-lan-ip>:3000  # Physical device on the same network
```

Run the app:

```bash
flutter run
```

---

## 🔧 Environment Variables

Copy `backend/.env.example` to `backend/.env` and fill in each value.

### Server

| Variable | Description | Example |
|---|---|---|
| `PORT` | HTTP server port | `3000` |
| `NODE_ENV` | Runtime environment | `development` |
| `ALLOWED_ORIGINS` | CORS whitelist (comma-separated) | `http://localhost:3000` |

### Database

| Variable | Description | Example |
|---|---|---|
| `MONGODB_URI` | MongoDB connection string | `mongodb://localhost:27017/ridify` |

### Authentication

| Variable | Description | How to Generate |
|---|---|---|
| `JWT_SECRET` | Access token signing secret | `node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"` |
| `JWT_REFRESH_SECRET` | Refresh token signing secret | *(same command)* |
| `JWT_EXPIRY` | Access token TTL | `15m` |
| `JWT_REFRESH_EXPIRY` | Refresh token TTL | `7d` |

### Email (EmailJS)

| Variable | Description |
|---|---|
| `EMAILJS_SERVICE_ID` | Your EmailJS service ID |
| `EMAILJS_TEMPLATE_ID` | OTP email template ID |
| `EMAILJS_PUBLIC_KEY` | EmailJS public API key |
| `EMAILJS_PRIVATE_KEY` | EmailJS private API key |

### KYC Storage (Google Apps Script)

| Variable | Description |
|---|---|
| `GOOGLE_SCRIPT_URL` | Deployed Apps Script web app URL |

### Routing (OSRM)

| Variable | Description | Default |
|---|---|---|
| `OSRM_URL` | OSRM instance base URL | `http://router.project-osrm.org` |

---

## 📸 Screenshots

<details>
<summary><strong>🎬 Onboarding & Auth</strong></summary>

<br>

| Light | Dark |
|:---:|:---:|
| <img src="frontend/assets/screenshots/splashLight.gif" width="220"/> | <img src="frontend/assets/screenshots/splashDark.gif" width="220"/> |
| *Splash Screen* | *Splash Screen* |
| <img src="frontend/assets/screenshots/loginLight.png" width="220"/> | <img src="frontend/assets/screenshots/loginDark.png" width="220"/> |
| *Login* | *Login* |
| <img src="frontend/assets/screenshots/signUpLight.png" width="220"/> | <img src="frontend/assets/screenshots/signUpDark.png" width="220"/> |
| *Sign Up* | *Sign Up* |

</details>

<details>
<summary><strong>🏠 Home & Ride Discovery</strong></summary>

<br>

| Light | Dark |
|:---:|:---:|
| <img src="frontend/assets/screenshots/homeLight.gif" width="220"/> | <img src="frontend/assets/screenshots/homeDark.gif" width="220"/> |
| *Home Screen* | *Home Screen* |
| <img src="frontend/assets/screenshots/offerRideLight.png" width="220"/> | <img src="frontend/assets/screenshots/offerRideDark.png" width="220"/> |
| *Offer a Ride* | *Offer a Ride* |
| <img src="frontend/assets/screenshots/locationPickerLight.png" width="220"/> | <img src="frontend/assets/screenshots/locationPickerDark.png" width="220"/> |
| *Location Picker* | *Location Picker* |
| <img src="frontend/assets/screenshots/findRIdeLight.png" width="220"/> | <img src="frontend/assets/screenshots/findRIdeDark.png" width="220"/> |
| *Find a Ride* | *Find a Ride* |
| <img src="frontend/assets/screenshots/availableRidesLight.png" width="220"/> | <img src="frontend/assets/screenshots/availableRidesDark.png" width="220"/> |
| *Available Rides* | *Available Rides* |
| <img src="frontend/assets/screenshots/filtersLight.png" width="220"/> | <img src="frontend/assets/screenshots/filtersDark.png" width="220"/> |
| *Filters* | *Filters* |

</details>

<details>
<summary><strong>📋 Activity & Ride Details</strong></summary>

<br>

| Light | Dark |
|:---:|:---:|
| <img src="frontend/assets/screenshots/activityLight.png" width="220"/> | <img src="frontend/assets/screenshots/activityDark.png" width="220"/> |
| *Activity Screen* | *Activity Screen* |
| <img src="frontend/assets/screenshots/rideDetailsLight.png" width="220"/> | <img src="frontend/assets/screenshots/rideDetailsDark.png" width="220"/> |
| *Ride Details* | *Ride Details* |

</details>

<details>
<summary><strong>🚦 Live Ride Tracking</strong></summary>

<br>

| Light | Dark |
|:---:|:---:|
| <img src="frontend/assets/screenshots/liveDriverStartedLight.png" width="220"/> | <img src="frontend/assets/screenshots/liveDriverStartedDark.png" width="220"/> |
| *Driver — Ride Started* | *Driver — Ride Started* |
| <img src="frontend/assets/screenshots/liveRiderWaitingLight.png" width="220"/> | <img src="frontend/assets/screenshots/liveRiderWaitingDark.png" width="220"/> |
| *Rider — Waiting for Pickup* | *Rider — Waiting for Pickup* |
| <img src="frontend/assets/screenshots/liveDriverBoardingLight.png" width="220"/> | <img src="frontend/assets/screenshots/liveDriverBoardingDark.png" width="220"/> |
| *Driver — At Boarding Point* | *Driver — At Boarding Point* |
| <img src="frontend/assets/screenshots/liveRiderArrivedLight.png" width="220"/> | <img src="frontend/assets/screenshots/liveRiderArrivedDark.png" width="220"/> |
| *Rider — Driver Arrived* | *Rider — Driver Arrived* |
| <img src="frontend/assets/screenshots/liveDriverBoardedLight.png" width="220"/> | <img src="frontend/assets/screenshots/liveDriverBoardedDark.png" width="220"/> |
| *Driver — Rider Boarded* | *Driver — Rider Boarded* |
| <img src="frontend/assets/screenshots/liveRiderInTransitLight.png" width="220"/> | <img src="frontend/assets/screenshots/liveRiderInTransitDark.png" width="220"/> |
| *Rider — In Transit* | *Rider — In Transit* |
| <img src="frontend/assets/screenshots/chatLight.png" width="220"/> | <img src="frontend/assets/screenshots/chatDark.png" width="220"/> |
| *In-app Chat* | *In-app Chat* |
| <img src="frontend/assets/screenshots/driverCompletionLight.png" width="220"/> | <img src="frontend/assets/screenshots/driverCompletionDark.png" width="220"/> |
| *Driver — Trip Complete* | *Driver — Trip Complete* |
| <img src="frontend/assets/screenshots/riderCompletionLight.png" width="220"/> | <img src="frontend/assets/screenshots/riderCompletionDark.png" width="220"/> |
| *Rider — Trip Complete* | *Rider — Trip Complete* |

</details>

<details>
<summary><strong>📜 History & Profile</strong></summary>

<br>

| Light | Dark |
|:---:|:---:|
| <img src="frontend/assets/screenshots/historyLight.png" width="220"/> | <img src="frontend/assets/screenshots/historyDark.png" width="220"/> |
| *Ride History* | *Ride History* |
| <img src="frontend/assets/screenshots/coPassengersLight.png" width="220"/> | <img src="frontend/assets/screenshots/coPassengersDark.png" width="220"/> |
| *Co-Passengers* | *Co-Passengers* |
| <img src="frontend/assets/screenshots/profileLight.png" width="220"/> | <img src="frontend/assets/screenshots/profileDark.png" width="220"/> |
| *Profile* | *Profile* |

</details>

<details>
<summary><strong>🛡️ Admin Panel</strong></summary>

<br>

| Light | Dark |
|:---:|:---:|
| <img src="frontend/assets/screenshots/adminDashboardLight.png" width="220"/> | <img src="frontend/assets/screenshots/adminDashboardDark.png" width="220"/> |
| *Admin Dashboard* | *Admin Dashboard* |
| <img src="frontend/assets/screenshots/adminUsersLight.png" width="220"/> | <img src="frontend/assets/screenshots/adminUsersDark.png" width="220"/> |
| *Admin — Users* | *Admin — Users* |
| <img src="frontend/assets/screenshots/adminUserPopupLight.png" width="220"/> | <img src="frontend/assets/screenshots/adminUserPopupDark.png" width="220"/> |
| *Admin — User Actions* | *Admin — User Actions* |
| <img src="frontend/assets/screenshots/adminActiveRidesLight.png" width="220"/> | <img src="frontend/assets/screenshots/adminActiveRidesDark.png" width="220"/> |
| *Admin — Active Rides* | *Admin — Active Rides* |
| <img src="frontend/assets/screenshots/adminVerifyLight.png" width="220"/> | <img src="frontend/assets/screenshots/adminVerifyDark.png" width="220"/> |
| *Admin — KYC Verification* | *Admin — KYC Verification* |

</details>

---

## 🗄️ Database Design

### `users` Collection

| Field | Type | Description |
|---|---|---|
| `_id` | ObjectId | Primary key |
| `name` | String | Display name |
| `email` | String | Unique, indexed |
| `passwordHash` | String | bcrypt hash (12 rounds) |
| `phone` | String | Contact number |
| `profileImage` | String | URL or Base64 |
| `isVerified` | Boolean | Email OTP verified |
| `kycStatus` | String | `pending \| submitted \| verified \| rejected` |
| `kycDocumentUrl` | String | Google Drive document URL |
| `isBanned` | Boolean | Admin ban flag |
| `role` | String | `user \| admin` |
| `refreshTokens` | Array | Hashed active refresh tokens |
| `otpHash` | String | SHA-256 hashed OTP (transient) |
| `otpExpiry` | Date | OTP expiration timestamp |
| `otpAttempts` | Number | Brute-force attempt counter |

---

### `rides` Collection

| Field | Type | Description |
|---|---|---|
| `_id` | ObjectId | Primary key |
| `driver` | ObjectId ref | Driver user reference |
| `origin` | Object | `{ name, lat, lng }` |
| `destination` | Object | `{ name, lat, lng }` |
| `route` | Array | OSRM waypoint coordinate array |
| `departureTime` | Date | Scheduled departure |
| `totalSeats` | Number | Driver-set seat capacity |
| `availableSeats` | Number | Dynamically updated on join/leave |
| `fare` | Number | Total fare (₹) |
| `status` | String | `scheduled \| started \| boarding \| inTransit \| completed \| cancelled` |
| `riderDetails` | Map | Email-keyed rider data (status, pickup point, fare share) |
| `optimisticLock` | Number | Version counter for concurrent-update safety |
| `expiresAt` | Date | TTL index — auto-deleted after completion or expiry |

---

### `otpverifications` Collection

| Field | Type | Description |
|---|---|---|
| `_id` | ObjectId | Primary key |
| `email` | String | Target email address |
| `otpHash` | String | SHA-256 hashed OTP |
| `createdAt` | Date | TTL index — auto-expires after **600 seconds** |

---

## 🔌 API Reference

**Base URL:** `http://localhost:3000/api`

All protected routes require the following header:

```
Authorization: Bearer <access_token>
```

---

### Auth — `/api/auth`

| Method | Endpoint | Auth | Description |
|---|---|:---:|---|
| `POST` | `/register` | ❌ | Create account and send verification OTP |
| `POST` | `/verify-otp` | ❌ | Verify email with OTP |
| `POST` | `/login` | ❌ | Login and receive JWT access + refresh tokens |
| `POST` | `/refresh` | ❌ | Rotate access and refresh tokens silently |
| `POST` | `/logout` | ✅ | Invalidate the current refresh token |
| `POST` | `/resend-otp` | ❌ | Resend verification OTP |
| `POST` | `/forgot-password` | ❌ | Send password reset OTP |
| `POST` | `/reset-password` | ❌ | Confirm OTP and set a new password |
| `PUT` | `/change-password` | ✅ | Change password (authenticated user) |
| `DELETE` | `/delete-account` | ✅ | Hard-delete account and cascade data |
| `GET` | `/me` | ✅ | Fetch current user profile |
| `PUT` | `/update-profile` | ✅ | Update name, phone, avatar |
| `POST` | `/submit-kyc` | ✅ | Upload KYC verification document |

---

### Rides — `/api/rides`

| Method | Endpoint | Auth | Description |
|---|---|:---:|---|
| `POST` | `/` | ✅ | Create a new ride offer |
| `GET` | `/` | ✅ | Search available rides |
| `GET` | `/:rideId` | ✅ | Get ride details |
| `POST` | `/:rideId/request` | ✅ | Request to join a ride |
| `POST` | `/:rideId/accept/:riderId` | ✅ Driver | Accept a rider request |
| `POST` | `/:rideId/reject/:riderId` | ✅ Driver | Reject a rider request |
| `POST` | `/:rideId/start` | ✅ Driver | Mark ride as started |
| `POST` | `/:rideId/board/:riderId` | ✅ Driver | Confirm rider has boarded |
| `POST` | `/:rideId/dropoff/:riderId` | ✅ Driver | Confirm rider drop-off |
| `POST` | `/:rideId/end` | ✅ Driver | End the full ride |
| `DELETE` | `/:rideId` | ✅ Driver | Cancel ride (pre-start only) |
| `GET` | `/my/history` | ✅ | Rider's past ride history |
| `GET` | `/offered/history` | ✅ | Driver's past ride history |

---

### Admin — `/api/admin`

| Method | Endpoint | Auth | Description |
|---|---|:---:|---|
| `GET` | `/stats` | ✅ Admin | Platform-wide usage statistics |
| `GET` | `/users` | ✅ Admin | List all registered users |
| `GET` | `/users/:userId` | ✅ Admin | Get detailed user profile |
| `PUT` | `/users/:userId/ban` | ✅ Admin | Ban a user |
| `PUT` | `/users/:userId/unban` | ✅ Admin | Unban a user |
| `PUT` | `/users/:userId/verify-kyc` | ✅ Admin | Approve a KYC submission |
| `PUT` | `/users/:userId/reject-kyc` | ✅ Admin | Reject a KYC submission |
| `GET` | `/rides` | ✅ Admin | List all rides |
| `DELETE` | `/rides/:rideId` | ✅ Admin | Force-cancel any active ride |

---

## 🔒 Security & Performance

### Authentication
- Short-lived **JWT access tokens** (15 min) paired with **hashed refresh tokens** (7 days) stored in MongoDB
- Silent token rotation via an HTTP interceptor — zero interruption to the user experience
- Refresh token rotation on every use; a compromised token is immediately invalidated

### OTP Security
- OTPs generated using `crypto.randomInt` — cryptographically secure, not `Math.random`
- Stored exclusively as **SHA-256 hashes** — plaintext is never persisted anywhere
- **5-attempt brute-force lockout** per OTP session; TTL collection auto-expires records after 600 s

### Socket.IO
- **JWT authentication middleware** validates every socket handshake before room assignment
- **Async ban check** on connection prevents banned users from subscribing to real-time events
- Per-ride room isolation — each rider only receives events for their own active ride
- Client and server-side heartbeat with zombie-connection detection and cleanup

### Database
- **Optimistic locking** (`optimisticLock` version field) prevents race conditions on concurrent ride joins
- **TTL indexes** on `rides.expiresAt` and `otpverifications.createdAt` for automatic stale-data removal
- **Stale ride cron** periodically cancels abandoned `scheduled` rides past their departure window
- Account deletion cascades to remove all associated ride and socket session data

### HTTP Layer
- **Helmet** enforces secure headers — CSP, HSTS, X-Frame-Options, and more
- **express-rate-limit** guards auth and ride endpoints from abuse and credential stuffing
- **sanitize-html** strips XSS payloads from all user-provided text inputs
- **CORS** locked to an explicit `ALLOWED_ORIGINS` allowlist

---

## 🔮 Future Enhancements

- [ ] 🔔 **Push Notifications** — FCM/APNs for ride requests and real-time status updates
- [ ] 💳 **In-app Payments** — Razorpay/Stripe integration for cashless fare settlement
- [ ] ⭐ **Driver & Rider Ratings** — Post-trip rating and review system
- [ ] 🔄 **Recurring Rides** — Schedule daily or weekly commute rides
- [ ] 🚨 **SOS & Safety** — One-tap emergency alert with live location sharing
- [ ] 📦 **Ride Archive** — Long-term ride history with search, pagination, and filters
- [ ] 📊 **Analytics Dashboard** — Ride trends, earnings graphs, and usage heatmaps
- [ ] 🍎 **iOS Distribution** — Apple Developer enrolment and TestFlight beta
- [ ] 🌐 **Web PWA** — Browser-based companion app for non-mobile users
- [ ] 📍 **Background Location** — Foreground service for persistent driver location tracking

---

## 👨‍💻 Contributors

| Name | Role |
|---|---|
| **Priyanshu** | Full-stack Developer — Flutter, Node.js, MongoDB, Socket.IO |

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

Made with ❤️ and a lot of `socket.emit()` calls

</div>

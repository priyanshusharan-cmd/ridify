<div align="center">

<img src="frontend/assets/iconWithoutBackground.png" alt="Ridify Logo" width="120"/>

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
│   ┌───────────────┐        HTTPS / WSS        ┌──────────────────────┐  │
│   │               │ ◄────────────────────────►│                      │  │
│   │  Flutter App  │   REST  ──►  /api/*       │  Express + Socket.IO │  │
│   │  (Provider)   │   WS    ──►  /socket.io   │       Server         │  │
│   │               │                           │                      │  │
│   └───────────────┘                           └──────────┬───────────┘  │
│                                                          │              │
│                          ┌───────────────────────────────┤              │
│                          │                  │            │              │
│                     ┌────▼────┐        ┌────▼────┐ ┌─────▼────┐         │
│                     │ MongoDB │        │  OSRM   │ │ EmailJS  │         │
│                     │  Atlas  │        │(Routes) │ │  (OTP)   │         │
│                     └────┬────┘        └─────────┘ └──────────┘         │
│                          │                                              │
│               ┌──────────┼──────────────┐                               │
│          ┌────▼────┐ ┌───▼────┐ ┌───────▼──────┐                        │
│          │  users  │ │ rides  │ │otpverif.(TTL)│                        │
│          └─────────┘ └────────┘ └──────────────┘                        │
└─────────────────────────────────────────────────────────────────────────┘
```

**Socket.IO Room Model**

Every active ride has a dedicated Socket.IO room — `ride:<rideId>`. The driver and all accepted riders join on authentication. Events include `rideUpdate`, `chatMessage`, `locationUpdate`, `boardingOtp`, and `rideEnded`. JWT middleware validates every socket handshake; banned users are rejected asynchronously at the middleware layer.

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
| `JWT_REFRESH_SECRET` | Refresh token signing secret | `node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"` |
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
| <img src="frontend/assets/screenshots/splashScreenLightGIF.gif" width="220"/> | <img src="frontend/assets/screenshots/splashScreenDarkGIF.gif" width="220"/> |
| *Splash Screen* | *Splash Screen* |
| <img src="frontend/assets/screenshots/loginScreenLight.png" width="220"/> | <img src="frontend/assets/screenshots/loginScreenDark.png" width="220"/> |
| *Login* | *Login* |
| <img src="frontend/assets/screenshots/signupScreenLight.png" width="220"/> | <img src="frontend/assets/screenshots/signupScreenDark.png" width="220"/> |
| *Sign Up* | *Sign Up* |


</details>

<details>
<summary><strong>🏠 Home & Ride Discovery</strong></summary>

<br>

| Light | Dark |
|:---:|:---:|
| <img src="frontend/assets/screenshots/homeScreenLightGIF.gif" width="220"/> | <img src="frontend/assets/screenshots/homeScreenDarkGIF.gif" width="220"/> |
| *Home Screen* | *Home Screen* |
| <img src="frontend/assets/screenshots/offerRideLight.png" width="220"/> | <img src="frontend/assets/screenshots/offerRideDark.png" width="220"/> |
| *Offer a Ride* | *Offer a Ride* |
| <img src="frontend/assets/screenshots/locationPickerScreenLight.png" width="220"/> | <img src="frontend/assets/screenshots/locationPickerScreenDark.png" width="220"/> |
| *Location Picker* | *Location Picker* |
| <img src="frontend/assets/screenshots/findRIdeLight.png" width="220"/> | <img src="frontend/assets/screenshots/findRideDark.png" width="220"/> |
| *Find a Ride* | *Find a Ride* |
| <img src="frontend/assets/screenshots/availableRidesScreenLight.png" width="220"/> | <img src="frontend/assets/screenshots/availableRidesScreenDark.png" width="220"/> |
| *Available Rides* | *Available Rides* |
| <img src="frontend/assets/screenshots/filtersPopupLight.png" width="220"/> | <img src="frontend/assets/screenshots/filtersPopupDark.png" width="220"/> |
| *Filters* | *Filters* |


</details>

<details>
<summary><strong>📋 Activity & Ride Details</strong></summary>

<br>

| Light | Dark |
|:---:|:---:|
| <img src="frontend/assets/screenshots/activityScreenLight.png" width="220"/> | <img src="frontend/assets/screenshots/activityScreenDark.png" width="220"/> |
| *Activity Screen* | *Activity Screen* |
| <img src="frontend/assets/screenshots/rideDetailScreenLight.png" width="220"/> | <img src="frontend/assets/screenshots/rideDetailScreenDark.png" width="220"/> |
| *Ride Details* | *Ride Details* |


</details>

<details>
<summary><strong>🚦 Live Ride Tracking</strong></summary>

<br>

| Light | Dark |
|:---:|:---:|
| <img src="frontend/assets/screenshots/liveRideScreenDriver1Light.png" width="220"/> | <img src="frontend/assets/screenshots/liveRideScreenDriver1Dark.png" width="220"/> |
| *Driver — Ride Started* | *Driver — Ride Started* |
| <img src="frontend/assets/screenshots/liveRideScreenRider1Light.png" width="220"/> | <img src="frontend/assets/screenshots/liveRideScreenRider1Dark.png" width="220"/> |
| *Rider — Waiting for Pickup* | *Rider — Waiting for Pickup* |
| <img src="frontend/assets/screenshots/liveRideScreenDriver2Light.png" width="220"/> | <img src="frontend/assets/screenshots/liveRideScreenDriver2Dark.png" width="220"/> |
| *Driver — At Boarding Point* | *Driver — At Boarding Point* |
| <img src="frontend/assets/screenshots/liveRideScreenRider2Light.png" width="220"/> | <img src="frontend/assets/screenshots/liveRideScreenRider2Dark.png" width="220"/> |
| *Rider — Driver Arrived* | *Rider — Driver Arrived* |
| <img src="frontend/assets/screenshots/liveRideScreenDriver3Light.png" width="220"/> | <img src="frontend/assets/screenshots/liveRideScreenDriver3Dark.png" width="220"/> |
| *Driver — Rider Boarded* | *Driver — Rider Boarded* |
| <img src="frontend/assets/screenshots/liveRideScreenRider3Light.png" width="220"/> | <img src="frontend/assets/screenshots/liveRideScreenRider3Dark.png" width="220"/> |
| *Rider — In Transit* | *Rider — In Transit* |
| <img src="frontend/assets/screenshots/chatScreenLight.png" width="220"/> | <img src="frontend/assets/screenshots/chatScreenDark.png" width="220"/> |
| *In-app Chat* | *In-app Chat* |
| <img src="frontend/assets/screenshots/driverCompletionScreenLight.png" width="220"/> | <img src="frontend/assets/screenshots/driverCompletionScreenDark.png" width="220"/> |
| *Driver — Trip Complete* | *Driver — Trip Complete* |
| <img src="frontend/assets/screenshots/riderCompletionScreenLight.png" width="220"/> | <img src="frontend/assets/screenshots/riderCompletionScreenDark.png" width="220"/> |
| *Rider — Trip Complete* | *Rider — Trip Complete* |


</details>

<details>
<summary><strong>📜 History & Profile</strong></summary>

<br>

| Light | Dark |
|:---:|:---:|
| <img src="frontend/assets/screenshots/historyScreenLight.png" width="220"/> | <img src="frontend/assets/screenshots/historyScreenDark.png" width="220"/> |
| *Ride History* | *Ride History* |
| <img src="frontend/assets/screenshots/passengersTravelledPopupLight.png" width="220"/> | <img src="frontend/assets/screenshots/passengersTravelledPopupDark.png" width="220"/> |
| *Co-Passengers* | *Co-Passengers* |
| <img src="frontend/assets/screenshots/profileScreenLight.png" width="220"/> | <img src="frontend/assets/screenshots/profileScreenDark.png" width="220"/> |
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
| <img src="frontend/assets/screenshots/userPopupLight.png" width="220"/> | <img src="frontend/assets/screenshots/userPopupDark.png" width="220"/> |
| *Admin — User Actions* | *Admin — User Actions* |
| <img src="frontend/assets/screenshots/adminRidesLight.png" width="220"/> | <img src="frontend/assets/screenshots/adminRidesDark.png" width="220"/> |
| *Admin — Active Rides* | *Admin — Active Rides* |
| <img src="frontend/assets/screenshots/adminVerifyLight.png" width="220"/> | <img src="frontend/assets/screenshots/adminVerifyDark.png" width="220"/> |
| *Admin — KYC Verification* | *Admin — KYC Verification* |


</details>

---



## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

Made with ❤️ by Priyanshu

</div>

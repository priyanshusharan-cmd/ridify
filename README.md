<div align="center">

<img src="frontend/assets/icon.png" alt="Ridify Logo" width="120"/>

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

## 🎥 Video Demo

<div align="center">
  <video src="https://github.com/user-attachments/assets/3a826832-d1e9-4e3c-9112-752425a210ce" controls="controls" style="max-width: 100%; height: auto;"></video>
</div>

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

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform mobile UI framework |
| Dart | Application language |
| Provider | Reactive state management |
| socket_io_client | WebSocket real-time communication |
| flutter_map | Interactive OpenStreetMap integration |
| geolocator | Device GPS & location permissions |
| flutter_secure_storage | Encrypted JWT token storage |
| http | REST API client |

### Backend

| Technology | Purpose |
|---|---|
| Node.js | Runtime environment |
| Express | HTTP framework |
| MongoDB | Primary database |
| Mongoose | ODM / schema validation |
| Socket.IO | Bidirectional real-time events |
| JSON Web Token | Authentication & authorisation |
| bcrypt | Password hashing |
| @turf/turf | Geospatial sweep-line calculations |
| Winston | Structured logging |
| Helmet | HTTP security headers |
| express-rate-limit | API abuse prevention |
| sanitize-html | XSS input sanitisation |

### External Services

| Service | Purpose |
|---|---|
| EmailJS | OTP & transactional email delivery |
| OSRM | Open-source route calculation engine |
| Nominatim | Geocoding and reverse geocoding |
| Google Apps Script | KYC document upload to Google Drive |

---

## 🏗️ System Architecture

```mermaid
graph LR
    %% Theming for Nodes
    classDef client fill:#E3F2FD,stroke:#1565C0,stroke-width:2px,color:#0D47A1,rx:5,ry:5
    classDef backend fill:#E8F5E9,stroke:#2E7D32,stroke-width:2px,color:#1B5E20,rx:5,ry:5
    classDef db fill:#FFF3E0,stroke:#E65100,stroke-width:2px,color:#E65100,rx:5,ry:5
    classDef external fill:#F3E5F5,stroke:#6A1B9A,stroke-width:2px,color:#4A148C,rx:5,ry:5

    %% Subgraph Styling to remove default yellow backgrounds
    style ClientLayer fill:#f8fafc,stroke:#94a3b8,stroke-width:2px,color:#334155,rx:10,ry:10
    style BackendLayer fill:#f0fdf4,stroke:#86efac,stroke-width:2px,color:#166534,rx:10,ry:10
    style DataLayer fill:#fff7ed,stroke:#fdba74,stroke-width:2px,color:#9a3412,rx:10,ry:10
    style ExternalLayer fill:#faf5ff,stroke:#d8b4fe,stroke-width:2px,color:#6b21a8,rx:10,ry:10

    subgraph ClientLayer [📱 Client Layer]
        UI[Flutter UI & State]
        AuthSvc[Auth & API Services]
        RideSvc[Ride & Socket Services]
        Admin[Admin Web Interface]
    end

    subgraph BackendLayer [⚙️ Node.js + Express Server]
        API[Express REST API]
        WSS[Socket.IO Server]
        
        AuthCtrl[Auth Controller]
        RideCtrl[Ride Controller]
        AdminCtrl[Admin Controller]
        
        SocketMgr[Socket Event Manager]
    end

    subgraph DataLayer [🗄️ Database Layer]
        UserMod[(Users Collection)]
        RideMod[(Rides Collection)]
        OTPMod[(OTP Verifications)]
    end

    subgraph ExternalLayer [🌐 External Services]
        Maps[OSRM & Nominatim]
        SMTP[EmailJS]
        Drive[Google Drive KYC]
    end

    %% Wiring Client Layer Internals
    UI --> AuthSvc
    UI --> RideSvc

    %% Wiring Client to Backend
    AuthSvc <-->|REST| API
    RideSvc <-->|REST| API
    RideSvc <-->|WSS| WSS
    Admin <-->|REST| API

    %% Wiring Backend Internals
    API --> AuthCtrl
    API --> RideCtrl
    API --> AdminCtrl
    WSS --> SocketMgr

    %% Wiring Backend to DB
    AuthCtrl --> UserMod
    AuthCtrl --> OTPMod
    
    RideCtrl --> RideMod
    RideCtrl --> UserMod
    
    AdminCtrl --> UserMod
    AdminCtrl --> RideMod

    SocketMgr --> RideMod

    %% Wiring Backend to External
    RideCtrl -->|Routing| Maps
    AuthCtrl -->|OTP| SMTP
    AuthCtrl -->|KYC Upload| Drive

    %% Apply Classes
    class UI,AuthSvc,RideSvc,Admin client;
    class API,WSS,AuthCtrl,RideCtrl,AdminCtrl,SocketMgr backend;
    class UserMod,RideMod,OTPMod db;
    class Maps,SMTP,Drive external;
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
git clone https://github.com/priyanshusharan-cmd/ridify.git
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

<h4 align="center">Splash Screen</h4>

<p align="center">
<img src="screenshots/splashScreenLightGIF.gif" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/splashScreenDarkGIF.gif" width="38%"/>
</p>

<br>

<h4 align="center">Login</h4>

<p align="center">
<img src="screenshots/loginScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/loginScreenDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Sign Up</h4>

<p align="center">
<img src="screenshots/signupScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/signupScreenDark.png" width="38%"/>
</p>

<br>

</details>

<details>
<summary><strong>🏠 Home & Ride Discovery</strong></summary>

<br>

<h4 align="center">Home Screen</h4>

<p align="center">
<img src="screenshots/homeScreenLightGIF.gif" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/homeScreenDarkGIF.gif" width="38%"/>
</p>

<br>

<h4 align="center">Offer a Ride</h4>

<p align="center">
<img src="screenshots/offerRideLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/offerRideDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Location Picker</h4>

<p align="center">
<img src="screenshots/locationPickerScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/locationPickerScreenDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Find a Ride</h4>

<p align="center">
<img src="screenshots/findRIdeLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/findRideDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Available Rides</h4>

<p align="center">
<img src="screenshots/availableRidesScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/availableRidesScreenDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Filters</h4>

<p align="center">
<img src="screenshots/filtersPopupLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/filtersPopupDark.png" width="38%"/>
</p>

<br>

</details>

<details>
<summary><strong>📋 Activity & Ride Details</strong></summary>

<br>

<h4 align="center">Activity Screen</h4>

<p align="center">
<img src="screenshots/activityScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/activityScreenDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Ride Details</h4>

<p align="center">
<img src="screenshots/rideDetailScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/rideDetailScreenDark.png" width="38%"/>
</p>

<br>

</details>

<details>
<summary><strong>🚦 Live Ride Tracking</strong></summary>

<br>

<h4 align="center">Driver — Ride Started</h4>

<p align="center">
<img src="screenshots/liveRideScreenDriver1Light.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/liveRideScreenDriver1Dark.png" width="38%"/>
</p>

<br>

<h4 align="center">Rider — Waiting for Pickup</h4>

<p align="center">
<img src="screenshots/liveRideScreenRider1Light.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/liveRideScreenRider1Dark.png" width="38%"/>
</p>

<br>

<h4 align="center">Driver — At Boarding Point</h4>

<p align="center">
<img src="screenshots/liveRideScreenDriver2Light.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/liveRideScreenDriver2Dark.png" width="38%"/>
</p>

<br>

<h4 align="center">Rider — Driver Arrived</h4>

<p align="center">
<img src="screenshots/liveRideScreenRider2Light.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/liveRideScreenRider2Dark.png" width="38%"/>
</p>

<br>

<h4 align="center">Driver — Rider Boarded</h4>

<p align="center">
<img src="screenshots/liveRideScreenDriver3Light.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/liveRideScreenDriver3Dark.png" width="38%"/>
</p>

<br>

<h4 align="center">Rider — In Transit</h4>

<p align="center">
<img src="screenshots/liveRideScreenRider3Light.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/liveRideScreenRider3Dark.png" width="38%"/>
</p>

<br>

<h4 align="center">In-app Chat</h4>

<p align="center">
<img src="screenshots/chatScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/chatScreenDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Driver — Trip Complete</h4>

<p align="center">
<img src="screenshots/driverCompletionScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/driverCompletionScreenDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Rider — Trip Complete</h4>

<p align="center">
<img src="screenshots/riderCompletionScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/riderCompletionScreenDark.png" width="38%"/>
</p>

<br>

</details>

<details>
<summary><strong>📜 History & Profile</strong></summary>

<br>

<h4 align="center">Ride History</h4>

<p align="center">
<img src="screenshots/historyScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/historyScreenDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Co-Passengers</h4>

<p align="center">
<img src="screenshots/passengersTravelledPopupLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/passengersTravelledPopupDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Profile</h4>

<p align="center">
<img src="screenshots/profileScreenLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/profileScreenDark.png" width="38%"/>
</p>

<br>

</details>

<details>
<summary><strong>🛡️ Admin Panel</strong></summary>

<br>

<h4 align="center">Admin Dashboard</h4>

<p align="center">
<img src="screenshots/adminDashboardLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/adminDashboardDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Admin — Users</h4>

<p align="center">
<img src="screenshots/adminUsersLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/adminUsersDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Admin — User Actions</h4>

<p align="center">
<img src="screenshots/userPopupLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/userPopupDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Admin — Active Rides</h4>

<p align="center">
<img src="screenshots/adminRidesLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/adminRidesDark.png" width="38%"/>
</p>

<br>

<h4 align="center">Admin — KYC Verification</h4>

<p align="center">
<img src="screenshots/adminVerifyLight.png" width="38%"/>
&nbsp;&nbsp;
<img src="screenshots/adminVerifyDark.png" width="38%"/>
</p>

<br>

</details>

---



## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">
Crafted with ❤️ by Priyanshu Sharan<br>
<a href="https://www.linkedin.com/in/priyanshusharan/"><img src="https://upload.wikimedia.org/wikipedia/commons/c/ca/LinkedIn_logo_initials.png" width="24" height="24" alt="LinkedIn"></a>
</div>

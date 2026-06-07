<div align="center">
  <img src="frontend/assets/icon.png" width="120" height="120" style="border-radius: 24px; box-shadow: 0px 6px 20px rgba(0, 0, 0, 0.15);" alt="Ridify Logo" />
  
  # Ridify
  
  ### *Real-Time Peer-to-Peer Ride-Sharing & Cost-Splitting*
  
  [![Flutter](https://img.shields.io/badge/Flutter-v3.11.4-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
  [![NodeJS](https://img.shields.io/badge/Node.js-v20+-339933?logo=node.js&logoColor=white)](https://nodejs.org)
  [![MongoDB](https://img.shields.io/badge/MongoDB-Latest-47A248?logo=mongodb&logoColor=white)](https://mongodb.com)
  [![Socket.io](https://img.shields.io/badge/Socket.io-v4.8-010101?logo=socket.io&logoColor=white)](https://socket.io)
  [![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
</div>

---

## 📖 Overview
**Ridify** is a production-grade, secure, real-time ride-sharing and cost-splitting mobile application. It empowers users to offer journeys, search for matches, pick locations via an interactive map, message co-passengers instantly, track rides live with real-time GPS telemetry, and split travel costs automatically.

The application offers an outstanding user experience featuring full-system **Light Mode** and **Dark Mode** support across every client interaction and a comprehensive administrative suite for platform security and verification.

---

## ✨ Features & Screen Showcase

### 1. App Startup & Branding (Splash Screen)
A responsive branding animation greeting the user and initializing state management. Session tokens are checked securely in background storage to route users automatically.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/splashScreenLightGIF.gif" width="320" alt="Splash Screen Light" /> | <img src="frontend/assets/screenshots/splashScreenDarkGIF.gif" width="320" alt="Splash Screen Dark" /> |

---

### 2. User Authentication (Login Screen)
Secure user login interface utilizing JWT credentials. Features email/password forms with password visibility toggles and direct connections to secure verification APIs.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/loginScreenLight.png" width="320" alt="Login Screen Light" /> | <img src="frontend/assets/screenshots/loginScreenDark.png" width="320" alt="Login Screen Dark" /> |

---

### 3. Account Registration (Sign-Up Screen)
Streamlined onboarding form prompting users for details, passwords, and mandatory identity validation metadata.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/signupScreenLight.png" width="320" alt="Sign-Up Screen Light" /> | <img src="frontend/assets/screenshots/signupScreenDark.png" width="320" alt="Sign-Up Screen Dark" /> |

---

### 4. Main User Dashboard (Home Screen)
The central user dashboard displaying active maps, current location overlays, and quick access functions for finding or offering rides.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/homeScreenLightGIF.gif" width="320" alt="Home Screen Light" /> | <img src="frontend/assets/screenshots/homeScreenDarkGIF.gif" width="320" alt="Home Screen Dark" /> |

---

### 5. Publishing a Journey (Offer Ride)
Drivers can publish upcoming rides specifying origin, destination, routing, intermediate stops, available seats, fare contributions, and car details.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/offerRideLight.png" width="320" alt="Offer Ride Light" /> | <img src="frontend/assets/screenshots/offerRideDark.png" width="320" alt="Offer Ride Dark" /> |

---

### 6. Interactive Map Pin-Drop (Location Picker)
A custom mapping layout using OpenStreetMap enabling precise, manual drag-and-drop marker pin placement to select pickup or drop-off coordinate pairs.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/locationPickerScreenLight.png" width="320" alt="Location Picker Light" /> | <img src="frontend/assets/screenshots/locationPickerScreenDark.png" width="320" alt="Location Picker Dark" /> |

---

### 7. Searching for a Journey (Find Ride)
An input form enabling users to scan for active journeys by configuring origin, destination, date, and preferred search range parameters.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/findRIdeLight.png" width="320" alt="Find Ride Light" /> | <img src="frontend/assets/screenshots/findRideDark.png" width="320" alt="Find Ride Dark" /> |

---

### 8. Matching Ride Results (Available Rides)
Displays a categorized list of all matches, showcasing fares, route maps, vehicle information, driver ratings, and passenger seat counts.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/availableRidesScreenLight.png" width="320" alt="Available Rides Light" /> | <img src="frontend/assets/screenshots/availableRidesScreenDark.png" width="320" alt="Available Rides Dark" /> |

---

### 9. Refining Search Criteria (Filters Popup)
A dynamic overlay allowing riders to filter matching results based on departures, pricing thresholds, driver preferences, and rating standards.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/filtersPopupLight.png" width="320" alt="Filters Popup Light" /> | <img src="frontend/assets/screenshots/filtersPopupDark.png" width="320" alt="Filters Popup Dark" /> |

---

### 10. Current Ongoing & Requested Rides (Activity Screen)
Tracks all active connections, showing status designations for requested, upcoming, ongoing, and completed trips for the user.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/activityScreenLight.png" width="320" alt="Activity Screen Light" /> | <img src="frontend/assets/screenshots/activityScreenDark.png" width="320" alt="Activity Screen Dark" /> |

---

### 11. Comprehensive Itinerary & Passengers (Ride Details)
Displays complete ride logistics, interactive route maps, profiles of co-passengers, luggage specifications, and contact triggers.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/rideDetailScreenLight.png" width="320" alt="Ride Details Light" /> | <img src="frontend/assets/screenshots/rideDetailScreenDark.png" width="320" alt="Ride Details Dark" /> |

---

### 12. Live Tracking (Driver: Ride Started)
The driver's live UI rendering current location, telemetry speed tracking, map routes, and navigation statuses after starting the journey.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/liveRideScreenDriver1Light.png" width="320" alt="Driver Live Tracking - Started Light" /> | <img src="frontend/assets/screenshots/liveRideScreenDriver1Dark.png" width="320" alt="Driver Live Tracking - Started Dark" /> |

---

### 13. Live Tracking (Rider: Waiting for Driver to Arrive)
Rider view showing real-time GPS telemetry updates of the driver's vehicle heading towards their pick-up coordinate.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/liveRideScreenRider1Light.png" width="320" alt="Rider Live Tracking - Waiting Light" /> | <img src="frontend/assets/screenshots/liveRideScreenRider1Dark.png" width="320" alt="Rider Live Tracking - Waiting Dark" /> |

---

### 14. Live Tracking (Driver: Waiting for Passengers to Board)
Once at the pickup coordinate, this interface guides the driver through the passenger check-in and onboarding workflow.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/liveRideScreenDriver2Light.png" width="320" alt="Driver Live Tracking - Boarding Light" /> | <img src="frontend/assets/screenshots/liveRideScreenDriver2Dark.png" width="320" alt="Driver Live Tracking - Boarding Dark" /> |

---

### 15. Live Tracking (Rider: Driver Arrived)
A system alert panel updating the rider's UI to confirm the driver has arrived and reached the pickup zone.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/liveRideScreenRider2Light.png" width="320" alt="Rider Live Tracking - Arrived Light" /> | <img src="frontend/assets/screenshots/liveRideScreenRider2Dark.png" width="320" alt="Rider Live Tracking - Arrived Dark" /> |

---

### 16. Live Tracking (Driver: Passenger Boarded)
Confirms passenger attendance, dynamically adjusting split balances, maps, and updating trip status records on the backend.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/liveRideScreenDriver3Light.png" width="320" alt="Driver Live Tracking - Passenger Boarded Light" /> | <img src="frontend/assets/screenshots/liveRideScreenDriver3Dark.png" width="320" alt="Driver Live Tracking - Passenger Boarded Dark" /> |

---

### 17. Live Tracking (Rider: In Transit)
The passenger tracking console displaying current vehicle path alignment, live speedometer metrics, and destination ETA alerts.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/liveRideScreenRider3Light.png" width="320" alt="Rider Live Tracking - In Transit Light" /> | <img src="frontend/assets/screenshots/liveRideScreenRider3Dark.png" width="320" alt="Rider Live Tracking - In Transit Dark" /> |

---

### 18. Real-Time Secure Messaging (Chat Screen)
A peer-to-peer WebSocket messaging room enabling drivers and passengers to coordinate trip logistics securely.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/chatScreenLight.png" width="320" alt="Chat Screen Light" /> | <img src="frontend/assets/screenshots/chatScreenDark.png" width="320" alt="Chat Screen Dark" /> |

---

### 19. End of Journey Summary (Driver)
Displays journey metrics for drivers: total distance traveled, total duration, and exact cost division earnings.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/driverCompletionScreenLight.png" width="320" alt="Driver End Journey Light" /> | <img src="frontend/assets/screenshots/driverCompletionScreenDark.png" width="320" alt="Driver End Journey Dark" /> |

---

### 20. End of Journey Receipt (Rider)
Breakdown of final fare contributions for riders, complete with feedback submission prompts for driver ratings.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/riderCompletionScreenLight.png" width="320" alt="Rider End Journey Light" /> | <img src="frontend/assets/screenshots/riderCompletionScreenDark.png" width="320" alt="Rider End Journey Dark" /> |

---

### 21. Past Journeys & Cost Summary (History Screen)
A comprehensive transaction and travel ledger displaying historical ride parameters, routes, costs split, and role statistics.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/historyScreenLight.png" width="320" alt="History Screen Light" /> | <img src="frontend/assets/screenshots/historyScreenDark.png" width="320" alt="History Screen Dark" /> |

---

### 22. Co-Passengers Travelled (Popup)
A safety and profile check detail overlay, displaying past co-passengers, mutual ratings, and fast connection links.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/passengersTravelledPopupLight.png" width="320" alt="Co-Passengers Popup Light" /> | <img src="frontend/assets/screenshots/passengersTravelledPopupDark.png" width="320" alt="Co-Passengers Popup Dark" /> |

---

### 23. User Account & Settings (Profile Screen)
Enables users to manage active vehicle profiles, upload documents, verify emails, review reviews, and toggle UI modes.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/profileScreenLight.png" width="320" alt="Profile Screen Light" /> | <img src="frontend/assets/screenshots/profileScreenDark.png" width="320" alt="Profile Screen Dark" /> |

---

### 24. System Overview Metrics (Admin Dashboard Home)
High-level administration analytics summarizing total registered users, overall rides matched, active real-time trips, and live system load.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/adminDashboardLight.png" width="320" alt="Admin Dashboard Light" /> | <img src="frontend/assets/screenshots/adminDashboardDark.png" width="320" alt="Admin Dashboard Dark" /> |

---

### 25. Directory of Registered Accounts (Admin Manage Users)
An interactive moderation directory displaying accounts, verification status tags, active ride metrics, and ban/unban moderation tools.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/adminUsersLight.png" width="320" alt="Admin Users Light" /> | <img src="frontend/assets/screenshots/adminUsersDark.png" width="320" alt="Admin Users Dark" /> |

---

### 26. Detailed User Data Modal (Admin User Info Popup)
An administrative profile inspect tool providing complete detail checks on users, ride safety history, and profile records.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/userPopupLight.png" width="320" alt="Admin User Modal Light" /> | <img src="frontend/assets/screenshots/userPopupDark.png" width="320" alt="Admin User Modal Dark" /> |

---

### 27. Monitoring Ongoing Journeys (Admin Active Rides)
A safety panel showcasing real-time geographic plots of all ongoing passenger journeys with system override links.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/adminRidesLight.png" width="320" alt="Admin Active Rides Light" /> | <img src="frontend/assets/screenshots/adminRidesDark.png" width="320" alt="Admin Active Rides Dark" /> |

---

### 28. KYC & Document Checking (Admin Verify Users)
A structured moderation interface allowing administrators to review identity documents, cross-reference user credentials, and approve KYC verification badges.

| Light Mode | Dark Mode |
| :---: | :---: |
| <img src="frontend/assets/screenshots/adminVerifyLight.png" width="320" alt="Admin Verification Light" /> | <img src="frontend/assets/screenshots/adminVerifyDark.png" width="320" alt="Admin Verification Dark" /> |

---

## 🛠️ Technical Stack & Architecture

### Frontend (Mobile Application)
* **Framework**: [Flutter (Dart)](https://flutter.dev) for cross-platform iOS and Android support.
* **State Management**: [Provider](https://pub.dev/packages/provider) for clean, reactive updates and decoupled state controllers.
* **Maps & GIS**: [flutter_map](https://pub.dev/packages/flutter_map) + [latlong2](https://pub.dev/packages/latlong2) + OpenStreetMap tiles. This offers a highly customized, responsive, and completely cost-free mapping solution.
* **Real-time Engine**: [socket_io_client](https://pub.dev/packages/socket_io_client) for persistent TCP sockets streaming real-time driver/rider locations and direct messages.
* **Hardware Sensors**: [geolocator](https://pub.dev/packages/geolocator) for highly accurate location updates.
* **Secure Storage**: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) for encrypting and persisting JWT session keys on device keychains.

### Backend (API & WebSocket Server)
* **Runtime**: [Node.js](https://nodejs.org) + [Express](https://expressjs.com) web framework.
* **Database**: [MongoDB](https://www.mongodb.com) hosted with object mapping handled via [Mongoose](https://mongoosejs.com).
* **Bi-directional Sync**: [Socket.io](https://socket.io) server orchestrating location events, chat rooms, and real-time state broadcasts.
* **Geospatial Engine**: [@turf/turf](https://turfjs.org) for performing geometry math (bounding-box search, proximity algorithms, distance splits).
* **Logging & Monitoring**: [Winston](https://github.com/winstonjs/winston) logger for trace routing and error capture.

### Security & Hardening
* **Helmet**: Hardens HTTP headers against clickjacking, sniff attacks, and cross-site scripting.
* **bcrypt**: 10-round salt hashing for database password protection.
* **JSON Web Tokens (JWT)**: Stateless tokenization validating HTTP requests securely.
* **express-rate-limit**: Rate limiting middleware applied globally to mitigate DDoS and credential brute-forcing.
* **sanitize-html**: Sanitizes user inputs to prevent injection attacks and cross-site scripting (XSS).

---

## 📂 Project Structure

```
ridify/
├── backend/                  # Node.js Server & Socket Host
│   ├── config/               # DB & server configs
│   ├── controllers/          # Business logic handlers (auth, rides, admin)
│   ├── middleware/           # Auth validation, rate-limiting, error capture
│   ├── models/               # MongoDB Mongoose Schemas (User, Ride, OTP)
│   ├── routes/               # API endpoints structure
│   └── server.js             # Main server entrypoint
│
└── frontend/                 # Flutter Client Application
    ├── assets/               # Local images, icons, and fonts
    │   ├── screenshots/      # Feature comparison captures & GIFs
    │   └── icon.png          # App branding asset
    │
    └── lib/                  # Dart files
        ├── core/             # Application constants and themes
        ├── screens/          # Interactive UI screens (Client + Admin)
        ├── services/         # API adapters, Socket services, location trackers
        ├── utils/            # Helper utilities
        └── widgets/          # Shared components & UI overlays
```

---

## ⚡ Setup & Installation

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.11.4 or higher recommended)
* [Node.js](https://nodejs.org/en) (v20.x or higher)
* [MongoDB](https://www.mongodb.com/try/download/community) running locally or an Atlas connection string

### 1. Backend Setup
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Configure environment variables. Copy `.env.example` to `.env` and fill in the values:
   ```bash
   cp .env.example .env
   ```
   * *Ensure you specify `PORT`, `MONGO_URI`, `JWT_SECRET`, and connection settings.*
4. Launch the developer server (with hot reload enabled):
   ```bash
   npm run dev
   ```

### 2. Frontend Setup
1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Fetch required Dart dependencies:
   ```bash
   flutter pub get
   ```
3. Configure your local client configuration. Create a `.env` file referencing your backend server IP:
   ```env
   BACKEND_URL=http://<YOUR_LOCAL_IP>:5001
   ```
4. Build and execute on your emulator or physical debugging device:
   ```bash
   flutter run
   ```

---

## 📄 License & Attribution
Distributed under the MIT License. See [LICENSE](LICENSE) for more details. 

Developed and maintained by **[Priyanshu Sharan](https://github.com/priyanshusharan-cmd)**. For support, issues, or contributions, please open an issue in the repository.

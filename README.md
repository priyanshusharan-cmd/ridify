<h1 align="center">
  <img src="frontend/assets/iconWithoutBackground.png" alt="Ridify Logo" width="120"/>
  <br>
  Ridify
</h1>

<p align="center">
  <b>A real-time ride-sharing app for students. Offer or find shared rides, track journeys live on a map, and split travel costs effortlessly.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Node.js-43853D?style=for-the-badge&logo=node.js&logoColor=white" alt="Node.js">
  <img src="https://img.shields.io/badge/Express.js-%23404d59.svg?style=for-the-badge&logo=express&logoColor=%2361DAFB" alt="Express">
  <img src="https://img.shields.io/badge/MongoDB-%234ea94b.svg?style=for-the-badge&logo=mongodb&logoColor=white" alt="MongoDB">
  <img src="https://img.shields.io/badge/Socket.io-black?style=for-the-badge&logo=socket.io&badgeColor=010101" alt="Socket.io">
  <img src="https://img.shields.io/badge/Turf.js-green?style=for-the-badge" alt="Turf.js">
</p>

<hr>

## 📖 About The Project

**Ridify** is a comprehensive, full-stack mobile application designed to solve transportation challenges for university students. It provides a secure, real-time platform where students can either offer empty seats in their vehicles or find a ride going in their direction. By carpooling, students can drastically reduce travel costs, minimize carbon footprints, and network with peers.

Unlike standard ride-hailing apps, Ridify is built from the ground up to emphasize **safety, community verification, and real-time responsiveness**. It integrates a seamless location-tracking engine, in-app messaging, and a robust administrative panel to oversee operations.

### ✨ Core Features & Technical Highlights

* **🚗 Intelligent Ride Matching:** Uses advanced geospatial querying (via MongoDB `$geoNear` and Turf.js) to match riders with drivers whose routes naturally overlap. 
* **📍 High-Frequency Real-Time Tracking:** Leveraging Socket.IO WebSockets, the app streams precise GPS coordinates continuously. Both riders and drivers see the vehicle moving smoothly on the Flutter Map in real-time, completely eliminating the need for manual refreshing.
* **💬 Instant In-App Chat:** A fully integrated real-time chat interface allows drivers and passengers to communicate securely, ensuring privacy without exposing personal phone numbers.
* **🛡️ Extensive Admin Moderation:** A dedicated administrative dashboard provides high-level control. Admins can verify student IDs, suspend malicious users, and monitor active rides in real-time to ensure platform safety.
* **🌗 Premium UI/UX Aesthetics:** The app features a meticulously crafted interface with full support for system-wide Dark and Light modes. It utilizes custom micro-animations, glassmorphic overlays, and highly responsive components to deliver a flagship-level user experience.
* **🔐 Multi-Layer Security:** Features OTP-based email verification, strictly validated JSON Web Tokens (JWT) for API requests, and bcrypt hashing for sensitive data.

---

## 📸 Comprehensive App Showcase

*(Note: Old login & signup screenshots are not included as they were recently removed. The flow begins straight from Splash to Home)*

| Light Mode | Dark Mode |
|:---:|:---:|
| **App Startup & Branding (Splash Screen)**<br><img src="frontend/assets/screenshots/splashScreenLightGIF.gif" width="280"> | **App Startup & Branding (Splash Screen)**<br><img src="frontend/assets/screenshots/splashScreenDarkGIF.gif" width="280"> |
| **Main User Dashboard (Home Screen)**<br><img src="frontend/assets/screenshots/homeScreenLightGIF.gif" width="280"> | **Main User Dashboard (Home Screen)**<br><img src="frontend/assets/screenshots/homeScreenDarkGIF.gif" width="280"> |
| **Publishing a Journey (Offer Ride)**<br><img src="frontend/assets/screenshots/offerRideLight.png" width="280"> | **Publishing a Journey (Offer Ride)**<br><img src="frontend/assets/screenshots/offerRideDark.png" width="280"> |
| **Interactive Map Pin-Drop (Location Picker)**<br><img src="frontend/assets/screenshots/locationPickerScreenLight.png" width="280"> | **Interactive Map Pin-Drop (Location Picker)**<br><img src="frontend/assets/screenshots/locationPickerScreenDark.png" width="280"> |
| **Searching for a Journey (Find Ride)**<br><img src="frontend/assets/screenshots/findRIdeLight.png" width="280"> | **Searching for a Journey (Find Ride)**<br><img src="frontend/assets/screenshots/findRideDark.png" width="280"> |
| **Matching Ride Results (Available Rides)**<br><img src="frontend/assets/screenshots/availableRidesScreenLight.png" width="280"> | **Matching Ride Results (Available Rides)**<br><img src="frontend/assets/screenshots/availableRidesScreenDark.png" width="280"> |
| **Refining Search Criteria (Filters Popup)**<br><img src="frontend/assets/screenshots/filtersPopupLight.png" width="280"> | **Refining Search Criteria (Filters Popup)**<br><img src="frontend/assets/screenshots/filtersPopupDark.png" width="280"> |
| **Current Ongoing & Requested Rides (Activity Screen)**<br><img src="frontend/assets/screenshots/activityScreenLight.png" width="280"> | **Current Ongoing & Requested Rides (Activity Screen)**<br><img src="frontend/assets/screenshots/activityScreenDark.png" width="280"> |
| **Comprehensive Itinerary & Passengers (Ride Details)**<br><img src="frontend/assets/screenshots/rideDetailScreenLight.png" width="280"> | **Comprehensive Itinerary & Passengers (Ride Details)**<br><img src="frontend/assets/screenshots/rideDetailScreenDark.png" width="280"> |
| **Live Tracking (Driver: Ride Started & Route Overview)**<br><img src="frontend/assets/screenshots/liveRideScreenDriver1Light.png" width="280"> | **Live Tracking (Driver: Ride Started & Route Overview)**<br><img src="frontend/assets/screenshots/liveRideScreenDriver1Dark.png" width="280"> |
| **Live Tracking (Rider: Waiting for Driver Acceptance)**<br><img src="frontend/assets/screenshots/liveRideScreenRider1Light.png" width="280"> | **Live Tracking (Rider: Waiting for Driver Acceptance)**<br><img src="frontend/assets/screenshots/liveRideScreenRider1Dark.png" width="280"> |
| **Live Tracking (Driver: Navigating to Pickup Point)**<br><img src="frontend/assets/screenshots/liveRideScreenDriver2Light.png" width="280"> | **Live Tracking (Driver: Navigating to Pickup Point)**<br><img src="frontend/assets/screenshots/liveRideScreenDriver2Dark.png" width="280"> |
| **Live Tracking (Rider: Driver is Approaching)**<br><img src="frontend/assets/screenshots/liveRideScreenRider2Light.png" width="280"> | **Live Tracking (Rider: Driver is Approaching)**<br><img src="frontend/assets/screenshots/liveRideScreenRider2Dark.png" width="280"> |
| **Live Tracking (Driver: Passenger Boarding & Transit)**<br><img src="frontend/assets/screenshots/liveRideScreenDriver3Light.png" width="280"> | **Live Tracking (Driver: Passenger Boarding & Transit)**<br><img src="frontend/assets/screenshots/liveRideScreenDriver3Dark.png" width="280"> |
| **Live Tracking (Rider: In Transit to Destination)**<br><img src="frontend/assets/screenshots/liveRideScreenRider3Light.png" width="280"> | **Live Tracking (Rider: In Transit to Destination)**<br><img src="frontend/assets/screenshots/liveRideScreenRider3Dark.png" width="280"> |
| **Real-Time Secure Messaging (Chat Screen)**<br><img src="frontend/assets/screenshots/chatScreenLight.png" width="280"> | **Real-Time Secure Messaging (Chat Screen)**<br><img src="frontend/assets/screenshots/chatScreenDark.png" width="280"> |
| **End of Journey Summary (Driver Perspective)**<br><img src="frontend/assets/screenshots/driverCompletionScreenLight.png" width="280"> | **End of Journey Summary (Driver Perspective)**<br><img src="frontend/assets/screenshots/driverCompletionScreenDark.png" width="280"> |
| **End of Journey Receipt (Rider Perspective)**<br><img src="frontend/assets/screenshots/riderCompletionScreenLight.png" width="280"> | **End of Journey Receipt (Rider Perspective)**<br><img src="frontend/assets/screenshots/riderCompletionScreenDark.png" width="280"> |
| **Past Journeys & Cost Summary (History Screen)**<br><img src="frontend/assets/screenshots/historyScreenLight.png" width="280"> | **Past Journeys & Cost Summary (History Screen)**<br><img src="frontend/assets/screenshots/historyScreenDark.png" width="280"> |
| **Networking & Co-Passengers Travelled (Popup)**<br><img src="frontend/assets/screenshots/passengersTravelledPopupLight.png" width="280"> | **Networking & Co-Passengers Travelled (Popup)**<br><img src="frontend/assets/screenshots/passengersTravelledPopupDark.png" width="280"> |
| **User Account & Settings (Profile Screen)**<br><img src="frontend/assets/screenshots/profileScreenLight.png" width="280"> | **User Account & Settings (Profile Screen)**<br><img src="frontend/assets/screenshots/profileScreenDark.png" width="280"> |
| **System Overview Metrics (Admin Dashboard Home)**<br><img src="frontend/assets/screenshots/adminDashboardLight.png" width="280"> | **System Overview Metrics (Admin Dashboard Home)**<br><img src="frontend/assets/screenshots/adminDashboardDark.png" width="280"> |
| **Directory of Registered Accounts (Admin Manage Users)**<br><img src="frontend/assets/screenshots/adminUsersLight.png" width="280"> | **Directory of Registered Accounts (Admin Manage Users)**<br><img src="frontend/assets/screenshots/adminUsersDark.png" width="280"> |
| **Detailed User Data Modal (Admin User Info Popup)**<br><img src="frontend/assets/screenshots/userPopupLight.png" width="280"> | **Detailed User Data Modal (Admin User Info Popup)**<br><img src="frontend/assets/screenshots/userPopupDark.png" width="280"> |
| **Monitoring Ongoing Journeys (Admin Active Rides)**<br><img src="frontend/assets/screenshots/adminRidesLight.png" width="280"> | **Monitoring Ongoing Journeys (Admin Active Rides)**<br><img src="frontend/assets/screenshots/adminRidesDark.png" width="280"> |
| **KYC & Document Checking (Admin Verify Users)**<br><img src="frontend/assets/screenshots/adminVerifyLight.png" width="280"> | **KYC & Document Checking (Admin Verify Users)**<br><img src="frontend/assets/screenshots/adminVerifyDark.png" width="280"> |

---

## 🛠️ Technology Architecture

### **Frontend (Mobile App)**
* **Framework:** [Flutter](https://flutter.dev/) (Dart) for high-performance cross-platform rendering.
* **State Management:** Provider for scalable and reactive UI updates.
* **Mapping Engine:** flutter_map with latlong2 for customizable vector maps.
* **Real-time Engine:** socket_io_client for instant event listening.
* **Local Storage:** shared_preferences & flutter_secure_storage for encrypted local tokens.

### **Backend (API Server)**
* **Runtime environment:** [Node.js](https://nodejs.org/) handling highly concurrent I/O.
* **Framework:** Express.js for REST API endpoint routing.
* **Database:** MongoDB configured with Mongoose ORM.
* **Real-time Engine:** Socket.IO to manage persistent TCP connections.
* **Security Middleware:** JWT Authentication, bcrypt hashing, Helmet.js headers, and express-rate-limit.
* **Geospatial Processing:** Turf.js for complex polygon and distance computations.

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.11.4+)
* [Node.js](https://nodejs.org/en/) (v16.x or later)
* [MongoDB](https://www.mongodb.com/) (Local instance or Atlas cluster)

### 1. Backend Server Setup
```bash
# Navigate to the backend root directory
cd backend

# Install necessary NPM packages
npm install

# Duplicate the environment template
cp .env.example .env
# Edit .env and supply your MongoDB URI, JWT Secret, etc.

# Boot up the development server
npm run dev
```

### 2. Frontend Application Setup
```bash
# Navigate to the frontend directory
cd frontend

# Retrieve Flutter dependencies
flutter pub get

# Duplicate the environment template
cp .env.example .env
# Edit .env with your backend API URL (e.g., http://10.0.2.2:5000 for Android emulator)

# Compile and run the app on a connected device/emulator
flutter run
```

---

## 🤝 Contributing

Contributions, bug reports, and feature requests are highly appreciated! Feel free to check the issues page or submit a Pull Request.

## 📝 License

This project is open-sourced under the MIT License - see the [LICENSE](LICENSE) file for details.

<p align="center">
  <i>Developed with ❤️ by Priyanshu Sharan.</i>
</p>

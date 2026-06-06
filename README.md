<div align="center">

  <img src="frontend/assets/icon.png" alt="Ridify Logo" width="150" style="border-radius: 20px; box-shadow: 0 4px 8px rgba(0,0,0,0.2);"/>
  
  <h1>🌟 Ridify</h1>
  
  <p>
    <b>A premium, real-time ride-sharing platform for daily commuters, students, and professionals.<br>Offer or find shared rides, track journeys live on a map, and split travel costs effortlessly.</b>
  </p>

  <p>
    <a href="https://flutter.dev/"><img src="https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white" alt="Flutter"></a>
    <a href="https://nodejs.org/"><img src="https://img.shields.io/badge/Node.js-43853D?style=for-the-badge&logo=node.js&logoColor=white" alt="Node.js"></a>
    <a href="https://expressjs.com/"><img src="https://img.shields.io/badge/Express.js-%23404d59.svg?style=for-the-badge&logo=express&logoColor=%2361DAFB" alt="Express"></a>
    <a href="https://www.mongodb.com/"><img src="https://img.shields.io/badge/MongoDB-%234ea94b.svg?style=for-the-badge&logo=mongodb&logoColor=white" alt="MongoDB"></a>
    <a href="https://socket.io/"><img src="https://img.shields.io/badge/Socket.io-black?style=for-the-badge&logo=socket.io&badgeColor=010101" alt="Socket.io"></a>
  </p>

  <p>
    <a href="#-about-the-project">About</a> •
    <a href="#-core-features--technical-highlights">Features</a> •
    <a href="#-app-showcase">Screenshots</a> •
    <a href="#-technology-architecture">Architecture</a> •
    <a href="#-getting-started">Getting Started</a>
  </p>

</div>

<hr>

## 📖 About The Project

> *"Redefining the daily commute through secure, peer-to-peer carpooling."*

**Ridify** is a comprehensive, full-stack mobile application meticulously designed to solve daily transportation challenges for everyone. It provides a secure, real-time platform where individuals can either offer empty seats in their vehicles or find a ride going in their direction. By carpooling, users can drastically reduce travel costs, minimize their carbon footprints, alleviate city parking congestion, and seamlessly network with fellow travelers.

Unlike standard ride-hailing applications, Ridify is built from the ground up to emphasize **safety, community verification, and real-time responsiveness**. It integrates a sophisticated location-tracking engine, peer-to-peer in-app messaging, intelligent routing, and a robust administrative panel to oversee operations and ensure strict compliance with community guidelines.

### 🎯 Motivation

Daily commuters, students, and frequent travelers often face challenges with expensive public transit, limited parking, and the difficulty of finding reliable transportation during peak hours or holidays. Ridify bridges this gap by creating an accessible and secure carpooling network. It fosters a sense of community, encourages sustainable travel habits, and provides a highly economical alternative to traditional taxis for all users.

---

## ✨ Core Features & Technical Highlights

* **🚗 Intelligent Ride Matching:** Uses advanced geospatial querying (via MongoDB `$geoNear` and Turf.js) to accurately match riders with drivers whose routes naturally overlap, ensuring minimal detours and maximum convenience.
* **📍 High-Frequency Real-Time Tracking:** Leveraging Socket.IO WebSockets, the app streams precise GPS coordinates continuously. Both riders and drivers see the vehicle moving smoothly on the Flutter Map in real-time, completely eliminating the need for manual refreshing and ensuring exact ETA predictions.
* **💬 Instant In-App Chat:** A fully integrated real-time chat interface allows drivers and passengers to communicate securely to coordinate pickup details, ensuring privacy without exposing personal phone numbers.
* **🛡️ Extensive Admin Moderation:** A dedicated administrative dashboard provides high-level control. Admins can verify user IDs, suspend malicious accounts, manage disputes, and monitor active rides in real-time to ensure platform safety.
* **🌗 Premium UI/UX Aesthetics:** The app features a meticulously crafted interface with full support for system-wide Dark and Light modes. It utilizes custom micro-animations, glassmorphic overlays, modern typography, and highly responsive components to deliver a flagship-level user experience.
* **🔐 Multi-Layer Security:** Features robust email verification, strictly validated JSON Web Tokens (JWT) for all API requests, bcrypt hashing for sensitive data, and comprehensive rate limiting to prevent abuse.
* **📊 Analytics & History:** Users have access to detailed journey histories, expense tracking, and a list of co-passengers they've traveled with, enhancing trust and record-keeping.

---

## 📸 App Showcase

<details open>
<summary><b>1. App Startup & Branding</b></summary>

| Light Mode | Dark Mode |
|:---:|:---:|
| **App Startup & Branding (Splash Screen)**<br><img src="frontend/assets/screenshots/splashScreenLightGIF.gif" width="280"> | **App Startup & Branding (Splash Screen)**<br><img src="frontend/assets/screenshots/splashScreenDarkGIF.gif" width="280"> |
</details>

<details>
<summary><b>2. User Authentication & Account Registration</b></summary>

| Light Mode | Dark Mode |
|:---:|:---:|
| **User Authentication (Login Screen)**<br><img src="frontend/assets/screenshots/loginScreenLight.png" width="280"> | **User Authentication (Login Screen)**<br><img src="frontend/assets/screenshots/loginScreenDark.png" width="280"> |
| **Account Registration (Sign-Up Screen)**<br><img src="frontend/assets/screenshots/signupScreenLight.png" width="280"> | **Account Registration (Sign-Up Screen)**<br><img src="frontend/assets/screenshots/signupScreenDark.png" width="280"> |
</details>

<details>
<summary><b>3. Main User Dashboard</b></summary>

| Light Mode | Dark Mode |
|:---:|:---:|
| **Main User Dashboard (Home Screen)**<br><img src="frontend/assets/screenshots/homeScreenLightGIF.gif" width="280"> | **Main User Dashboard (Home Screen)**<br><img src="frontend/assets/screenshots/homeScreenDarkGIF.gif" width="280"> |
</details>

<details>
<summary><b>4. Ride Creation and Geospatial Search</b></summary>

| Light Mode | Dark Mode |
|:---:|:---:|
| **Publishing a Journey (Offer Ride)**<br><img src="frontend/assets/screenshots/offerRideLight.png" width="280"> | **Publishing a Journey (Offer Ride)**<br><img src="frontend/assets/screenshots/offerRideDark.png" width="280"> |
| **Interactive Map Pin-Drop (Location Picker)**<br><img src="frontend/assets/screenshots/locationPickerScreenLight.png" width="280"> | **Interactive Map Pin-Drop (Location Picker)**<br><img src="frontend/assets/screenshots/locationPickerScreenDark.png" width="280"> |
| **Searching for a Journey (Find Ride)**<br><img src="frontend/assets/screenshots/findRIdeLight.png" width="280"> | **Searching for a Journey (Find Ride)**<br><img src="frontend/assets/screenshots/findRideDark.png" width="280"> |
</details>

<details>
<summary><b>5. Ride Matching and Itinerary Management</b></summary>

| Light Mode | Dark Mode |
|:---:|:---:|
| **Matching Ride Results (Available Rides)**<br><img src="frontend/assets/screenshots/availableRidesScreenLight.png" width="280"> | **Matching Ride Results (Available Rides)**<br><img src="frontend/assets/screenshots/availableRidesScreenDark.png" width="280"> |
| **Refining Search Criteria (Filters Popup)**<br><img src="frontend/assets/screenshots/filtersPopupLight.png" width="280"> | **Refining Search Criteria (Filters Popup)**<br><img src="frontend/assets/screenshots/filtersPopupDark.png" width="280"> |
| **Current Ongoing & Requested Rides (Activity Screen)**<br><img src="frontend/assets/screenshots/activityScreenLight.png" width="280"> | **Current Ongoing & Requested Rides (Activity Screen)**<br><img src="frontend/assets/screenshots/activityScreenDark.png" width="280"> |
| **Comprehensive Itinerary & Passengers (Ride Details)**<br><img src="frontend/assets/screenshots/rideDetailScreenLight.png" width="280"> | **Comprehensive Itinerary & Passengers (Ride Details)**<br><img src="frontend/assets/screenshots/rideDetailScreenDark.png" width="280"> |
</details>

<details>
<summary><b>6. Real-Time Telemetry and Peer Communication</b></summary>

| Light Mode | Dark Mode |
|:---:|:---:|
| **Live Tracking (Driver: Ride Started)**<br><img src="frontend/assets/screenshots/liveRideScreenDriver1Light.png" width="280"> | **Live Tracking (Driver: Ride Started)**<br><img src="frontend/assets/screenshots/liveRideScreenDriver1Dark.png" width="280"> |
| **Live Tracking (Rider: Waiting for Driver to Arrive)**<br><img src="frontend/assets/screenshots/liveRideScreenRider1Light.png" width="280"> | **Live Tracking (Rider: Waiting for Driver to Arrive)**<br><img src="frontend/assets/screenshots/liveRideScreenRider1Dark.png" width="280"> |
| **Live Tracking (Driver: Waiting for Passengers to Board)**<br><img src="frontend/assets/screenshots/liveRideScreenDriver2Light.png" width="280"> | **Live Tracking (Driver: Waiting for Passengers to Board)**<br><img src="frontend/assets/screenshots/liveRideScreenDriver2Dark.png" width="280"> |
| **Live Tracking (Rider: Driver Arrived)**<br><img src="frontend/assets/screenshots/liveRideScreenRider2Light.png" width="280"> | **Live Tracking (Rider: Driver Arrived)**<br><img src="frontend/assets/screenshots/liveRideScreenRider2Dark.png" width="280"> |
| **Live Tracking (Driver: Passenger Boarded)**<br><img src="frontend/assets/screenshots/liveRideScreenDriver3Light.png" width="280"> | **Live Tracking (Driver: Passenger Boarded)**<br><img src="frontend/assets/screenshots/liveRideScreenDriver3Dark.png" width="280"> |
| **Live Tracking (Rider: In Transit)**<br><img src="frontend/assets/screenshots/liveRideScreenRider3Light.png" width="280"> | **Live Tracking (Rider: In Transit)**<br><img src="frontend/assets/screenshots/liveRideScreenRider3Dark.png" width="280"> |
| **Real-Time Secure Messaging (Chat Screen)**<br><img src="frontend/assets/screenshots/chatScreenLight.png" width="280"> | **Real-Time Secure Messaging (Chat Screen)**<br><img src="frontend/assets/screenshots/chatScreenDark.png" width="280"> |
</details>

<details>
<summary><b>7. Post-Ride Logistics and Analytics</b></summary>

| Light Mode | Dark Mode |
|:---:|:---:|
| **End of Journey Summary (Driver)**<br><img src="frontend/assets/screenshots/driverCompletionScreenLight.png" width="280"> | **End of Journey Summary (Driver)**<br><img src="frontend/assets/screenshots/driverCompletionScreenDark.png" width="280"> |
| **End of Journey Receipt (Rider)**<br><img src="frontend/assets/screenshots/riderCompletionScreenLight.png" width="280"> | **End of Journey Receipt (Rider)**<br><img src="frontend/assets/screenshots/riderCompletionScreenDark.png" width="280"> |
| **Past Journeys & Cost Summary (History Screen)**<br><img src="frontend/assets/screenshots/historyScreenLight.png" width="280"> | **Past Journeys & Cost Summary (History Screen)**<br><img src="frontend/assets/screenshots/historyScreenDark.png" width="280"> |
| **Co-Passengers Travelled (Popup)**<br><img src="frontend/assets/screenshots/passengersTravelledPopupLight.png" width="280"> | **Co-Passengers Travelled (Popup)**<br><img src="frontend/assets/screenshots/passengersTravelledPopupDark.png" width="280"> |
| **User Account & Settings (Profile Screen)**<br><img src="frontend/assets/screenshots/profileScreenLight.png" width="280"> | **User Account & Settings (Profile Screen)**<br><img src="frontend/assets/screenshots/profileScreenDark.png" width="280"> |
</details>

<details>
<summary><b>8. Administration and Platform Security</b></summary>

| Light Mode | Dark Mode |
|:---:|:---:|
| **System Overview Metrics (Admin Dashboard Home)**<br><img src="frontend/assets/screenshots/adminDashboardLight.png" width="280"> | **System Overview Metrics (Admin Dashboard Home)**<br><img src="frontend/assets/screenshots/adminDashboardDark.png" width="280"> |
| **Directory of Registered Accounts (Admin Manage Users)**<br><img src="frontend/assets/screenshots/adminUsersLight.png" width="280"> | **Directory of Registered Accounts (Admin Manage Users)**<br><img src="frontend/assets/screenshots/adminUsersDark.png" width="280"> |
| **Detailed User Data Modal (Admin User Info Popup)**<br><img src="frontend/assets/screenshots/userPopupLight.png" width="280"> | **Detailed User Data Modal (Admin User Info Popup)**<br><img src="frontend/assets/screenshots/userPopupDark.png" width="280"> |
| **Monitoring Ongoing Journeys (Admin Active Rides)**<br><img src="frontend/assets/screenshots/adminRidesLight.png" width="280"> | **Monitoring Ongoing Journeys (Admin Active Rides)**<br><img src="frontend/assets/screenshots/adminRidesDark.png" width="280"> |
| **KYC & Document Checking (Admin Verify Users)**<br><img src="frontend/assets/screenshots/adminVerifyLight.png" width="280"> | **KYC & Document Checking (Admin Verify Users)**<br><img src="frontend/assets/screenshots/adminVerifyDark.png" width="280"> |
</details>

---

## 🛠️ Technology Architecture

### **📱 Frontend (Mobile App)**
* **Framework:** [Flutter](https://flutter.dev/) (Dart) for high-performance cross-platform rendering on both iOS and Android.
* **State Management:** Provider for scalable, reactive, and predictable UI updates.
* **Mapping Engine:** `flutter_map` paired with `latlong2` for customizable, open-source vector maps.
* **Real-time Engine:** `socket_io_client` for instant event listening and bidirectional communication.
* **Local Storage:** `shared_preferences` for user settings and `flutter_secure_storage` for encrypted storage of JWTs and sensitive data.

### **⚙️ Backend (API Server)**
* **Runtime Environment:** [Node.js](https://nodejs.org/) optimized for handling highly concurrent I/O operations.
* **Framework:** Express.js for robust RESTful API endpoint routing and middleware integration.
* **Database:** MongoDB configured with Mongoose ORM for flexible, document-based data modeling.
* **Real-time Engine:** Socket.IO to manage persistent TCP connections for live tracking and chat.
* **Security & Middleware:**
  * **Authentication:** JSON Web Tokens (JWT)
  * **Encryption:** bcrypt for password hashing
  * **Headers:** Helmet.js for securing HTTP headers
  * **Traffic Control:** `express-rate-limit` to thwart DDoS and brute-force attacks
* **Geospatial Processing:** Turf.js for complex polygon, intersection, and distance computations.

---

## 🚀 Getting Started

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (v3.11.4+)
* [Node.js](https://nodejs.org/en/) (v16.x or later)
* [MongoDB](https://www.mongodb.com/) (Local instance or an Atlas cloud cluster)
* Git

### 1. Backend Server Setup
```bash
# Clone the repository
git clone https://github.com/your-username/ridify.git

# Navigate to the backend root directory
cd ridify/backend

# Install necessary NPM dependencies
npm install

# Duplicate the environment template
cp .env.example .env

# Edit the .env file and supply your MongoDB URI, JWT Secret, and other required variables
nano .env

# Boot up the development server
npm run dev
```

### 2. Frontend Application Setup
```bash
# Navigate to the frontend directory
cd ../frontend

# Retrieve Flutter dependencies
flutter pub get

# Duplicate the environment template
cp .env.example .env

# Edit .env with your backend API URL
# For Android emulator pointing to local host, use http://10.0.2.2:5000
# For iOS simulator pointing to local host, use http://127.0.0.1:5000
nano .env

# Compile and run the app on a connected device or emulator
flutter run
```

---

## 🛡️ Security Measures

Security is paramount in a ride-sharing application. Ridify implements the following:
- **Data Protection:** All passwords are one-way hashed using bcrypt before being stored.
- **Session Management:** Stateless authentication via JWT with brief expiration times.
- **Input Validation:** Strict sanitization of all incoming API requests to prevent NoSQL injections and XSS attacks.
- **Role-Based Access Control (RBAC):** Distinct permissions separating standard users from administrators.

## 🗺️ Future Roadmap

- [ ] Implementation of a seamless in-app payment gateway (e.g., Stripe) for automated cost-splitting.
- [ ] Integration with university Single Sign-On (SSO) systems.
- [ ] Push notifications via Firebase Cloud Messaging (FCM) for offline alerts.
- [ ] AI-driven route optimization and dynamic pricing suggestions.

## 🤝 Contributing

Contributions, bug reports, and feature requests are highly appreciated! 
1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is open-sourced under the MIT License - see the [LICENSE](LICENSE) file for details.

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue?style=flat-square">
  <img src="https://img.shields.io/badge/Architecture-Full%20Stack-success?style=flat-square">
  <img src="https://img.shields.io/badge/Real--Time-WebSockets-orange?style=flat-square">
</p>

---

## 📖 About Ridify

> **"Redefining daily commuting through secure, intelligent, and community-driven carpooling."**

Ridify is a full-stack ride-sharing platform designed to make transportation more affordable, sustainable, and convenient. Users can either offer available seats in their vehicles or discover rides traveling along similar routes.

The platform combines real-time tracking, intelligent ride matching, secure communication, and comprehensive administrative controls to create a modern carpooling ecosystem that prioritizes safety, reliability, and user experience.

By encouraging ride sharing, Ridify helps reduce travel expenses, traffic congestion, parking demand, and environmental impact while fostering stronger community connections among commuters.

---

## 🎯 Project Objectives

- Provide an affordable alternative to traditional ride-hailing services.
- Encourage sustainable transportation through ride sharing.
- Improve safety using verification and administrative moderation.
- Deliver real-time ride visibility and communication.
- Create a seamless user experience through modern mobile design.

---

## ✨ Core Features

### 🚗 Intelligent Ride Matching

Ridify leverages MongoDB Geospatial Queries and Turf.js route analysis to match riders and drivers whose journeys naturally overlap.

**Key Benefits**
- Route-based matching
- Minimal driver detours
- Distance filtering
- Efficient ride discovery

---

### 📍 Real-Time Location Tracking

Using Socket.IO WebSockets, Ridify continuously synchronizes GPS coordinates between riders and drivers.

**Features**
- Live vehicle tracking
- Dynamic ETA calculations
- Arrival notifications
- Smooth map animations

---

### 💬 Secure In-App Messaging

Built-in real-time chat enables riders and drivers to coordinate pickups and communicate without sharing personal contact information.

---

### 🛡️ Safety & Verification

Ridify prioritizes community safety through:

- Email Verification
- JWT Authentication
- Password Hashing (bcrypt)
- User Verification
- Administrative Monitoring
- Account Suspension Controls

---

### 👨‍💼 Administrative Dashboard

Administrators can:

- Monitor active rides
- Verify user documents
- Manage user accounts
- Review ride activity
- Moderate platform operations

---

### 🌗 Modern User Experience

- Dark Mode Support
- Light Mode Support
- Glassmorphism UI
- Responsive Design
- Custom Animations
- Modern Flutter Components

---

### 📊 Analytics & Travel History

Users gain access to:

- Ride History
- Cost Summaries
- Passenger Records
- Journey Statistics
- Travel Insights

---

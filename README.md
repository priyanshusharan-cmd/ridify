<div align="center">

<img src="frontend/assets/icon.png" alt="Ridify Logo" width="120" />

# 🚗 Ridify

### **Real-time ride-sharing, reimagined for students.**  
*Offer a seat, find a ride, track it live, and split the cost — all in one seamless experience.*

[![License: MIT](https://img.shields.io/badge/License-MIT-F1C40F?style=for-the-badge&logo=opensourceinitiative&logoColor=white)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-Express-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
[![MongoDB](https://img.shields.io/badge/MongoDB-Atlas-47A248?style=for-the-badge&logo=mongodb&logoColor=white)](https://mongodb.com)
[![Socket.IO](https://img.shields.io/badge/Socket.IO-4.x-010101?style=for-the-badge&logo=socket.io&logoColor=white)](https://socket.io)

</div>

---

## 🚀 Key Features

Ridify is designed to make commuting easier, safer, and more social. Here’s what makes it stand out:

- 🚘 **Flexible Ride Offering** — Post journeys with custom vehicle types, available seats, and transparent fares.
- 🔍 **Smart Ride Discovery** — Find the perfect ride based on your location, schedule, and vehicle preference.
- ⚡ **Instant Matching** — Connect with drivers and passengers instantly via real-time Socket.IO events.
- 🗺️ **Live Map Tracking** — Watch your ride approach in real-time with integrated OpenStreetMap & GPS tracking.
- 💬 **Integrated Group Chat** — Coordinate pickup details and socialize with your ride group before and during the journey.
- 💰 **Financial Dashboard** — Track your total earnings as a driver or your savings as a passenger at a glance.
- 🛡️ **Admin Suite** — Robust management tools for data cleanup and user moderation, protected by secure middleware.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| **Mobile App** | **Flutter (Dart)** — Cross-platform experience with `shared_preferences` persistence |
| **Backend API** | **Node.js & Express.js** — High-performance RESTful architecture |
| **Real-time Engine** | **Socket.IO** — Bidirectional low-latency communication for tracking and chat |
| **Database** | **MongoDB Atlas** — Scalable NoSQL storage with Mongoose ODM |
| **Maps & Tracking** | **OpenStreetMap & OSRM** — Seamless live location tracking and routing |
| **Security** | **Bcrypt** — Industry-standard password hashing (10 salt rounds) |

---

## 🔐 Security & Authentication

We believe security shouldn't compromise simplicity:

- **Bcrypt Hashing** — Every password is cryptographically hashed using salting. Plain-text is never stored in the database.
- **Secure Email Auth** — Strict validation on both client and server ensures only legitimate accounts are created.
- **Persistent Sessions** — A frictionless login experience that remembers you securely across app restarts.
- **Admin Shield** — Critical data management routes are protected by role-based access control (RBAC) middleware.

---

## 📸 Experience Ridify

> *A complete walkthrough of the Ridify ecosystem, featuring 20 unique states across the Passenger and Driver journeys, live routing, and real-time data sync.*

### 🚪 Authentication & User Hub
| Login & Registration | Profile & History |
|:---:|:---:|
| **Login**<br><img src="frontend/assets/screenshots/login.jpg" alt="Login" width="250"> | **Signup**<br><img src="frontend/assets/screenshots/signup.jpg" alt="Signup" width="250"> |
| **User Profile**<br><img src="frontend/assets/screenshots/profile.jpg" alt="Profile" width="250"> | **Ride History**<br><img src="frontend/assets/screenshots/rideHistory.jpg" alt="History" width="250"> |

### 💰 Dynamic Dashboards
| Initial State | Active State |
|:---:|:---:|
| **New Dashboard**<br><img src="frontend/assets/screenshots/home.jpg" alt="Home" width="250"> | **Earnings & Spending**<br><img src="frontend/assets/screenshots/toatalEarning&Spending.jpg" alt="Earnings" width="250"> |

### 🚘 The Marketplace
| Passenger Search | Driver Hosting |
|:---:|:---:|
| **Search Form**<br><img src="frontend/assets/screenshots/findRide.jpg" alt="Find Ride" width="250"> | **Create Listing**<br><img src="frontend/assets/screenshots/offerRide.jpg" alt="Offer Ride" width="250"> |
| **Available Rides**<br><img src="frontend/assets/screenshots/availableRides.jpg" alt="Available Rides" width="250"> | **Driver Match Requests**<br><img src="frontend/assets/screenshots/matchRequest.jpg" alt="Match Request" width="250"> |
| **Request Processing**<br><img src="frontend/assets/screenshots/matchStatus.jpg" alt="Match Status" width="250"> | **Ongoing Activity**<br><img src="frontend/assets/screenshots/activity.jpg" alt="Activity" width="250"> |

### 📱 Live Journey: Passenger Perspective
| Approaching | Boarded |
|:---:|:---:|
| **Driver Arriving**<br><img src="frontend/assets/screenshots/liveTrackingScreen.jpg" alt="Driver Arriving" width="250"> | **You're In!**<br><img src="frontend/assets/screenshots/liveTrackingScreen5.jpg" alt="Boarded" width="250"> |

### 🚗 Live Journey: Driver Perspective & Chat
| Route Management | Communication |
|:---:|:---:|
| **Waiting for Passengers**<br><img src="frontend/assets/screenshots/liveTrackingScreen2.jpg" alt="Waiting" width="250"> | **Ride In Progress**<br><img src="frontend/assets/screenshots/liveTrackingScreen4.jpg" alt="In Progress" width="250"> |
| **Ready to End**<br><img src="frontend/assets/screenshots/liveTrackingScreen3.jpg" alt="Ready to End" width="250"> | **Socket.IO Live Chat**<br><img src="frontend/assets/screenshots/chatScreen.jpg" alt="Chat" width="250"> |

### 🏁 Ride Completion
| Driver Success | Passenger Success |
|:---:|:---:|
| **Driver Completion**<br><img src="frontend/assets/screenshots/rideCompletedDriverScreen.jpg" alt="Driver Done" width="250"> | **Rider Completion**<br><img src="frontend/assets/screenshots/rideCompletedRiderScreen.jpg" alt="Rider Done" width="250"> |

---

## ⚙️ Installation & Setup

### 📦 Prerequisites
* **Flutter SDK** (`^3.x`)
* **Node.js** (`^18.x`)
* **MongoDB Atlas** connection string

### 🖥️ Backend Setup
```bash
# Navigate to backend directory
cd backend

# Create your environment file
cp .env.example .env   # Update with your MONGO_URI and ADMIN_EMAILS

# Install dependencies and start
npm install
npm start
```

### 📱 Frontend Setup
```bash
# Navigate to frontend directory
cd frontend

# Install Flutter dependencies
flutter pub get

# Launch the app
flutter run
```

---

## 📄 License
This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

## 👤 Author
**Priyanshu Sharan**  
[![GitHub](https://img.shields.io/badge/GitHub-Profile-181717?style=flat&logo=github&logoColor=white)](https://github.com/priyanshusharan-cmd)

<div align="center">
  <sub>Built with ❤️ as a real-world solution for student mobility.</sub>
</div>

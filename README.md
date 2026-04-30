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

> *Below are placeholders for the major screens within the Ridify application.*

| Login & Home | Discovery & Posting |
|---|---|
| **Login Screen**<br>![Login Screen]() | **Home Screen**<br>![Home Screen]() |
| **Find Ride Screen**<br>![Find Ride Screen]() | **Offer Ride Screen**<br>![Offer Ride Screen]() |

| Tracking & Status | Communication |
|---|---|
| **Active Rides**<br>![Active Rides]() | **Match Request/Status**<br>![Match Request/Status]() |
| **In-ride Chat**<br>![In-ride Chat]() | **Live Map Tracking**<br>![Live Map Tracking]() |

| History & Profile | Administration |
|---|---|
| **Ride History**<br>![Ride History]() | **Profile Screen**<br>![Profile Screen]() |
| **Admin Controls**<br>![Admin Controls]() | |

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

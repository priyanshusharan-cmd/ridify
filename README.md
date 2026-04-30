# 🚗 Ridify

> **Real-time ride-sharing for students.** Offer a ride, find a ride, track it live on a map, and split the cost — all from one app.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-Express-green?logo=node.js)](https://nodejs.org)
[![MongoDB](https://img.shields.io/badge/MongoDB-Atlas-green?logo=mongodb)](https://mongodb.com)
[![Socket.IO](https://img.shields.io/badge/Socket.IO-4.x-black?logo=socket.io)](https://socket.io)

---

## ✨ Features

- **Offer a Ride** — Post your journey with vehicle type, seats, fare per seat, and departure time
- **Find a Ride** — Search for available rides by location, date, and seats needed
- **Real-time Matching** — Drivers accept/decline passenger requests instantly via Socket.IO
- **Live Map Tracking** — See the driver's location in real-time using OpenStreetMap & flutter_map
- **In-ride Chat** — Communicate with your ride group during the journey
- **Ride History** — View all past completed, cancelled, or declined rides
- **Financial Dashboard** — Track total earnings (as driver) and total spending (as passenger)
- **Profile Management** — Edit name, age, and email; delete account

---

## 🗂️ Project Structure

```
ridify/
├── backend/          # Node.js + Express + Socket.IO + MongoDB API
│   ├── models/       # Mongoose schemas (User, Ride)
│   ├── server.js     # Main server entry point
│   └── .env          # Environment variables (NOT committed)
├── frontend/         # Flutter mobile app
│   ├── lib/
│   │   ├── screens/  # All app screens
│   │   ├── widgets/  # Reusable widgets
│   │   ├── constants.dart  # API base URL config
│   │   └── utils.dart      # Shared utility functions
│   └── assets/       # App icon and images
└── README.md
```

---

## 🛠️ Tech Stack

| Layer     | Technology                          |
|-----------|-------------------------------------|
| Frontend  | Flutter (Dart)                      |
| Backend   | Node.js, Express.js                 |
| Database  | MongoDB (via Mongoose)              |
| Real-time | Socket.IO                           |
| Maps      | flutter_map + OpenStreetMap + OSRM  |
| Hosting   | Render (backend)                    |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `^3.x`
- [Node.js](https://nodejs.org/) `^18.x`
- MongoDB connection string (Atlas or local)

### Backend Setup

```bash
cd backend
cp .env.example .env        # Add your MONGO_URI
npm install
npm start
```

### Frontend Setup

```bash
cd frontend
flutter pub get
flutter run
```

> **Note:** Update `lib/constants.dart` with your backend URL before running.

---

## 🔒 Environment Variables

Create a `backend/.env` file with:

```env
MONGO_URI=your_mongodb_connection_string_here
PORT=5001
```

⚠️ **Never commit `.env` to version control.** It is already ignored in `.gitignore`.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Priyanshu Sharan**  
[GitHub](https://github.com/priyanshusharan-cmd)

---

*Built with ❤️ as a real-world ride-sharing solution.*

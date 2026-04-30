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
- **Persistent Login** — Stay logged in across app restarts; session cleared on logout
- **Email OTP Signup** — Verify your email with a 4-digit OTP before creating an account
- **Admin Controls** — Role-based trash/delete features protected by backend middleware

---

## 🔐 Security & Authentication

### Persistent Login
Once you log in, your session (name, age, email) is stored locally via `shared_preferences`. On the next app open, the app reads this session and navigates directly to the Home screen — no need to log in again.

Logging out (or deleting your account) clears this session, forcing a return to the Login screen on next launch.

---

### Bcrypt Password Hashing
All passwords are hashed with **bcrypt (10 salt rounds)** before being stored in MongoDB. Plain-text passwords are never saved. Login uses `bcrypt.compare()` for secure verification.

---

### Admin Shield (Role-Based Access)
Admin emails are defined in the backend `.env` as `ADMIN_EMAILS` (comma-separated). All sensitive delete routes are protected by an `adminOnly` middleware that checks the `x-admin-email` request header.

| Action | Route | Protection |
|--------|-------|------------|
| Wipe all rides | `DELETE /api/rides` | `adminOnly` middleware |
| Wipe all users | `DELETE /api/auth/users` | `adminOnly` middleware |

In the Flutter app, the trash icons are **conditionally rendered** — only visible if the logged-in user's email is in `kAdminEmails`:

- **Home Screen** → Trash icon wipes all ride data (with confirmation dialog).
- **Profile Screen** → "Admin: Wipe All Users" button wipes all accounts and **auto-logs out** the admin.

![Screenshot — Admin Trash Icon (Home Screen)]()

![Screenshot — Admin Confirmation Dialog]()

![Screenshot — Profile Screen Admin Button]()

---

## 🗂️ Project Structure

```
ridify/
├── backend/          # Node.js + Express + Socket.IO + MongoDB API
│   ├── server.js     # Main server entry point (OTP, bcrypt, admin middleware)
│   └── .env          # Environment variables (NOT committed — see below)
├── frontend/         # Flutter mobile app
│   ├── lib/
│   │   ├── screens/  # All app screens
│   │   ├── widgets/  # Reusable widgets
│   │   ├── constants.dart  # API base URL + kAdminEmails
│   │   └── utils.dart      # Shared utility functions
│   └── assets/       # App icon and images
└── README.md
```

---

## 🛠️ Tech Stack

| Layer        | Technology                          |
|--------------|-------------------------------------|
| Frontend     | Flutter (Dart) + shared_preferences |
| Backend      | Node.js, Express.js                 |
| Database     | MongoDB (via Mongoose)              |
| Real-time    | Socket.IO                           |
| Maps         | flutter_map + OpenStreetMap + OSRM  |
| Email / OTP  | Nodemailer (Gmail SMTP)             |
| Auth         | bcrypt password hashing             |
| Hosting      | Render (backend)                    |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `^3.x`
- [Node.js](https://nodejs.org/) `^18.x`
- MongoDB connection string (Atlas or local)
- A Gmail account with an **App Password** enabled (for OTP emails)

### Backend Setup

```bash
cd backend
cp .env.example .env        # Fill in your values
npm install
npm start
```

### Frontend Setup

```bash
cd frontend
flutter pub get
flutter run
```

> **Note:** Update `lib/constants.dart` with your backend URL and admin emails before running.

---

## 🔒 Environment Variables

Create a `backend/.env` file with:

```env
PORT=5001
MONGO_URI=your_mongodb_connection_string_here
EMAIL_USER=your_gmail_address@gmail.com
EMAIL_PASS=your_gmail_app_password
ADMIN_EMAILS=admin1@example.com,admin2@example.com
```

⚠️ **Never commit `.env` to version control.** It is already ignored in `.gitignore`.

---

## 📸 Screenshots

> Drop your screenshots below by replacing the empty image links.

![Screenshot 1 — Login Screen]()

![Screenshot 2 — Signup with OTP]()

![Screenshot 3 — Home Screen]()

![Screenshot 4 — Active Rides]()

![Screenshot 5 — Live Map Tracking]()

![Screenshot 6 — In-ride Chat]()

![Screenshot 7 — Ride History]()

![Screenshot 8 — Profile Screen]()

![Screenshot 9 — Admin Controls]()

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Priyanshu Sharan**  
[GitHub](https://github.com/priyanshusharan-cmd)

---

*Built with ❤️ as a real-world ride-sharing solution.*

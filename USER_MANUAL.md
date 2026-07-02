<div align="center">

<img src="frontend/assets/icon.png" alt="Ridify Logo" width="120"/>

# Ridify — Comprehensive User Manual

### Version 1.0 · July 2026

**Real-time peer-to-peer ride-sharing & cost-splitting — built for everyone.**

</div>

---

> **About this manual**
>
> This document is the single authoritative reference for every feature, workflow, and technical detail in the Ridify application. It is structured so that **casual users** can jump straight to the [Quick-Start Guide](#part-i-quick-start-guide-5-minutes) and start using the app immediately, while **power users, developers, and administrators** can find exhaustive technical detail in the later parts.
>
> Screenshots referenced throughout correspond to both **Light** and **Dark** theme variants.

---

## Table of Contents

### Part I — Quick-Start Guide
1. [Quick-Start Guide (5 minutes)](#part-i-quick-start-guide-5-minutes)

### Part II — Detailed User Guide
2. [Introduction to Ridify](#chapter-1-introduction-to-ridify)
3. [Installation & Device Requirements](#chapter-2-installation--device-requirements)
4. [Account Registration & Authentication](#chapter-3-account-registration--authentication)
5. [Your Profile & Identity Verification (KYC)](#chapter-4-your-profile--identity-verification-kyc)
6. [The Home Screen — Your Command Center](#chapter-5-the-home-screen--your-command-center)

### Part III — Rider's Handbook
7. [Finding a Ride](#chapter-6-finding-a-ride)
8. [Browsing & Filtering Available Rides](#chapter-7-browsing--filtering-available-rides)
9. [Joining a Ride & Cost-Splitting](#chapter-8-joining-a-ride--cost-splitting)
10. [The Live Ride Experience (Rider Perspective)](#chapter-9-the-live-ride-experience-rider-perspective)
11. [Trip Completion & Payment (Rider)](#chapter-10-trip-completion--payment-rider)

### Part IV — Driver's Handbook
12. [Offering a Ride](#chapter-11-offering-a-ride)
13. [Managing Join Requests](#chapter-12-managing-join-requests)
14. [Starting & Managing the Trip](#chapter-13-starting--managing-the-trip)
15. [Trip Completion & Earnings (Driver)](#chapter-14-trip-completion--earnings-driver)
16. [Driver Statistics Dashboard](#chapter-15-driver-statistics-dashboard)

### Part V — Communication & Social
17. [In-App Chat System](#chapter-16-in-app-chat-system)
18. [Activity Feed & Ride History](#chapter-17-activity-feed--ride-history)
19. [Co-Passengers & Community](#chapter-18-co-passengers--community)

### Part VI — Administration
20. [Admin Panel Overview](#chapter-19-admin-panel-overview)
21. [User Management & Moderation](#chapter-20-user-management--moderation)
22. [Ride Monitoring & Force Controls](#chapter-21-ride-monitoring--force-controls)
23. [KYC Document Verification Workflow](#chapter-22-kyc-document-verification-workflow)
24. [Platform Statistics Dashboard](#chapter-23-platform-statistics-dashboard)

### Part VII — Technical Deep Dive
25. [System Architecture Overview](#chapter-24-system-architecture-overview)
26. [Authentication & Token System](#chapter-25-authentication--token-system)
27. [Database Schema Reference](#chapter-26-database-schema-reference)
28. [The Ride Lifecycle State Machine](#chapter-27-the-ride-lifecycle-state-machine)
29. [The Sweep-Line Matching Algorithm](#chapter-28-the-sweep-line-matching-algorithm)
30. [Real-Time Communication (Socket.IO)](#chapter-29-real-time-communication-socketio)
31. [REST API Reference](#chapter-30-rest-api-reference)
32. [Security Architecture](#chapter-31-security-architecture)
33. [Rate Limiting & Abuse Prevention](#chapter-32-rate-limiting--abuse-prevention)

### Part VIII — Policies & Legal
34. [Terms of Service](#chapter-33-terms-of-service)
35. [Privacy Policy](#chapter-34-privacy-policy)
36. [Community Guidelines](#chapter-35-community-guidelines)
37. [Data Retention & Deletion](#chapter-36-data-retention--deletion)

### Part IX — Reference
38. [Troubleshooting Guide](#chapter-37-troubleshooting-guide)
39. [Frequently Asked Questions (FAQ)](#chapter-38-frequently-asked-questions-faq)
40. [Glossary of Terms](#chapter-39-glossary-of-terms)
41. [Contact & Support](#chapter-40-contact--support)

---

---

# Part I: Quick-Start Guide (5 minutes)

> **This section is designed for users who want to get on the road immediately.** Read this, and you'll be sharing rides within minutes. For in-depth explanations of every feature, see Parts II through IX.

### For Riders — Find a Ride in 4 Steps

| Step | What to Do |
|------|------------|
| **1. Sign Up** | Open Ridify → Tap **Sign Up** → Enter your email → Receive a 6-digit OTP → Enter OTP → Set your name and password. Done! |
| **2. Find a Ride** | From the Home Screen, tap **Find a Ride** → Pick your **Pickup** and **Drop-off** locations on the map → Set date & time → Tap **Search**. |
| **3. Join a Ride** | Browse the available rides → Tap a ride card to view details → Review the fare → Tap **Join Ride** → Wait for the driver to accept. |
| **4. Track & Ride** | Once accepted, track the driver live on the map → Get in when they arrive → Enjoy the ride → Pay the displayed fare at the end. |

### For Drivers — Offer a Ride in 4 Steps

| Step | What to Do |
|------|------------|
| **1. Verify Your Identity** | Go to **Profile** → Tap **Verify Identity** → Upload your government ID → Wait for admin approval (usually within 24 hours). |
| **2. Offer a Ride** | From the Home Screen, tap **Offer a Ride** → Set your route on the map → Choose vehicle type, seats, fare, and departure time → Tap **Publish**. |
| **3. Manage Requests** | Review incoming rider requests → Tap **Accept** or **Decline** for each one. |
| **4. Drive & Complete** | Tap **Start Ride** → Pick up passengers → Mark them as **Boarded** → Drive to destination → Tap **End Trip**. |

**That's it!** For everything else — chat, history, admin tools, how the algorithm works — keep reading.

---

---

# Part II: Detailed User Guide

---

## Chapter 1: Introduction to Ridify

### 1.1 What is Ridify?

Ridify is a **production-grade, real-time ride-sharing and cost-splitting application** that connects drivers who have empty seats with riders heading in the same direction. Unlike traditional ride-hailing services (where a dedicated driver picks you up), Ridify is **peer-to-peer** — meaning any user can both offer and find rides.

The core philosophy is simple: if you're already driving somewhere, why not share the ride and split the cost? This reduces individual travel expenses, decreases traffic congestion, and lowers carbon emissions.

### 1.2 What Makes Ridify Different?

| Feature | How Ridify Does It |
|---------|-------------------|
| **Real-Time Tracking** | Live GPS tracking of the driver on an interactive OpenStreetMap, updated every 1.5 seconds via WebSocket. |
| **Smart Route Matching** | A sweep-line geometry algorithm analyzes the driver's entire route polyline to find riders whose pickup and drop-off points fall along the path — not just a simple "point A to point B" match. |
| **Fair Cost Splitting** | Fares are calculated proportionally based on the distance each rider actually travels along the driver's route. If you're only riding half the route, you pay roughly half the fare. |
| **Flexible Capacity** | The sweep-line algorithm allows different riders to occupy the same seat on different segments of the route. A rider who gets off at Point B frees a seat for another rider who boards at Point B. |
| **Instant Communication** | Built-in per-ride group chat via Socket.IO — no need to exchange phone numbers. |
| **Verified Community** | KYC verification with government ID upload, admin review, and ban controls. |
| **Admin Oversight** | A full administrative panel for platform moderators to monitor rides, manage users, and review verification documents. |

### 1.3 Key Concepts

Before diving into the app, it helps to understand these core concepts:

**Roles:**
- **Rider** — A user who is looking for a ride. Riders search for available rides, request to join, and contribute to the fare.
- **Driver** — A user who offers a ride. Drivers set the route, vehicle type, number of seats, departure time, and the total fare for the full journey.
- **Co-Passenger** — Once a rider is accepted by a driver, they become a co-passenger. All accepted riders on the same trip are co-passengers of each other.
- **Admin** — A platform moderator with elevated access. Admins can manage users, monitor active rides, verify identity documents, and enforce community guidelines.

**Ride Terminology:**
- **Route Path** — The complete polyline of GPS coordinates representing the driver's planned journey from start to finish. This is generated using the OSRM (Open Source Routing Machine) when the driver creates a ride.
- **Segment** — A portion of the route path. When a rider joins a ride, they occupy a specific segment defined by their pickup index (where they board) and drop-off index (where they exit).
- **Fare Split** — The proportional share of the total fare that each rider pays, based on the fraction of the total route distance they are traveling.
- **Sweep-Line** — The algorithm Ridify uses to check seat availability. Rather than just counting total passengers, it analyzes which seats are occupied at every point along the route, allowing overlapping segments as long as the vehicle's physical capacity is never exceeded.

**Ride Statuses:**
- `available` — The ride is published and open for requests.
- `accepted` — At least one rider has been accepted.
- `full` — Every seat on every segment of the route is occupied.
- `started` — The driver has begun the journey.
- `completed` — The trip is finished and all passengers have been dropped off.
- `cancelled` — The ride has been cancelled by the driver, admin, or system.

---

## Chapter 2: Installation & Device Requirements

### 2.1 Supported Platforms

| Platform | Support Status |
|----------|---------------|
| Android 10.0+ | ✅ Fully Supported |
| iOS | 🔜 Planned for future release |
| Web (Flutter Web) | ⚠️ Admin panel only |

### 2.2 Minimum Device Requirements

| Requirement | Specification |
|-------------|--------------|
| Operating System | Android 10.0 (API 29) or higher |
| RAM | 2 GB minimum, 4 GB recommended |
| Storage | 150 MB free space for app installation |
| GPS | Required — high-accuracy mode recommended |
| Internet | Active Wi-Fi or mobile data connection required |
| Google Play Services | Required for location services |

### 2.3 Permissions Required

When you first open Ridify, you'll be asked to grant the following permissions:

| Permission | Why It's Needed |
|-----------|----------------|
| **Location (Precise)** | To show your current position on the map and enable live tracking during rides. |
| **Location (Background)** | Required for drivers to continue broadcasting their position when the app is minimized during a ride. |
| **Internet** | To communicate with the Ridify backend server and receive real-time updates. |
| **Camera** (optional) | For uploading your government ID photo during KYC verification. |
| **Storage** (optional) | For selecting a pre-existing photo for KYC upload. |

### 2.4 Installing the App

1. Download the Ridify APK or install from the app distribution platform your organization uses.
2. If installing via APK, enable "Install from unknown sources" in your device settings.
3. Open the installer and follow the on-screen prompts.
4. Once installed, launch Ridify.

---

## Chapter 3: Account Registration & Authentication

### 3.1 How Ridify Authentication Works

Ridify uses a **dual authentication system** combining traditional passwords with One-Time Passwords (OTPs) for enhanced security:

- **Sign-Up:** Requires email, name, password, and a one-time OTP for email verification.
- **Login:** Supports both password-based login and passwordless OTP-based login.
- **Session Management:** After logging in, Ridify issues a short-lived JWT access token (15 minutes) and a long-lived refresh token (7 days). The app silently refreshes your access token in the background — you should rarely need to log in again.
- **Token Storage:** All tokens are stored in encrypted device storage using `flutter_secure_storage`, ensuring they cannot be accessed by other apps on your device.

### 3.2 Creating a New Account (Sign Up)

1. **Open Ridify.** You will see the animated Splash Screen, followed by the Login page.
2. Tap **"Don't have an account? Sign Up"** at the bottom of the Login screen.
3. **Enter your email address.**
   - If your organization has configured an allowed email domain (e.g., only `@university.edu`), you must use an email from that domain.
   - The system checks if the email is already registered. If so, you'll be prompted to log in instead.
4. **Tap "Send OTP."**
   - A 6-digit OTP is generated and sent to your email via the EmailJS service.
   - The OTP is valid for **10 minutes**.
   - If you already requested an OTP within the last 10 minutes, you'll see a cooldown message.
5. **Enter the OTP** you received in your email inbox.
6. **Fill in your profile details:**
   - **Full Name** (required, max 500 characters)
   - **Age** (optional, max 3 digits)
   - **Password** (required, minimum 8 characters)
7. **Tap "Register."**
   - If successful, your account is instantly created and verified.
   - You are automatically logged in and taken to the Home Screen.
   - Your access and refresh tokens are securely stored on your device.

### 3.3 Logging In

#### Method A: Password Login
1. Open Ridify and enter your registered **email** and **password**.
2. Tap **Login**.
3. If your credentials are correct, you'll be taken to the Home Screen.

#### Method B: OTP Login (Passwordless)
1. Open Ridify and enter your registered **email**.
2. Tap **"Login with OTP"**.
3. A SHA-256 hashed OTP is generated and sent to your email.
4. Enter the OTP (valid for 10 minutes).
5. You'll be logged in without needing your password.

**Security Notes:**
- After 5 incorrect OTP attempts, the OTP is invalidated and you must request a new one.
- If your account has been **banned** by an admin, you will see a "Your account has been suspended" message and will not be able to log in.

### 3.4 Changing Your Password

1. Navigate to **Profile** → **Change Password**.
2. Enter your **current password** and your **new password** (minimum 8 characters).
3. Tap **Update Password**.
4. **Important:** Changing your password invalidates all existing refresh tokens across all devices. You will be logged out everywhere except the current device.

### 3.5 Logging Out

1. Navigate to **Profile** → **Logout**.
2. Your refresh token is revoked on the server, preventing further use.
3. All locally stored tokens are cleared from encrypted storage.

### 3.6 Session Expiry & Silent Refresh

- Your access token expires every **15 minutes**.
- When it expires, the app automatically sends your refresh token to `/api/auth/refresh` to obtain a new access token.
- This process is completely invisible to you — you don't need to do anything.
- Your refresh token is valid for **7 days**. If you don't open the app for more than 7 days, you'll need to log in again.

---

## Chapter 4: Your Profile & Identity Verification (KYC)

### 4.1 Viewing and Editing Your Profile

Your profile is accessible via the **Profile** tab in the bottom navigation bar. Here you can see and manage:

| Field | Editable? | Details |
|-------|----------|---------|
| **Full Name** | ✅ Yes | Tap to update. Max 200 characters. Your name is displayed to co-passengers and drivers. |
| **Age** | ✅ Yes | Optional. Max 3 digits. |
| **Email** | ❌ No | Your email serves as your unique identifier across the platform and cannot be changed. |
| **Verification Status** | ❌ No (managed by admin) | Shows `Not Verified`, `Pending`, or `Verified`. |

When you update your name, the change is **automatically cascaded** to all your active rides, chat messages, and rider detail records. Other users will see your updated name immediately.

### 4.2 Understanding KYC Verification

KYC (Know Your Customer) is an identity verification process that enhances trust and safety within the Ridify community. While it's not required to use the app as a rider, KYC verification builds trust with drivers and co-passengers.

### 4.3 Verification Statuses Explained

| Status | Badge | What It Means |
|--------|-------|--------------|
| **Not Verified** (`none`) | No badge | You have not submitted any verification documents. You can still use all app features. |
| **Pending** (`pending`) | ⏳ Yellow badge | You have submitted your ID and it is awaiting admin review. |
| **Verified** (`verified`) | ✅ Green badge | An admin has reviewed and approved your identity document. Other users can see you are verified. |

### 4.4 Submitting Your Identity Document

1. Navigate to **Profile** → **Verify Identity**.
2. Select or capture a photo of a valid, government-issued identification document. Acceptable documents include:
   - Driver's License
   - Passport
   - National ID Card
   - University/College ID (if configured by your organization)
3. Ensure the photo is:
   - **Clear and well-lit** — all text must be readable.
   - **Complete** — all four corners of the document must be visible.
   - **Not expired** — the document must be currently valid.
4. Tap **Upload**.

**Behind the scenes:**
- Your verification status is immediately set to `pending`.
- The document image is converted to Base64 and uploaded from the backend server to **Google Drive** via a Google Apps Script webhook.
- If the upload fails (e.g., network error), your status is reset to `none` and you can retry.
- The admin panel shows your submission in the **Pending Verifications** queue.

### 4.5 What Happens After Submission?

- An admin will review your document from the Admin Panel.
- If **approved**, your verification status changes to `verified` and a green badge appears next to your name in ride cards and detail screens. This status is also cascaded to all your active rides.
- If **rejected** (e.g., blurry photo, expired document), your status returns to `none` with your `idUrl` cleared. You can upload a new document.

### 4.6 Deleting Your Account

1. Navigate to **Profile** → **Delete Account**.
2. Confirm the deletion.
3. **What happens:**
   - Your user record is permanently deleted from the database.
   - All active rides where you are the driver are automatically **cancelled**.
   - All co-passengers and pending requesters on those rides are notified in real-time via Socket.IO.
   - Your pending requests on other users' rides are automatically removed.
   - This action is **irreversible**.

---

## Chapter 5: The Home Screen — Your Command Center

The Home Screen is the first thing you see after logging in. It is designed to give you instant access to the two primary actions:

### 5.1 Navigation Structure

The app uses a bottom navigation bar with the following tabs:

| Tab | Purpose |
|-----|---------|
| 🏠 **Home** | Access "Offer a Ride" and "Find a Ride" actions, view nearby activity. |
| 📋 **Activity** | View all your rides — upcoming, active, past, and cancelled. |
| 📜 **History** | Detailed ride history with co-passenger information. |
| 👤 **Profile** | Manage your profile, KYC, password, and account settings. |

### 5.2 Theme Support

Ridify supports both **Light** and **Dark** themes. The theme follows your device's system-level setting, providing a comfortable experience in any lighting condition. All screenshots in this manual show both variants.

### 5.3 Real-Time Connectivity

As soon as you open the Home Screen, the app establishes a **WebSocket connection** (Socket.IO) to the Ridify backend. This connection:
- Authenticates using your JWT token.
- Automatically joins you to rooms for all your active rides.
- Listens for real-time updates: new ride requests, acceptances, status changes, chat messages, and location updates.
- Reconnects automatically if your internet drops temporarily.

---

---

# Part III: Rider's Handbook

---

## Chapter 6: Finding a Ride

### 6.1 Starting a Search

1. From the Home Screen, tap **"Find a Ride"**.
2. You'll be taken to the **Find Ride Screen** where you need to specify:

| Field | Description | Required? |
|-------|------------|-----------|
| **Pickup Location** | Where you want to be picked up. | ✅ Yes |
| **Drop-off Destination** | Where you want to go. | ✅ Yes |
| **Date** | The date you want to travel. | ✅ Yes |
| **Time** | Your preferred departure time. | ✅ Yes |
| **Number of Seats** | How many seats you need (1–8). | ✅ Yes (default: 1) |
| **Vehicle Type Filter** | Filter by Bike, Sedan, SUV, or Any. | Optional |

### 6.2 Using the Location Picker

When you tap on either the Pickup or Destination field, the **Map Picker Screen** opens:

1. **The interactive map** (powered by `flutter_map` + OpenStreetMap) shows your current GPS position.
2. You can:
   - **Tap anywhere on the map** to select that point as your location.
   - **Use the search bar** at the top to type an address. This uses the **Nominatim** geocoding service to convert text addresses into GPS coordinates.
   - **Drag the map** to explore different areas and tap to pin your location.
3. Once satisfied with your selection, tap **Confirm**.
4. The app displays the address (reverse-geocoded from the selected coordinates) and saves the GPS coordinates for the search algorithm.

### 6.3 How the Search Algorithm Works

When you tap **Search**, the Ridify backend performs the following process:

1. **Query Active Rides:** The server fetches all rides with status `available` or `accepted` that haven't expired (checked against `expiresAt`).

2. **Apply Filters:**
   - If you selected a specific vehicle type (e.g., "Sedan"), only rides with that vehicle type are returned.
   - If you selected a specific date, only rides departing on that date are returned.
   - Rides are filtered by time window — your search time must be within 1 hour of the ride's departure time.

3. **Route Proximity Matching (The Core Algorithm):**
   For each remaining ride, the algorithm:
   - Takes the ride's **route polyline** (an array of GPS coordinates representing the driver's planned path).
   - Samples approximately 100 evenly-spaced points along the route for efficiency.
   - Measures the geographic distance from **your pickup point** to every sampled route point. The closest one becomes your potential pickup index.
   - Measures the geographic distance from **your destination point** to every sampled route point. The closest one becomes your potential drop-off index.
   - Checks if both distances are within the **search radius** (default: 2,000 meters, adjustable per deployment).
   - Critically checks that your **pickup index comes BEFORE your drop-off index** along the route — ensuring you're traveling in the same direction as the driver.

4. **Minimum Distance Check:** The calculated trip distance for your segment must be at least 1.5 km (configurable). This prevents trivially short ride matches.

5. **Route Preference Check:**
   - `flexible` — Your pickup and drop-off can be anywhere along the route.
   - `shared_start` — Your pickup must be near the start of the route (within the first 10% of route points).
   - `nonstop` — Your pickup must be near the start AND your drop-off near the end of the route.

6. **Capacity Check (Sweep-Line):** The algorithm verifies that the vehicle has enough available seats on the segment you'd be traveling. This uses the sweep-line algorithm (explained in [Chapter 28](#chapter-28-the-sweep-line-matching-algorithm)).

7. **Fare Calculation:** Your individual fare is calculated as:
   ```
   Your Fare = Total Fare × (Your Segment Distance / Total Route Distance)
   ```
   If your segment covers 99% or more of the route, you're charged the full fare to avoid rounding losses.

8. **Exclusion Filters:** The search automatically hides rides where:
   - You are the driver.
   - You have been declined or kicked from the ride.
   - You are already a passenger or have a pending request.

### 6.4 Understanding Search Results

The search returns a list of rides ranked by relevance. Each result includes computed data:
- `computedFare` — Your calculated fare for this specific segment.
- `computedDistance` — The distance you would travel.
- `startIndex` / `endIndex` — Your boarding and alighting points on the route.

---

## Chapter 7: Browsing & Filtering Available Rides

### 7.1 The Available Rides Screen

After searching, you're presented with a list of **Ride Cards**. Each card displays:

| Information | Description |
|------------|-------------|
| **Driver Name** | The name of the person offering the ride. A ✅ badge appears if they are KYC verified. |
| **Vehicle Type** | Bike 🏍, Sedan 🚗, or SUV 🚙. |
| **Departure Time** | When the driver plans to leave. |
| **Pickup Location** | The text address closest to your requested pickup. |
| **Destination** | The text address closest to your requested destination. |
| **Your Estimated Fare** | The calculated fare for your specific segment (not the total ride fare). |
| **Available Seats** | How many seats are still available. |
| **Route Preference** | Flexible, Shared Start, or Nonstop. |

### 7.2 Using Filters

Tap the **filter icon** at the top of the Available Rides screen to access sorting and filtering options:

| Filter | Options |
|--------|---------|
| **Vehicle Type** | Any, Bike, Sedan, SUV |
| **Sort By** | Lowest Price, Earliest Departure |

### 7.3 Real-Time Updates on the Search Screen

The Available Rides screen is **live**. While you're browsing:
- If a ride fills up, it disappears from your list in real-time.
- If a ride is cancelled by the driver, it's removed.
- If new rides are published matching your criteria, they appear automatically.
- This is powered by the `global_search_room` Socket.IO room that your device joins while viewing search results.

---

## Chapter 8: Joining a Ride & Cost-Splitting

### 8.1 Viewing Ride Details

Tap on any ride card to open the **Ride Details Screen**. Here you'll find:

- **Route Map:** A visual representation of the driver's full route on the map, with your pickup and drop-off points highlighted.
- **Driver Profile:** Name, verification badge, and profile picture.
- **Co-Passengers:** List of other riders who have already been accepted.
- **Fare Breakdown:**
  - Total ride fare (set by the driver).
  - Your computed fare (proportional to your segment distance).
  - Number of seats you're requesting.
- **Departure Details:** Date, time, and the driver's starting location.

### 8.2 Requesting to Join

1. Review all the details on the Ride Details screen.
2. Tap **"Request to Join"** (or "Join Ride").
3. The app sends your request to the server with:
   - Your email (from your authenticated session — never from client input).
   - Your name (fetched fresh from the database).
   - The number of seats you need.
   - Your pickup and drop-off coordinates and their corresponding route indices.
4. **Server-Side Fare Recalculation:** The server independently recalculates your fare based on the route geometry. This prevents any client-side fare manipulation — even if someone tampered with the app, they'd still be charged the correct amount.
5. **Optimistic Locking:** The request uses optimistic locking with automatic retry (up to 5 attempts with random jitter). If another user is simultaneously requesting the same ride, the system resolves the conflict gracefully.
6. Once submitted, your request appears in the driver's pending requests list.

### 8.3 After Requesting

- Your ride status in the Activity tab changes to show a pending request.
- You're automatically joined to the ride's Socket.IO room, so you'll receive real-time updates.
- The driver receives a `new_ride_request` event and can accept or decline.

### 8.4 Understanding the Cost-Splitting Formula

The cost-splitting in Ridify is **distance-proportional**, not a simple equal split:

```
Rider's Fare = Total Fare × (Rider's Segment Distance / Total Route Distance)
```

**Example:**
- A driver publishes a 100 km ride from City A to City D with a total fare of ₹500.
- Rider 1 joins from City A to City B (first 30 km): Fare = ₹500 × (30/100) = **₹150**
- Rider 2 joins from City B to City D (last 70 km): Fare = ₹500 × (70/100) = **₹350**
- Both riders can be in the car simultaneously if their segments overlap, and seat availability is managed per-segment.

This system is fair because you only pay for the distance you actually travel.

### 8.5 Cancelling Your Request

If you change your mind before the driver accepts you:
1. Go to **Activity** → find the ride with your pending request.
2. Tap **Cancel Request**.
3. Your request is removed. If the driver hasn't seen it yet, it simply disappears. The ride's `cancelledRequests` array tracks this for history purposes.

---

## Chapter 9: The Live Ride Experience (Rider Perspective)

### 9.1 Waiting for Pickup

Once the driver accepts your request and starts the ride:
1. The **Live Tracking Screen** opens automatically (or you can access it from Activity).
2. You see an interactive map with:
   - **The driver's real-time position** — a moving car icon that updates every ~1.5 seconds via Socket.IO `driver_location_update` events.
   - **Your pickup point** — highlighted with a marker.
   - **Your drop-off point** — highlighted with a different marker.
   - **The full route** — drawn as a polyline on the map.
3. An info panel at the bottom shows the driver's name, vehicle type, and current ride status.

### 9.2 Driver Arrived at Your Pickup

When the driver arrives at your pickup location:
1. They mark **"Arrived"** in their app.
2. You receive a `driver_arrived` event and see a notification: "Your driver has arrived!"
3. The ride status panel updates to show "Driver is waiting at your pickup point."

### 9.3 Boarding the Vehicle

1. Meet the driver at the pickup point.
2. Verify the driver and vehicle (check the name, vehicle type displayed in the app).
3. Get into the vehicle.
4. The driver marks you as **"Boarded"** in their app.
5. You receive a `passenger_boarded` event and the map interface transitions to the "In Transit" view.

### 9.4 In Transit

While the ride is in progress:
- The map continues showing the driver's real-time position.
- You can monitor progress toward your drop-off point.
- You can use the **In-App Chat** to communicate with the driver and co-passengers.
- The estimated time of arrival updates dynamically based on the driver's position.

### 9.5 Arriving at Your Destination

When you reach your drop-off point:
1. The driver marks you as **"Dropped Off"**.
2. You receive a `passenger_dropped` event with your final fare.
3. The **Rider Completion Screen** appears, showing:
   - The trip summary (pickup, drop-off, distance traveled).
   - Your final fare amount.
   - A "Mark as Paid" button.

---

## Chapter 10: Trip Completion & Payment (Rider)

### 10.1 The Payment Model

Ridify currently operates on a **facilitated direct payment** model:
- The app **calculates** the exact fare each rider owes.
- The actual payment is made **directly between rider and driver** — cash, UPI, Venmo, Zelle, bank transfer, or any method both parties agree upon.
- The app does not process financial transactions.

### 10.2 Marking Payment as Complete

1. After being dropped off, you'll see your fare on the Rider Completion Screen.
2. Pay the driver the displayed amount using your preferred payment method.
3. Tap **"Mark as Paid"** in the app.
4. The server records your payment status and notifies the driver via Socket.IO.
5. **Important:** Only you can mark yourself as paid. The driver cannot mark payment on your behalf.

### 10.3 What If There's a Payment Dispute?

- If the rider leaves without paying, the system logs an `unpaidPassengers` entry when the ride ends.
- This is logged as a warning in the server logs: `Ride ${rideId} ended with N unpaid passenger(s)`.
- In future versions, a reputation system will track payment reliability.

---

---

# Part IV: Driver's Handbook

---

## Chapter 11: Offering a Ride

### 11.1 Prerequisites

To offer a ride, you need:
- A Ridify account (KYC verification is recommended but not strictly required in all deployments).
- A planned journey with a clear start and end point.

### 11.2 Creating a Ride Offer

1. From the Home Screen, tap **"Offer a Ride"**.
2. **Set Your Route:**
   - Tap **"Set Pickup"** to open the Map Picker and choose your starting location.
   - Tap **"Set Destination"** to choose your final destination.
   - The app calls the **OSRM (Open Source Routing Machine)** to calculate the optimal driving route between these two points.
   - The full route polyline is displayed on the map for your review.

3. **Configure Ride Details:**

   | Setting | Description | Constraints |
   |---------|-------------|-------------|
   | **Vehicle Type** | Bike, Sedan, or SUV. | Required. Determines what icon riders see. |
   | **Total Seats** | Number of available seats in your vehicle. | 1–8. |
   | **Total Fare** | The fare for the complete journey (start to end). | ₹1 to ₹9,999 (configurable). Individual riders pay proportionally based on distance. |
   | **Departure Date & Time** | When you plan to leave. | Must be in the future. Can be up to 7 days in advance. |
   | **Route Preference** | How flexible you are about pickup/drop-off locations. | See below. |

4. **Route Preferences Explained:**

   | Preference | Description |
   |-----------|-------------|
   | **Flexible** | Riders can board and alight at any point along your route. This maximizes the number of potential matches. Ideal for long-distance trips. |
   | **Shared Start** | Riders must board near the beginning of your route (within the first 10%). They can be dropped off anywhere. Good for daily commutes where everyone starts from the same area. |
   | **Nonstop** | Riders must board near the start AND be dropped off near the end. The most restrictive option — essentially only matches riders going the full distance with you. |

5. **Tap "Publish Ride."**

### 11.3 What Happens When You Publish

- Your ride is saved to the MongoDB database with all details.
- The route polyline is stored as an array of `{lat, lng}` coordinates.
- If your route has more than 500 points (the server limit), it is automatically downsampled while preserving the start and end points.
- Your ride immediately appears in search results for riders looking for rides along your route.
- You are joined to the ride's Socket.IO room for real-time updates.
- The ride has an automatic expiry: it expires **15 minutes after the departure time** you set.

### 11.4 Route Distance and Fare Calculation

- The total route distance is calculated using the Turf.js geospatial library, summing up the distances between consecutive route points.
- When a rider searches and finds your ride, their individual fare is computed as:
  ```
  Rider Fare = Your Total Fare × (Rider's Segment Distance / Your Total Route Distance)
  ```
- This is recalculated on the server — even if a malicious client sends a tampered fare, the server recomputes it independently.

---

## Chapter 12: Managing Join Requests

### 12.1 Receiving Requests

When a rider requests to join your ride:
1. You receive a real-time `new_ride_request` Socket.IO event.
2. The app shows a notification with the rider's name and their requested segment.
3. In the Ride Details screen, the pending request appears with:
   - Rider's name and verification status (Not Verified / Pending / Verified).
   - Their pickup and drop-off locations.
   - Number of seats they need.
   - Their computed fare.

### 12.2 Accepting a Rider

1. Tap **"Accept"** on the rider's request.
2. The server performs a final **sweep-line capacity check** to ensure the seat(s) are still available for the rider's segment.
3. If capacity is confirmed:
   - The rider moves from `requests` to `passengers`.
   - If this is the first accepted rider, the ride status changes from `available` to `accepted`.
   - All participants are notified via the `ride_accepted` Socket.IO event.
   - The rider is automatically joined to the ride's Socket.IO room.
4. **Auto-Decline on Full:** If accepting this rider causes other pending requests to no longer fit (capacity exceeded on overlapping segments), those conflicting requests are automatically declined and the affected riders are notified.
5. **Full Status:** If the vehicle is now completely full on every segment of the route, the ride status changes to `full` and it no longer appears in search results.

### 12.3 Declining a Rider

1. Tap **"Decline"** on the rider's request.
2. The rider is moved from `requests` to `declined`.
3. The declined rider receives a `ride_cancelled` event and is removed from the ride's Socket.IO room.
4. A declined rider **cannot re-request** the same ride — they will need to find another one.
5. If all requests and passengers are removed, the ride returns to `available` status.

### 12.4 Kicking a Passenger

If you need to remove an already-accepted passenger (before or during the ride):
1. In the Ride Details or Live Tracking screen, find the passenger you want to remove.
2. Tap **"Kick"**.
3. The passenger is removed from `passengers`, `boardedPassengers`, and `arrivedAt` lists.
4. Their `kickedAt` timestamp is recorded.
5. They receive a `passenger_kicked` event and are removed from the ride room.
6. Kicked passengers **cannot re-request** the same ride.
7. If the ride was `full`, removing a passenger changes the status back to `accepted`, and the ride reappears in search results.

### 12.5 Concurrency & Optimistic Locking

All request acceptance and rider management operations use **optimistic locking** to prevent race conditions:
- Every ride document has an `optimisticLock` version counter.
- When the server processes an accept/decline/kick, it includes the current lock version in the database update query.
- If another update happened in between (e.g., two admins acting simultaneously), the update fails and the system retries automatically (up to 5 times with random 20–100ms jitter).
- If all retries fail, you'll see a "Concurrent modification detected. Please retry." message.

---

## Chapter 13: Starting & Managing the Trip

### 13.1 Starting the Ride

When you're ready to begin your journey:
1. Open the ride from **Activity** or the Home Screen.
2. Tap **"Start Ride"**.
3. **What happens on the server:**
   - The ride status changes to `started`.
   - A `startedAt` timestamp is recorded.
   - All pending requests are **automatically declined** — the ride is no longer accepting new passengers.
   - Declined requesters receive a `ride_cancelled` event.
   - For `nonstop` and `shared_start` rides, all accepted passengers are immediately marked as "arrived at" (ready for boarding).
   - All participants receive a `ride_started` event.
   - The ride disappears from search results.
4. **Live location sharing begins.** Your GPS position is broadcast to all passengers every ~1.5 seconds via Socket.IO.

### 13.2 The Live Tracking Screen (Driver View)

As a driver, the Live Tracking Screen shows:
- Your current position on the map.
- The full route polyline.
- Markers for each passenger's pickup and drop-off points.
- A panel listing all passengers with their current status:
  - ⏳ **Waiting** — Accepted but not yet at their pickup.
  - 📍 **Arrived** — You've marked that you're at their pickup.
  - 🚗 **Boarded** — They're in the vehicle.
  - ✅ **Dropped Off** — They've been dropped at their destination.

### 13.3 Managing Passengers During the Trip

#### Marking "Arrived" at a Passenger's Pickup

1. When you reach a passenger's pickup location, tap **"Arrived"** next to their name.
2. **Behavior varies by route preference:**
   - **Flexible:** Only the specific passenger is marked as arrived.
   - **Nonstop / Shared Start:** All accepted passengers are marked as arrived simultaneously (since they all board at roughly the same point).
3. **Capacity check (flexible only):** The system checks that boarding this passenger won't exceed the vehicle's physical capacity at this moment (considering who is currently boarded).
4. The passenger receives a `driver_arrived` notification.

#### Boarding a Passenger

1. After the passenger gets into your vehicle, tap **"Board"** next to their name.
2. A `boardedAt` timestamp is recorded for the passenger.
3. The system performs a **physical capacity check** — the total seats currently occupied by boarded passengers plus the new boarding request must not exceed `totalSeats`.
4. The passenger is moved from the "arrived" list to the `boardedPassengers` list.
5. All participants receive a `passenger_boarded` event.

#### Dropping Off a Passenger

1. When you reach a passenger's destination, tap **"Drop Off"** next to their name.
2. The passenger must be currently **boarded** to be dropped off.
3. A `droppedAt` timestamp is recorded.
4. The passenger is moved from `boardedPassengers` and `passengers` to `droppedPassengers`.
5. The passenger receives a `passenger_dropped` event with their final fare.
6. They are removed from the ride's Socket.IO room.

### 13.4 Route Preference Behavior During the Trip

| Action | Flexible | Shared Start | Nonstop |
|--------|----------|-------------|---------|
| **Arrive** | Per-passenger | All passengers at once | All passengers at once |
| **Board** | Per-passenger | Per-passenger | Per-passenger |
| **Drop Off** | Per-passenger | Per-passenger | Per-passenger (or auto at end) |
| **End Ride** | Must drop off all first (or use Force End) | Auto-drops all remaining | Auto-drops all remaining |

---

## Chapter 14: Trip Completion & Earnings (Driver)

### 14.1 Ending the Trip

When all passengers have been dropped off:
1. Tap **"End Trip"**.
2. **For Nonstop / Shared Start rides:** All remaining active passengers (boarded or accepted) are automatically dropped off with timestamps.
3. **For Flexible rides:** You must drop off all passengers individually first. If any are still active, you'll see an error message: *"Cannot end trip. Passengers are still active."* You can use **Force End** (`force=true`) to auto-drop everyone.
4. The ride status changes to `completed` and a `completedAt` timestamp is recorded.
5. All participants receive a `ride_ended` event.

### 14.2 The Driver Completion Screen

After ending the trip, you see the **Driver Completion Screen** with:
- Trip summary: starting point, destination, total distance, total duration.
- List of all passengers who traveled, with their individual fares.
- Payment status for each passenger (Paid ✅ / Unpaid ❌).
- Any passengers who haven't marked payment will show as unpaid.

### 14.3 Understanding Earnings

Your total earnings for a ride = Sum of all passengers' individual fares.

Since fares are distance-proportional, if your total fare was ₹500 for a 100 km ride:
- Rider A traveled 30 km → Paid ₹150
- Rider B traveled 70 km → Paid ₹350
- **Your total earnings: ₹500** (matching the fare you set)

Note: In the current version, Ridify does not take a commission. The full fare goes to the driver.

---

## Chapter 15: Driver Statistics Dashboard

### 15.1 Accessing Your Stats

Go to **Profile** → **Driver Stats** (or the stats section on the Home Screen).

### 15.2 Available Metrics

| Metric | Description |
|--------|-------------|
| **Total Rides** | Number of completed rides where you were the driver. |
| **Total Distance (km)** | Sum of `totalDistance` across all your completed rides. |
| **Total Online Time (minutes)** | Sum of duration (`completedAt - startedAt`) for all completed rides. |

These stats are calculated via a MongoDB aggregation pipeline on the server and are always up-to-date.

---

---

# Part V: Communication & Social

---

## Chapter 16: In-App Chat System

### 16.1 Overview

Every ride has a dedicated **group chat room**. This allows the driver and all accepted co-passengers to communicate without exchanging personal phone numbers or social media accounts.

### 16.2 Who Can Chat?

| Role | Can Send Messages? |
|------|-------------------|
| Driver | ✅ Yes |
| Accepted Passenger | ✅ Yes |
| Boarded Passenger | ✅ Yes |
| Pending Requester | ❌ No |
| Declined/Kicked User | ❌ No |
| Dropped-Off Passenger | ❌ No (ride must still be active) |

### 16.3 Sending a Message

1. Open the ride from Activity or the Live Tracking Screen.
2. Tap the **Chat** icon.
3. Type your message (max 1,000 characters, configurable via `CHAT_MAX_LENGTH`).
4. Tap **Send**.

### 16.4 Message Features

| Feature | Description |
|---------|-------------|
| **Reply-to** | You can reply to a specific message. The reply includes the original sender's name and text. |
| **Real-time delivery** | Messages are delivered instantly via Socket.IO to all participants — both through the ride room and direct per-user emission for reliability. |
| **HTML sanitization** | All messages are stripped of HTML tags server-side using `sanitize-html` to prevent XSS attacks. |
| **Sender name** | The sender's name is always fetched fresh from the database — not from client input — preventing impersonation. |
| **Chat history** | Messages are stored in the ride document's `chatMessages` array (max 500 messages per ride). The full chat history is available when you open the chat screen. |
| **Offline resilience** | Messages are emitted to participants' personal socket rooms in addition to the ride room. This ensures delivery even if the user's ride room membership was lost due to a mobile data NAT timeout. |

### 16.5 Chat Limitations

- Chat is **disabled** once a ride is `completed` or `cancelled`.
- Maximum 500 messages per ride (server-enforced).
- Each message has a maximum length of 1,000 characters (server-enforced).
- No image or file sharing (text only in the current version).

---

## Chapter 17: Activity Feed & Ride History

### 17.1 The Activity Screen

The Activity tab shows all rides you are involved in, organized by status:

| Category | What's Shown |
|----------|-------------|
| **Active** | Rides you're currently driving or riding in (status: `started`). |
| **Upcoming** | Rides you've been accepted for that haven't started yet (status: `available`, `accepted`, `full`). |
| **Pending** | Rides where you have a pending join request. |
| **Past** | Completed or cancelled rides. |

Each ride card shows the route, driver/rider info, status, and fare.

### 17.2 Pagination

The Activity feed is paginated:
- Default: 20 rides per page.
- Maximum: 50 rides per page.
- Scroll down to load more rides automatically.

### 17.3 The History Screen

The History screen provides a more detailed view of your past rides, focusing on:
- Complete route maps for each ride.
- Exact timestamps (started, completed).
- Fare paid/earned.
- List of co-passengers.

---

## Chapter 18: Co-Passengers & Community

### 18.1 Viewing Your Co-Passengers

From the History screen, tap on any past ride to expand it and see the full list of co-passengers:
- Their name and verification status.
- Whether they paid their fare.
- The segment they traveled (pickup/drop-off locations).

### 18.2 The Co-Passengers Network

Over time, you build a network of people you've shared rides with. The Co-Passengers view aggregates all unique users from your ride history, letting you recognize familiar faces for future trips.

---

---

# Part VI: Administration

---

## Chapter 19: Admin Panel Overview

### 19.1 What Is the Admin Panel?

The Admin Panel is a secure, dedicated interface within the Ridify app that is accessible only to users whose email addresses are listed in the `ADMIN_EMAILS` environment variable on the server. Admins are regular users with elevated privileges.

### 19.2 Accessing the Admin Panel

1. Log in with an email that is configured as an admin email.
2. The app automatically detects your admin status from the login response (`isAdmin: true`).
3. An **Admin** tab appears in the navigation, giving you access to the admin dashboard.

### 19.3 Admin Panel Sections

| Section | Purpose |
|---------|---------|
| **Dashboard** | High-level platform statistics. |
| **Users** | Search, view, edit, ban/unban, and delete user accounts. |
| **Rides** | View all rides (active, completed, cancelled), force-cancel, or delete. |
| **Verifications** | Review pending KYC document submissions, approve or reject. |

---

## Chapter 20: User Management & Moderation

### 20.1 Viewing Users

The Users section displays a paginated, searchable list of all registered users.

| Column | Description |
|--------|-------------|
| **Name** | The user's full name. |
| **Email** | Their registered email address. |
| **Verified** | Their KYC verification status (None / Pending / Verified). |
| **Banned** | Whether the account is banned. |
| **Joined** | Account creation date. |

**Search:** You can search by name or email. The search uses case-insensitive regex matching (with special characters escaped to prevent ReDoS attacks).

**Sort:** Sort by name (alphabetical) or creation date.

### 20.2 Viewing User Details

Tap on a user to see:
- Full profile information (name, age, email, verification status).
- **Stats:** Number of rides as a driver and as a passenger.
- Their uploaded ID document URL (if any).

### 20.3 Editing a User

Admins can update a user's:
- **Name** (max 500 characters).
- **Age** (max 3 digits).
- **Email cannot be changed** — this is enforced server-side due to cascade complexities (email is used as the unique identifier in rides, chat messages, and socket rooms).

When you update a user's name, the change is **automatically cascaded** across:
- All rides where they are the driver (updates `riderName`).
- All rides where they are a passenger/requester (updates `riderDetails[email].riderName`).
- All chat messages they've sent (updates `sender` field).

### 20.4 Banning a User

1. Tap **"Ban"** on a user's profile.
2. Their `isBanned` field is set to `true`.
3. **Effect:**
   - The user cannot log in — they receive an "Account suspended" error.
   - Their existing JWT tokens will fail during refresh (the refresh endpoint checks `isBanned`).
   - They are effectively locked out of the platform.

### 20.5 Unbanning a User

1. Tap **"Unban"** on a banned user's profile.
2. Their `isBanned` field is set to `false`.
3. They can log in normally again.

### 20.6 Deleting a User

1. Tap **"Delete"** on a user's profile.
2. **Cascade effects:**
   - All active rides where they are the driver are **cancelled**.
   - All co-passengers and requesters on those rides are notified via Socket.IO.
   - Their pending requests on other rides are removed.
   - Their user record is permanently deleted.

### 20.7 Bulk Delete

Admins can select multiple users and delete them in bulk (max 100 at a time). The admin's own account is protected and cannot be included in a bulk delete.

### 20.8 Delete All Users

The nuclear option: deletes every user **except the admin** who triggered the action, and all rides. A `database_wiped` event is broadcast to all connected clients.

---

## Chapter 21: Ride Monitoring & Force Controls

### 21.1 Viewing All Rides

The Rides section shows all rides with filtering options:

| Filter | Options |
|--------|---------|
| **Status** | Available, Accepted, Full, Started, Completed, Cancelled |
| **Driver Email** | Filter by a specific driver's email. |

Rides are displayed with route information (excluding the full route path for performance) and paginated (max 50 per page).

### 21.2 Force-Cancelling a Ride

If a ride needs to be stopped for safety or policy reasons:
1. Find the ride and tap **"Force Cancel"**.
2. All pending requests are automatically declined.
3. The ride status changes to `cancelled`.
4. All participants are notified via Socket.IO with `adminCancelled: true`.

### 21.3 Deleting a Ride

Completely removes a ride record from the database. All connected clients receive a `ride_cancelled` event with `adminDeleted: true`.

### 21.4 Wiping All Rides

Permanently deletes every ride in the database. An `all_rides_wiped` event is broadcast to all connected clients.

---

## Chapter 22: KYC Document Verification Workflow

### 22.1 The Verification Queue

Navigate to the **Verifications** section to see all users with `verificationStatus: 'pending'`.

### 22.2 Reviewing a Document

For each pending verification:
1. The admin can see the user's name, email, and the URL of their uploaded ID document (hosted on Google Drive).
2. Open the document URL to view the government ID.
3. **Verification checklist:**
   - Is the document a valid government-issued ID?
   - Is the name on the document consistent with the user's registered name?
   - Is the document legible and not expired?
   - Are all four corners visible?

### 22.3 Approving a Verification

1. Tap **"Approve"**.
2. The user's `documentsVerified` is set to `true` and `verificationStatus` to `'verified'`.
3. **Cascade:** The verification status is propagated to ALL rides where this user is a driver or passenger. The `driverVerificationStatus` field and `riderDetails[email].verificationStatus` fields are updated across all rides.
4. The user will see a ✅ verified badge next to their name.

### 22.4 Rejecting a Verification

1. Tap **"Reject"**.
2. The user's `verificationStatus` is reset to `'none'` and their `idUrl` is cleared.
3. **Cascade:** Same as approval — the status is propagated across all rides.
4. The user will need to upload a new, valid document.

---

## Chapter 23: Platform Statistics Dashboard

### 23.1 Dashboard Metrics

The admin dashboard provides these real-time metrics:

| Metric | Description |
|--------|-------------|
| **Total Users** | All registered accounts. |
| **Total Rides** | All rides ever created. |
| **Available Rides** | Rides currently open for requests. |
| **Accepted Rides** | Rides with at least one accepted passenger. |
| **Full Rides** | Rides where every segment is at capacity. |
| **Started Rides** | Rides currently in progress. |
| **Completed Rides** | Successfully finished rides. |
| **Cancelled Rides** | Rides that were cancelled. |
| **Active Rides** | Sum of Available + Accepted + Started + Full. |
| **Recent Users** | The 5 most recently registered users. |

---

---

# Part VII: Technical Deep Dive

---

## Chapter 24: System Architecture Overview

Ridify follows a **client-server architecture** with four distinct layers:

### 24.1 Client Layer (Flutter)

| Component | Technology | Purpose |
|-----------|-----------|---------|
| UI Framework | Flutter 3.x + Dart | Cross-platform mobile user interface. |
| State Management | Provider | Reactive state management for real-time updates. |
| Maps | `flutter_map` + OpenStreetMap | Interactive map rendering. |
| Location | `geolocator` | Device GPS and permission management. |
| WebSocket Client | `socket_io_client` | Real-time bidirectional communication. |
| HTTP Client | `http` | REST API calls. |
| Token Storage | `flutter_secure_storage` | Encrypted, secure JWT token storage on device. |
| Geocoding | `nominatim_service` | Convert addresses to coordinates and vice-versa. |

### 24.2 Backend Layer (Node.js + Express)

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Runtime | Node.js 20+ | JavaScript runtime. |
| HTTP Framework | Express 5.x | RESTful API routing and middleware. |
| WebSocket Server | Socket.IO 4.8 | Real-time event broadcasting. |
| Geospatial Math | `@turf/turf` | Sweep-line calculations, distance measurements, point-in-route matching. |
| Authentication | `jsonwebtoken` + `bcrypt` | JWT token signing/verification + password hashing. |
| Logging | `winston` | Structured, leveled logging (info, warn, error). |
| Security | `helmet` | HTTP security headers (CSP, HSTS, X-Frame-Options, etc.). |
| Rate Limiting | `express-rate-limit` | Per-IP and per-email request throttling. |
| Input Sanitization | `sanitize-html` | Strip HTML/XSS from chat messages. |

### 24.3 Database Layer (MongoDB)

| Collection | Purpose |
|-----------|---------|
| `users` | User accounts, credentials, verification status, ban status. |
| `rides` | Ride data including route, passengers, chat messages, lifecycle state. |
| `otpverifications` | Temporary OTP records for sign-up (auto-deleted after 10 minutes via TTL index). |

### 24.4 External Services

| Service | Integration Method | Purpose |
|---------|--------------------|---------|
| OSRM | HTTP (public API or self-hosted) | Calculates optimal driving routes between two points. Returns a polyline of GPS coordinates. |
| Nominatim | HTTP (OpenStreetMap) | Forward and reverse geocoding — converting between addresses and GPS coordinates. |
| EmailJS | HTTP API | Sends OTP emails for sign-up and login. |
| Google Apps Script | HTTP POST webhook | Uploads KYC identity documents to Google Drive. |

---

## Chapter 25: Authentication & Token System

### 25.1 Token Architecture

Ridify uses a **two-token system**:

| Token | Purpose | Lifespan | Storage |
|-------|---------|---------|---------|
| **Access Token** | Authorizes API requests. Sent in the `Authorization: Bearer <token>` header. | 15 minutes | In-memory + `flutter_secure_storage` |
| **Refresh Token** | Used to obtain new access tokens without re-logging in. | 7 days | `flutter_secure_storage` on device; stored as an array in the `user.refreshTokens` field in the database. |

### 25.2 Token Flow

```
1. User logs in → Server returns accessToken + refreshToken
2. Client stores both tokens securely
3. Client sends accessToken with every API request
4. When accessToken expires (15 min):
   a. Client sends refreshToken to POST /api/auth/refresh
   b. Server validates refreshToken exists in user.refreshTokens[]
   c. Server checks user is not banned
   d. Server returns new accessToken
5. When refreshToken expires (7 days):
   a. User must log in again with password or OTP
```

### 25.3 Token Revocation

- **On logout:** The specific refresh token is removed from `user.refreshTokens[]`.
- **On password change:** ALL refresh tokens are cleared, logging the user out everywhere.
- **On ban:** The refresh endpoint rejects the token with a `ACCOUNT_BANNED` error code.
- **On account deletion:** The entire user record is deleted, invalidating all tokens.

### 25.4 Socket.IO Authentication

WebSocket connections are also authenticated:
1. When connecting, the client sends the JWT access token in `socket.handshake.auth.token`.
2. The Socket.IO middleware (`io.use()`) verifies the token.
3. If valid, the user's email and ID are attached to the socket object.
4. If invalid, the connection is rejected with an error.

---

## Chapter 26: Database Schema Reference

### 26.1 User Schema

```javascript
{
  name:               String (required, max 500 chars),
  age:                String (max 3 chars),
  email:              String (unique, required, lowercase, max 500 chars),
  password:           String (bcrypt hashed, select: false),
  isVerified:         Boolean (default: false),
  otp:                String (SHA-256 hashed, select: false),
  otpExpiry:          Date (select: false),
  otpAttempts:        Number (default: 0, select: false),
  lastOtpSentAt:      Date (select: false),
  refreshTokens:      [String] (select: false),
  isBanned:           Boolean (default: false),
  documentsVerified:  Boolean (default: false),
  verificationStatus: String (enum: ['none', 'pending', 'verified']),
  idUrl:              String (Google Drive URL),
  timestamps:         { createdAt, updatedAt }
}
```

**Indexes:** `createdAt: 1`

### 26.2 Ride Schema

```javascript
{
  riderName:              String (driver's name),
  riderEmail:             String (driver's email, required),
  driverVerificationStatus: String (enum: ['none', 'pending', 'verified']),
  pickupLocation:         String (human-readable address),
  pickupLat/pickupLng:    Number (GPS coordinates),
  destination:            String (human-readable address),
  destLat/destLng:        Number (GPS coordinates),
  pickupCoords:           GeoJSON Point (for 2dsphere queries),
  departureTime:          String (formatted date/time string),
  expiresAt:              Number (epoch ms — auto-expiry timestamp),
  optimisticLock:         Number (for concurrency control),
  fare:                   Number (total fare, min 1),
  status:                 String (enum: ['available', 'accepted', 'full',
                                         'started', 'completed', 'cancelled']),
  vehicleType:            String (enum: ['Bike', 'Sedan', 'SUV']),
  totalSeats:             Number (1-8),
  availableSeats:         Number,
  routePath:              [{lat: Number, lng: Number}] (GPS polyline, max 500 points),
  totalDistance:           Number (km),
  routePreference:        String (enum: ['flexible', 'shared_start', 'nonstop']),
  
  // Passenger tracking
  riderDetails:           Map<email → {
    pickupLat, pickupLng, destLat, destLng,
    pickupLocation, destination, fare, distance,
    seats, startIndex, endIndex, paid, riderName,
    verificationStatus, boardedAt, droppedAt, kickedAt
  }>,
  requests:               [String] (emails of pending requesters),
  passengers:             [String] (emails of accepted passengers),
  boardedPassengers:      [String] (emails of physically boarded),
  droppedPassengers:      [String] (emails of dropped-off),
  paidPassengers:         [String] (emails who marked payment),
  arrivedAt:              [String] (emails where driver has arrived),
  declined:               [String] (emails declined by driver),
  kicked:                 [String] (emails kicked by driver),
  cancelledRequests:      [String] (emails who self-cancelled their request),
  seatAllocations:        Map<email → Number>,
  
  // Chat
  chatMessages:           [{
    sender: String, senderEmail: String,
    text: String (max 1000 chars),
    timestamp: String (ISO),
    replyTo: { sender: String, text: String }
  }] (max 500 messages),
  
  startedAt:              Date,
  completedAt:            Date,
  timestamps:             { createdAt, updatedAt }
}
```

**Indexes:**
- `pickupCoords: "2dsphere"` — Geospatial queries.
- `riderEmail + status` — Find driver's active rides.
- `passengers` — Find rides where user is a passenger.
- `requests` — Find rides where user has pending request.
- `droppedPassengers` — Historical queries.
- `status + expiresAt` — Efficient expired ride queries.
- `status + vehicleType + departureTime` — Compound search filter.
- `updatedAt` (TTL) — **Auto-deletes** completed/cancelled rides after 30 days.

### 26.3 OTP Verification Schema

```javascript
{
  email:          String (required, lowercase),
  otp:            String (plaintext — used only for signup verification),
  createdAt:      Date (default: now, TTL: 10 minutes — auto-deleted),
  lastOtpSentAt:  Date
}
```

---

## Chapter 27: The Ride Lifecycle State Machine

```
                    ┌─────────────┐
                    │  available   │ ← Ride is published, open for requests
                    └──────┬──────┘
                           │ First rider accepted
                           ▼
                    ┌─────────────┐
                    │  accepted    │ ← Has passengers, still accepting more
                    └──────┬──────┘
                           │ All segments full
                           ▼
                    ┌─────────────┐
                    │    full      │ ← No more capacity on any segment
                    └──────┬──────┘
                           │
              ┌────────────┤ Driver taps "Start Ride"
              │            ▼
              │     ┌─────────────┐
              │     │   started    │ ← Driver is en route, live tracking active
              │     └──────┬──────┘
              │            │ Driver taps "End Trip"
              │            ▼
              │     ┌─────────────┐
              │     │  completed   │ ← Trip finished, payments pending
              │     └─────────────┘
              │
              │  Driver/Admin/System cancels at any point
              │            │
              └────────────▼
                    ┌─────────────┐
                    │  cancelled   │ ← Ride is cancelled
                    └─────────────┘
```

**Transition Rules:**
- `available` → `accepted`: When the first rider is accepted.
- `accepted` → `full`: When the sweep-line determines every segment is at capacity.
- `full` → `accepted`: When a passenger is kicked, freeing capacity.
- `accepted` → `available`: When all passengers and requests are removed.
- `available`/`accepted`/`full` → `started`: When the driver starts the ride. Pending requests are auto-declined.
- `started` → `completed`: When the driver ends the ride.
- Any active state → `cancelled`: By driver, admin, or auto-cleanup (stale rides stuck in `started` for >6 hours).
- `completed`/`cancelled` → *(auto-deleted)*: After 30 days via MongoDB TTL index.

---

## Chapter 28: The Sweep-Line Matching Algorithm

### 28.1 The Problem

Traditional ride-sharing apps use simple seat counting: "3 seats available, 2 passengers = 1 seat left." But this doesn't account for **segment overlap**. Consider:

- A car has 2 seats.
- Rider A travels from Point 10 to Point 50 on the route (1 seat).
- Rider B travels from Point 60 to Point 90 (1 seat).
- Since their segments don't overlap, both can travel in the car — even though "2 passengers = 0 seats" would suggest the car is full for a third rider.
- Rider C wants to travel from Point 20 to Point 40 (1 seat). Under simple counting, they'd be rejected. But with sweep-line, we see that at Point 20, only Rider A is in the car (1/2 seats used), so Rider C can fit!

### 28.2 How Ridify Solves It

The sweep-line algorithm works as follows:

1. **Create events:** For each existing passenger, create two events:
   - A **pickup event** at their `startIndex` with change = `+seats`.
   - A **dropoff event** at their `endIndex` with change = `-seats`.

2. **Add the new request:** Add the candidate rider's pickup (+seats) and dropoff (-seats) events.

3. **Sort events:** By index first, then by change value (dropoffs before pickups at the same index — so a seat is freed before a new passenger tries to use it).

4. **Sweep:** Walk through the sorted events, maintaining a running count of currently occupied seats. Track the **peak** occupancy.

5. **Decision:** If the peak occupancy ≤ `totalSeats`, the new rider fits. Otherwise, they don't.

### 28.3 Capacity Check Variants

| Function | Used When | Counts |
|----------|----------|--------|
| `checkCapacityForSearch` | Searching for rides | Only accepted passengers (pending requests don't count). Ensures rides stay visible until genuinely full. |
| `checkCapacityForRequest` | Requesting to join | Only accepted passengers (allows multiple simultaneous requests to the same ride). |
| `checkCapacity` | Accepting a rider | Only accepted passengers (the just-accepted rider is already in the passengers list). |

### 28.4 Example

```
Route: [0] ───────── [25] ───────── [50] ───────── [75] ───────── [100]
Car capacity: 2 seats

Rider A: [10 ─────────── 60]  (1 seat)
Rider B: [40 ─────────────────── 90]  (1 seat)

Events (sorted):
  Index 10: +1 (A boards)
  Index 40: +1 (B boards)
  Index 60: -1 (A alights)
  Index 90: -1 (B alights)

Sweep:
  At 10: occupancy = 1  ← OK (≤ 2)
  At 40: occupancy = 2  ← OK (≤ 2) — peak!
  At 60: occupancy = 1
  At 90: occupancy = 0

Peak = 2 = totalSeats → Car is at capacity between [40, 60].

New Rider C: [65 ─── 85] (1 seat)?
  Add events: Index 65: +1, Index 85: -1
  New sweep peak would be max(2, 1+1) = 2 ← Still OK! Rider C can board.

New Rider D: [30 ─── 55] (1 seat)?
  Add events: Index 30: +1, Index 55: -1
  At Index 40: 1(A) + 1(D) + 1(B) = 3 > 2 ← Exceeds capacity! Rider D rejected.
```

---

## Chapter 29: Real-Time Communication (Socket.IO)

### 29.1 Connection Architecture

Every authenticated user maintains a persistent WebSocket connection to the Ridify server.

**Room Structure:**
- Each user joins a **personal room** named after their email address. This enables sending events to a specific user across all their connected devices.
- Each user automatically joins **ride rooms** for all their active rides (found via database query on connection).
- The **global search room** (`global_search_room`) is joined by users who are actively browsing search results.

### 29.2 Event Reference

| Event Name | Direction | Description |
|------------|-----------|-------------|
| `new_ride_request` | Server → Client | A rider has requested to join a ride. |
| `ride_accepted` | Server → Client | A rider's request has been accepted. |
| `ride_cancelled` | Server → Client | A ride has been cancelled or a request declined. |
| `ride_updated` | Server → Client | Generic ride state update (capacity change, etc.). |
| `ride_started` | Server → Client | The driver has started the ride. |
| `driver_arrived` | Server → Client | The driver has arrived at a passenger's pickup. |
| `passenger_boarded` | Server → Client | A passenger has boarded the vehicle. |
| `passenger_dropped` | Server → Client | A passenger has been dropped off. |
| `passenger_paid` | Server → Client | A passenger has marked their payment as complete. |
| `passenger_kicked` | Server → Client | A passenger has been kicked from the ride. |
| `ride_ended` | Server → Client | The trip is complete. |
| `receive_message` | Server → Client | A new chat message has been sent. |
| `driver_location_update` | Client → Server → Clients | Driver broadcasts GPS position (throttled to 1 update per 1.5s). |
| `request_driver_location` | Client → Server → Driver | A passenger requests the driver's current location. |
| `join_ride` | Client → Server | Explicitly join a ride's room. |
| `leave_ride` | Client → Server | Leave a ride's room. |
| `join_global_search_room` | Client → Server | Join the search results room. |
| `leave_global_search_room` | Client → Server | Leave the search results room. |
| `database_wiped` | Server → All | Admin wiped the database. |

### 29.3 Reliability

To handle mobile network instability (NAT timeouts, data drops), every event is emitted through **two channels**:
1. The **ride room** (standard Socket.IO room broadcast).
2. **Direct per-user emission** via the user's personal room.

This dual-channel approach ensures events are delivered even if a user's ride room membership was silently lost during a reconnect.

### 29.4 Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `SOCKET_PING_INTERVAL` | 25,000ms (25s) | How often the server pings the client. Set higher than default for mobile data tolerance. |
| `SOCKET_PING_TIMEOUT` | 20,000ms (20s) | How long to wait for a pong before considering the connection dead. Generous for mobile. |
| Location update cooldown | 1,500ms | Minimum interval between location broadcasts from the same driver. |

---

## Chapter 30: REST API Reference

### 30.1 Base URL

```
http://<server-ip>:<port>/api
```

### 30.2 Authentication Routes — `/api/auth`

| Method | Endpoint | Auth? | Description |
|--------|----------|-------|-------------|
| `POST` | `/signup-otp-request` | No | Request OTP for new account registration. |
| `POST` | `/register` | No | Register a new account with name, email, password, and OTP. |
| `POST` | `/login` | No | Log in with email + password or email + OTP. |
| `POST` | `/login-otp-request` | No | Request OTP for passwordless login. |
| `POST` | `/refresh` | No | Exchange a refresh token for a new access token. |
| `POST` | `/logout` | Yes | Revoke the provided refresh token. |
| `PATCH` | `/change-password` | Yes | Change password (requires current password). |
| `PATCH` | `/user/:email` | Yes | Update own profile (name, age). |
| `POST` | `/user/:email/upload-id` | Yes | Upload KYC identity document. |
| `GET` | `/user/:email/profile` | Yes | Fetch own profile details. |
| `DELETE` | `/user/:email` | Yes | Delete own account (or admin can delete any). |
| `DELETE` | `/users` | Yes (Admin) | Delete all users except the requesting admin. |

### 30.3 Ride Routes — `/api/rides`

| Method | Endpoint | Auth? | Description |
|--------|----------|-------|-------------|
| `GET` | `/search` | Yes | Search for available rides by coordinates, date, vehicle type. |
| `GET` | `/stats/driver` | Yes | Get the authenticated driver's statistics. |
| `GET` | `/` | Yes | Get all rides the user is involved in (paginated). |
| `GET` | `/:id` | Yes | Get a specific ride by ID (full details including chat). |
| `POST` | `/` | Yes | Create a new ride. |
| `PATCH` | `/cancel/:id` | Yes | Cancel a ride (driver or admin only). |
| `PATCH` | `/request/:id` | Yes | Request to join a ride. |
| `PATCH` | `/accept/:id/:passengerEmail` | Yes | Accept a rider's request (driver only). |
| `PATCH` | `/decline/:id/:passengerEmail` | Yes | Decline a rider's request (driver or self). |
| `PATCH` | `/kick/:id/:passengerEmail` | Yes | Kick a passenger (driver only). |
| `PATCH` | `/arrive/:id/:passengerEmail` | Yes | Mark driver arrived at passenger's pickup. |
| `PATCH` | `/board/:id/:passengerEmail` | Yes | Mark passenger as boarded. |
| `PATCH` | `/dropoff/:id/:passengerEmail` | Yes | Drop off a boarded passenger. |
| `PATCH` | `/pay/:id/:passengerEmail` | Yes | Mark self as paid (passenger only). |
| `PATCH` | `/start/:id` | Yes | Start the ride (driver only). |
| `PATCH` | `/end/:id` | Yes | End the ride (driver only). Use `?force=true` to auto-drop all. |
| `POST` | `/:id/chat` | Yes | Send a chat message. |
| `DELETE` | `/` | Yes (Admin) | Delete all rides. |

### 30.4 Admin Routes — `/api/admin`

All admin routes require authentication + admin email verification.

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/users` | List users (paginated, searchable). |
| `GET` | `/users/:id` | Get user details + ride stats. |
| `POST` | `/users/create` | Create a new user (no OTP required). |
| `PATCH` | `/users/:id` | Update user profile. |
| `DELETE` | `/users/:id` | Delete a specific user. |
| `POST` | `/users/bulk-delete` | Delete multiple users (max 100). |
| `POST` | `/users/:id/ban` | Ban a user. |
| `POST` | `/users/:id/unban` | Unban a user. |
| `PATCH` | `/users/:id/verify` | Approve KYC verification. |
| `PATCH` | `/users/:id/reject-verification` | Reject KYC verification. |
| `GET` | `/verifications/pending` | List all pending KYC submissions. |
| `GET` | `/rides` | List all rides (paginated, filterable). |
| `GET` | `/rides/:id` | Get full ride details (including chat). |
| `DELETE` | `/rides/:id` | Delete a specific ride. |
| `DELETE` | `/rides` | Delete all rides. |
| `PATCH` | `/rides/:id/cancel` | Force-cancel a ride. |
| `GET` | `/stats` | Get platform statistics. |

### 30.5 Utility Routes

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check — returns `200 OK` if MongoDB is connected, `503` otherwise. |
| `GET` | `/` | Root — returns a text message confirming the API is running. |
| `GET` | `/api/config` | Returns configurable constants (max field length, max message length, max price, min ride distance, max route points, default search radius). |

---

## Chapter 31: Security Architecture

### 31.1 HTTP Security Headers (Helmet)

Ridify configures Helmet with the following policies:

| Header | Configuration |
|--------|--------------|
| **Content-Security-Policy** | `default-src: 'self'`, `script-src: 'self'`, `object-src: 'none'`, `upgrade-insecure-requests` |
| **Strict-Transport-Security** | `max-age: 31536000` (1 year), `includeSubDomains` |
| **X-Content-Type-Options** | `nosniff` |
| **X-Frame-Options** | `DENY` |

### 31.2 CORS Policy

- **Production:** Only origins listed in the `ALLOWED_ORIGIN` environment variable are permitted. Requests from unlisted origins are rejected.
- **Development:** Allows all origins (or configured origins) for easier testing.
- **Allowed Methods:** GET, POST, PATCH, DELETE, OPTIONS.
- **Allowed Headers:** Content-Type, Authorization, x-admin-email, x-admin-secret.
- **Credentials:** Allowed.

### 31.3 Password Security

- Passwords are hashed using **bcrypt** with a configurable number of salt rounds (default: 12).
- OTPs for login are hashed using **SHA-256** before storage, preventing plaintext OTP leaks even if the database is compromised.
- Sign-up OTPs are stored as plaintext in the temporary `OtpVerification` collection (which auto-deletes after 10 minutes).

### 31.4 Input Validation & Sanitization

- **Email validation:** Regex-based format check (`^[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}$`).
- **ObjectId validation:** MongoDB `ObjectId.isValid()` check on all ID parameters.
- **Field length limits:** Configurable `MAX_FIELD_LENGTH` (default 500) enforced on names, emails, and search queries.
- **Chat sanitization:** All chat messages pass through `sanitize-html` with zero allowed tags — stripping all HTML to prevent XSS.
- **Regex escaping:** Admin search queries have special regex characters escaped to prevent ReDoS attacks.
- **JSON body limit:** Requests are limited to 1 MB.
- **API caching disabled:** All `/api` routes set `Cache-Control: no-store` to prevent stale data.

---

## Chapter 32: Rate Limiting & Abuse Prevention

### 32.1 Rate Limit Tiers

| Limiter | Scope | Window | Max Requests | Applied To |
|---------|-------|--------|-------------|------------|
| **Global** | Per IP | 1 minute | 200 | All routes |
| **Auth** | Per IP + Email | 15 minutes | 1,000 | `/api/auth/*` |
| **Ride** | Per User Email or IP | 1 minute | 300 | `/api/rides/*` |

### 32.2 OTP Brute Force Protection

- **Signup OTP:** Cannot request another OTP within 10 minutes of the last request.
- **Login OTP:** Cannot request another OTP within 10 minutes. Max 5 wrong OTP attempts — after that, the OTP is invalidated.
- **Login OTP Expiry:** OTPs expire after 10 minutes.

### 32.3 Optimistic Locking

Critical ride operations (request, accept, board, dropoff, arrive, start) use optimistic locking:
- Each ride document has an `optimisticLock` counter.
- Update operations include the current lock value in the query filter.
- If a concurrent modification changed the lock, the update returns null and the operation retries (up to 5 times with 20-100ms random jitter).

### 32.4 Stale Ride Auto-Cleanup

A background job runs every 30 minutes (first run after 5 minutes of server start):
- Finds rides with status `started` where `startedAt` is more than 6 hours ago.
- Automatically cancels them to prevent orphaned "in progress" rides.
- Logged as a warning: `Auto-cancelled N stale ride(s)`.

---

---

# Part VIII: Policies & Legal

---

## Chapter 33: Terms of Service

### 33.1 Acceptance

By creating an account on Ridify, you agree to these Terms of Service. If you do not agree, you must discontinue use of the application immediately.

### 33.2 Eligibility

- You must be at least 18 years old to use Ridify.
- You must have a valid email address.
- If operating as a driver, you must hold a valid driver's license and adequate vehicle insurance as required by your local jurisdiction.

### 33.3 Account Responsibilities

- You are responsible for maintaining the confidentiality of your account credentials.
- You may not share your account with others.
- You are responsible for all activity that occurs under your account.
- You must provide accurate information during registration and KYC verification.

### 33.4 Ride Conduct

- Drivers must operate their vehicles safely and in compliance with all traffic laws.
- Riders must behave respectfully toward drivers and co-passengers.
- Harassment, discrimination, or threatening behavior toward any user is strictly prohibited.
- Smoking, alcohol consumption, and illegal substance use during rides is prohibited.
- Both drivers and riders must wear seatbelts where required by law.

### 33.5 Payment Terms

- Ridify calculates fare splits as a facilitation service. Actual payments are settled directly between parties.
- Ridify does not guarantee payment collection. Riders are expected to pay their computed fare promptly upon trip completion.
- Ridify does not currently charge a commission or service fee.

### 33.6 Prohibited Activities

- Manipulating the app or its API to falsify ride data, fares, or locations.
- Creating multiple accounts to circumvent bans or restrictions.
- Using the platform for commercial transportation services (e.g., operating as an unlicensed taxi).
- Uploading false or fraudulent identity documents.
- Spamming the chat system or harassing other users.
- Attempting to reverse-engineer, decompile, or exploit the Ridify software.

### 33.7 Account Suspension and Termination

- Ridify reserves the right to suspend or permanently ban any account that violates these Terms.
- Suspended users will receive an "Account suspended" message when attempting to log in.
- You may delete your own account at any time via Profile → Delete Account. This action is irreversible.

### 33.8 Limitation of Liability

- Ridify is a platform that connects drivers and riders. It is not a transportation company.
- Ridify does not guarantee the safety, quality, or legality of rides.
- Ridify is not liable for any accidents, injuries, property damage, or losses that occur during rides.
- Users participate in rides at their own risk.

### 33.9 Modifications

Ridify reserves the right to modify these Terms at any time. Continued use of the platform after modifications constitutes acceptance of the updated Terms.

---

## Chapter 34: Privacy Policy

### 34.1 Information We Collect

| Data Type | What We Collect | Why |
|-----------|----------------|-----|
| **Account Data** | Name, email, age, password (hashed). | To create and manage your account. |
| **Location Data** | GPS coordinates during ride creation, search, and live tracking. | To match rides, display maps, and enable real-time tracking. |
| **Identity Documents** | Government-issued ID photos (uploaded to Google Drive). | For KYC verification to build community trust. |
| **Ride Data** | Routes, pickup/dropoff locations, fares, timestamps, passenger lists. | To facilitate ride-sharing and cost-splitting. |
| **Chat Messages** | Text messages sent within ride chat rooms. | To enable in-ride communication. |
| **Device Data** | IP address (for rate limiting). | To prevent abuse and ensure security. |

### 34.2 How We Use Your Data

- **Ride Matching:** Your pickup and destination coordinates are compared against driver routes to find compatible rides.
- **Live Tracking:** During active rides, the driver's GPS position is shared with co-passengers via Socket.IO.
- **Communication:** Chat messages are stored in the ride document and visible to all ride participants.
- **Security:** IP addresses are used for rate limiting. Email addresses are used for OTP delivery and admin identification.

### 34.3 Data Sharing

- **With Co-Passengers and Drivers:** Your name, verification status, and ride-specific details (pickup, dropoff, fare) are shared with other participants in your ride.
- **With Admins:** Admins can view all user profiles, ride data, and KYC documents.
- **With Third Parties:**
  - **EmailJS:** Your email address is sent to EmailJS to deliver OTP emails.
  - **Google Drive:** Your KYC document is uploaded to Google Drive via Google Apps Script.
  - **OSRM / Nominatim:** Your requested pickup and destination coordinates are sent to these open-source services for route calculation and geocoding. These services are operated by the OpenStreetMap community.
- **We do not sell your personal data** to advertisers or third-party marketers.

### 34.4 Data Retention

| Data | Retention Period |
|------|-----------------|
| **Active user accounts** | Retained indefinitely until the user deletes their account. |
| **Completed/Cancelled rides** | Auto-deleted 30 days after the last update (MongoDB TTL index). |
| **OTP verification records** | Auto-deleted 10 minutes after creation (MongoDB TTL index). |
| **KYC documents** | Stored on Google Drive. Not automatically deleted. Admins can manually remove rejected documents. |
| **Chat messages** | Deleted with the ride document (30 days after completion). |
| **Server logs** | Retained per your server deployment's logging configuration. |

### 34.5 Your Rights

- **Access:** You can view your profile data at any time via Profile → View Profile.
- **Correction:** You can update your name and age via Profile → Edit Profile.
- **Deletion:** You can delete your entire account via Profile → Delete Account. This removes your user record and cancels all active rides.
- **Portability:** Contact the platform administrator to request an export of your data.

### 34.6 Security Measures

- Passwords are hashed with bcrypt (12 rounds).
- Login OTPs are hashed with SHA-256.
- JWT tokens are stored in encrypted device storage.
- API communications use HTTPS in production (enforced by `upgrade-insecure-requests` CSP directive).
- Rate limiting prevents brute-force attacks.
- Helmet security headers protect against common web vulnerabilities.

---

## Chapter 35: Community Guidelines

### 35.1 Be Respectful

Treat every user — driver, rider, and co-passenger — with courtesy and respect. Ridify is a shared community platform.

### 35.2 Be Punctual

- **Drivers:** Start your ride on time. Riders are counting on you.
- **Riders:** Be at your pickup location when the driver arrives. Don't keep the driver (and other co-passengers) waiting.

### 35.3 Be Honest

- Set fair and reasonable fares.
- Provide accurate pickup and drop-off locations.
- Pay the full computed fare promptly after being dropped off.
- Do not submit fraudulent verification documents.

### 35.4 Be Safe

- Drivers: ensure your vehicle is in safe operating condition.
- Follow all traffic laws and speed limits.
- Do not drive under the influence of drugs or alcohol.
- Share your ride details with a trusted contact if you feel more comfortable.

### 35.5 Reporting Violations

If you experience or witness a violation of these guidelines:
- Contact a platform administrator via the contact information in [Chapter 40](#chapter-40-contact--support).
- Provide the ride ID, user email, and a description of the incident.
- Admins can ban violating users and force-cancel problematic rides.

---

## Chapter 36: Data Retention & Deletion

### 36.1 Automatic Data Lifecycle

| Stage | What Happens | Timeline |
|-------|-------------|----------|
| **OTP Created** | OTP record exists in `otpverifications` collection. | Auto-deleted after **10 minutes** (MongoDB TTL). |
| **Ride Active** | Full ride data retained with real-time updates. | Indefinite while active. |
| **Ride Completed/Cancelled** | Ride data retained for history access. | Auto-deleted after **30 days** (MongoDB TTL on `updatedAt`). |
| **Account Deleted** | User record purged; active rides cancelled; requests removed. | Immediate and irreversible. |

### 36.2 Manual Deletion by Admins

Admins have the ability to:
- Delete individual users (cascades to their rides).
- Delete individual rides.
- Wipe all rides from the database.
- Wipe all users (except themselves) and all rides.

### 36.3 Important Note on Archiving

The codebase includes a policy comment noting that before production deployment, an **archive job** should be implemented to copy completed/cancelled rides to a `ride_archive` collection before TTL deletion. This ensures ride history is preserved for regulatory or analytics purposes.

---

---

# Part IX: Reference

---

## Chapter 37: Troubleshooting Guide

### 37.1 Authentication Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| "Email already registered. Please log in." | You're trying to sign up with an email that already has an account. | Use the Login screen instead. |
| "User not registered. Please sign up first." | You're trying to log in with an email that doesn't have an account. | Use the Sign Up flow instead. |
| "Invalid OTP" | The OTP you entered doesn't match. | Check your email for the most recent OTP. Make sure you didn't enter a previous OTP. |
| "OTP has expired" | More than 10 minutes passed since the OTP was sent. | Request a new OTP. |
| "Too many wrong attempts" | You entered 5 incorrect OTPs. | Request a new OTP and enter it carefully. |
| "Please wait N minute(s) before requesting another OTP" | You requested an OTP too recently. | Wait for the cooldown period to expire (10 minutes). |
| "Your account has been suspended" | An admin has banned your account. | Contact the platform administrator. |
| "Only emails from @domain are allowed" | Your organization restricts registrations to specific email domains. | Use an email from the allowed domain. |
| "New password must be different" | You're trying to change your password to the same one. | Choose a genuinely different password. |
| "Incorrect current password" | The password you entered as "current" doesn't match. | Enter your actual current password. |

### 37.2 Ride Search Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| No rides found | No drivers have published rides matching your route, time, and vehicle preference. | Try widening your time window, removing the vehicle filter, or checking back later. |
| Ride disappeared from results | The ride was cancelled, started, or filled while you were browsing. | This is expected real-time behavior. Search again for updated results. |
| "Missing coordinates" error | The search was submitted without valid GPS coordinates. | Ensure you selected both pickup and destination on the map. |
| Fare seems too high/low | The fare is proportional to your segment distance vs. the total route. | This is normal — short segments cost less, long segments cost more. |

### 37.3 Ride Request Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| "You cannot request your own ride" | You're trying to join a ride you created. | You can only be a rider on someone else's ride. |
| "This ride has expired" | The ride's departure time + 15 minutes has passed. | Search for a newer ride. |
| "You have already requested or joined this ride" | Duplicate request prevention. | Wait for the driver to respond to your existing request. |
| "You were already declined for this ride" | The driver previously declined your request. | Find a different ride. |
| "You were removed from this ride" | The driver kicked you. | Find a different ride. |
| "Capacity exceeded for this segment" | The seats on your specific route segment are full. | Try requesting fewer seats or find another ride. |
| "Concurrent modification detected. Please retry." | Another request was being processed simultaneously. | The system retries automatically (up to 5 times). If you still see this, try again manually. |

### 37.4 Live Tracking Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| Driver's position not updating | WebSocket connection lost or driver's GPS is off. | Check your internet connection. The driver may have entered an area with poor GPS/data. The system will auto-reconnect. |
| Map not loading | Network issue or OpenStreetMap tile server is slow. | Ensure you have internet connectivity. Try scrolling/zooming the map to trigger tile loading. |
| "Physical car is full!" error when boarding | The total seats currently occupied by boarded passengers equals `totalSeats`. | A passenger must be dropped off before another can board. |

### 37.5 Admin Panel Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| Admin tab not visible | Your email is not in the `ADMIN_EMAILS` environment variable. | Contact the server administrator to add your email. |
| "Cannot delete your own admin account" | The bulk delete endpoint protects admin self-deletion. | This is a safety feature. Delete other users or use single-user delete for non-admin accounts. |
| "Email cannot be updated" | Email changes are blocked due to database cascade complexities. | This is by design. Users must create new accounts if they need a different email. |

### 37.6 Connection & Network Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| "Too many requests, please slow down" | You've exceeded the global rate limit (200 req/min). | Wait a moment and try again. |
| "Too many auth attempts" | You've exceeded the auth rate limit (1000 req/15 min). | Wait 15 minutes. |
| Socket disconnects frequently | Mobile data instability, NAT timeouts. | The app auto-reconnects with generous ping settings (25s interval, 20s timeout). Ensure you have stable connectivity. |
| Events not received in real-time | Socket room membership lost after reconnect. | The app uses dual-channel emission (room + direct). If still missing events, close and reopen the ride screen. |

---

## Chapter 38: Frequently Asked Questions (FAQ)

### General

**Q: Is Ridify free to use?**
A: Yes. There are no fees for creating an account, searching for rides, or offering rides. Ridify does not charge a commission on fares.

**Q: Can I use Ridify for daily commuting?**
A: Absolutely! Ridify is ideal for daily commutes. Publish your route with a recurring departure time, and nearby riders can request to join every day.

**Q: Do I need to be KYC verified?**
A: KYC is optional but recommended. Being verified shows a ✅ badge next to your name, which builds trust with other users.

### For Riders

**Q: How is my fare calculated?**
A: Your fare is proportional to the distance you travel. If you travel 40% of the driver's total route, you pay approximately 40% of the total fare.

**Q: Do I pay through the app?**
A: No. The app calculates the exact fare split, but payment is settled directly between you and the driver — cash, UPI, Venmo, bank transfer, or any method you both agree on.

**Q: What if the driver doesn't show up?**
A: If the driver cancels the ride, you'll be notified immediately. If the ride is still in `available` or `accepted` status and the departure time passes, the ride automatically expires after 15 minutes.

**Q: Can I request multiple rides simultaneously?**
A: Yes. You can have pending requests on multiple rides. However, once you are accepted for one ride, you should cancel your other requests.

**Q: What if I need to cancel after the driver accepted me?**
A: The driver can kick you from the ride, or you can contact the driver via chat to arrange the cancellation.

### For Drivers

**Q: How do I set the right fare?**
A: Consider your total trip cost (fuel, tolls, wear) and set a fare that is reasonable to split among 2-4 passengers. Ridify splits the fare proportionally based on distance.

**Q: Can passengers board and alight at different points?**
A: Yes, if you set your route preference to **Flexible**. This allows multiple riders to use the same seat on non-overlapping segments of your route.

**Q: What's the maximum number of seats I can offer?**
A: 8 seats maximum.

**Q: What happens if a passenger doesn't pay?**
A: The system logs unpaid passengers, but payment enforcement is currently outside the app. Settle any disputes directly with the passenger.

**Q: Can I cancel a ride after passengers have been accepted?**
A: Yes. All accepted passengers and pending requesters will be notified immediately.

**Q: How far in advance can I schedule a ride?**
A: Up to 7 days in advance.

### Technical

**Q: What happens if I lose internet during a ride?**
A: The app maintains a persistent WebSocket connection with generous timeouts (25s ping interval, 20s timeout). If you lose connectivity, the app will auto-reconnect when your connection is restored. Location data will resume broadcasting.

**Q: Is my data encrypted?**
A: Passwords are hashed with bcrypt (12 rounds). Login OTPs are hashed with SHA-256. JWT tokens are stored in encrypted device storage. In production, all API communication uses HTTPS.

**Q: How long is ride data kept?**
A: Active rides are retained indefinitely. Completed and cancelled rides are automatically deleted 30 days after their last update.

**Q: Can multiple people use the same account?**
A: No. Account sharing is prohibited per the Terms of Service.

**Q: What vehicles are supported?**
A: Bike, Sedan, and SUV. This is an identifier for riders to know what type of vehicle to expect.

---

## Chapter 39: Glossary of Terms

| Term | Definition |
|------|------------|
| **Access Token** | A short-lived JWT token (15 min) used to authenticate API requests. |
| **Admin** | A platform moderator with elevated privileges, identified by email in `ADMIN_EMAILS`. |
| **bcrypt** | A password hashing algorithm used by Ridify with 12 salt rounds. |
| **Co-Passenger** | An accepted rider on a shared ride. All accepted riders are co-passengers of each other. |
| **Driver** | A user who creates and offers a ride. Also referred to as the ride owner. |
| **EmailJS** | Third-party service used to send OTP emails. |
| **Fare Split** | The proportional division of the total ride fare based on each rider's segment distance. |
| **Flutter** | Google's UI toolkit for building cross-platform mobile applications. Used for Ridify's frontend. |
| **GeoJSON** | A format for encoding geographic data. Used for the `pickupCoords` field with a `2dsphere` index. |
| **Helmet** | Express middleware that sets various HTTP headers for security. |
| **JWT** | JSON Web Token — a compact, URL-safe token format used for authentication. |
| **KYC** | Know Your Customer — an identity verification process requiring government ID upload. |
| **Nominatim** | An OpenStreetMap service for geocoding (address ↔ coordinates conversion). |
| **Optimistic Locking** | A concurrency control method where the `optimisticLock` counter prevents conflicting simultaneous updates. |
| **OSRM** | Open Source Routing Machine — calculates driving routes and returns GPS polylines. |
| **OTP** | One-Time Password — a 6-digit code sent via email for account verification. |
| **Provider** | Flutter's reactive state management solution used throughout the Ridify frontend. |
| **Rate Limiting** | Restricting the number of API requests a user/IP can make in a given time window. |
| **Refresh Token** | A long-lived token (7 days) used to obtain new access tokens without re-authentication. |
| **Rider** | A user who searches for and joins an existing ride. |
| **Route Path** | An ordered array of `{lat, lng}` coordinates representing the driver's planned route. |
| **Route Preference** | The driver's setting for how flexible pickup/drop-off locations can be along the route. |
| **Segment** | A portion of the route path between a rider's pickup index and drop-off index. |
| **SHA-256** | A cryptographic hash function used to hash login OTPs before database storage. |
| **Socket.IO** | A library enabling real-time, bidirectional communication between client and server. |
| **Sweep-Line Algorithm** | An algorithm that checks seat availability per-segment rather than globally, enabling efficient capacity management for overlapping rider segments. |
| **TTL Index** | A MongoDB index that automatically deletes documents after a specified time period. |
| **WebSocket** | A protocol providing full-duplex communication channels over a single TCP connection. Used via Socket.IO. |

---

## Chapter 40: Contact & Support

### 40.1 Getting Help

If you encounter any issues not covered in this manual:

1. **In-App:** Check the Troubleshooting Guide (Chapter 37) and FAQ (Chapter 38).
2. **Email:** Contact the platform administrator at the email address provided by your organization.
3. **GitHub:** For open-source contributions or bug reports, visit the Ridify repository:
   - **Repository:** [github.com/priyanshusharan-cmd/ridify](https://github.com/priyanshusharan-cmd/ridify)
   - **Issues:** Submit bug reports or feature requests via GitHub Issues.

### 40.2 Contributing

Ridify is open-source software licensed under the MIT License. Contributions are welcome:
1. Fork the repository.
2. Create a feature branch.
3. Submit a pull request with a clear description of your changes.

---

## Appendix A: Complete Environment Variable Reference

This appendix documents every environment variable used by the Ridify backend server. All variables are configured in the `backend/.env` file.

### A.1 Server & Database

| Variable | Required? | Default | Description |
|----------|----------|---------|-------------|
| `PORT` | No | `5001` | The TCP port the HTTP server listens on. |
| `NODE_ENV` | No | `development` | Runtime environment. Set to `production` for production deployments. In production, CORS is strictly enforced and error messages are generic. |
| `MONGO_URI` | ✅ Yes | — | MongoDB connection string. Supports both local MongoDB instances (`mongodb://localhost:27017/ridify`) and MongoDB Atlas cloud clusters (`mongodb+srv://...`). |

### A.2 JWT Authentication

| Variable | Required? | Default | Description |
|----------|----------|---------|-------------|
| `JWT_SECRET` | ✅ Yes | — | Secret key for signing JWT access tokens. Must be a strong random string (recommended: 64 bytes hex). Generate with: `node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"` |
| `JWT_REFRESH_SECRET` | ✅ Yes | — | Separate secret key for signing JWT refresh tokens. Must be different from `JWT_SECRET`. Generate with the same command as above. |
| `JWT_EXPIRES_IN` | No | `24h` | How long access tokens remain valid. Accepts values like `15m`, `1h`, `24h`, `7d`. |
| `JWT_REFRESH_EXPIRES_IN` | No | `7d` | How long refresh tokens remain valid before requiring re-authentication. |

### A.3 App Security & Admin

| Variable | Required? | Default | Description |
|----------|----------|---------|-------------|
| `ADMIN_EMAILS` | ✅ Yes | — | Comma-separated list of email addresses that have admin privileges. These users can access the Admin Panel, manage users, and moderate rides. Example: `admin@example.com,moderator@example.com` |
| `ADMIN_SECRET` | ✅ Yes | — | A secret string used for admin API authentication via the `x-admin-secret` header. Generate with: `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"` |
| `ALLOWED_ORIGIN` | No | `*` | Comma-separated list of allowed CORS origins. In production, set this to your frontend's URL. Set to `*` for mobile-only deployments (mobile apps don't send CORS origin headers). |

### A.4 Security Tuning

| Variable | Required? | Default | Description |
|----------|----------|---------|-------------|
| `BCRYPT_ROUNDS` | No | `12` | Number of bcrypt salt rounds for password hashing. Higher values are more secure but slower. 12 is a good balance. |
| `MAX_FIELD_LENGTH` | No | `500` | Maximum character length for text fields (names, emails, search queries). Prevents oversized inputs. |
| `LOG_LEVEL` | No | `debug` | Winston logger level. Options: `debug`, `info`, `warn`, `error`. In production, set to `info` or `warn`. |

### A.5 Socket.IO Configuration

| Variable | Required? | Default | Description |
|----------|----------|---------|-------------|
| `SOCKET_PING_INTERVAL` | No | `25000` (25s) | How frequently the Socket.IO server pings connected clients (in milliseconds). Higher values are more tolerant of poor mobile connections but detect disconnections slower. |
| `SOCKET_PING_TIMEOUT` | No | `20000` (20s) | How long the server waits for a pong response before considering the client disconnected (in milliseconds). Must be less than `SOCKET_PING_INTERVAL`. |

### A.6 Ride Configuration

| Variable | Required? | Default | Description |
|----------|----------|---------|-------------|
| `MAX_ROUTE_POINTS` | No | `500` | Maximum number of GPS coordinates stored in a ride's `routePath` array. Routes with more points are automatically downsampled. Higher values provide more accurate route matching but increase database storage and query time. |
| `MIN_RIDE_DISTANCE_KM` | No | `1.5` | Minimum trip distance (in kilometers) for a rider's segment to be considered a valid match. Prevents trivially short ride matches. |
| `SEARCH_RADIUS_DEFAULT_M` | No | `2000` | Default search radius (in meters) for matching pickup/dropoff points to the driver's route. A rider's pickup/dropoff must be within this distance of the closest route point. |
| `SEARCH_TIME_WINDOW_MS` | No | `3600000` (1 hour) | Maximum time difference (in milliseconds) between the rider's search time and the ride's departure time for a match. Default is 1 hour. |
| `CHAT_MAX_LENGTH` | No | `1000` | Maximum character length for a single chat message. Messages exceeding this length are rejected. |
| `MAX_FARE` | No | `9999` | Maximum fare (in ₹) that a driver can set for a ride. Prevents unreasonable fare entries. |
| `MAX_PRICE_RUPEES` | No | `99999` | Maximum price value exposed via the `/api/config` endpoint for client-side validation. |

### A.7 Email Configuration (EmailJS)

| Variable | Required? | Default | Description |
|----------|----------|---------|-------------|
| `EMAILJS_SERVICE_ID` | ✅ Yes | — | Your EmailJS service ID. Found in your EmailJS dashboard under Email Services. |
| `EMAILJS_TEMPLATE_ID` | ✅ Yes | — | The ID of the email template configured in EmailJS for OTP delivery. The template should have a `{{otp}}` variable placeholder. |
| `EMAILJS_PUBLIC_KEY` | ✅ Yes | — | Your EmailJS public API key. Found in your EmailJS dashboard under Account → API Keys. |
| `EMAILJS_PRIVATE_KEY` | ✅ Yes | — | Your EmailJS private API key. Used for server-side API authentication. |

### A.8 Google Apps Script (KYC Upload)

| Variable | Required? | Default | Description |
|----------|----------|---------|-------------|
| `GOOGLE_APPS_SCRIPT_URL` | ✅ Yes | — | The deployed URL of your Google Apps Script web app that handles KYC document uploads to Google Drive. The script receives a JSON payload with `filename` and `base64` fields and returns `{ status: 'success', url: '<drive_url>' }`. |

### A.9 Domain Restriction

| Variable | Required? | Default | Description |
|----------|----------|---------|-------------|
| `ALLOWED_EMAIL_DOMAIN` | No | *(empty)* | If set, only email addresses ending with `@<this_domain>` can register. Useful for university or corporate deployments. Example: `university.edu`. Leave empty to allow any email domain. |

---

## Appendix B: Server Deployment Guide

### B.1 Prerequisites

| Software | Version | Purpose |
|----------|---------|---------|
| Node.js | 20+ | Backend runtime |
| npm | 9+ | Package manager |
| MongoDB | 7.x | Database (local or MongoDB Atlas) |
| Flutter SDK | 3.x | Frontend build tool |
| Git | Any | Version control |

### B.2 Backend Deployment Steps

```bash
# 1. Clone the repository
git clone https://github.com/priyanshusharan-cmd/ridify.git
cd ridify/backend

# 2. Install dependencies
npm install

# 3. Configure environment
cp .env.example .env
# Edit .env with your actual values (see Appendix A)

# 4. Verify required environment variables
# The server checks for JWT_SECRET, JWT_REFRESH_SECRET, MONGO_URI,
# ADMIN_SECRET, and ADMIN_EMAILS on startup. It exits with an error
# if any are missing or contain placeholder values.

# 5. Start the server
node server.js
# Server will log: 🚀 Server running on http://<your-ip>:<port>
```

### B.3 Frontend Build & Run

```bash
cd ridify/frontend

# 1. Install Flutter dependencies
flutter pub get

# 2. Create frontend environment file
echo 'BASE_URL=http://<your-server-ip>:<port>' > .env
# For Android emulator pointing to host: http://10.0.2.2:5001
# For physical device on same network: http://<lan-ip>:5001

# 3. Run the app
flutter run
```

### B.4 Production Considerations

| Concern | Recommendation |
|---------|---------------|
| **HTTPS** | Place the Node.js server behind a reverse proxy (nginx, Caddy) with TLS certificates. The Helmet middleware's `upgrade-insecure-requests` CSP directive encourages HTTPS. |
| **Database** | Use MongoDB Atlas for managed hosting with automatic backups, or configure replica sets for local deployments. |
| **Process Management** | Use PM2 or systemd to keep the Node.js process running and auto-restart on crashes. |
| **CORS** | Set `ALLOWED_ORIGIN` to your specific frontend URL(s). Never use `*` in production for web clients. |
| **Logging** | Set `LOG_LEVEL=info` or `LOG_LEVEL=warn` in production to reduce log volume. |
| **Rate Limiting** | The default limits (200 req/min global, 1000 auth/15min) are suitable for moderate traffic. Adjust for larger deployments. |
| **Stale Ride Cleanup** | The built-in cleanup job runs every 30 minutes. For production, consider implementing a dedicated ride archival job before TTL deletion. |
| **Monitoring** | Use the `/health` endpoint for uptime monitoring (returns 200 when MongoDB is connected, 503 otherwise). |

### B.5 EmailJS Setup Guide

1. Create an account at [emailjs.com](https://www.emailjs.com/).
2. Add an Email Service (e.g., Gmail, Outlook).
3. Create an Email Template with the following structure:
   ```
   Subject: Your Ridify OTP
   Body: Your OTP code is: {{otp}}
   ```
4. Note down the Service ID, Template ID, Public Key, and Private Key.
5. Add these to your `.env` file.

### B.6 Google Apps Script Setup Guide

1. Open [Google Apps Script](https://script.google.com/).
2. Create a new project.
3. Write a `doPost(e)` function that:
   - Accepts `{ filename, base64 }` as JSON input.
   - Decodes the Base64 data.
   - Creates a file in a designated Google Drive folder.
   - Returns `{ status: 'success', url: '<shareable_drive_url>' }`.
4. Deploy as a Web App with access set to "Anyone".
5. Copy the deployment URL and add it to your `.env` as `GOOGLE_APPS_SCRIPT_URL`.

---

## Appendix C: Complete Screen Inventory

This appendix catalogs every screen in the Ridify Flutter application, its file location, and its purpose.

### C.1 Onboarding & Auth Screens

| Screen | File | Purpose |
|--------|------|---------|
| **Splash Screen** | `splash_screen.dart` | Animated app intro with logo animation. Checks for existing authentication tokens and routes to Home or Login accordingly. |
| **Login Screen** | `login_screen.dart` | Email + password login, OTP login toggle, and "Sign Up" link. Handles both authentication methods. |

### C.2 Main App Screens

| Screen | File | Purpose |
|--------|------|---------|
| **Home Screen** | `home_screen.dart` | Central hub with "Offer a Ride" and "Find a Ride" cards. Shows driver stats and recent activity. Contains the bottom navigation bar. |
| **Find Ride Screen** | `find_ride_screen.dart` | Form to enter pickup/destination, date/time, seats, and vehicle type for ride search. Launches the Map Picker for location selection. |
| **Map Picker Screen** | `map_picker_screen.dart` | Interactive OpenStreetMap with tap-to-select location, search bar (Nominatim geocoding), and GPS current-location button. |
| **Available Rides Screen** | `available_rides_screen.dart` | Displays search results as ride cards with real-time updates. Includes filter popup. |
| **Offer Ride Screen** | `offer_ride_screen.dart` | Form to create a new ride: set route, vehicle type, seats, fare, departure time, and route preference. |
| **Profile Screen** | `profile_screen.dart` | View/edit profile, KYC upload, change password, driver stats, delete account, logout. |

### C.3 Live Ride Screens

| Screen | File | Purpose |
|--------|------|---------|
| **Live Tracking Screen** | `live_tracking_screen.dart` | Real-time map with driver position, route polyline, passenger markers. Controls for arrive/board/dropoff/start/end. Adapts UI based on whether user is driver or rider. |
| **Chat Screen** | `chat_screen.dart` | Per-ride group chat with message list, reply-to support, and real-time message delivery. |

### C.4 Trip Completion Screens

| Screen | File | Purpose |
|--------|------|---------|
| **Driver Completing Screen** | `driver_completing_screen.dart` | Shows trip summary, passenger list, payment statuses, and total earnings after the driver ends a ride. |
| **Rider Completing Screen** | `rider_completing_screen.dart` | Shows trip summary, fare owed, and "Mark as Paid" button after the rider is dropped off. |

### C.5 History & Activity Screens

| Screen | File | Purpose |
|--------|------|---------|
| **Ride History Screen** | `ride_history_screen.dart` | Chronological list of past rides with details, fares, and co-passenger popup. |

### C.6 Admin Screen

| Screen | File | Purpose |
|--------|------|---------|
| **Admin Panel Screen** | `admin_panel_screen.dart` | Full admin interface: dashboard stats, user management (search, view, edit, ban, unban, delete, bulk delete), ride management (list, filter, force-cancel, delete), and KYC verification workflow. |

---

## Appendix D: Frontend Service Layer Reference

### D.1 Services Overview

| Service | File | Purpose |
|---------|------|---------|
| **API Client** | `api_client.dart` | Centralized HTTP client with automatic JWT token attachment, silent refresh on 401, and base URL configuration. |
| **Auth Service** | `auth_service.dart` | Handles signup OTP requests, registration, login (password/OTP), logout, and password change API calls. |
| **Token Service** | `token_service.dart` | Manages secure storage of access and refresh tokens using `flutter_secure_storage`. |
| **Ride Service** | `ride_service.dart` | All ride-related API calls: create, search, request, accept, decline, kick, arrive, board, dropoff, pay, start, end, chat. |
| **Admin Service** | `admin_service.dart` | Admin API calls: list/create/update/delete users, list/delete rides, ban/unban, verify/reject KYC, get stats. |
| **Chat Service** | `chat_service.dart` | Sends chat messages via REST API (Socket.IO handles real-time delivery). |
| **Location Service** | `location_service.dart` | Manages GPS permissions, gets current location, and streams location updates for live tracking. |
| **Nominatim Service** | `nominatim_service.dart` | Reverse geocoding: converts GPS coordinates to human-readable addresses via the Nominatim API. |
| **Config Service** | `config_service.dart` | Fetches server configuration (max field lengths, max fares, etc.) from the `/api/config` endpoint. |
| **Health Service** | `health_service.dart` | Checks server health via the `/health` endpoint. Used to verify connectivity on app startup. |

### D.2 API Client Architecture

The API Client (`api_client.dart`) is the backbone of all HTTP communication:

1. **Base URL:** Loaded from the frontend `.env` file.
2. **Token Management:** Every request automatically includes the `Authorization: Bearer <accessToken>` header.
3. **Silent Refresh:** If a request returns HTTP 401 (Unauthorized), the client:
   - Attempts to refresh the access token using the stored refresh token.
   - If refresh succeeds, retries the original request with the new token.
   - If refresh fails, redirects the user to the Login screen.
4. **Error Handling:** Network errors, timeouts, and server errors are caught and surfaced to the UI layer.

---

## Appendix E: Advanced Troubleshooting Scenarios

### E.1 Ride Shows "Available" But No One Can Request

**Possible causes:**
- The ride has expired (`expiresAt` is in the past). The ride remains in the database but is filtered out of search results.
- The `routePath` has fewer than 2 points, which is invalid.
- The ride's departure time doesn't fall within any searcher's time window.

**Resolution:** Check the ride's `expiresAt` field. If expired, the driver should create a new ride.

### E.2 Optimistic Lock Conflicts Occur Frequently

**Possible cause:** High concurrency — many users are simultaneously requesting or being accepted on the same ride.

**Resolution:** This is expected behavior under heavy load. The system retries automatically up to 5 times with random jitter (20-100ms). If conflicts persist, it may indicate that the MongoDB instance is experiencing write contention. Consider upgrading your database tier or reducing the number of concurrent operations per ride.

### E.3 Chat Messages Not Delivering

**Possible causes:**
1. The recipient lost their Socket.IO room membership due to a mobile data reconnect.
2. The ride has been completed or cancelled (chat is disabled on these statuses).
3. The sender is not a driver, accepted passenger, or boarded passenger.

**Resolution:** Ridify uses dual-channel emission (ride room + personal room) to mitigate cause 1. If messages are still missing, the user should close and reopen the chat screen. Check that the ride status is still active.

### E.4 Driver Location Not Updating on Rider's Map

**Possible causes:**
1. The driver's GPS is turned off or set to low-accuracy mode.
2. The driver's internet connection dropped.
3. The location update cooldown (1.5 seconds) is being enforced.
4. The Socket.IO server verified that the emitting user is not the ride's driver and silently dropped the update.

**Resolution:** Ensure the driver has GPS enabled in high-accuracy mode with a stable internet connection. The rider can send a `request_driver_location` event by tapping the refresh button on the map.

### E.5 KYC Document Upload Fails

**Possible causes:**
1. The `GOOGLE_APPS_SCRIPT_URL` environment variable is not set.
2. The Google Apps Script web app is not properly deployed or has an error.
3. Network connectivity between the Ridify backend and Google's servers is interrupted.
4. The document image exceeds the 1 MB JSON body limit (extremely large photos).

**Resolution:** Check the server logs for the specific error message. Verify the Google Apps Script URL is correct and the script is deployed with "Anyone" access. If the upload fails, the user's verification status is automatically reset to `none`, allowing them to retry.

### E.6 Ride Stuck in "Started" Status

**Possible cause:** The driver force-closed the app without ending the trip, or lost connectivity permanently.

**Resolution:** The server runs a **stale ride cleanup job** every 30 minutes. Any ride stuck in `started` for more than 6 hours is automatically cancelled. Admins can also force-cancel the ride from the Admin Panel at any time.

### E.7 Passenger Shows Wrong Name

**Possible cause:** The passenger updated their profile name after requesting/joining the ride. The cascade should have updated it, but if the cascade failed (e.g., a save error on one of many rides), stale data may remain.

**Resolution:** The admin can trigger a name update via the Admin Panel's user edit feature, which re-cascades the name across all rides.

### E.8 Server Crashes on Startup

**Possible causes:**
1. Missing required environment variables (`JWT_SECRET`, `JWT_REFRESH_SECRET`, `MONGO_URI`, `ADMIN_SECRET`, `ADMIN_EMAILS`).
2. Environment variables contain placeholder values like `your-` or `example.com`.
3. MongoDB is not running or the connection string is incorrect.

**Resolution:** The server checks for these on startup and prints the specific missing variables before exiting: `FATAL: Missing or placeholder env vars: <list>`. Fix the `.env` file and restart.

### E.9 Users Cannot Register (Specific Email Domain Only)

**Possible cause:** The `ALLOWED_EMAIL_DOMAIN` environment variable is set to a specific domain (e.g., `university.edu`), and the user is trying to register with an email from a different domain.

**Resolution:** If intentional (e.g., a university deployment), inform the user they must use their institutional email. If unintentional, clear the `ALLOWED_EMAIL_DOMAIN` variable and restart the server.

### E.10 Ride Auto-Deleted Before User Could View History

**Possible cause:** Completed and cancelled rides are automatically deleted 30 days after their last update via a MongoDB TTL index on the `updatedAt` field (partitioned to only affect `completed` and `cancelled` rides).

**Resolution:** This is by design. For production deployments, implement an archive job that copies ride data to a separate `ride_archive` collection before TTL deletion. The codebase includes a policy comment about this: *"ACTION REQUIRED before production: implement archive job that copies to ride_archive collection."*

---


---

## Appendix G: Accessibility & Usability Best Practices

### G.1 For Users with Visual Impairments

Ridify's Flutter frontend uses semantic widgets that are compatible with screen readers:
- All interactive buttons have descriptive labels.
- Map interactions provide haptic feedback on tap.
- Color contrast ratios meet WCAG 2.1 AA standards in both Light and Dark themes.

### G.2 For Users with Limited Connectivity

Ridify is designed to work gracefully under poor network conditions:

| Feature | Offline Behavior |
|---------|-----------------|
| **Login** | Requires internet. Cached tokens allow re-opening the app without re-authenticating. |
| **Ride Search** | Requires internet to query the server. Cached results are not displayed. |
| **Live Tracking** | Driver location updates pause when connectivity drops and resume automatically upon reconnection. |
| **Chat** | Messages are sent when connectivity is restored. The app does not display unsent messages. |
| **Map Tiles** | OpenStreetMap tiles are cached locally by `flutter_map`. Previously viewed areas remain visible offline. |

### G.3 For Users Unfamiliar with Technology

The following design choices make Ridify accessible to non-technical users:

1. **Clear iconography:** Every action button uses universally understood icons (➕ for Add, ✕ for Cancel, ✓ for Confirm).
2. **Progressive disclosure:** The Home Screen shows only two options (Offer/Find). Advanced features are nested in Profile and Activity tabs.
3. **Error messages in plain language:** Instead of HTTP status codes, users see messages like "Please wait 5 minutes before requesting another OTP" rather than "HTTP 429 Rate Limited."
4. **Visual status indicators:** Ride statuses use color-coded badges — green for active, yellow for pending, red for cancelled.
5. **Confirmation dialogs:** Destructive actions (Delete Account, Cancel Ride, Kick Passenger) always require a confirmation tap.

### G.4 Internationalization (i18n)

The current version of Ridify uses English for all user-facing text. The Flutter frontend is built with i18n-ready architecture — all user-facing strings can be extracted to ARB (Application Resource Bundle) files for translation into other languages in future releases.

### G.5 Font & Text Sizing

- Ridify uses the device's system font size settings. Users who increase their device's font size will see larger text throughout the app.
- All text elements use scalable font units (sp) rather than fixed pixel sizes.
- Long text (addresses, names) is automatically truncated with ellipsis to prevent layout overflow.

---

## Appendix H: Performance Optimization Tips

### H.1 For Drivers

| Tip | Why It Helps |
|-----|-------------|
| **Keep GPS set to "High Accuracy"** | Ensures smooth, accurate location updates on the map. Battery-saving GPS modes may cause jumpy tracking. |
| **Close unused apps** | Frees RAM for Ridify to maintain its WebSocket connection without being killed by the OS. |
| **Use Wi-Fi when creating rides** | Route calculation (OSRM) downloads the full route polyline, which can be several KB. |
| **Limit route length** | Very long routes (cross-country) generate large `routePath` arrays. The server caps at 500 points, but shorter routes provide faster search matching. |

### H.2 For Riders

| Tip | Why It Helps |
|-----|-------------|
| **Set precise pickup/destination** | The more accurate your coordinates, the better the route matching algorithm works. Use the map tap rather than address search for precision. |
| **Use specific vehicle filters** | Filtering by vehicle type reduces the number of rides the server needs to process. |
| **Don't leave the search screen idle** | The global search room keeps your WebSocket connection busy with updates. Leave the screen when you've found a ride. |

### H.3 For Server Administrators

| Optimization | Impact |
|-------------|--------|
| **MongoDB Index Maintenance** | Run `db.rides.getIndexes()` periodically to verify all expected indexes exist. Missing indexes cause slow queries. |
| **Reduce `MAX_ROUTE_POINTS`** | Lower values (e.g., 200) reduce database document size and speed up the sweep-line algorithm, at the cost of slightly less precise route matching. |
| **Tune `SEARCH_RADIUS_DEFAULT_M`** | Smaller radius = fewer matches but faster search. Larger radius = more matches but slower. 2,000m is a good default for urban areas; increase for rural. |
| **Use MongoDB Atlas** | Atlas provides automatic scaling, backups, and performance insights. The free tier (M0) supports up to 500 concurrent connections. |
| **Enable PM2 Cluster Mode** | For multi-core servers, run multiple Node.js instances behind PM2's cluster mode. Socket.IO requires the `@socket.io/cluster-adapter` to work in cluster mode. |
| **Monitor WebSocket Memory** | Each active Socket.IO connection consumes ~5 KB of server memory. For 10,000 concurrent users, expect ~50 MB of WebSocket overhead. |
| **Archive Completed Rides** | Implement an archive job to move completed rides to a separate collection before the 30-day TTL deletes them. This preserves historical data for analytics without growing the primary collection. |

---

## Appendix I: Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | July 2026 | Initial release of the comprehensive user manual. Covers all features of Ridify v1.0 including authentication, ride lifecycle, sweep-line algorithm, admin panel, Socket.IO real-time events, REST API reference, security architecture, and legal policies. |

---


<div align="center">

---

**Ridify User Manual v1.0** · July 2026

Crafted with ❤️ by Priyanshu Sharan

<a href="https://www.linkedin.com/in/priyanshusharan/"><img src="https://upload.wikimedia.org/wikipedia/commons/c/ca/LinkedIn_logo_initials.png" alt="LinkedIn" width="24" height="24"/></a>

Licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

</div>


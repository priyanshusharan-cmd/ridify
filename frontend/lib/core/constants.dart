import 'package:flutter_dotenv/flutter_dotenv.dart';

// IMPORTANT: When building an APK for production (e.g. connecting to Render),
// make sure the BACKEND_URL in frontend/.env points to your Render URL.
String get kBaseUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:5001';



// ── Shared constants ────────────────────────────────────────────────────────
// These mirror the backend env defaults so frontend validation stays in sync.
// They are fetched dynamically via ConfigService at startup.

/// Maximum length for text input fields (name, email, addresses)
int kMaxFieldLength = 500;

/// Maximum length for chat messages
int kMaxMessageLength = 1000;

/// Maximum price in rupees (prevents absurd fare entry)
int kMaxPriceRupees = 99999;

/// Minimum ride distance in km
double kMinRideDistanceKm = 1.5;

/// Maximum route points to send to backend
int kMaxRoutePoints = 500;

/// Default search radius in meters
double kDefaultSearchRadiusM = 1000;

/// Standard HTTP request timeout
const Duration kHttpTimeout = Duration(seconds: 15);

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// The base URL for backend API calls, pulled securely from .env.
/// Falls back to localhost only in debug mode; release builds must set BACKEND_URL.
String get kBaseUrl {
  final url = dotenv.env['BACKEND_URL']?.trim();
  if (url == null || url.isEmpty) {
    if (kDebugMode) {
      debugPrint('WARNING: BACKEND_URL not set, using localhost fallback.');
      return 'http://localhost:5001';
    }
    throw StateError('BACKEND_URL must be set in .env for release builds.');
  }
  if (!kDebugMode && url.startsWith('http://') && !url.contains('localhost')) {
    throw StateError(
      'SECURITY: Production BACKEND_URL must use HTTPS. Got: $url'
    );
  }
  return url;
}

/// Emails that have admin privileges, pulled securely from .env
List<String> get kAdminEmails => [dotenv.env['ADMIN_EMAIL'] ?? ''];

// ── Shared constants ────────────────────────────────────────────────────────
// These mirror the backend env defaults so frontend validation stays in sync.

/// Maximum length for text input fields (name, email, addresses)
const int kMaxFieldLength = 500;

/// Maximum length for chat messages
const int kMaxMessageLength = 1000;

/// Maximum price in rupees (prevents absurd fare entry)
const int kMaxPriceRupees = 99999;

/// Minimum ride distance in km
const double kMinRideDistanceKm = 1.5;

/// Maximum route points to send to backend
const int kMaxRoutePoints = 500;

/// Default search radius in meters
const double kDefaultSearchRadiusM = 1000;

/// Standard HTTP request timeout
const Duration kHttpTimeout = Duration(seconds: 15);

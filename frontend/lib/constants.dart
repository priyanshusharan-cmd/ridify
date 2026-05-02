import 'package:flutter_dotenv/flutter_dotenv.dart';

/// The base URL for backend API calls, pulled from .env or defaulting to production.
String get kBaseUrl => dotenv.env['BACKEND_URL'] ?? "https://ridify.onrender.com";

/// Emails that have admin privileges, pulled from .env or defaulting to a hardcoded list.
List<String> get kAdminEmails => [
      dotenv.env['ADMIN_EMAIL'] ?? 'priyanshu0sharan@gmail.com',
    ];

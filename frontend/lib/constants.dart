import 'package:flutter_dotenv/flutter_dotenv.dart';

/// The base URL for backend API calls, pulled securely from .env
String get kBaseUrl => dotenv.env['BACKEND_URL'] ?? "http://localhost:5001";

/// Emails that have admin privileges, pulled securely from .env
List<String> get kAdminEmails => [dotenv.env['ADMIN_EMAIL'] ?? ''];

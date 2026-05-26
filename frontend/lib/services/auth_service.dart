import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$kBaseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(kHttpTimeout);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Login failed');
    }
  }

  static Future<Map<String, dynamic>> register(String name, String age, String email, String password) async {
    final response = await http.post(
      Uri.parse('$kBaseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'age': age,
        'email': email,
        'password': password,
      }),
    ).timeout(kHttpTimeout);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Registration failed');
    }
  }

  /// Deletes the user's own account. Passes callerEmail in the body for
  /// backend ownership verification.
  static Future<void> deleteAccount(String email) async {
    final response = await http.delete(
      Uri.parse('$kBaseUrl/api/auth/user/$email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'callerEmail': email}),
    ).timeout(kHttpTimeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete account');
    }
  }

  static Future<void> adminDeleteAllUsers(String adminEmail) async {
    final response = await http.delete(
      Uri.parse('$kBaseUrl/api/auth/users'),
      headers: {'x-admin-email': adminEmail},
    ).timeout(kHttpTimeout);
    if (response.statusCode != 200) {
      throw Exception('Failed to wipe users. Are you an admin?');
    }
  }
}

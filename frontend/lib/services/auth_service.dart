import 'dart:convert';
import 'api_client.dart';
import 'token_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await ApiClient.post('/api/auth/login', {'email': email, 'password': password});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await TokenService.saveTokens(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
      );
      return data['user'];
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Login failed');
    }
  }

  static Future<Map<String, dynamic>> register(String name, String age, String email, String password) async {
    final response = await ApiClient.post('/api/auth/register', {
      'name': name,
      'age': age,
      'email': email,
      'password': password,
    });
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await TokenService.saveTokens(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'],
      );
      return data['user'];
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Registration failed');
    }
  }

  static Future<void> deleteAccount(String email) async {
    final response = await ApiClient.delete('/api/auth/user/$email');
    if (response.statusCode != 200) {
      throw Exception('Failed to delete account');
    }
    await TokenService.clearTokens();
  }

  static Future<void> adminDeleteAllUsers(String adminEmail) async {
    // Left as an exercise, or can just use ApiClient (admin rights handled by token soon)
    throw UnimplementedError("Admin routes should use ApiClient");
  }

  static Future<void> logout() async {
    await TokenService.clearTokens();
  }
}

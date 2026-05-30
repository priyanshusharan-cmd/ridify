import 'dart:convert';
import 'api_client.dart';
import 'token_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await ApiClient.post('/api/auth/login', {'email': email, 'password': password});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['accessToken'] == null) {
        throw Exception("Server did not return a JWT. Are you connected to the new backend?");
      }
      await TokenService.saveTokens(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'] ?? '',
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
      // Backend returns { message, email }, not tokens. We do not save tokens here.
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Registration failed');
    }
  }

  static Future<void> requestLoginOtp(String email) async {
    final response = await ApiClient.post('/api/auth/login-otp-request', {'email': email});
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to request OTP');
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    final response = await ApiClient.post('/api/auth/verify-otp', {
      'email': email,
      'otp': otp,
    });
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['accessToken'] == null) {
        throw Exception("Server did not return a JWT.");
      }
      await TokenService.saveTokens(
        accessToken: data['accessToken'],
        refreshToken: data['refreshToken'] ?? '',
      );
      return data['user'];
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'OTP Verification failed');
    }
  }

  static Future<void> resendOtp(String email) async {
    final response = await ApiClient.post('/api/auth/resend-otp', {'email': email});
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to resend OTP');
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
    final response = await ApiClient.delete('/api/auth/users');
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to wipe all users.');
    }
  }

  static Future<void> logout() async {
    try {
      final refreshToken = await TokenService.getRefreshToken();
      await ApiClient.post(
        '/api/auth/logout',
        refreshToken != null ? {'refreshToken': refreshToken} : {},
      );
    } catch (_) {} // best-effort, always clear locally
    await TokenService.clearTokens();
  }

  static Future<Map<String, dynamic>> updateProfile(String email, {String? name, String? age}) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (age != null) body['age'] = age;
    final response = await ApiClient.patch('/api/auth/user/${Uri.encodeComponent(email)}', body);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['user'];
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to update profile.');
  }
}

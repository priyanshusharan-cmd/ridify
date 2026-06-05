import 'dart:convert';
import 'api_client.dart';
import 'token_service.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String email, String password, {String? otp}) async {
    final body = <String, dynamic>{'email': email};
    if (password.isNotEmpty) body['password'] = password;
    if (otp != null && otp.isNotEmpty) body['otp'] = otp;
    final response = await ApiClient.post('/api/auth/login', body);
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

  static Future<Map<String, dynamic>> register(String name, String age, String email, String password, String otp) async {
    final response = await ApiClient.post('/api/auth/register', {
      'name': name,
      'age': age,
      'email': email,
      'password': password,
      'otp': otp,
    });
    if (response.statusCode == 201) {
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
      throw Exception(jsonDecode(response.body)['error'] ?? 'Registration failed');
    }
  }

  static Future<void> requestSignupOtp(String email) async {
    final response = await ApiClient.post('/api/auth/signup-otp-request', {'email': email});
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to request OTP');
    }
  }

  static Future<void> requestLoginOtp(String email) async {
    final response = await ApiClient.post('/api/auth/login-otp-request', {'email': email});
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to request OTP');
    }
  }

  static Future<Map<String, dynamic>> uploadIdForVerification(String email, String base64Data, String filename) async {
    final response = await ApiClient.post('/api/auth/user/${Uri.encodeComponent(email)}/upload-id', {
      'base64': base64Data,
      'filename': filename,
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to upload ID.');
  }

  static Future<Map<String, dynamic>> getVerificationStatus(String email) async {
    final response = await ApiClient.get('/api/auth/user/${Uri.encodeComponent(email)}/verification-status');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to fetch verification status.');
  }

  // verifyOtp and resendOtp removed as they are obsolete in the new flow

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

  static Future<void> changePassword(String currentPassword, String newPassword) async {
    final response = await ApiClient.patch('/api/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to change password.');
    }
  }
}

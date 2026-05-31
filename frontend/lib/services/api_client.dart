import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'token_service.dart';
import '../core/socket_service.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/login_screen.dart';

class ApiClient {
  static Future<Map<String, String>> _authHeaders() async {
    final token = await TokenService.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String path) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$kBaseUrl$path'),
      headers: headers,
    ).timeout(kHttpTimeout);
    return _handleResponse(response, path, 'GET');
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$kBaseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    ).timeout(kHttpTimeout);
    return _handleResponse(response, path, 'POST', body);
  }

  static Future<http.Response> patch(String path, [Map<String, dynamic>? body]) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('$kBaseUrl$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(kHttpTimeout);
    return _handleResponse(response, path, 'PATCH', body);
  }

  static Future<http.Response> delete(String path, {Map<String, dynamic>? body, Map<String, String>? customHeaders}) async {
    final headers = await _authHeaders();
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    final response = await http.delete(
      Uri.parse('$kBaseUrl$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(kHttpTimeout);
    return _handleResponse(response, path, 'DELETE', body);
  }

  static Future<http.Response> _handleResponse(
    http.Response response, String path, String method, [Map<String, dynamic>? body]) async {
    
    // Check for explicit ban or deletion first
    try {
      final decoded = jsonDecode(response.body);
      if (decoded['code'] == 'USER_DELETED' || decoded['code'] == 'ACCOUNT_BANNED') {
        await TokenService.clearTokens();
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
        return response; // Return the response, but they are already logged out
      }
    } catch (_) {}

    if (response.statusCode == 401 && !path.contains('/auth/refresh') && !path.contains('/auth/login') && !path.contains('/auth/verify-otp') && !path.contains('/auth/change-password')) {
      final refreshed = await _attemptRefresh();
      if (refreshed) {
        debugPrint('Token refreshed, retrying: $method $path');
        return _retryRequest(path, method, body);
      } else {
        // Force logout if refresh fails or user is deleted
        await TokenService.clearTokens();
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
    return response;
  }

  static Future<http.Response> _retryRequest(String path, String method, [Map<String, dynamic>? body]) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$kBaseUrl$path');
    switch (method) {
      case 'GET':
        return await http.get(uri, headers: headers).timeout(kHttpTimeout);
      case 'POST':
        return await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(kHttpTimeout);
      case 'PATCH':
        return await http.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null).timeout(kHttpTimeout);
      case 'DELETE':
        return await http.delete(uri, headers: headers, body: body != null ? jsonEncode(body) : null).timeout(kHttpTimeout);
      default:
        throw UnsupportedError('Method $method not supported for retry');
    }
  }

  static Future<bool> _attemptRefresh() async {
    final refreshToken = await TokenService.getRefreshToken();
    if (refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$kBaseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await TokenService.saveTokens(
          accessToken: data['accessToken'],
          refreshToken: refreshToken, // Keep existing refresh token
        );
        SocketService().updateAccessToken(data['accessToken']);
        return true;
      }
    } catch (_) {}
    return false;
  }
}

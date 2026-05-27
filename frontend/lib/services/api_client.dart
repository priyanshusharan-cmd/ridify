import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'token_service.dart';

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
    return _handleResponse(response, path, 'POST');
  }

  static Future<http.Response> patch(String path, [Map<String, dynamic>? body]) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('$kBaseUrl$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(kHttpTimeout);
    return _handleResponse(response, path, 'PATCH');
  }

  static Future<http.Response> delete(String path, [Map<String, dynamic>? body]) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('$kBaseUrl$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ).timeout(kHttpTimeout);
    return _handleResponse(response, path, 'DELETE');
  }

  static Future<http.Response> _handleResponse(
    http.Response response, String path, String method) async {
    if (response.statusCode == 401) {
      // Try token refresh
      final refreshed = await _attemptRefresh();
      if (refreshed) {
        // Retry the request once with new token
        // Recursion guard: only retry if this wasn't already a refresh attempt
        if (!path.contains('/auth/refresh')) {
          // Re-call appropriate method — use a retry flag pattern
          debugPrint('Token refreshed, caller should retry: $method $path');
        }
      }
    }
    return response;
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
        return true;
      }
    } catch (_) {}
    return false;
  }
}

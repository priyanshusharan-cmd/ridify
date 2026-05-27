import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  static final _storage = const FlutterSecureStorage();
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _accessKey, value: accessToken),
        _storage.write(key: _refreshKey, value: refreshToken),
      ]).timeout(const Duration(seconds: 2));
    } catch (e) {
      // Web hot restart occasionally throws here
    }
  }

  static Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessKey).timeout(const Duration(seconds: 2));
    } catch (e) {
      return null;
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshKey).timeout(const Duration(seconds: 2));
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearTokens() async {
    try {
      await Future.wait([
        _storage.delete(key: _accessKey),
        _storage.delete(key: _refreshKey),
      ]).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Error clearing tokens: $e');
    }
  }

  static Future<bool> hasValidToken() async {
    final token = await getAccessToken();
    if (token == null) return false;
    try {
      // Decode JWT payload (no verification — server verifies)
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = parts[1];
      final padded = payload.padRight(
        payload.length + (4 - payload.length % 4) % 4, '=');
      final decoded = String.fromCharCodes(base64Url.decode(padded));
      final Map<String, dynamic> json = jsonDecode(decoded);
      final exp = json['exp'] as int?;
      if (exp == null) return false;
      // Consider token expired 60s early to allow refresh
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000)
          .isAfter(DateTime.now().add(const Duration(seconds: 60)));
    } catch (_) {
      return false;
    }
  }
}

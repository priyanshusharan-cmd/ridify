import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ConfigService {
  /// Fetches shared constants from the backend to ensure frontend validation
  /// stays in sync with backend environment variables.
  static Future<void> fetchConfig() async {
    try {
      final response = await http.get(Uri.parse('$kBaseUrl/api/config')).timeout(kHttpTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['kMaxFieldLength'] != null) kMaxFieldLength = data['kMaxFieldLength'];
        if (data['kMaxMessageLength'] != null) kMaxMessageLength = data['kMaxMessageLength'];
        if (data['kMaxPriceRupees'] != null) kMaxPriceRupees = data['kMaxPriceRupees'];
        if (data['kMinRideDistanceKm'] != null) kMinRideDistanceKm = (data['kMinRideDistanceKm'] as num).toDouble();
        if (data['kMaxRoutePoints'] != null) kMaxRoutePoints = data['kMaxRoutePoints'];
        if (data['kDefaultSearchRadiusM'] != null) kDefaultSearchRadiusM = (data['kDefaultSearchRadiusM'] as num).toDouble();
      }
    } catch (e) {
      // Silently fall back to hardcoded defaults in constants.dart if fetch fails
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      return null;
    }
  }

  static Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      return null;
    }
  }

  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url = "https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng";
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Ridify-App/1.0'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'];
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchOsrmRoute(
    double pickupLng, 
    double pickupLat, 
    double destLng, 
    double destLat, 
    {String overview = 'full'}
  ) async {
    // Note: This uses the public OSRM demo server which has usage limits.
    // In production, you should host your own OSRM instance.
    try {
      final url = "https://router.project-osrm.org/route/v1/driving/"
          "$pickupLng,$pickupLat;$destLng,$destLat"
          "?geometries=geojson&overview=$overview";
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          return data['routes'][0];
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return null;
  }

  static Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high, 
    int distanceFilter = 10
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }
}

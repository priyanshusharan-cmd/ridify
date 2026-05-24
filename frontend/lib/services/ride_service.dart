import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class RideService {
  static Future<List<dynamic>> getAllRides() async {
    final response = await http.get(Uri.parse('$kBaseUrl/api/rides'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load rides');
    }
  }

  static Future<List<dynamic>> searchRides({
    required String pickup,
    required String destination,
    required int seats,
    required String vehicle,
    required String date,
    String? timeEpoch,
    required double lat,
    required double lng,
    required double destLat,
    required double destLng,
    required int radius,
    required String userEmail,
  }) async {
    String url = "$kBaseUrl/api/rides/search"
        "?pickup=${Uri.encodeComponent(pickup)}"
        "&destination=${Uri.encodeComponent(destination)}"
        "&seats=$seats"
        "&vehicle=${Uri.encodeComponent(vehicle)}"
        "&date=${Uri.encodeComponent(date)}"
        "&lat=$lat&lng=$lng"
        "&destLat=$destLat&destLng=$destLng"
        "&radius=$radius"
        "&userEmail=${Uri.encodeComponent(userEmail)}";

    if (timeEpoch != null) {
      url += "&searchTimeEpoch=$timeEpoch";
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to search rides');
    }
  }

  static Future<Map<String, dynamic>> getRideById(String rideId) async {
    final response = await http.get(Uri.parse('$kBaseUrl/api/rides/$rideId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load ride details');
    }
  }

  static Future<Map<String, dynamic>> createRide(Map<String, dynamic> rideData) async {
    final response = await http.post(
      Uri.parse('$kBaseUrl/api/rides'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(rideData),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Server rejected the ride.');
    }
  }

  static Future<void> cancelRide(String rideId) async {
    final response = await http.delete(Uri.parse('$kBaseUrl/api/rides/$rideId'));
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not cancel the ride.');
    }
  }

  static Future<void> requestRide(String rideId, Map<String, dynamic> requestBody) async {
    final response = await http.patch(
      Uri.parse('$kBaseUrl/api/rides/request/$rideId'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(requestBody),
    );
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to request ride.');
    }
  }

  static Future<Map<String, dynamic>> acceptRider(String rideId, String riderName) async {
    final response = await http.patch(Uri.parse('$kBaseUrl/api/rides/accept/$rideId/${Uri.encodeComponent(riderName)}'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not accept rider.');
    }
  }

  static Future<Map<String, dynamic>> declineRider(String rideId, String riderName) async {
    final response = await http.patch(Uri.parse('$kBaseUrl/api/rides/decline/$rideId/${Uri.encodeComponent(riderName)}'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not decline rider.');
    }
  }

  static Future<Map<String, dynamic>> kickPassenger(String rideId, String riderName) async {
    final response = await http.patch(Uri.parse('$kBaseUrl/api/rides/kick/$rideId/${Uri.encodeComponent(riderName)}'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not remove passenger.');
    }
  }

  static Future<void> markDriverArrived(String rideId, String riderName) async {
    final response = await http.patch(Uri.parse('$kBaseUrl/api/rides/arrive/$rideId/${Uri.encodeComponent(riderName)}'));
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not mark arrival.');
    }
  }

  static Future<void> boardPassenger(String rideId, String riderEmail) async {
    final response = await http.patch(Uri.parse('$kBaseUrl/api/rides/board/$rideId/${Uri.encodeComponent(riderEmail)}'));
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not mark boarded.');
    }
  }

  static Future<void> dropOffPassenger(String rideId, String riderEmail) async {
    final response = await http.patch(Uri.parse('$kBaseUrl/api/rides/dropoff/$rideId/${Uri.encodeComponent(riderEmail)}'));
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not mark dropped off.');
    }
  }

  static Future<void> markPaid(String rideId, String riderEmail) async {
    final response = await http.patch(Uri.parse('$kBaseUrl/api/rides/pay/$rideId/${Uri.encodeComponent(riderEmail)}'));
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not mark paid.');
    }
  }

  static Future<Map<String, dynamic>> startRide(String rideId) async {
    final response = await http.patch(Uri.parse('$kBaseUrl/api/rides/start/$rideId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not start ride.');
    }
  }

  static Future<Map<String, dynamic>> endRide(String rideId, {bool force = false}) async {
    final response = await http.patch(Uri.parse('$kBaseUrl/api/rides/end/$rideId?force=$force'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not end trip.');
    }
  }

  static Future<void> adminDeleteAllRides(String adminEmail) async {
    final response = await http.delete(
      Uri.parse('$kBaseUrl/api/rides'),
      headers: {'x-admin-email': adminEmail},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete all rides');
    }
  }
}

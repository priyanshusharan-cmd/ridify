import 'dart:convert';
import 'api_client.dart';

class RideService {
  static Future<List<dynamic>> getAllRides() async {
    final response = await ApiClient.get('/api/rides');
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
    // Identity is sent via token, but we might still have userEmail param for legacy reasons
    String url = "/api/rides/search"
        "?pickup=${Uri.encodeComponent(pickup)}"
        "&destination=${Uri.encodeComponent(destination)}"
        "&seats=$seats"
        "&vehicle=${Uri.encodeComponent(vehicle)}"
        "&date=${Uri.encodeComponent(date)}"
        "&lat=$lat&lng=$lng"
        "&destLat=$destLat&destLng=$destLng"
        "&radius=$radius";

    if (timeEpoch != null) {
      url += "&searchTimeEpoch=$timeEpoch";
    }

    final response = await ApiClient.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to search rides');
    }
  }

  static Future<Map<String, dynamic>> getRideById(String rideId) async {
    final response = await ApiClient.get('/api/rides/$rideId');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load ride details');
    }
  }

  static Future<Map<String, dynamic>> createRide(Map<String, dynamic> rideData) async {
    final response = await ApiClient.post('/api/rides', rideData);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Server rejected the ride.');
    }
  }

  static Future<void> cancelRide(String rideId, {required String callerEmail}) async {
    final response = await ApiClient.patch('/api/rides/cancel/$rideId', {"status": "cancelled"});
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not cancel the ride.');
    }
  }

  static Future<void> requestRide(String rideId, Map<String, dynamic> requestBody) async {
    final body = Map<String, dynamic>.from(requestBody);
    body.remove('callerEmail'); // Ensure it's stripped if still passed
    final response = await ApiClient.patch('/api/rides/request/$rideId', body);
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Failed to request ride.');
    }
  }

  static Future<Map<String, dynamic>> acceptRider(String rideId, String riderName) async {
    final response = await ApiClient.patch('/api/rides/accept/$rideId/${Uri.encodeComponent(riderName)}', {});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not accept rider.');
    }
  }

  static Future<Map<String, dynamic>> declineRider(String rideId, String riderName) async {
    final response = await ApiClient.patch('/api/rides/decline/$rideId/${Uri.encodeComponent(riderName)}', {});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not decline rider.');
    }
  }

  static Future<Map<String, dynamic>> kickPassenger(String rideId, String riderName) async {
    final response = await ApiClient.patch('/api/rides/kick/$rideId/${Uri.encodeComponent(riderName)}', {});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not remove passenger.');
    }
  }

  static Future<void> markDriverArrived(String rideId, String riderName) async {
    final response = await ApiClient.patch('/api/rides/arrive/$rideId/${Uri.encodeComponent(riderName)}', {});
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not mark arrival.');
    }
  }

  static Future<void> boardPassenger(String rideId, String riderEmail) async {
    final response = await ApiClient.patch('/api/rides/board/$rideId/${Uri.encodeComponent(riderEmail)}', {});
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not mark boarded.');
    }
  }

  static Future<void> dropOffPassenger(String rideId, String riderEmail) async {
    final response = await ApiClient.patch('/api/rides/dropoff/$rideId/${Uri.encodeComponent(riderEmail)}', {});
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not mark dropped off.');
    }
  }

  static Future<void> markPaid(String rideId, String riderEmail) async {
    final response = await ApiClient.patch('/api/rides/pay/$rideId/${Uri.encodeComponent(riderEmail)}', {});
    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not mark paid.');
    }
  }

  static Future<Map<String, dynamic>> startRide(String rideId) async {
    final response = await ApiClient.patch('/api/rides/start/$rideId', {});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not start ride.');
    }
  }

  static Future<Map<String, dynamic>> endRide(String rideId, {bool force = false}) async {
    final response = await ApiClient.patch('/api/rides/end/$rideId?force=$force', {});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['error'] ?? 'Could not end trip.');
    }
  }

  static Future<void> adminDeleteAllRides(String adminEmail) async {
    // Unimplemented in ApiClient structure for now
    throw UnimplementedError("Use ApiClient");
  }
}

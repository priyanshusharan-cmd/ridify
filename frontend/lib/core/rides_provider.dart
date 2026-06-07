import 'package:flutter/material.dart';
import '../services/ride_service.dart';
import 'socket_service.dart';

class RidesProvider extends ChangeNotifier {
  List<dynamic> _allRides = [];
  bool _isListening = false;

  List<dynamic> get allRides => _allRides;

  void startPolling() {
    if (_isListening) return;
    _isListening = true;
    fetchRides();
    SocketService().addReconnectCallback(fetchRides);
  }

  void stopPolling() {
    if (!_isListening) return;
    _isListening = false;
    SocketService().removeReconnectCallback(fetchRides);
  }

  void upsertRide(Map<String, dynamic> rideData) {
    final index = _allRides.indexWhere((r) =>
        r['_id'] == rideData['_id'] ||
        (r['rideId'] != null && r['rideId'] == rideData['rideId']));
    if (index != -1) {
      _allRides[index] = rideData;
    } else {
      _allRides.add(rideData);
    }
    notifyListeners();
  }

  void clearRides() {
    _allRides = [];
    notifyListeners();
  }

  Future<void> fetchRides() async {
    try {
      final rides = await RideService.getAllRides();
      _allRides = rides;
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Fetch Error in RidesProvider: $e");
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

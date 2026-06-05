import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ride_service.dart';

class RidesProvider extends ChangeNotifier {
  List<dynamic> _allRides = [];
  Timer? _pollingTimer;

  List<dynamic> get allRides => _allRides;

  void startPolling() {
    if (_pollingTimer != null) return;
    fetchRides();
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      fetchRides();
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
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

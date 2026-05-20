import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/socket_service.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'chat_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import 'rider_completing_screen.dart';
import 'driver_completing_screen.dart';

class LiveTrackingScreen extends StatefulWidget {
  final bool isDriver;
  final bool isAlreadyAccepted;
  final String myName;
  final String myEmail;
  final String otherUserName;
  final String rideId;
  const LiveTrackingScreen({super.key, this.isDriver = false, this.isAlreadyAccepted = false, this.myName = "Me", this.myEmail = "", this.otherUserName = "Group", this.rideId = ""});
  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  late io.Socket socket;
  late bool isAccepted;
  bool isStarted = false;

  Map<String, dynamic>? rideData;
  LatLng? driverPosition;
  LatLng? myPosition;
  List<LatLng> routePoints = [];
  Timer? _routeTimer;
  final MapController mapController = MapController();
  StreamSubscription<Position>? positionStreamSubscription;
  bool _isNavigatingToCompletion = false;
  final List<MapEntry<String, void Function(dynamic)>> _socketListeners = [];

  @override
  void initState() {
    super.initState();
    isAccepted = widget.isDriver || widget.isAlreadyAccepted;
    initSocket();
    syncRideStatus();
    _routeTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchRoute());
    _initLocationTracking();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && driverPosition == null) {
        syncRideStatus();
        if (!widget.isDriver && rideData != null && rideData!['pickupLat'] != null) {
          setState(() => driverPosition = LatLng(rideData!['pickupLat'], rideData!['pickupLng']));
          try { mapController.move(driverPosition!, 15.0); } catch (_) {}
        }
      }
    });
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    void applyFallback() {
      if (mounted) {
        setState(() {
          if (widget.isDriver) {
            driverPosition = const LatLng(12.9716, 77.5946);
            Future.delayed(const Duration(milliseconds: 100), () { try { mapController.move(driverPosition!, 15.0); } catch (_) {} });
          } else { myPosition = const LatLng(12.9716, 77.5946); }
        });
      }
    }
    if (permission == LocationPermission.deniedForever) { applyFallback(); return; }
    try {
      if (widget.isDriver) {
        Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(timeLimit: Duration(seconds: 3)));
        if (mounted) {
          setState(() => driverPosition = LatLng(position.latitude, position.longitude));
          Future.delayed(const Duration(milliseconds: 100), () { mapController.move(driverPosition!, 15.0); });
          socket.emit('driver_location_update', {'rideId': widget.rideId, 'lat': position.latitude, 'lng': position.longitude});
          positionStreamSubscription = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)).listen((Position p) {
            if (mounted) {
              setState(() => driverPosition = LatLng(p.latitude, p.longitude));
              _fitBounds();
              socket.emit('driver_location_update', {'rideId': widget.rideId, 'lat': p.latitude, 'lng': p.longitude});
            }
          });
        }
      } else {
        Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(timeLimit: Duration(seconds: 3)));
        if (mounted) setState(() => myPosition = LatLng(position.latitude, position.longitude));
        positionStreamSubscription = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5)).listen((Position pos) {
          if (mounted) setState(() => myPosition = LatLng(pos.latitude, pos.longitude));
        });
      }
    } catch (e) { debugPrint("GPS Error: $e"); applyFallback(); }
  }

  Future<void> _fetchRoute() async {
    if (rideData == null || driverPosition == null) return;
    if (rideData!['destLat'] == null || rideData!['destLng'] == null) return;
    try {
      final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${driverPosition!.longitude},${driverPosition!.latitude};${rideData!['destLng']},${rideData!['destLat']}?geometries=geojson&overview=simplified');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          if (mounted) setState(() => routePoints = coords.map((c) => LatLng(c[1], c[0])).toList());
        }
      }
    } catch (e) { debugPrint("OSRM Error: $e"); }
  }

  void _fitBounds() {
    if (driverPosition == null) return;
    LatLng? target;
    if (widget.isDriver && rideData != null && rideData!['destLat'] != null) {
      target = LatLng(rideData!['destLat'], rideData!['destLng']);
    } else { target = myPosition; }
    if (target != null) {
      if (driverPosition!.latitude == target.latitude && driverPosition!.longitude == target.longitude) { mapController.move(driverPosition!, 15.0); return; }
      try { mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints([driverPosition!, target]), padding: const EdgeInsets.all(80.0))); } catch (_) { mapController.move(driverPosition!, 15.0); }
    } else { mapController.move(driverPosition!, 15.0); }
  }

  Future<void> syncRideStatus() async {
    if (widget.rideId.isEmpty) return;
    try {
      final response = await http.get(Uri.parse('$kBaseUrl/api/rides/${widget.rideId}'));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        if (!widget.isDriver && !(data['passengers'] ?? []).contains(widget.myEmail) && !(data['boardedPassengers'] ?? []).contains(widget.myEmail) && !(data['droppedPassengers'] ?? []).contains(widget.myEmail)) { _kickSelfOut(); return; }
        // If rider was dropped, navigate to payment
        if (!widget.isDriver && (data['droppedPassengers'] ?? []).contains(widget.myEmail)) {
          int fare = 0;
          final details = data['riderDetails'];
          if (details != null && details[widget.myEmail] != null) fare = details[widget.myEmail]['fare'] ?? 0;
          _triggerPaymentScreen(fare);
          return;
        }
        setState(() {
          bool isFirstLoad = rideData == null;
          rideData = data;
          // Only driver sees completion on status=completed
          if (data['status'] == 'completed' && widget.isDriver) { _triggerCompletionScreen(); return; }
          if (data['status'] == 'started' && !isStarted) isStarted = true;
          if (isFirstLoad) _fetchRoute();
        });
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  /// Register a socket listener with automatic cleanup tracking.
  void _on(String event, void Function(dynamic) handler) {
    socket.on(event, handler);
    _socketListeners.add(MapEntry(event, handler));
  }

  void _removeAllListeners() {
    for (final entry in _socketListeners) {
      socket.off(entry.key, entry.value);
    }
    _socketListeners.clear();
  }

  void initSocket() {
    final socketService = SocketService();
    socket = socketService.socket;
    socketService.joinRide(widget.rideId);

    _on('passenger_boarded', (data) {
      if (data == null) return;
      final map = Map<String, dynamic>.from(data);
      if (mounted && map['rideId'].toString() == widget.rideId) {
        if (map['ride'] != null) {
          setState(() {
            rideData = Map<String, dynamic>.from(map['ride']);
          });
        } else {
          syncRideStatus();
        }
      }
    });
    _on('passenger_dropped', (data) {
      if (data == null) return;
      final map = Map<String, dynamic>.from(data);
      if (mounted && map['rideId'].toString() == widget.rideId) {
        if (!widget.isDriver && map['riderName'] == widget.myEmail) {
          _triggerPaymentScreen(map['fare'] ?? 0);
        } else if (map['ride'] != null) {
          setState(() {
            rideData = Map<String, dynamic>.from(map['ride']);
          });
        } else {
          syncRideStatus();
        }
      }
    });
    _on('driver_arrived', (data) {
      if (data == null) return;
      final map = Map<String, dynamic>.from(data);
      if (mounted && map['rideId'].toString() == widget.rideId) {
        if (map['ride'] != null) {
          setState(() {
            rideData = Map<String, dynamic>.from(map['ride']);
            // Proactively mark as arrived for instantaneous UI update
            if (map['riderName'] == widget.myEmail) {
              List arrived = List.from(rideData!['arrivedAt'] ?? []);
              if (!arrived.contains(widget.myEmail)) arrived.add(widget.myEmail);
              rideData!['arrivedAt'] = arrived;
            }
          });
        }
        syncRideStatus(); // Robust fetch to guarantee state is perfectly synced
        // Only show the banner if this event is specifically for this passenger
        // AND they haven't already boarded (prevents stale re-notifications)
        if (!widget.isDriver &&
            map['riderName'] == widget.myEmail &&
            !(rideData?['boardedPassengers'] ?? []).contains(widget.myEmail)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Driver has arrived! Please board."), backgroundColor: Colors.green));
        }
      }
    });
    _on('ride_started', (data) {
      if (data == null) return;
      final map = Map<String, dynamic>.from(data);
      if (mounted && map['rideId'].toString() == widget.rideId) {
        setState(() {
          isStarted = true;
          if (map['ride'] != null) {
            rideData = Map<String, dynamic>.from(map['ride']);
          } else {
            syncRideStatus();
          }
        });
      }
    });
    _on('passenger_kicked', (data) {
      if (data == null) return;
      final map = Map<String, dynamic>.from(data);
      if (mounted && map['rideId'].toString() == widget.rideId) {
        if (map['ride'] != null) {
          setState(() {
            rideData = Map<String, dynamic>.from(map['ride']);
          });
        }
        if (map['kickedUser'] == widget.myEmail) {
          _kickSelfOut();
        }
      }
    });
    _on('driver_location_update', (data) {
      if (data == null) return;
      final map = Map<String, dynamic>.from(data);
      if (mounted && !widget.isDriver && map['rideId'].toString() == widget.rideId) {
        setState(() => driverPosition = LatLng(map['lat'], map['lng']));
        try {
          _fitBounds();
        } catch (_) {}
      }
    });
    _on('passenger_paid', (data) {
      if (data == null) return;
      final map = Map<String, dynamic>.from(data);
      if (mounted && map['rideId'].toString() == widget.rideId) {
        if (map['ride'] != null) {
          setState(() {
            rideData = Map<String, dynamic>.from(map['ride']);
          });
        }
      }
    });
    // ride_ended: only driver sees the green completion screen
    _on('ride_ended', (data) {
      if (data == null) return;
      final map = Map<String, dynamic>.from(data);
      if (mounted) {
        String id = (map['rideId'] ?? map['_id'] ?? '').toString();
        if (id == widget.rideId) {
          if (widget.isDriver) {
            _triggerCompletionScreen();
          } else {
            final rideMap = map['ride'] as Map<String, dynamic>?;
            if (rideMap != null) {
              List kicked = List.from(rideMap['kicked'] ?? []);
              List declined = List.from(rideMap['declined'] ?? []);
              List passengers = List.from(rideMap['passengers'] ?? []);
              List boarded = List.from(rideMap['boardedPassengers'] ?? []);
              List dropped = List.from(rideMap['droppedPassengers'] ?? []);
              if (kicked.contains(widget.myEmail) || declined.contains(widget.myEmail) || (!passengers.contains(widget.myEmail) && !boarded.contains(widget.myEmail) && !dropped.contains(widget.myEmail))) {
                _kickSelfOut();
                return;
              }
            }

            int fare = 0;
            if (rideMap != null) {
              final details = rideMap['riderDetails'];
              if (details != null && details[widget.myEmail] != null) {
                fare = (details[widget.myEmail]['fare'] as num?)?.toInt() ?? 0;
              }
            }
            _triggerPaymentScreen(fare);
          }
        }
      }
    });
    _on('ride_cancelled', (data) {
      if (data == null) return;
      final map = Map<String, dynamic>.from(data);
      if (mounted && map['rideId'].toString() == widget.rideId) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ride cancelled"), backgroundColor: Colors.red));
      }
    });
  }

  // Driver-only green completion screen
  void _triggerCompletionScreen() {
    if (_isNavigatingToCompletion || !mounted) return;
    _isNavigatingToCompletion = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DriverCompletingScreen(rideId: widget.rideId)));
    });
  }

  // Rider payment screen after drop-off
  void _triggerPaymentScreen(int fareAmount) {
    if (_isNavigatingToCompletion || !mounted) return;
    _isNavigatingToCompletion = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RiderCompletingScreen(isDriver: false, rideId: widget.rideId, myName: widget.myName, myEmail: widget.myEmail, fareAmount: fareAmount)));
    });
  }

  void _kickSelfOut() {

    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      title: const Text("Removed from Ride"), content: const Text("The driver has removed you from this ride."),
      actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.popUntil(context, (route) => route.isFirst); }, child: const Text("OK", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))],
    ));
  }

  Future<void> driverArriveForPassenger(String name) async {
    // Optimistic UI update
    setState(() {
      if (rideData != null) {
        List arrived = List.from(rideData!['arrivedAt'] ?? []);
        if (!arrived.contains(name)) arrived.add(name);
        rideData!['arrivedAt'] = arrived;
      }
    });
    try {
      final response = await http.patch(Uri.parse('$kBaseUrl/api/rides/arrive/${widget.rideId}/$name'));
      if (response.statusCode != 200 && mounted) {
        final error = jsonDecode(response.body)['error'] ?? 'Failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
        syncRideStatus(); // Rollback/Sync
      }
    } catch (e) { debugPrint(e.toString()); syncRideStatus(); }
  }
  Future<void> boardRide() async {
    if (widget.rideId.isEmpty) return;
    // Optimistic UI update
    setState(() {
      if (rideData != null) {
        List boarded = List.from(rideData!['boardedPassengers'] ?? []);
        if (!boarded.contains(widget.myEmail)) boarded.add(widget.myEmail);
        rideData!['boardedPassengers'] = boarded;
      }
    });
    try {
      final response = await http.patch(Uri.parse('$kBaseUrl/api/rides/board/${widget.rideId}/${widget.myEmail}'));
      if (response.statusCode != 200) { 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(jsonDecode(response.body)['error'] ?? "Failed to board"), backgroundColor: Colors.red)); 
        syncRideStatus();
      }
    } catch (e) { debugPrint(e.toString()); syncRideStatus(); }
  }

  void _confirmKickPassenger(String passengerEmail) {
    String displayName = rideData?['riderDetails']?[passengerEmail]?['riderName'] ?? passengerEmail;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Kick Passenger"),
        content: Text("Are you sure you want to kick out $displayName?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              kickPassenger(passengerEmail);
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> kickPassenger(String name) async { 
    // Optimistic UI update
    setState(() {
      if (rideData != null) {
        rideData!['passengers'] = (rideData!['passengers'] as List).where((p) => p != name).toList();
        rideData!['boardedPassengers'] = (rideData!['boardedPassengers'] as List).where((p) => p != name).toList();
        rideData!['arrivedAt'] = (rideData!['arrivedAt'] as List).where((p) => p != name).toList();
      }
    });
    try { 
      final response = await http.patch(Uri.parse('$kBaseUrl/api/rides/kick/${widget.rideId}/$name')); 
      if (response.statusCode != 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(jsonDecode(response.body)['error'] ?? "Failed to kick"), backgroundColor: Colors.red));
        syncRideStatus();
      }
    } catch (e) { debugPrint(e.toString()); syncRideStatus(); } 
  }
  Future<void> _executeDropOff(String name) async { 
    // Optimistic UI update
    setState(() {
      if (rideData != null) {
        rideData!['boardedPassengers'] = (rideData!['boardedPassengers'] as List).where((p) => p != name).toList();
        rideData!['passengers'] = (rideData!['passengers'] as List).where((p) => p != name).toList();
        List dropped = List.from(rideData!['droppedPassengers'] ?? []);
        if (!dropped.contains(name)) dropped.add(name);
        rideData!['droppedPassengers'] = dropped;
      }
    });
    try { await http.patch(Uri.parse('$kBaseUrl/api/rides/dropoff/${widget.rideId}/$name')); } catch (e) { debugPrint(e.toString()); syncRideStatus(); } 
  }

  Future<void> dropOffPassenger(String passengerEmail) async {
    String displayName = rideData?['riderDetails']?[passengerEmail]?['riderName'] ?? passengerEmail;
    int fare = rideData?['riderDetails']?[passengerEmail]?['fare'] ?? 0;
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text("Drop-off $displayName"), content: Text("Collect ₹$fare from $displayName."),
      actions: [TextButton(onPressed: () { Navigator.pop(context); _executeDropOff(passengerEmail); }, child: const Text("Confirm Drop-off", style: TextStyle(color: Colors.green)))],
    ));
  }

  Future<void> endRide() async {
    if (widget.rideId.isEmpty) return;
    List activePassengers = ((rideData?['passengers'] ?? []) as List).where((p) => !(rideData?['droppedPassengers'] ?? []).contains(p)).toList();
    List boardedPassengers = rideData?['boardedPassengers'] ?? [];
    bool canEnd = false;
    String pref = rideData?['routePreference'] ?? 'flexible';
    if (pref == 'nonstop') {
      List unboarded = activePassengers.where((p) => !boardedPassengers.contains(p)).toList();
      canEnd = unboarded.isEmpty;
    } else {
      canEnd = activePassengers.isEmpty && boardedPassengers.isEmpty;
    }
    
    if (!canEnd) { 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot end trip. Passengers still active."), backgroundColor: Colors.red)); 
      return; 
    }

    if (boardedPassengers.isNotEmpty) {
      int totalFare = 0;
      List<String> details = [];
      for (var p in boardedPassengers) {
        String pEmail = p.toString();
        String displayName = rideData?['riderDetails']?[pEmail]?['riderName'] ?? pEmail;
        int fare = (rideData?['riderDetails']?[pEmail]?['fare'] as num?)?.toInt() ?? 0;
        totalFare += fare;
        details.add("$displayName: ₹$fare");
      }
      
      bool? confirm = await showDialog<bool>(
        context: context, 
        builder: (_) => AlertDialog(
          title: const Text("End Ride & Collect Fare"), 
          content: Text("Collect a total of ₹$totalFare.\n\n${details.join('\n')}"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            TextButton(
              onPressed: () => Navigator.pop(context, true), 
              child: const Text("Confirm", style: TextStyle(color: Colors.green))
            )
          ],
        )
      );
      if (confirm != true) return;
    }

    // Optimistic UI update
    setState(() {
      if (rideData != null) rideData!['status'] = 'completed';
    });
    try { 
      final res = await http.patch(Uri.parse('$kBaseUrl/api/rides/end/${widget.rideId}')); 
      if (res.statusCode == 200 && mounted) {
        _triggerCompletionScreen();
      }
    } catch (e) { 
      debugPrint(e.toString()); 
      syncRideStatus(); 
    }
  }
  Future<void> startRide() async { 
    if (widget.rideId.isEmpty) return; 
    // Optimistic UI update
    setState(() {
      isStarted = true;
      if (rideData != null) rideData!['status'] = 'started';
    });
    try { await http.patch(Uri.parse('$kBaseUrl/api/rides/start/${widget.rideId}')); } catch (e) { debugPrint(e.toString()); syncRideStatus(); } 
  }

  // Returns {title, address, lat, lng} for the next stop header
  Map<String, dynamic> _getNextStopInfo() {
    if (rideData == null || !isStarted) return {"title": "Start ride to see stops", "address": "", "lat": null, "lng": null};
    
    String? pref = rideData?['routePreference'];
    if (pref == 'nonstop') {
      return {"title": "Final Destination", "address": rideData?['destination'] ?? "", "lat": rideData?['destLat'], "lng": rideData?['destLng']};
    }

    List<Map<String, dynamic>> wps = [];
    for (var p in (rideData!['passengers'] ?? [])) {
      final d = rideData!['riderDetails']?[p];
      if (d != null) {
        wps.add({"type": "pickup", "passenger": p, "index": d['startIndex'] ?? 0, "location": d['pickupLocation'] ?? "Pickup", "lat": d['pickupLat'], "lng": d['pickupLng']});
        wps.add({"type": "dropoff", "passenger": p, "index": d['endIndex'] ?? 9999, "location": d['destination'] ?? "Drop-off", "lat": d['destLat'], "lng": d['destLng']});
      }
    }
    for (var p in (rideData!['boardedPassengers'] ?? [])) {
      if ((rideData!['passengers'] ?? []).contains(p)) continue; // already added
      final d = rideData!['riderDetails']?[p];
      if (d != null) {
        wps.add({"type": "dropoff", "passenger": p, "index": d['endIndex'] ?? 9999, "location": d['destination'] ?? "Drop-off", "lat": d['destLat'], "lng": d['destLng']});
      }
    }
    wps.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
    
    for (var wp in wps) {
      String p = wp['passenger'];
      if (wp['type'] == 'pickup' && pref != 'shared_start' && !(rideData!['boardedPassengers'] ?? []).contains(p) && !(rideData!['droppedPassengers'] ?? []).contains(p)) {
        String displayName = rideData?['riderDetails']?[p]?['riderName'] ?? p;
        return {"title": "$displayName's Pickup", "address": wp['location'], "lat": wp['lat'], "lng": wp['lng']};
      }
      if (wp['type'] == 'dropoff' && (rideData!['boardedPassengers'] ?? []).contains(p)) {
        String displayName = rideData?['riderDetails']?[p]?['riderName'] ?? p;
        return {"title": "$displayName's Drop", "address": wp['location'], "lat": wp['lat'], "lng": wp['lng']};
      }
    }
    
    return {"title": "Final Destination", "address": rideData?['destination'] ?? "", "lat": rideData?['destLat'], "lng": rideData?['destLng']};
  }

  /// Opens the next stop location in an external map app (Google Maps / Apple Maps).
  Future<void> _openInMaps(double? lat, double? lng, String address) async {
    if (lat == null || lng == null) {
      // Fallback: use address string for search
      if (address.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No location data available"), backgroundColor: Colors.orange));
        return;
      }
      final encoded = Uri.encodeComponent(address);
      final Uri fallbackUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
      if (await canLaunchUrl(fallbackUrl)) {
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // On web or any platform: open Google Maps directions URL (works everywhere)
    final webUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(webUrl)) {
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    } else {
      // Absolute fallback — try without canLaunchUrl check
      await launchUrl(webUrl);
    }
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    positionStreamSubscription?.cancel();
    _removeAllListeners();
    SocketService().leaveRide(widget.rideId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final panelText = isDark ? Colors.white : Colors.black;
    final panelSub = isDark ? Colors.white54 : Colors.grey;
    String driverLabel = widget.isDriver ? "Me (Driver)" : "${widget.otherUserName} (Driver)";

    bool iHaveBoarded = (rideData?['boardedPassengers'] ?? []).contains(widget.myEmail);
    bool iAmArrived = (rideData?['arrivedAt'] ?? []).contains(widget.myEmail);
    bool iAmDropped = (rideData?['droppedPassengers'] ?? []).contains(widget.myEmail);

    String statusText;
    if (isStarted) {
      if (widget.isDriver) { statusText = "In Progress"; }
      else { statusText = iHaveBoarded ? "You're in!" : (iAmArrived ? "Board Now!" : "Arriving"); }
    } else {
      statusText = widget.isDriver ? "Ready to Start" : "Waiting for driver";
    }

    int currentlyOccupied = 0;
    for (var p in (rideData?['boardedPassengers'] ?? [])) { currentlyOccupied += ((rideData?['riderDetails']?[p]?['seats']) ?? 1) as int; }
    int totalCap = rideData?['totalSeats'] ?? 4;

    // Only count passengers who haven't been dropped
    List activePassengers = ((rideData?['passengers'] ?? []) as List).where((p) => !(rideData?['droppedPassengers'] ?? []).contains(p)).toList();
    List boardedPassengers = rideData?['boardedPassengers'] ?? [];
    bool canEnd = false;
    String pref = rideData?['routePreference'] ?? 'flexible';
    if (pref == 'nonstop') {
      List unboarded = activePassengers.where((p) => !boardedPassengers.contains(p)).toList();
      canEnd = unboarded.isEmpty;
    } else {
      canEnd = activePassengers.isEmpty && boardedPassengers.isEmpty;
    }

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, title: const Text("Live Ride Map", style: TextStyle(color: Colors.white)), iconTheme: const IconThemeData(color: Colors.white)),
      body: Stack(children: [
        Positioned.fill(
          child: driverPosition == null ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black)) : FlutterMap(
            mapController: mapController, options: MapOptions(initialCenter: driverPosition!, initialZoom: 15.0),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.ridify', tileProvider: CancellableNetworkTileProvider()),
              if (routePoints.isNotEmpty) PolylineLayer(polylines: [Polyline(points: routePoints, strokeWidth: 5.0, color: Colors.blueAccent)]),
              MarkerLayer(markers: [
                if (!widget.isDriver && myPosition != null) Marker(point: myPosition!, width: 20, height: 20, child: Container(decoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)]))),
                Marker(point: driverPosition!, width: 120, height: 80, child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(padding: const EdgeInsets.all(5), color: Colors.white, child: Text(driverLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black))),
                  const Icon(Icons.directions_car, color: Colors.red, size: 30),
                ])),
              ]),
            ],
          ),
        ),
        // Locate button
        Positioned(top: 20, right: 20, child: Column(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: _fitBounds, 
            child: Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))]), 
              child: const Icon(Icons.my_location, color: Colors.black, size: 20),
            )
          ),
          const SizedBox(height: 12),
          // Compass button – rotates map to face north
          if (driverPosition != null) GestureDetector(
            onTap: () {
              try {
                mapController.rotate(0);
              } catch (_) {}
            },
            child: Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
              ),
              child: StreamBuilder<MapEvent>(
                stream: mapController.mapEventStream,
                builder: (context, snapshot) {
                  double rotation = 0;
                  try { rotation = mapController.camera.rotation; } catch (_) {}
                  // Icons.explore points top-right (45 degrees). We subtract 45 degrees so it points UP when rotation is 0.
                  return Transform.rotate(
                    angle: (-rotation - 45) * (math.pi / 180),
                    child: Icon(
                      Icons.explore,
                      color: rotation.abs() > 1 ? Colors.red : Colors.black,
                      size: 20,
                    ),
                  );
                },
              ),
            ),
          ),
        ])),
        // Next Stop header with dynamic passenger name and address
        if (widget.isDriver && isStarted) Builder(builder: (ctx) {
          final stopInfo = _getNextStopInfo();
          return Positioned(top: 20, left: 20, right: 80, child: GestureDetector(
            onTap: () => _openInMaps(
              (stopInfo['lat'] as num?)?.toDouble(),
              (stopInfo['lng'] as num?)?.toDouble(),
              (stopInfo['address'] as String?) ?? '',
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text("NEXT STOP", style: TextStyle(color: panelSub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(width: 6),
                    Icon(Icons.open_in_new, size: 12, color: panelSub),
                  ]),
                  const SizedBox(height: 4),
                  Text(stopInfo['title'] as String, style: TextStyle(color: panelText, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if ((stopInfo['address'] as String).isNotEmpty) ...[const SizedBox(height: 2), Text(stopInfo['address'] as String, style: TextStyle(color: panelSub, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)],
                ])),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.blue.shade900.withValues(alpha: 0.4) : Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.navigation_rounded, color: isDark ? Colors.blue.shade300 : Colors.blue, size: 20),
                ),
              ]),
            ),
          ));
        }),
        Builder(
          builder: (context) {
            double minSize = widget.isDriver ? 0.32 : 0.25;
            double maxSize = widget.isDriver
                ? (minSize + (activePassengers.length * 0.13)).clamp(minSize + 0.01, 0.85)
                : minSize + 0.01;

            return DraggableScrollableSheet(
              initialChildSize: minSize,
              minChildSize: minSize,
              maxChildSize: maxSize,
              snap: true,
              snapSizes: (widget.isDriver && activePassengers.isNotEmpty) ? [minSize, maxSize] : null,
              builder: (BuildContext context, ScrollController scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: panelBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                      },
                    ).copyWith(scrollbars: false),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      children: [
                        // ── Drag handle ──
                        Center(
                          child: Container(
                            width: 40, height: 5,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : Colors.black26,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        // ── Header row ──
                        Row(children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade900,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Text(
                                isAccepted ? (widget.isDriver ? "G" : widget.otherUserName.substring(0, 1).toUpperCase()) : "?",
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              isAccepted ? (widget.isDriver ? "Ride Group" : widget.otherUserName) : "Finding Match...",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: panelText),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isStarted ? Colors.blue.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isStarted ? Colors.blue : Colors.green)),
                                const SizedBox(width: 6),
                                Text(statusText, style: TextStyle(color: isStarted ? (isDark ? Colors.blue.shade300 : Colors.blue.shade700) : (isDark ? Colors.green.shade300 : Colors.green.shade700), fontWeight: FontWeight.bold, fontSize: 12)),
                              ]),
                            ),
                          ])),
                          // Rider: Board button
                          if (!widget.isDriver && isAccepted && !iHaveBoarded && !iAmDropped)
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !iAmArrived ? Colors.grey.shade300 : (isDark ? const Color(0xFF1B4332) : Colors.green.shade600),
                                foregroundColor: !iAmArrived ? Colors.grey.shade600 : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              onPressed: () {
                                if (!iAmArrived) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wait for the driver to arrive"), backgroundColor: Colors.orange));
                                } else {
                                  boardRide();
                                }
                              },
                              child: const Text("Board", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          // Driver: Start / End button
                          if (widget.isDriver) ...[
                            if (!isStarted)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? const Color(0xFF1A3A5C) : Colors.blue.shade600,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                ),
                                onPressed: startRide,
                                child: const Text("Start", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              )
                            else
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: canEnd ? (isDark ? const Color(0xFF5C1A1A) : Colors.red.shade600) : Colors.grey.shade300,
                                  foregroundColor: canEnd ? Colors.white : Colors.grey.shade600,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                ),
                                onPressed: () {
                                  if (!canEnd) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("There are passengers still in the car"), backgroundColor: Colors.red));
                                  } else {
                                    endRide();
                                  }
                                },
                                child: const Text("End", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                          ],
                        ]),
                        // ── Capacity indicator ──
                        if (widget.isDriver) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF252525) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                            ),
                            child: Row(children: [
                              Icon(Icons.airline_seat_recline_normal, size: 20, color: Colors.blue.shade400),
                              const SizedBox(width: 8),
                              Text("$currentlyOccupied / $totalCap seats occupied", style: TextStyle(color: panelText, fontSize: 14, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ],
                        // ── Passengers (revealed when dragged up) ──
                        if (widget.isDriver && rideData != null && activePassengers.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text("Passengers", style: TextStyle(fontWeight: FontWeight.bold, color: panelSub, fontSize: 14, letterSpacing: 0.5)),
                          const SizedBox(height: 12),
                          ...activePassengers.map<Widget>((p) {
                            bool isBoarded = (rideData!['boardedPassengers'] ?? []).contains(p);
                            bool isArrived = (rideData!['arrivedAt'] ?? []).contains(p);
                            int neededSeats = ((rideData?['riderDetails']?[p]?['seats']) ?? 1) as int;
                            bool canFit = (currentlyOccupied + neededSeats) <= totalCap;
                            String? pickupAddr = rideData?['riderDetails']?[p]?['pickupLocation'];
                            String? destAddr = rideData?['riderDetails']?[p]?['destination'];
                            String subtitle = isBoarded ? "Boarded ✓" : (isArrived ? "Arrived — waiting to board" : "Picking up soon");
                            String addrText = isBoarded ? (destAddr ?? "") : (pickupAddr ?? "");
                            String displayName = rideData?['riderDetails']?[p]?['riderName'] ?? p.toString();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Row(children: [
                                Container(
                                  width: 48, height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [Colors.blue.shade400, Colors.blue.shade700],
                                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      displayName.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(displayName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: panelText)),
                                  const SizedBox(height: 2),
                                  Text(subtitle, style: TextStyle(color: isBoarded ? Colors.green.shade600 : Colors.orange.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
                                  if (addrText.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      Icon(Icons.location_on, size: 12, color: panelSub),
                                      const SizedBox(width: 4),
                                      Expanded(child: Text(addrText, style: TextStyle(color: panelSub, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    ]),
                                  ],
                                ])),
                                const SizedBox(width: 8),
                                if (isBoarded) ...[
                                  if (rideData?['routePreference'] != 'nonstop') ...[
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        backgroundColor: Colors.red.shade50,
                                        foregroundColor: Colors.red.shade700,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () => dropOffPassenger(p),
                                      child: const Text("Drop-off", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  IconButton(
                                    onPressed: () => _confirmKickPassenger(p),
                                    icon: Icon(Icons.person_remove_rounded, color: Colors.red.shade300, size: 22),
                                    style: IconButton.styleFrom(backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100),
                                  ),
                                ] else ...[
                                  if (!isArrived && rideData?['routePreference'] != 'nonstop' && rideData?['routePreference'] != 'shared_start') ...[
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        backgroundColor: (canFit && isStarted) ? Colors.green.shade50 : Colors.grey.shade100,
                                        foregroundColor: (canFit && isStarted) ? Colors.green.shade700 : Colors.grey.shade600,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {
                                        if (!isStarted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("First start the ride"), backgroundColor: Colors.orange));
                                        } else if (!canFit) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Car capacity reached"), backgroundColor: Colors.red));
                                        } else {
                                          driverArriveForPassenger(p);
                                        }
                                      },
                                      child: Text((canFit && isStarted) ? "Arrived" : (isStarted ? "Full" : "Arrived"), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  IconButton(
                                    onPressed: () => _confirmKickPassenger(p),
                                    icon: Icon(Icons.person_remove_rounded, color: Colors.red.shade300, size: 22),
                                    style: IconButton.styleFrom(backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100),
                                  ),
                                ],
                              ]),
                            );
                          }),
                        ],
                        // ── Chat button (always at bottom of list) ──
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF333333) : Colors.black,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(myName: widget.myName, myEmail: widget.myEmail, otherName: widget.isDriver ? "Group" : widget.otherUserName, rideId: widget.rideId))),
                            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                            label: const Text("Chat", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ]),
    );
  }
}


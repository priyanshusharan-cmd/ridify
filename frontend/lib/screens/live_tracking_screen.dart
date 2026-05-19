import 'package:flutter/material.dart';
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
import 'completion_screen.dart';

class LiveTrackingScreen extends StatefulWidget {
  final bool isDriver;
  final bool isAlreadyAccepted;
  final String myName;
  final String otherUserName;
  final String rideId;
  const LiveTrackingScreen({super.key, this.isDriver = false, this.isAlreadyAccepted = false, this.myName = "Me", this.otherUserName = "Group", this.rideId = ""});
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
        if (!widget.isDriver && !(data['passengers'] ?? []).contains(widget.myName) && !(data['boardedPassengers'] ?? []).contains(widget.myName) && !(data['droppedPassengers'] ?? []).contains(widget.myName)) { _kickSelfOut(); return; }
        // If rider was dropped, navigate to payment
        if (!widget.isDriver && (data['droppedPassengers'] ?? []).contains(widget.myName)) {
          int fare = 0;
          final details = data['riderDetails'];
          if (details != null && details[widget.myName] != null) fare = details[widget.myName]['fare'] ?? 0;
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
        if (!widget.isDriver && map['riderName'] == widget.myName) {
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
            if (map['riderName'] == widget.myName) {
              List arrived = List.from(rideData!['arrivedAt'] ?? []);
              if (!arrived.contains(widget.myName)) arrived.add(widget.myName);
              rideData!['arrivedAt'] = arrived;
            }
          });
        }
        syncRideStatus(); // Robust fetch to guarantee state is perfectly synced
        // Only show the banner if this event is specifically for this passenger
        // AND they haven't already boarded (prevents stale re-notifications)
        if (!widget.isDriver &&
            map['riderName'] == widget.myName &&
            !(rideData?['boardedPassengers'] ?? []).contains(widget.myName)) {
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
        if (map['kickedUser'] == widget.myName) {
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
      if (mounted && widget.isDriver) {
        String id = (map['rideId'] ?? map['_id'] ?? '').toString();
        if (id == widget.rideId) {
          _triggerCompletionScreen();
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
    });
  }

  // Rider payment screen after drop-off
  void _triggerPaymentScreen(int fareAmount) {
    if (_isNavigatingToCompletion || !mounted) return;
    _isNavigatingToCompletion = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompletionScreen(isDriver: false, rideId: widget.rideId, myName: widget.myName, fareAmount: fareAmount)));
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
        if (!boarded.contains(widget.myName)) boarded.add(widget.myName);
        rideData!['boardedPassengers'] = boarded;
      }
    });
    try {
      final response = await http.patch(Uri.parse('$kBaseUrl/api/rides/board/${widget.rideId}/${widget.myName}'));
      if (response.statusCode != 200 && mounted) { 
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(jsonDecode(response.body)['error'] ?? "Failed to board"), backgroundColor: Colors.red)); 
        syncRideStatus();
      }
    } catch (e) { debugPrint(e.toString()); syncRideStatus(); }
  }

  void _confirmKickPassenger(String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Kick Passenger"),
        content: Text("Are you sure you want to kick out $name?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.black)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              kickPassenger(name);
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
    try { await http.patch(Uri.parse('$kBaseUrl/api/rides/kick/${widget.rideId}/$name')); } catch (e) { debugPrint(e.toString()); syncRideStatus(); } 
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

  Future<void> dropOffPassenger(String name) async {
    int fare = rideData?['riderDetails']?[name]?['fare'] ?? 0;
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text("Drop-off $name"), content: Text("Collect ₹$fare from $name."),
      actions: [TextButton(onPressed: () { Navigator.pop(context); _executeDropOff(name); }, child: const Text("Confirm Drop-off", style: TextStyle(color: Colors.green)))],
    ));
  }

  Future<void> endRide() async {
    if (widget.rideId.isEmpty) return;
    List bp = rideData?['boardedPassengers'] ?? [];
    List ps = rideData?['passengers'] ?? [];
    if (bp.isNotEmpty || ps.isNotEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot end trip. Passengers still active."), backgroundColor: Colors.red)); return; }
    // Optimistic UI update
    setState(() {
      if (rideData != null) rideData!['status'] = 'completed';
    });
    try { await http.patch(Uri.parse('$kBaseUrl/api/rides/end/${widget.rideId}')); } catch (e) { debugPrint(e.toString()); syncRideStatus(); }
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
        return {"title": "$p's Pickup", "address": wp['location'], "lat": wp['lat'], "lng": wp['lng']};
      }
      if (wp['type'] == 'dropoff' && (rideData!['boardedPassengers'] ?? []).contains(p)) {
        return {"title": "$p's Drop", "address": wp['location'], "lat": wp['lat'], "lng": wp['lng']};
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

    bool iHaveBoarded = (rideData?['boardedPassengers'] ?? []).contains(widget.myName);
    bool iAmArrived = (rideData?['arrivedAt'] ?? []).contains(widget.myName);
    bool iAmDropped = (rideData?['droppedPassengers'] ?? []).contains(widget.myName);

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
    bool canEnd = activePassengers.isEmpty && (rideData?['boardedPassengers'] ?? []).isEmpty;

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
          GestureDetector(onTap: _fitBounds, child: Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))]), child: const Icon(Icons.my_location, color: Colors.black, size: 20))),
          const SizedBox(height: 12),
          // Compass button – rotates map to face north
          if (driverPosition != null) GestureDetector(
            onTap: () {
              try {
                mapController.rotate(0);
              } catch (_) {}
            },
            child: Container(
              padding: const EdgeInsets.all(10),
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
                  return Transform.rotate(
                    angle: -rotation * (math.pi / 180),
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
        // Bottom panel
        Align(alignment: Alignment.bottomCenter, child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: panelBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header row
            Row(children: [
              CircleAvatar(backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.black, child: Text(isAccepted ? (widget.isDriver ? "G" : widget.otherUserName.substring(0, 1).toUpperCase()) : "?", style: const TextStyle(color: Colors.white))),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isAccepted ? (widget.isDriver ? "Ride Group" : widget.otherUserName) : "Finding Match...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: panelText), maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isStarted ? Colors.blue : Colors.green)),
                  const SizedBox(width: 6),
                  Text(statusText, style: TextStyle(color: isStarted ? (isDark ? Colors.blue.shade300 : Colors.blue) : (isDark ? Colors.green.shade300 : Colors.green), fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ])),
              // Rider: Board button (grey until arrived, shows snackbar)
              if (!widget.isDriver && isAccepted && !iHaveBoarded && !iAmDropped)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: !iAmArrived ? Colors.grey : (isDark ? const Color(0xFF1B4332) : Colors.green)),
                  onPressed: () {
                    if (!iAmArrived) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wait for the driver to arrive"), backgroundColor: Colors.orange));
                    } else {
                      boardRide();
                    }
                  },
                  child: const Text("Board", style: TextStyle(color: Colors.white)),
                ),
              // Driver: Start / Arrive disabled until started / End disabled until empty
              if (widget.isDriver) ...[
                if (!isStarted) ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFF1A3A5C) : Colors.blue), onPressed: startRide, child: const Text("Start", style: TextStyle(color: Colors.white)))
                else ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: canEnd ? (isDark ? const Color(0xFF5C1A1A) : Colors.red) : Colors.grey),
                  onPressed: () {
                    if (!canEnd) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("There are passengers still in the car"), backgroundColor: Colors.red));
                    } else {
                      endRide();
                    }
                  },
                  child: const Text("End", style: TextStyle(color: Colors.white)),
                ),
              ],
            ]),
            // Capacity indicator
            if (widget.isDriver && isStarted) ...[
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.airline_seat_recline_normal, size: 16, color: panelSub),
                const SizedBox(width: 6),
                Text("$currentlyOccupied / $totalCap seats occupied", style: TextStyle(color: panelSub, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ],
            // Passenger list (driver view)
            if (widget.isDriver && rideData != null && activePassengers.isNotEmpty) ...[
              Divider(height: 20, color: isDark ? Colors.white24 : Colors.black12),
              Align(alignment: Alignment.centerLeft, child: Text("Passengers", style: TextStyle(fontWeight: FontWeight.bold, color: panelSub, fontSize: 13))),
              const SizedBox(height: 4),
              ConstrainedBox(constraints: const BoxConstraints(maxHeight: 220), child: ListView(shrinkWrap: true, children: activePassengers.map<Widget>((p) {
                bool isBoarded = (rideData!['boardedPassengers'] ?? []).contains(p);
                bool isArrived = (rideData!['arrivedAt'] ?? []).contains(p);
                int neededSeats = ((rideData?['riderDetails']?[p]?['seats']) ?? 1) as int;
                bool canFit = (currentlyOccupied + neededSeats) <= totalCap;
                String? pickupAddr = rideData?['riderDetails']?[p]?['pickupLocation'];
                String? destAddr = rideData?['riderDetails']?[p]?['destination'];
                String subtitle = isBoarded ? "Boarded ✓" : (isArrived ? "Arrived — waiting to board" : "Picking up soon");
                String addrText = isBoarded ? (destAddr ?? "") : (pickupAddr ?? "");
                // Truncate address
                if (addrText.length > 40) addrText = "${addrText.substring(0, 40)}...";

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF252525) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isBoarded ? Colors.green.withValues(alpha: 0.3) : (isDark ? Colors.white10 : Colors.black12)),
                  ),
                  child: Row(children: [
                    CircleAvatar(radius: 16, backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200], child: Text(p.toString().substring(0, 1).toUpperCase(), style: TextStyle(color: panelText, fontWeight: FontWeight.bold, fontSize: 13))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: panelText)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: isBoarded ? (isDark ? Colors.green.shade300 : Colors.green) : Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
                      if (addrText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(addrText, style: TextStyle(color: panelSub, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ])),
                    // Action buttons - kick always visible
                    if (isBoarded) ...[
                      if (rideData?['routePreference'] != 'nonstop') ...[
                        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(70, 32), padding: const EdgeInsets.symmetric(horizontal: 10)), onPressed: () => dropOffPassenger(p), child: const Text("Drop-off", style: TextStyle(color: Colors.white, fontSize: 11))),
                        const SizedBox(width: 6),
                      ],
                      GestureDetector(onTap: () => _confirmKickPassenger(p), child: const Icon(Icons.person_remove, color: Colors.redAccent, size: 20)),
                    ] else ...[
                      if (!isArrived && rideData?['routePreference'] != 'nonstop' && rideData?['routePreference'] != 'shared_start') ...[
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: (canFit && isStarted) ? Colors.green : Colors.grey, minimumSize: const Size(70, 32), padding: const EdgeInsets.symmetric(horizontal: 10)),
                          onPressed: () {
                            if (!isStarted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("First start the ride"), backgroundColor: Colors.orange));
                            } else if (!canFit) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Car capacity reached"), backgroundColor: Colors.red));
                            } else {
                              driverArriveForPassenger(p);
                            }
                          },
                          child: Text((canFit && isStarted) ? "Arrived" : (isStarted ? "Full" : "Arrived"), style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      GestureDetector(onTap: () => _confirmKickPassenger(p), child: const Icon(Icons.person_remove, color: Colors.redAccent, size: 20)),
                    ],
                  ]),
                );
              }).toList())),
            ],
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.black),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(myName: widget.myName, otherName: widget.isDriver ? "Group" : widget.otherUserName, rideId: widget.rideId))),
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white), label: const Text("Chat", style: TextStyle(color: Colors.white)),
            )),
          ]),
        )),
      ]),
    );
  }
}

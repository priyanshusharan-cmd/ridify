import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/socket_service.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ride_service.dart';
import '../services/location_service.dart';
import 'rider_completing_screen.dart';
import 'driver_completing_screen.dart';
import '../main.dart';
import '../widgets/live_tracking/animated_marker.dart';
import '../widgets/live_tracking/ride_status_panel.dart';
import '../widgets/live_tracking/next_stop_header.dart';

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
  String get myEmailLower => widget.myEmail.trim().toLowerCase();
  
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
  
  bool _locationTimedOut = false;
  Timer? _locationTimeoutTimer;
  bool _processingAction = false;

  @override
  void initState() {
    super.initState();
    isAccepted = widget.isDriver || widget.isAlreadyAccepted;
    initSocket();
    syncRideStatus();
    _routeTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchRoute());
    _initLocationTracking();
    
    _locationTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && driverPosition == null) {
        setState(() => _locationTimedOut = true);
      }
    });

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

    final position = await LocationService.getCurrentPosition();
    if (position == null) {
      applyFallback();
      return;
    }

    try {
      if (widget.isDriver) {
        if (mounted) {
          setState(() => driverPosition = LatLng(position.latitude, position.longitude));
          Future.delayed(const Duration(milliseconds: 100), () { mapController.move(driverPosition!, 15.0); });
          socket.emit('driver_location_update', {'rideId': widget.rideId, 'lat': position.latitude, 'lng': position.longitude});
          positionStreamSubscription = LocationService.getPositionStream(distanceFilter: 10).listen((Position p) {
            if (mounted) {
              setState(() => driverPosition = LatLng(p.latitude, p.longitude));
              _fitBounds();
              socket.emit('driver_location_update', {'rideId': widget.rideId, 'lat': p.latitude, 'lng': p.longitude});
            }
          });
        }
      } else {
        if (mounted) setState(() => myPosition = LatLng(position.latitude, position.longitude));
        // Cancel the stream subscription setup for passengers
        return; // Don't set up positionStreamSubscription for passengers
      }
    } catch (e) { debugPrint("GPS Error: $e"); applyFallback(); }
  }

  Future<void> _fetchRoute() async {
    if (rideData == null || driverPosition == null) return;
    if (rideData!['destLat'] == null || rideData!['destLng'] == null) return;
    try {
      final route = await LocationService.fetchOsrmRoute(
        driverPosition!.longitude, driverPosition!.latitude,
        (rideData!['destLng'] as num).toDouble(), (rideData!['destLat'] as num).toDouble(),
        overview: 'simplified'
      );
      if (route != null) {
        final coords = route['geometry']['coordinates'] as List;
        if (mounted) setState(() => routePoints = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList());
      }
    } catch (e) { debugPrint("OSRM Error: $e"); }
  }

  void _fitBounds() {
    if (driverPosition == null) return;
    List<LatLng> points = [driverPosition!];
    
    // Always add destination to bounds so the map isn't zoomed in too close
    if (rideData != null && rideData!['destLat'] != null) {
      points.add(LatLng((rideData!['destLat'] as num).toDouble(), (rideData!['destLng'] as num).toDouble()));
    }
    
    if (myPosition != null) {
      points.add(myPosition!);
    }
    
    try {
      if (points.length == 1) {
        mapController.move(driverPosition!, 15.0);
        return;
      }
      final bounds = LatLngBounds.fromPoints(points);
      if (bounds.southWest.latitude == bounds.northEast.latitude && 
          bounds.southWest.longitude == bounds.northEast.longitude) {
        mapController.move(driverPosition!, 15.0);
        return;
      }
      mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80.0)));
    } catch (_) {
      try { mapController.move(driverPosition!, 15.0); } catch (_) {}
    }
  }

  bool _syncInProgress = false;

  Future<void> syncRideStatus() async {
    if (_syncInProgress) return;
    _syncInProgress = true;
    try {
      if (widget.rideId.isEmpty) return;
      final data = await RideService.getRideById(widget.rideId);
      if (!mounted) return;
      
      if (!widget.isDriver &&
          !(data['passengers'] ?? []).contains(myEmailLower) &&
          !(data['boardedPassengers'] ?? []).contains(myEmailLower) &&
          !(data['droppedPassengers'] ?? []).contains(myEmailLower)) {
        _kickSelfOut();
        return;
      }
      if (!widget.isDriver &&
          (data['droppedPassengers'] ?? []).contains(myEmailLower)) {
        int fare = 0;
        final details = data['riderDetails'];
        if (details != null && details[myEmailLower] != null) {
          fare = (details[myEmailLower]['fare'] as num?)?.toInt() ?? 0;
        }
        _triggerPaymentScreen(fare);
        return;
      }
      setState(() {
        final bool isFirstLoad = rideData == null;
        rideData = data;
        if (data['status'] == 'completed' && widget.isDriver) {
          _triggerCompletionScreen();
          return;
        }
        if (data['status'] == 'started' && !isStarted) isStarted = true;
        if (isFirstLoad) _fetchRoute();
      });
    } catch (e) {
      debugPrint('syncRideStatus error: $e');
      // Don't rethrow — sync failures should not crash the screen
    } finally {
      _syncInProgress = false; // ALWAYS reset, even on exception
    }
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
    _removeAllListeners();
    final socketService = SocketService();
    socket = socketService.socket;
    socketService.joinRide(widget.rideId);

    if (!widget.isDriver) {
      socket.emit('request_driver_location', {'rideId': widget.rideId});
    }

    _on('request_driver_location', (data) {
      if (widget.isDriver && driverPosition != null) {
        socket.emit('driver_location_update', {'rideId': widget.rideId, 'lat': driverPosition!.latitude, 'lng': driverPosition!.longitude});
      }
    });

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
        if (!widget.isDriver && map['riderName'] == myEmailLower) {
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
            if (map['riderName'] == myEmailLower) {
              List arrived = List.from(rideData!['arrivedAt'] ?? []);
              if (!arrived.contains(myEmailLower)) arrived.add(myEmailLower);
              rideData!['arrivedAt'] = arrived;
            }
          });
        }
        syncRideStatus(); // Robust fetch to guarantee state is perfectly synced
        // Only show the banner if this event is specifically for this passenger
        // AND they haven't already boarded (prevents stale re-notifications)
        if (!widget.isDriver &&
            map['riderName'] == myEmailLower &&
            !(rideData?['boardedPassengers'] ?? []).contains(myEmailLower)) {
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
        if (map['kickedUser'] == myEmailLower) {
          _kickSelfOut();
        }
      }
    });
    _on('driver_location_update', (data) {
      if (data == null) return;
      final map = Map<String, dynamic>.from(data);
      if (mounted && !widget.isDriver && map['rideId'].toString() == widget.rideId) {
        bool wasNull = driverPosition == null;
        setState(() => driverPosition = LatLng((map['lat'] as num).toDouble(), (map['lng'] as num).toDouble()));
        if (wasNull) {
          Future.delayed(const Duration(milliseconds: 100), () {
            _fetchRoute();
            _fitBounds();
          });
        } else {
          try {
            _fitBounds();
          } catch (_) {}
        }
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
          final rideMap = map['ride'] as Map<String, dynamic>?;
          if (rideMap != null) {
            setState(() {
              rideData = rideMap;
            });
          }
          if (widget.isDriver) {
            _triggerCompletionScreen();
          } else {
            if (rideMap != null) {
              List kicked = List.from(rideMap['kicked'] ?? []);
              List declined = List.from(rideMap['declined'] ?? []);
              List passengers = List.from(rideMap['passengers'] ?? []);
              List boarded = List.from(rideMap['boardedPassengers'] ?? []);
              List dropped = List.from(rideMap['droppedPassengers'] ?? []);
              if (kicked.contains(myEmailLower) || declined.contains(myEmailLower) || (!passengers.contains(myEmailLower) && !boarded.contains(myEmailLower) && !dropped.contains(myEmailLower))) {
                _kickSelfOut();
                return;
              }
            }

            int fare = 0;
            if (rideMap != null) {
              final details = rideMap['riderDetails'];
              if (details != null && details[myEmailLower] != null) {
                fare = (details[myEmailLower]['fare'] as num?)?.toInt() ?? 0;
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
      if (mounted && map['rideId'].toString() == widget.rideId && !_isNavigatingToCompletion) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ride cancelled"), backgroundColor: Colors.red));
      }
    });
  }

  // Driver-only green completion screen
  void _triggerCompletionScreen() {
    if (_isNavigatingToCompletion || !mounted) {
      return;
    }
    if (navigatedRides.contains(widget.rideId)) return;
    navigatedRides.add(widget.rideId);
    _isNavigatingToCompletion = true;
    // Delay to ensure dialog is fully closed and context is stable
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => DriverCompletingScreen(rideId: widget.rideId, initialRideData: rideData)));
    });
  }

  // Rider payment screen after drop-off
  void _triggerPaymentScreen(int fareAmount) {
    if (_isNavigatingToCompletion || !mounted) return;
    if (navigatedRides.contains(widget.rideId)) return;
    navigatedRides.add(widget.rideId);
    _isNavigatingToCompletion = true;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => RiderCompletingScreen(isDriver: false, rideId: widget.rideId, myName: widget.myName, myEmail: widget.myEmail, fareAmount: fareAmount, initialRideData: rideData)));
    });
  }

  void _kickSelfOut() {

    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      title: const Text("Removed from Ride"), content: const Text("The driver has removed you from this ride."),
      actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.popUntil(context, (route) => route.isFirst); }, child: const Text("OK", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))],
    ));
  }

  Future<void> driverArriveForPassenger(String name) async {
    if (_processingAction) return;
    _processingAction = true;
    // Optimistic UI update
    setState(() {
      if (rideData != null) {
        List arrived = List.from(rideData!['arrivedAt'] ?? []);
        if (!arrived.contains(name)) arrived.add(name);
        rideData!['arrivedAt'] = arrived;
      }
    });
    try {
      await RideService.markDriverArrived(widget.rideId, name);
    } catch (e) { debugPrint(e.toString()); syncRideStatus(); } finally {
      if (mounted) _processingAction = false;
    }
  }
  Future<void> boardRide() async {
    if (widget.rideId.isEmpty || _processingAction) return;
    setState(() => _processingAction = true);

    try {
      await RideService.boardPassenger(widget.rideId, myEmailLower);
      // Success — socket event 'passenger_boarded' will update UI
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        String msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
      syncRideStatus();
    } finally {
      if (mounted) setState(() => _processingAction = false);
    }
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
    if (_processingAction) return;
    _processingAction = true;
    // Optimistic UI update
    setState(() {
      if (rideData != null) {
        rideData!['passengers'] = (rideData!['passengers'] as List).where((p) => p != name).toList();
        rideData!['boardedPassengers'] = (rideData!['boardedPassengers'] as List).where((p) => p != name).toList();
        rideData!['arrivedAt'] = (rideData!['arrivedAt'] as List).where((p) => p != name).toList();
      }
    });
    try { 
      await RideService.kickPassenger(widget.rideId, name);
    } catch (e) { debugPrint(e.toString()); syncRideStatus(); } finally {
      if (mounted) _processingAction = false;
    }
  }
  Future<void> _executeDropOff(String name) async {
    if (_processingAction) return;
    _processingAction = true;
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
    try { await RideService.dropOffPassenger(widget.rideId, name); } catch (e) { debugPrint(e.toString()); syncRideStatus(); } finally {
      if (mounted) _processingAction = false;
    }
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
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot end trip. Passengers still active."), backgroundColor: Colors.red));
      }
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
      final updatedRide = await RideService.endRide(widget.rideId);
      if (mounted) {
        setState(() {
          rideData = updatedRide;
        });
        _triggerCompletionScreen();
      }
    } catch (e) {
      syncRideStatus();
    }
  }
  Future<void> startRide() async { 
    if (widget.rideId.isEmpty || _processingAction) return;
    _processingAction = true;
    // Optimistic UI update
    setState(() {
      isStarted = true;
      if (rideData != null) rideData!['status'] = 'started';
    });
    try { await RideService.startRide(widget.rideId); } catch (e) { debugPrint(e.toString()); syncRideStatus(); } finally {
      if (mounted) _processingAction = false;
    }
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
    wps.sort((a, b) {
      int cmp = (a['index'] as num).compareTo(b['index'] as num);
      if (cmp != 0) return cmp;
      if (a['type'] == 'dropoff' && b['type'] == 'pickup') return -1;
      if (a['type'] == 'pickup' && b['type'] == 'dropoff') return 1;
      return 0;
    });
    
    int totalSeats = (rideData!['totalSeats'] as num?)?.toInt() ?? 4;
    int currentlyOccupied = 0;
    for (String p in (rideData!['boardedPassengers'] ?? [])) {
      currentlyOccupied += (rideData!['riderDetails']?[p]?['seats'] as num?)?.toInt() ?? 1;
    }

    for (var wp in wps) {
      String p = wp['passenger'];
      if (wp['type'] == 'pickup' && pref != 'shared_start' && !(rideData!['boardedPassengers'] ?? []).contains(p) && !(rideData!['droppedPassengers'] ?? []).contains(p)) {
        int seatsNeeded = (rideData!['riderDetails']?[p]?['seats'] as num?)?.toInt() ?? 1;
        if (currentlyOccupied + seatsNeeded <= totalSeats) {
          String displayName = rideData?['riderDetails']?[p]?['riderName'] ?? p;
          return {"title": "$displayName's Pickup", "address": wp['location'], "lat": wp['lat'], "lng": wp['lng']};
        }
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
    _locationTimeoutTimer?.cancel();
    _routeTimer?.cancel();
    positionStreamSubscription?.cancel();
    _removeAllListeners();
    SocketService().leaveRide(widget.rideId);
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String driverLabel = widget.isDriver ? "Me (Driver)" : "${widget.otherUserName} (Driver)";

    bool iHaveBoarded = (rideData?['boardedPassengers'] ?? []).contains(myEmailLower);
    bool iAmArrived = (rideData?['arrivedAt'] ?? []).contains(myEmailLower);
    bool iAmDropped = (rideData?['droppedPassengers'] ?? []).contains(myEmailLower);

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

    LatLng? riderPickupPosition;
    LatLng? riderDestPosition;
    if (!widget.isDriver && rideData != null) {
      final details = rideData!['riderDetails']?[myEmailLower];
      if (details != null) {
        if (details['pickupLat'] != null && details['pickupLng'] != null) {
          riderPickupPosition = LatLng((details['pickupLat'] as num).toDouble(), (details['pickupLng'] as num).toDouble());
        }
        if (details['destLat'] != null && details['destLng'] != null) {
          riderDestPosition = LatLng((details['destLat'] as num).toDouble(), (details['destLng'] as num).toDouble());
        }
      }
    }

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.black, title: const Text("Live Ride Map", style: TextStyle(color: Colors.white)), iconTheme: const IconThemeData(color: Colors.white)),
      body: Stack(children: [
        Positioned.fill(
          child: driverPosition == null
              ? Center(child: _locationTimedOut
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.location_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Could not get location.\nCheck GPS permissions.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initLocationTracking,
                        child: const Text('Retry'),
                      ),
                    ])
                  : CircularProgressIndicator(color: isDark ? Colors.white : Colors.black))
              : FlutterMap(
            mapController: mapController, options: MapOptions(initialCenter: driverPosition!, initialZoom: 15.0),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.ridify', tileProvider: CancellableNetworkTileProvider()),
              if (routePoints.isNotEmpty) PolylineLayer(polylines: [Polyline(points: routePoints, strokeWidth: 5.0, color: Colors.blueAccent)]),
              MarkerLayer(markers: [
                if (!widget.isDriver && myPosition != null) Marker(point: myPosition!, width: 20, height: 20, child: const AnimatedPassengerMarker()),
                if (riderPickupPosition != null) Marker(point: riderPickupPosition, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.green, size: 40)),
                if (riderDestPosition != null) Marker(point: riderDestPosition, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40)),
                Marker(point: driverPosition!, width: 120, height: 80, child: AnimatedDriverMarker(driverLabel: driverLabel)),
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
          return Positioned(top: 20, left: 20, right: 80, child: NextStopHeader(
            stopInfo: stopInfo,
            isDark: isDark,
            onTap: () => _openInMaps(
              (stopInfo['lat'] as num?)?.toDouble(),
              (stopInfo['lng'] as num?)?.toDouble(),
              (stopInfo['address'] as String?) ?? '',
            ),
          ));
        }),
        RideStatusPanel(
          isDriver: widget.isDriver,
          isAccepted: isAccepted,
          isStarted: isStarted,
          iHaveBoarded: iHaveBoarded,
          iAmArrived: iAmArrived,
          iAmDropped: iAmDropped,
          canEnd: canEnd,
          otherUserName: widget.otherUserName,
          statusText: statusText,
          currentlyOccupied: currentlyOccupied,
          totalCap: totalCap,
          rideData: rideData,
          activePassengers: activePassengers,
          myName: widget.myName,
          myEmail: widget.myEmail,
          rideId: widget.rideId,
          isProcessing: _processingAction,
          onBoardRide: boardRide,
          onStartRide: startRide,
          onEndRide: endRide,
          onDropOffPassenger: dropOffPassenger,
          onConfirmKickPassenger: _confirmKickPassenger,
          onDriverArriveForPassenger: driverArriveForPassenger,
        ),
      ]),
    );
  }
}


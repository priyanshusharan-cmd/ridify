import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import '../core/user_provider.dart';
import '../core/rides_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  Timer? _backgroundSyncTimer;
  final MapController mapController = MapController();
  StreamSubscription<Position>? positionStreamSubscription;
  bool _isNavigatingToCompletion = false;
  String? _processingActionId;
  final List<MapEntry<String, void Function(dynamic)>> _socketListeners = [];
  
  bool _locationTimedOut = false;
  Timer? _locationTimeoutTimer;

  /// Live positions of passengers waiting for pickup (driver only).
  final Map<String, LatLng> passengerLivePositions = {};
  /// GPS is only switched on once the driver has started the ride.
  bool _liveTrackingActive = false;
  /// True once we have a real GPS fix (never share a fallback position).
  bool _hasRealFix = false;

  LatLng? get _mapCenter => driverPosition ?? myPosition;

  bool get _iAmWaitingForPickup {
    final me = myEmailLower;
    final List passengers = rideData?['passengers'] ?? [];
    final List boarded = rideData?['boardedPassengers'] ?? [];
    final List dropped = rideData?['droppedPassengers'] ?? [];
    return passengers.contains(me) && !boarded.contains(me) && !dropped.contains(me);
  }

  @override
  void initState() {
    super.initState();
    isAccepted = widget.isDriver || widget.isAlreadyAccepted;
    initSocket();
    syncRideStatus();
    _routeTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchRoute());
    if (kIsWeb) {
      _backgroundSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) => syncRideStatus());
    }
    // No GPS here: location tracking starts in _markStarted(), once the
    // driver has started the ride.

    // Register reconnect callback so ride status refreshes when socket reconnects on mobile
    SocketService().addReconnectCallback(syncRideStatus);
  }

  /// Called whenever we learn the ride has started. This is the only place
  /// that turns on GPS and location sharing.
  void _markStarted() {
    isStarted = true;
    if (_liveTrackingActive) return;
    _liveTrackingActive = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _locationTimeoutTimer?.cancel();
      _locationTimeoutTimer = Timer(const Duration(seconds: 15), () {
        if (mounted && _mapCenter == null) setState(() => _locationTimedOut = true);
      });
      _initLocationTracking();
      if (widget.isDriver) {
        SocketService().socket.emit('request_passenger_location', {'rideId': widget.rideId});
      } else {
        SocketService().socket.emit('request_driver_location', {'rideId': widget.rideId});
      }
    });
  }

  void _shareDriverLocation() {
    if (!widget.isDriver || !isStarted || !_hasRealFix || driverPosition == null) return;
    SocketService().socket.emit('driver_location_update', {'rideId': widget.rideId, 'lat': driverPosition!.latitude, 'lng': driverPosition!.longitude});
  }

  void _sharePassengerLocation() {
    if (widget.isDriver || !isStarted || !_hasRealFix || myPosition == null || !_iAmWaitingForPickup) return;
    SocketService().socket.emit('passenger_location_update', {'rideId': widget.rideId, 'lat': myPosition!.latitude, 'lng': myPosition!.longitude});
  }

  Future<void> _initLocationTracking() async {
    void applyFallback() {
      if (mounted) {
        setState(() {
          if (widget.isDriver) {
            driverPosition = const LatLng(12.9716, 77.5946);
            Future.delayed(const Duration(milliseconds: 100), () { try { mapController.move(driverPosition!, 15.0); } catch (_) {} });
          }
          // Passengers: no fallback dot; the map centres on the driver instead.
        });
      }
    }

    final position = await LocationService.getCurrentPosition();
    if (position == null) {
      applyFallback();
      return;
    }

    if (!mounted) return;
    _hasRealFix = true;
    positionStreamSubscription?.cancel();
    try {
      if (widget.isDriver) {
        setState(() => driverPosition = LatLng(position.latitude, position.longitude));
        Future.delayed(const Duration(milliseconds: 150), () { _fetchRoute(); _fitBounds(); });
        _shareDriverLocation();
        positionStreamSubscription = LocationService.getPositionStream(distanceFilter: 10).listen((Position p) {
          if (!mounted) return;
          setState(() => driverPosition = LatLng(p.latitude, p.longitude));
          _fitBounds();
          _shareDriverLocation();
        });
      } else {
        // Passengers share their position with the driver only (the server
        // enforces this) and only until they are picked up.
        setState(() => myPosition = LatLng(position.latitude, position.longitude));
        Future.delayed(const Duration(milliseconds: 150), _fitBounds);
        _sharePassengerLocation();
        positionStreamSubscription = LocationService.getPositionStream(distanceFilter: 10).listen((Position p) {
          if (!mounted) return;
          setState(() => myPosition = LatLng(p.latitude, p.longitude));
          _sharePassengerLocation();
        });
      }
    } catch (e) { debugPrint("GPS Error: $e"); applyFallback(); }
  }

  /// Stops still ahead of the car, in driving order.
  /// Driver: every waiting passenger's pickup and every boarded passenger's
  /// drop, then the ride's destination.
  /// Passenger: only their own pickup (until boarded) and their own drop.
  List<LatLng> _remainingStops() {
    final data = rideData;
    if (data == null) return [];
    LatLng? at(dynamic lat, dynamic lng) =>
        (lat is num && lng is num) ? LatLng(lat.toDouble(), lng.toDouble()) : null;
    final List boarded = data['boardedPassengers'] ?? [];
    final List dropped = data['droppedPassengers'] ?? [];
    final Map details = (data['riderDetails'] as Map?) ?? {};

    if (!widget.isDriver) {
      final d = details[myEmailLower];
      if (d == null || dropped.contains(myEmailLower)) return [];
      final stops = <LatLng>[];
      if (!boarded.contains(myEmailLower)) {
        final pickup = at(d['pickupLat'], d['pickupLng']);
        if (pickup != null) stops.add(pickup);
      }
      final drop = at(d['destLat'], d['destLng']);
      if (drop != null) stops.add(drop);
      return stops;
    }

    final riders = <dynamic>{...(data['passengers'] ?? []), ...boarded};
    final waypoints = <({num index, bool isPickup, LatLng point})>[];
    for (final p in riders) {
      if (dropped.contains(p)) continue;
      final d = details[p];
      if (d == null) continue;
      if (!boarded.contains(p)) {
        final pickup = at(d['pickupLat'], d['pickupLng']);
        if (pickup != null) waypoints.add((index: (d['startIndex'] as num?) ?? 0, isPickup: true, point: pickup));
      }
      final drop = at(d['destLat'], d['destLng']);
      if (drop != null) waypoints.add((index: (d['endIndex'] as num?) ?? 9999, isPickup: false, point: drop));
    }
    waypoints.sort((a, b) {
      final cmp = a.index.compareTo(b.index);
      if (cmp != 0) return cmp;
      if (a.isPickup == b.isPickup) return 0;
      return a.isPickup ? 1 : -1; // drop before pickup at the same spot
    });
    final stops = waypoints.map((w) => w.point).toList();
    final dest = at(data['destLat'], data['destLng']);
    if (dest != null) stops.add(dest);
    return stops;
  }

  Future<void> _fetchRoute() async {
    if (!isStarted || rideData == null) return;
    final start = driverPosition;
    if (start == null) return;
    final stops = _remainingStops();
    if (stops.isEmpty) return;
    final points = <List<double>>[
      [start.longitude, start.latitude],
      ...stops.map((s) => [s.longitude, s.latitude]),
    ];
    try {
      final route = await LocationService.fetchOsrmRouteVia(points);
      if (route != null) {
        final coords = route['geometry']['coordinates'] as List;
        if (mounted) setState(() => routePoints = coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList());
      }
    } catch (e) { debugPrint("OSRM Error: $e"); }
  }

  void _fitBounds() {
    final center = _mapCenter;
    if (center == null) return;
    final points = <LatLng>[
      if (driverPosition != null) driverPosition!,
      if (myPosition != null) myPosition!,
      if (widget.isDriver) ...passengerLivePositions.values,
      ..._remainingStops().take(3),
    ];

    try {
      if (points.length < 2) {
        mapController.move(center, 15.0);
        return;
      }
      final bounds = LatLngBounds.fromPoints(points);
      if (bounds.southWest.latitude == bounds.northEast.latitude &&
          bounds.southWest.longitude == bounds.northEast.longitude) {
        mapController.move(center, 15.0);
        return;
      }
      mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80.0)));
    } catch (_) {
      try { mapController.move(center, 15.0); } catch (_) {}
    }
  }

  bool _syncInProgress = false;

  Future<void> syncRideStatus() async {
    if (mounted) {
      Provider.of<UserProvider>(context, listen: false).fetchProfile();
      Provider.of<RidesProvider>(context, listen: false).fetchRides();
    }
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
        
        bool hasPaid = false;
        final details = data['riderDetails'];
        if (details != null && details[myEmailLower] != null) {
          hasPaid = details[myEmailLower]['paid'] == true;
        }
        final List paidPass = data['paidPassengers'] ?? [];
        if (paidPass.map((e) => e.toString().toLowerCase().trim()).contains(myEmailLower)) {
          hasPaid = true;
        }

        if (hasPaid) {
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You have already paid for this ride.")));
            Navigator.popUntil(context, (route) => route.isFirst);
          }
          return;
        }

        int fare = 0;
        if (details != null && details[myEmailLower] != null) {
          fare = (details[myEmailLower]['fare'] as num?)?.toInt() ?? 0;
        }
        _triggerPaymentScreen(fare);
        return;
      }
      setState(() {
        final bool isFirstLoad = rideData == null;
        rideData = data;
        if (data['status'] == 'completed') {
          if (widget.isDriver) {
            _triggerCompletionScreen();
          } else {
            bool hasPaid = false;
            final details = data['riderDetails'];
            if (details != null && details[myEmailLower] != null) {
              hasPaid = details[myEmailLower]['paid'] == true;
            }
            final List paidPass = data['paidPassengers'] ?? [];
            if (paidPass.map((e) => e.toString().toLowerCase().trim()).contains(myEmailLower)) {
              hasPaid = true;
            }

            if (hasPaid) {
              if (mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You have already paid for this ride.")));
                Navigator.popUntil(context, (route) => route.isFirst);
              }
              return;
            }

            int fare = 0;
            if (details != null && details[myEmailLower] != null) {
              fare = (details[myEmailLower]['fare'] as num?)?.toInt() ?? 0;
            }
            _triggerPaymentScreen(fare);
          }
          return;
        }
        if (data['status'] == 'started') _markStarted();
        if (isFirstLoad) _fetchRoute();
      });
    } catch (e) {
      debugPrint('syncRideStatus error: $e');
      if (mounted && rideData == null) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network error loading ride data. Please try again.")));
         Navigator.pop(context);
      }
      // Don't rethrow — sync failures should not crash the screen if already loaded
    } finally {
      _syncInProgress = false; // ALWAYS reset, even on exception
    }
  }

  /// Register a socket listener via SocketService so it survives reconnects.
  void _on(String event, void Function(dynamic) handler) {
    SocketService().on(event, handler);
    _socketListeners.add(MapEntry(event, handler));
  }

  void _removeAllListeners() {
    final svc = SocketService();
    for (final entry in _socketListeners) {
      svc.off(entry.key, entry.value);
    }
    _socketListeners.clear();
  }

  void initSocket() {
    _removeAllListeners();
    final socketService = SocketService();
    socket = socketService.socket;

    // Set up ALL listeners FIRST before joining the ride, to prevent race conditions
    // where events arrive before listeners are ready
    String eventRideId(dynamic data) =>
        data is Map ? (data['rideId'] ?? '').toString() : '';

    // A passenger opened the map and wants a fresh driver fix.
    _on('request_driver_location', (data) {
      if (eventRideId(data) == widget.rideId) _shareDriverLocation();
    });

    // The driver opened the map and wants a fresh fix from waiting passengers.
    _on('request_passenger_location', (data) {
      if (eventRideId(data) == widget.rideId) _sharePassengerLocation();
    });

    // Driver only: live position of a passenger waiting for pickup.
    _on('passenger_location_update', (data) {
      if (data == null || !widget.isDriver) return;
      final map = SocketService.deepConvertMap(data);
      if (!mounted || map['rideId'].toString() != widget.rideId) return;
      final email = (map['email'] ?? '').toString();
      final lat = map['lat'], lng = map['lng'];
      if (email.isEmpty || lat is! num || lng is! num) return;
      setState(() => passengerLivePositions[email] = LatLng(lat.toDouble(), lng.toDouble()));
    });

    _on('new_ride_request', (data) {
      if (data == null) return;
      final map = SocketService.deepConvertMap(data);
      if (mounted && map['rideId'].toString() == widget.rideId && map['ride'] != null) {
        setState(() {
          rideData = SocketService.deepConvertMap(map['ride']);
        });
      }
    });

    _on('ride_accepted', (data) {
      if (data == null) return;
      final map = SocketService.deepConvertMap(data);
      if (mounted && map['rideId'].toString() == widget.rideId && map['ride'] != null) {
        setState(() {
          rideData = SocketService.deepConvertMap(map['ride']);
        });
      }
    });

    _on('ride_updated', (data) {
      if (data == null) return;
      final map = SocketService.deepConvertMap(data);
      if (mounted && map['rideId'].toString() == widget.rideId && map['ride'] != null) {
        setState(() {
          rideData = SocketService.deepConvertMap(map['ride']);
        });
      }
    });

    _on('passenger_boarded', (data) {
      if (data == null) return;
      final map = SocketService.deepConvertMap(data);
      if (mounted && map['rideId'].toString() == widget.rideId) {
        passengerLivePositions.remove(map['riderName']?.toString());
        Future.delayed(const Duration(milliseconds: 100), _fetchRoute);
        if (map['ride'] != null) {
          setState(() {
            rideData = SocketService.deepConvertMap(map['ride']);
          });
        } else {
          syncRideStatus();
        }
      }
    });
    _on('passenger_dropped', (data) {
      if (data == null) return;
      final map = SocketService.deepConvertMap(data);
      if (mounted && map['rideId'].toString() == widget.rideId) {
        passengerLivePositions.remove(map['riderName']?.toString());
        Future.delayed(const Duration(milliseconds: 100), _fetchRoute);
        if (!widget.isDriver && map['riderName'] == myEmailLower) {
          _triggerPaymentScreen(map['fare'] ?? 0);
        } else if (map['ride'] != null) {
          setState(() {
            rideData = SocketService.deepConvertMap(map['ride']);
          });
        } else {
          syncRideStatus();
        }
      }
    });
    _on('driver_arrived', (data) {
      if (data == null) return;
      final map = SocketService.deepConvertMap(data);
      if (mounted && map['rideId'].toString() == widget.rideId) {
        if (map['ride'] != null) {
          setState(() {
            rideData = SocketService.deepConvertMap(map['ride']);
            if (map['riderName'] == myEmailLower) {
              List arrived = List.from(rideData!['arrivedAt'] ?? []);
              if (!arrived.contains(myEmailLower)) arrived.add(myEmailLower);
              rideData!['arrivedAt'] = arrived;
            }
          });
        }
        syncRideStatus();
        if (!widget.isDriver &&
            map['riderName'] == myEmailLower &&
            !(rideData?['boardedPassengers'] ?? []).contains(myEmailLower)) {
          ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(const SnackBar(content: Text("Driver has arrived! Please board."), backgroundColor: Colors.green));
        }
      }
    });
    _on('ride_started', (data) {
      if (data == null) return;
      final map = SocketService.deepConvertMap(data);
      if (mounted && map['rideId'].toString() == widget.rideId) {
        setState(() {
          _markStarted();
          if (map['ride'] != null) {
            rideData = SocketService.deepConvertMap(map['ride']);
          } else {
            syncRideStatus();
          }
        });
      }
    });
    _on('passenger_kicked', (data) {
      if (data == null) return;
      final map = SocketService.deepConvertMap(data);
      if (mounted && map['rideId'].toString() == widget.rideId) {
        passengerLivePositions.remove(map['kickedUser']?.toString());
        if (map['ride'] != null) {
          setState(() {
            rideData = SocketService.deepConvertMap(map['ride']);
          });
        }
        if (map['kickedUser'] == myEmailLower) {
          _kickSelfOut();
        }
      }
    });
    _on('driver_location_update', (data) {
      if (data == null) return;
      final map = SocketService.deepConvertMap(data);
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
      final map = SocketService.deepConvertMap(data);
      if (mounted && map['rideId'].toString() == widget.rideId) {
        if (map['ride'] != null) {
          setState(() {
            rideData = SocketService.deepConvertMap(map['ride']);
          });
        }
      }
    });
    _on('ride_ended', (data) {
      if (data == null) return;
      final map = SocketService.deepConvertMap(data);
      if (mounted) {
        String id = (map['rideId'] ?? map['_id'] ?? '').toString();
        if (id == widget.rideId) {
          final rideMap = map['ride'] != null ? SocketService.deepConvertMap(map['ride']) : null;
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
      final map = SocketService.deepConvertMap(data);
      if (mounted && map['rideId'].toString() == widget.rideId && !_isNavigatingToCompletion) {
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(const SnackBar(content: Text("Ride cancelled"), backgroundColor: Colors.red));
      }
    });

    // NOW join the ride room after all listeners are attached
    socketService.joinRide(widget.rideId);
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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => DriverCompletingScreen(rideId: widget.rideId, initialRideData: rideData)),
        (route) => route.isFirst
      );
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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => RiderCompletingScreen(isDriver: false, rideId: widget.rideId, myName: widget.myName, myEmail: widget.myEmail, fareAmount: fareAmount, initialRideData: rideData)),
        (route) => route.isFirst
      );
    });
  }

  void _kickSelfOut() {

    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      title: const Text("Removed from Ride"), content: const Text("The driver has removed you from this ride."),
      actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.popUntil(context, (route) => route.isFirst); }, child: const Text("OK", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))],
    ));
  }

  Future<void> driverArriveForPassenger(String name) async {
    if (_processingActionId != null) return;
    _processingActionId = name;
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
      if (mounted) setState(() => _processingActionId = null);
    }
  }
  Future<void> boardRide() async {
    if (widget.rideId.isEmpty || _processingActionId != null) return;
    setState(() => _processingActionId = 'board');

    try {
      await RideService.boardPassenger(widget.rideId, myEmailLower);
      // Success — socket event 'passenger_boarded' will update UI
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        String msg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
      syncRideStatus();
    } finally {
      if (mounted) setState(() => _processingActionId = null);
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
    if (_processingActionId != null) return;
    _processingActionId = name;
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
      if (mounted) setState(() => _processingActionId = null);
    }
  }
  Future<void> _executeDropOff(String name) async {
    if (_processingActionId != null) return;
    _processingActionId = name;
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
      if (mounted) setState(() => _processingActionId = null);
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
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(const SnackBar(content: Text("Cannot end trip. Passengers still active."), backgroundColor: Colors.red));
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

    setState(() => _processingActionId = 'end');
    
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
    } finally {
      if (mounted) setState(() => _processingActionId = null);
    }
  }
  Future<void> startRide() async { 
    if (widget.rideId.isEmpty || _processingActionId != null) return;
    setState(() => _processingActionId = 'start');
    try {
      // Not optimistic: GPS turns on only after the server confirms the start.
      await RideService.startRide(widget.rideId);
      if (mounted) {
        setState(() {
          if (rideData != null) rideData!['status'] = 'started';
          _markStarted();
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(const SnackBar(content: Text("Couldn't start the ride. Please try again."), backgroundColor: Colors.red));
      }
      syncRideStatus();
    } finally {
      if (mounted) setState(() => _processingActionId = null);
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
        if (mounted) ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(const SnackBar(content: Text("No location data available"), backgroundColor: Colors.orange));
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
    _backgroundSyncTimer?.cancel();
    positionStreamSubscription?.cancel();
    SocketService().removeReconnectCallback(syncRideStatus);
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
        if (details['pickupLat'] != null && details['pickupLng'] != null && !iHaveBoarded) {
          riderPickupPosition = LatLng((details['pickupLat'] as num).toDouble(), (details['pickupLng'] as num).toDouble());
        }
        if (details['destLat'] != null && details['destLng'] != null) {
          riderDestPosition = LatLng((details['destLat'] as num).toDouble(), (details['destLng'] as num).toDouble());
        }
      }
    }

    // Driver map: every passenger's pickup (and live position while they wait),
    // or their drop once they're on board. Passengers never get these.
    final List<Marker> passengerMarkers = [];
    if (widget.isDriver && rideData != null) {
      for (final p in activePassengers) {
        final d = rideData!['riderDetails']?[p];
        if (d == null) continue;
        final name = (d['riderName'] ?? p).toString().split(' ').first;
        if (!boardedPassengers.contains(p)) {
          if (d['pickupLat'] is num && d['pickupLng'] is num) {
            passengerMarkers.add(Marker(
              point: LatLng((d['pickupLat'] as num).toDouble(), (d['pickupLng'] as num).toDouble()),
              width: 110, height: 66,
              child: _LabeledPin(label: name, color: Colors.green),
            ));
          }
          final live = passengerLivePositions[p.toString()];
          if (live != null) {
            passengerMarkers.add(Marker(point: live, width: 110, height: 46, child: _LiveRiderDot(label: name)));
          }
        } else if (d['destLat'] is num && d['destLng'] is num) {
          passengerMarkers.add(Marker(
            point: LatLng((d['destLat'] as num).toDouble(), (d['destLng'] as num).toDouble()),
            width: 110, height: 66,
            child: _LabeledPin(label: "$name drop", color: Colors.red),
          ));
        }
      }
    }

    final panel = RideStatusPanel(
      fullScreen: !isStarted,
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
      processingActionId: _processingActionId,
      onBoardRide: boardRide,
      onStartRide: startRide,
      onEndRide: endRide,
      onDropOffPassenger: dropOffPassenger,
      onConfirmKickPassenger: _confirmKickPassenger,
      onDriverArriveForPassenger: driverArriveForPassenger,
    );

    final center = _mapCenter;

    // Before the driver starts: full-screen ride panel, no map, no GPS.
    final Widget lobby = RefreshIndicator(
      key: const ValueKey('lobby'),
      onRefresh: syncRideStatus,
      child: panel,
    );

    final Widget live = RefreshIndicator(
      key: const ValueKey('live'),
      onRefresh: syncRideStatus,
      child: Stack(children: [
        // 1. Map and markers (Base layer)
        Positioned.fill(
          child: center == null
              ? Center(child: _locationTimedOut
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.location_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(widget.isDriver ? 'Could not get location.\nCheck GPS permissions.' : 'Waiting for the driver\'s location…', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _initLocationTracking, child: const Text('Retry')),
                    ])
                  : CircularProgressIndicator(color: isDark ? Colors.white : Colors.black))
              : FlutterMap(
                  mapController: mapController, options: MapOptions(initialCenter: center, initialZoom: 15.0),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.ridify', tileProvider: CancellableNetworkTileProvider()),
                    if (routePoints.isNotEmpty) PolylineLayer(polylines: [Polyline(points: routePoints, strokeWidth: 5.0, color: Colors.blueAccent)]),
                    MarkerLayer(markers: [
                      ...passengerMarkers,
                      if (!widget.isDriver && myPosition != null && !iHaveBoarded) Marker(point: myPosition!, width: 20, height: 20, child: const AnimatedPassengerMarker()),
                      if (riderPickupPosition != null) Marker(point: riderPickupPosition, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.green, size: 40)),
                      if (riderDestPosition != null) Marker(point: riderDestPosition, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.red, size: 40)),
                      if (driverPosition != null) Marker(point: driverPosition!, width: 120, height: 80, child: AnimatedDriverMarker(driverLabel: driverLabel)),
                    ]),
                  ],
                ),
        ),

        // 2. Pull-to-refresh trigger zone (Transparent overlay at top)
        Positioned(
          top: 0, left: 0, right: 0, height: 150,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: { PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad },
            ),
            child: ListView(
              physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.zero,
              children: [
                Container(height: 150, color: Colors.transparent),
              ],
            ),
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
          if (center != null) GestureDetector(
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
        if (widget.isDriver) Builder(builder: (ctx) {
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
        panel,
      ]),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(isStarted ? "Live Ride Map" : (widget.isDriver ? "Your Ride" : "Ride Confirmed"), style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: isStarted ? live : lobby,
      ),
    );
  }
}


/// Pin with a name chip above it (driver map: pickup / drop of each passenger).
class _LabeledPin extends StatelessWidget {
  final String label;
  final Color color;
  const _LabeledPin({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)]),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
      ),
      Icon(Icons.location_on, color: color, size: 34),
    ]);
  }
}

/// Live position of a passenger waiting for pickup (driver map only).
class _LiveRiderDot extends StatelessWidget {
  final String label;
  const _LiveRiderDot({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.blue.shade700, borderRadius: BorderRadius.circular(6)),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      const SizedBox(height: 4),
      Container(
        width: 16, height: 16,
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
      ),
    ]);
  }
}

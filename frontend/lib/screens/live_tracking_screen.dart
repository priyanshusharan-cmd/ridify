import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'chat_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants.dart';
import 'completion_screen.dart';

class LiveTrackingScreen extends StatefulWidget {
  final bool isDriver;
  final bool isAlreadyAccepted;
  final String myName;
  final String otherUserName;
  final String rideId;

  const LiveTrackingScreen({
    super.key,
    this.isDriver = false,
    this.isAlreadyAccepted = false,
    this.myName = "Me",
    this.otherUserName = "Group",
    this.rideId = "",
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  late io.Socket socket;
  late bool isAccepted;
  bool isStarted = false;
  Timer? _pollingTimer;

  Map<String, dynamic>? rideData;
  LatLng? driverPosition;
  LatLng? myPosition;
  List<LatLng> routePoints = [];
  Timer? _routeTimer;
  final MapController mapController = MapController();
  StreamSubscription<Position>? positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    isAccepted = widget.isDriver || widget.isAlreadyAccepted;
    initSocket();
    syncRideStatus();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => syncRideStatus(),
    );
    _routeTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchRoute(),
    );
    _initLocationTracking();

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && driverPosition == null) {
        syncRideStatus();
        if (!widget.isDriver && rideData != null && rideData!['pickupLat'] != null) {
          setState(() {
            driverPosition = LatLng(rideData!['pickupLat'], rideData!['pickupLng']);
          });
          try {
            mapController.move(driverPosition!, 15.0);
          } catch (_) {}
        }
      }
    });
  }

  Future<void> _initLocationTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    void applyFallback() {
      if (mounted) {
        setState(() {
          if (widget.isDriver) {
            driverPosition = const LatLng(12.9716, 77.5946);
            Future.delayed(const Duration(milliseconds: 100), () {
              try {
                mapController.move(driverPosition!, 15.0);
              } catch (_) {}
            });
          } else {
            myPosition = const LatLng(12.9716, 77.5946);
          }
        });
      }
    }

    if (permission == LocationPermission.deniedForever) {
      applyFallback();
      return;
    }

    try {
      if (widget.isDriver) {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(timeLimit: Duration(seconds: 3)),
        );
        if (mounted) {
          setState(() {
            driverPosition = LatLng(position.latitude, position.longitude);
          });
          Future.delayed(const Duration(milliseconds: 100), () {
            mapController.move(driverPosition!, 15.0);
          });

          socket.emit('driver_location_update', {
            'rideId': widget.rideId,
            'lat': position.latitude,
            'lng': position.longitude,
          });

          positionStreamSubscription = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
          ).listen((Position position) {
            if (mounted) {
              setState(() {
                driverPosition = LatLng(position.latitude, position.longitude);
              });
              _fitBounds();
              socket.emit('driver_location_update', {
                'rideId': widget.rideId,
                'lat': position.latitude,
                'lng': position.longitude,
              });
            }
          });
        }
      } else {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(timeLimit: Duration(seconds: 3)),
        );
        if (mounted) {
          setState(() => myPosition = LatLng(position.latitude, position.longitude));
        }

        positionStreamSubscription = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
        ).listen((Position pos) {
          if (mounted) {
            setState(() => myPosition = LatLng(pos.latitude, pos.longitude));
          }
        });
      }
    } catch (e) {
      debugPrint("GPS Error: $e");
      applyFallback();
    }
  }

  Future<void> _fetchRoute() async {
    if (rideData == null || driverPosition == null) return;
    if (rideData!['destLat'] == null || rideData!['destLng'] == null) return;

    final destLat = rideData!['destLat'];
    final destLng = rideData!['destLng'];

    try {
      final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${driverPosition!.longitude},${driverPosition!.latitude};$destLng,$destLat?geometries=geojson');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final coords = data['routes'][0]['geometry']['coordinates'] as List;
          if (mounted) {
            setState(() {
              routePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint("OSRM Error: $e");
    }
  }

  void _fitBounds() {
    if (driverPosition == null) return;

    LatLng? targetPosition;
    if (widget.isDriver && rideData != null && rideData!['destLat'] != null) {
      targetPosition = LatLng(rideData!['destLat'], rideData!['destLng']);
    } else {
      targetPosition = myPosition;
    }

    if (targetPosition != null) {
      if (driverPosition!.latitude == targetPosition.latitude && driverPosition!.longitude == targetPosition.longitude) {
        mapController.move(driverPosition!, 15.0);
        return;
      }
      try {
        final bounds = LatLngBounds.fromPoints([driverPosition!, targetPosition]);
        mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80.0)));
      } catch (_) {
        mapController.move(driverPosition!, 15.0);
      }
    } else {
      mapController.move(driverPosition!, 15.0);
    }
  }

  Future<void> syncRideStatus() async {
    if (widget.rideId.isEmpty) return;
    try {
      final response = await http.get(Uri.parse('$kBaseUrl/api/rides/${widget.rideId}'));
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);

        if (!widget.isDriver &&
            !(data['passengers'] ?? []).contains(widget.myName) &&
            !(data['boardedPassengers'] ?? []).contains(widget.myName) &&
            !(data['droppedPassengers'] ?? []).contains(widget.myName)) {
          _kickSelfOut();
          return;
        }

        setState(() {
          bool isFirstLoad = rideData == null;
          rideData = data;
          if (data['status'] == 'completed') {
            _triggerCompletionScreen(0);
            return;
          }
          if (data['status'] == 'started' && !isStarted) isStarted = true;
          if (isFirstLoad) _fetchRoute();
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void initSocket() {
    socket = io.io(kBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.on('passenger_boarded', (data) {
      if (mounted && data != null && data['_id'] == widget.rideId) {
        syncRideStatus();
      }
    });

    socket.on('passenger_dropped', (data) {
      if (mounted && data != null && data['rideId'] == widget.rideId) {
        syncRideStatus();
        if (!widget.isDriver && data['riderName'] == widget.myName) {
          _triggerCompletionScreen(data['fare'] ?? 0);
        }
      }
    });

    socket.on('driver_arrived', (data) {
      if (mounted && data != null && data['rideId'] == widget.rideId) {
        syncRideStatus();
        if (!widget.isDriver && data['riderName'] == widget.myName) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Driver has arrived! Please board."), backgroundColor: Colors.green),
          );
        }
      }
    });

    socket.on('ride_started', (data) {
      if (mounted && data != null && data['_id'] == widget.rideId) {
        setState(() {
          isStarted = true;
          rideData = data;
        });
      }
    });

    socket.on('passenger_kicked', (data) {
      if (mounted && data != null && data['rideId'] == widget.rideId) {
        if (data['kickedUser'] == widget.myName) {
          _kickSelfOut();
        } else {
          syncRideStatus();
        }
      }
    });

    socket.on('driver_location_update', (data) {
      if (mounted && !widget.isDriver && data != null && data['rideId'] == widget.rideId) {
        setState(() {
          driverPosition = LatLng(data['lat'], data['lng']);
        });
        try { _fitBounds(); } catch (_) {}
      }
    });

    socket.on('ride_ended', (data) {
      if (mounted && data != null) {
        String eventRideId = data['rideId']?.toString() ?? data['_id']?.toString() ?? '';
        if (eventRideId == widget.rideId) {
          _triggerCompletionScreen(0);
        }
      }
    });
  }

  bool _isNavigatingToCompletion = false;

  void _triggerCompletionScreen(int fareAmount) {
    if (_isNavigatingToCompletion || !mounted) return;
    _isNavigatingToCompletion = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CompletionScreen(
          isDriver: widget.isDriver,
          rideId: widget.rideId,
          myName: widget.myName,
          fareAmount: fareAmount,
        )
      ));
    });
  }

  void _kickSelfOut() {
    _pollingTimer?.cancel();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Removed from Ride"),
        content: const Text("The driver has removed you from this ride."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text("OK", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> driverArriveForPassenger(String passengerName) async {
    try {
      await http.patch(Uri.parse('$kBaseUrl/api/rides/arrive/${widget.rideId}/$passengerName'));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> boardRide() async {
    if (widget.rideId.isEmpty) return;
    try {
      final response = await http.patch(Uri.parse('$kBaseUrl/api/rides/board/${widget.rideId}/${widget.myName}'));
      if (response.statusCode != 200) {
        final err = jsonDecode(response.body)['error'];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err ?? "Failed to board"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> dropOffPassenger(String passengerName) async {
    int fareAmount = rideData?['riderDetails']?[passengerName]?['fare'] ?? 0;
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Drop-off $passengerName"),
        content: Text("Collect ₹$fareAmount from $passengerName."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _executeDropOff(passengerName);
            },
            child: const Text("Confirm Drop-off", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDropOff(String passengerName) async {
    try {
      await http.patch(Uri.parse('$kBaseUrl/api/rides/dropoff/${widget.rideId}/$passengerName'));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> kickPassenger(String passengerName) async {
    try {
      await http.patch(Uri.parse('$kBaseUrl/api/rides/kick/${widget.rideId}/$passengerName'));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> endRide() async {
    if (widget.rideId.isEmpty) return;
    
    int activePassengers = (rideData?['passengers']?.length ?? 0) - (rideData?['droppedPassengers']?.length ?? 0);
    if (activePassengers > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot end trip. Passengers are still active."), backgroundColor: Colors.red),
        );
      }
      return;
    }

    try {
      await http.patch(Uri.parse('$kBaseUrl/api/rides/end/${widget.rideId}'));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> startRide() async {
    if (widget.rideId.isEmpty) return;
    try {
      await http.patch(Uri.parse('$kBaseUrl/api/rides/start/${widget.rideId}'));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  String _getNextStopLocation() {
    if (rideData == null || !isStarted) return "Start ride to see stops";
    
    List<Map<String, dynamic>> waypoints = [];
    final List passengers = rideData!['passengers'] ?? [];
    for (var p in passengers) {
      final details = rideData!['riderDetails']?[p];
      if (details != null) {
        waypoints.add({
          "type": "pickup",
          "passenger": p,
          "index": details['startIndex'] ?? 0,
          "location": details['pickupLocation'] ?? "Pickup for $p",
        });
        waypoints.add({
          "type": "dropoff",
          "passenger": p,
          "index": details['endIndex'] ?? 9999,
          "location": details['destination'] ?? "Drop-off for $p",
        });
      }
    }
    
    waypoints.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
    
    for (var wp in waypoints) {
      String p = wp['passenger'];
      if (wp['type'] == 'pickup') {
        if (!(rideData!['boardedPassengers'] ?? []).contains(p)) {
          return wp['location'];
        }
      } else {
        if (!(rideData!['droppedPassengers'] ?? []).contains(p)) {
          return wp['location'];
        }
      }
    }
    return "Destination";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final panelTextColor = isDark ? Colors.white : Colors.black;
    final panelSubTextColor = isDark ? Colors.white54 : Colors.grey;

    String driverLabel = widget.isDriver ? "Me (Driver)" : "${widget.otherUserName} (Driver)";

    bool iHaveBoarded = (rideData?['boardedPassengers'] ?? []).contains(widget.myName);
    bool iAmArrived = (rideData?['arrivedAt'] ?? []).contains(widget.myName);

    String statusText = "Pending";
    if (isStarted) {
      if (widget.isDriver) {
        statusText = "In Progress";
      } else {
        statusText = iHaveBoarded ? "You're in!" : (iAmArrived ? "Board Now!" : "Arriving");
      }
    } else {
      if (widget.isDriver) {
        statusText = "Ready to Start";
      } else {
        statusText = "Waiting for Driver to start";
      }
    }

    int currentlyOccupied = 0;
    for (var p in (rideData?['boardedPassengers'] ?? [])) {
      currentlyOccupied += ((rideData?['riderDetails']?[p]?['seats']) ?? 1) as int;
    }
    int totalCarCapacity = rideData?['totalSeats'] ?? 4;
    
    int activePassengers = (rideData?['passengers']?.length ?? 0) - (rideData?['droppedPassengers']?.length ?? 0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Live Ride Map", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: driverPosition == null
                ? Center(child: CircularProgressIndicator(color: isDark ? Colors.white : Colors.black))
                : FlutterMap(
                    mapController: mapController,
                    options: MapOptions(initialCenter: driverPosition!, initialZoom: 15.0),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.ridify',
                        tileProvider: CancellableNetworkTileProvider(),
                      ),
                      if (routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(points: routePoints, strokeWidth: 5.0, color: Colors.blueAccent),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (!widget.isDriver && myPosition != null)
                            Marker(
                              point: myPosition!,
                              width: 20,
                              height: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
                                ),
                              ),
                            ),
                          Marker(
                            point: driverPosition!,
                            width: 120,
                            height: 80,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  color: Colors.white,
                                  child: Text(
                                    driverLabel,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black),
                                  ),
                                ),
                                const Icon(Icons.directions_car, color: Colors.red, size: 30),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: GestureDetector(
              onTap: _fitBounds,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3))],
                ),
                child: const Icon(Icons.my_location, color: Colors.black, size: 20),
              ),
            ),
          ),
          
          if (widget.isDriver && isStarted)
            Positioned(
              top: 20,
              left: 20,
              right: 80,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3))],
                  border: Border.all(color: isDark ? Colors.white24 : Colors.transparent),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("NEXT STOP", style: TextStyle(color: panelSubTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _getNextStopLocation(),
                      style: TextStyle(color: panelTextColor, fontSize: 16, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: panelBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.black,
                        child: Text(
                          isAccepted ? (widget.isDriver ? "G" : widget.otherUserName.substring(0, 1).toUpperCase()) : "?",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAccepted ? (widget.isDriver ? "Ride Group" : widget.otherUserName) : "Finding Match...",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: panelTextColor),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: isStarted ? (isDark ? Colors.blue.shade300 : Colors.blue) : (isDark ? Colors.green.shade300 : Colors.green),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!widget.isDriver && isAccepted && !iHaveBoarded)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: !iAmArrived ? Colors.grey : (isDark ? const Color(0xFF1B4332) : Colors.green),
                          ),
                          onPressed: !iAmArrived ? null : boardRide,
                          child: const Text("Board", style: TextStyle(color: Colors.white)),
                        ),
                      if (widget.isDriver) ...[
                        if (!isStarted)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFF1A3A5C) : Colors.blue),
                            onPressed: startRide,
                            child: const Text("Start", style: TextStyle(color: Colors.white)),
                          )
                        else
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activePassengers > 0 ? Colors.grey : (isDark ? const Color(0xFF5C1A1A) : Colors.red),
                            ),
                            onPressed: activePassengers > 0 ? null : endRide,
                            child: const Text("End", style: TextStyle(color: Colors.white)),
                          ),
                      ],
                    ],
                  ),
                  
                  if (widget.isDriver && rideData != null && (rideData!['passengers'] as List).isNotEmpty) ...[
                    Divider(height: 20, color: isDark ? Colors.white24 : null),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Passengers", style: TextStyle(fontWeight: FontWeight.bold, color: panelSubTextColor)),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView(
                        shrinkWrap: true,
                        children: ((rideData!['passengers'] ?? []) as List).where((p) => !(rideData!['droppedPassengers'] ?? []).contains(p)).map((p) {
                          bool isBoarded = (rideData!['boardedPassengers'] ?? []).contains(p);
                          bool isArrived = (rideData!['arrivedAt'] ?? []).contains(p);
                          int neededSeats = ((rideData?['riderDetails']?[p]?['seats']) ?? 1) as int;
                          bool canFit = (currentlyOccupied + neededSeats) <= totalCarCapacity;
                          
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 15,
                              backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200],
                              child: Text(p.toString().substring(0, 1).toUpperCase(), style: TextStyle(color: panelTextColor)),
                            ),
                            title: Text(p, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: panelTextColor)),
                            subtitle: Text(
                              isBoarded ? "Boarded" : (isArrived ? "Waiting for rider..." : "Picking up soon"),
                              style: TextStyle(color: isBoarded ? (isDark ? Colors.green.shade300 : Colors.green) : Colors.orange, fontSize: 12),
                            ),
                            trailing: isBoarded
                                ? ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(60, 30)),
                                    onPressed: () => dropOffPassenger(p),
                                    child: const Text("Drop-off", style: TextStyle(color: Colors.white, fontSize: 10)),
                                  )
                                : (!isArrived 
                                  ? ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: canFit ? Colors.green : Colors.grey, minimumSize: const Size(60, 30)),
                                      onPressed: canFit ? () => driverArriveForPassenger(p) : null,
                                      child: const Text("Arrived", style: TextStyle(color: Colors.white, fontSize: 10)),
                                    )
                                  : null),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.black),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(myName: widget.myName, otherName: widget.isDriver ? "Group" : widget.otherUserName, rideId: widget.rideId))),
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                      label: const Text("Chat", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

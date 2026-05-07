import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'chat_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants.dart';
import 'global_completion_screen.dart';

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

    // Re-sync logic if map stays empty
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && driverPosition == null) {
        syncRideStatus();
        if (!widget.isDriver &&
            rideData != null &&
            rideData!['pickupLat'] != null) {
          setState(() {
            driverPosition = LatLng(
              rideData!['pickupLat'],
              rideData!['pickupLng'],
            );
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
          // We defer moving the map controller slightly to ensure map is built
          Future.delayed(const Duration(milliseconds: 100), () {
            mapController.move(driverPosition!, 15.0);
          });

          socket.emit('driver_location_update', {
            'rideId': widget.rideId,
            'lat': position.latitude,
            'lng': position.longitude,
          });

          positionStreamSubscription =
              Geolocator.getPositionStream(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high,
                  distanceFilter: 10,
                ),
              ).listen((Position position) {
                if (mounted) {
                  setState(() {
                    driverPosition = LatLng(
                      position.latitude,
                      position.longitude,
                    );
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
          setState(
            () => myPosition = LatLng(position.latitude, position.longitude),
          );
        }

        positionStreamSubscription =
            Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 5,
              ),
            ).listen((Position pos) {
              if (mounted) {
                setState(
                  () => myPosition = LatLng(pos.latitude, pos.longitude),
                );
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
      final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${driverPosition!.longitude},${driverPosition!.latitude};$destLng,$destLat?geometries=geojson',
      );
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
      final bounds = LatLngBounds.fromPoints([driverPosition!, targetPosition]);
      mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80.0)),
      );
    } else {
      mapController.move(driverPosition!, 15.0);
    }
  }

  Future<void> syncRideStatus() async {
    if (widget.rideId.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('$kBaseUrl/api/rides/${widget.rideId}'),
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);

        if (!widget.isDriver &&
            !(data['passengers'] ?? []).contains(widget.myName)) {
          _kickSelfOut();
          return;
        }

        setState(() {
          bool isFirstLoad = rideData == null;
          rideData = data;
          if (data['status'] == 'completed') {
            _triggerCompletionScreen();
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
      if (mounted &&
          !widget.isDriver &&
          data != null &&
          data['rideId'] == widget.rideId) {
        setState(() {
          driverPosition = LatLng(data['lat'], data['lng']);
        });
        // mapController may throw if map isn't fully built yet, so catch
        try {
          _fitBounds();
        } catch (_) {}
      }
    });

    socket.on('ride_ended', (data) {
      if (mounted && data != null) {
        String eventRideId =
            data['rideId']?.toString() ?? data['_id']?.toString() ?? '';
        if (eventRideId == widget.rideId) {
          _triggerCompletionScreen();
        }
      }
    });

    // We no longer manually pop on database wipe or ride end, because HomeScreen handles it globally!
  }

  bool _isNavigatingToCompletion = false;

  void _triggerCompletionScreen() {
    if (_isNavigatingToCompletion || !mounted) return;
    _isNavigatingToCompletion = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const GlobalCompletionScreen()));
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
            child: const Text(
              "OK",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> boardRide() async {
    if (widget.rideId.isEmpty) return;
    try {
      await http.patch(
        Uri.parse(
          '$kBaseUrl/api/rides/board/${widget.rideId}/${widget.myName}',
        ),
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> kickPassenger(String passengerName) async {
    try {
      await http.patch(
        Uri.parse('$kBaseUrl/api/rides/kick/${widget.rideId}/$passengerName'),
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> endRide() async {
    if (widget.rideId.isEmpty) return;
    try {
      await http.patch(Uri.parse('$kBaseUrl/api/rides/end/${widget.rideId}'));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> startRide() async {
    if (widget.rideId.isEmpty) return;

    bool allBoarded =
        (rideData?['passengers']?.length ?? 0) ==
        (rideData?['boardedPassengers']?.length ?? 0);

    if (!allBoarded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Wait! Not everyone has boarded yet. Kick them out if you want to leave without them.",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      await http.patch(Uri.parse('$kBaseUrl/api/rides/start/${widget.rideId}'));
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _routeTimer?.cancel();
    positionStreamSubscription?.cancel();
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String driverLabel = widget.isDriver
        ? "Me (Driver)"
        : "${widget.otherUserName} (Driver)";

    bool iHaveBoarded = (rideData?['boardedPassengers'] ?? []).contains(
      widget.myName,
    );
    bool allBoarded =
        (rideData?['passengers']?.length ?? 0) ==
        (rideData?['boardedPassengers']?.length ?? 0);

    String statusText = "Pending";
    if (isStarted) {
      statusText = "In Progress";
    } else if (isAccepted) {
      if (widget.isDriver) {
        statusText = allBoarded
            ? "Ready to Start"
            : "Waiting for passengers...";
      } else {
        statusText = iHaveBoarded ? "You're in!" : "Arriving";
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "Live Ride Map",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: driverPosition == null
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: driverPosition!,
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.ridify',
                      ),
                      if (routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: routePoints,
                              strokeWidth: 5.0,
                              color: Colors.blueAccent,
                            ),
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
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      blurRadius: 5,
                                      color: Colors.black26,
                                    ),
                                  ],
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.directions_car,
                                  color: Colors.red,
                                  size: 30,
                                ),
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black,
                        child: Text(
                          isAccepted
                              ? (widget.isDriver
                                    ? "G"
                                    : widget.otherUserName
                                          .substring(0, 1)
                                          .toUpperCase())
                              : "?",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAccepted
                                ? (widget.isDriver
                                      ? "Ride Group"
                                      : widget.otherUserName)
                                : "Finding Match...",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: isStarted ? Colors.blue : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (!widget.isDriver && isAccepted && !iHaveBoarded)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: boardRide,
                          child: const Text(
                            "Start",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      if (widget.isDriver && !isStarted)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          onPressed: startRide,
                          child: const Text(
                            "Start Ride",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      if (widget.isDriver && isStarted)
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: endRide,
                          child: const Text(
                            "End",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                    ],
                  ),

                  if (widget.isDriver &&
                      rideData != null &&
                      (rideData!['passengers'] as List).isNotEmpty) ...[
                    const Divider(height: 30),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Passengers",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    ...((rideData!['passengers'] ?? []) as List).map((p) {
                      bool isBoarded = (rideData!['boardedPassengers'] ?? [])
                          .contains(p);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 15,
                          backgroundColor: Colors.grey[200],
                          child: Text(
                            p.toString().substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                        title: Text(
                          p,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          isBoarded ? "Boarded" : "Waiting",
                          style: TextStyle(
                            color: isBoarded ? Colors.green : Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                        trailing: isStarted
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.person_remove,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () => kickPassenger(p),
                              ),
                      );
                    }),
                  ],

                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            myName: widget.myName,
                            otherName: widget.isDriver
                                ? "Group"
                                : widget.otherUserName,
                            rideId: widget.rideId,
                          ),
                        ),
                      ),
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "Chat",
                        style: TextStyle(color: Colors.white),
                      ),
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

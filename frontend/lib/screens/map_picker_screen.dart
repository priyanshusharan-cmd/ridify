import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import '../services/location_service.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'dart:math' as math;
import '../widgets/address_search_widget.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;
  const MapPickerScreen({super.key, this.initialPosition});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  late LatLng _centerPosition;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isLocating = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _centerPosition = widget.initialPosition!;
      _isLocating = false;
    } else {
      _centerPosition = const LatLng(28.6139, 77.2090); // Default to New Delhi
      _determinePosition();
    }
  }

  Future<void> _determinePosition() async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        setState(() {
          _centerPosition = LatLng(position.latitude, position.longitude);
          _isLocating = false;
        });
        _mapController.move(_centerPosition, 15.0);
      } else {
        setState(() => _isLocating = false);
      }
    } catch (e) {
      setState(() => _isLocating = false);
      debugPrint("Error getting location: $e");
    }
  }

  Future<void> _selectLocation() async {
    setState(() => _isLoading = true);
    try {
      final lat = _centerPosition.latitude;
      final lng = _centerPosition.longitude;
      final displayName = await LocationService.reverseGeocode(lat, lng);
      if (displayName != null) {
        if (mounted) {
          Navigator.pop(context, {
            'name': displayName,
            'lat': lat,
            'lng': lng,
          });
        }
      } else {
        throw Exception("Failed to fetch address");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to get address for this location"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose Location"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.iconTheme?.color ?? Colors.white,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centerPosition,
              initialZoom: 15.0,
              onPositionChanged: (position, hasGesture) {
                  setState(() {
                    _centerPosition = position.center;
                  });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.ridify.app",
                tileProvider: CancellableNetworkTileProvider(),
              ),
            ],
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40.0), // Offset slightly to point correctly
              child: Icon(Icons.location_on, size: 50, color: Colors.red),
            ),
          ),
          if (_isLocating)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: _isLoading ? null : _selectLocation,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Select this location", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          Positioned(
            top: 20, left: 20, right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
              ),
              child: AddressSearchWidget(
                controller: _searchController,
                hintText: "Search places...",
                prefixIcon: Icons.search,
                iconColor: Colors.grey,
                onSelected: (name, lat, lon) {
                  setState(() {
                    _centerPosition = LatLng(lat, lon);
                  });
                  _mapController.move(_centerPosition, 15.0);
                },
              ),
            ),
          ),
          Positioned(
            bottom: 100, right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() => _isLocating = true);
                    _determinePosition();
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))]),
                    child: const Icon(Icons.my_location, color: Colors.black, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    try { _mapController.rotate(0); } catch (_) {}
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))]),
                    child: StreamBuilder<MapEvent>(
                      stream: _mapController.mapEventStream,
                      builder: (context, snapshot) {
                        double rotation = 0;
                        try { rotation = _mapController.camera.rotation; } catch (_) {}
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

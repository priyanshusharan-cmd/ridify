import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import '../core/socket_service.dart';
import '../widgets/find_ride/available_ride_card.dart';
import '../services/ride_service.dart';

class AvailableRidesScreen extends StatefulWidget {
  final List<dynamic> initialRides;
  final String userName;
  final String userEmail;
  final int selectedSeats;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;
  final String pickupLocation;
  final String destination;
  final VoidCallback? onBack;
  final Future<void> Function()? onRefresh;

  const AvailableRidesScreen({
    super.key,
    required this.initialRides,
    required this.userName,
    required this.userEmail,
    required this.selectedSeats,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    required this.pickupLocation,
    required this.destination,
    this.onBack,
    this.onRefresh,
  });

  @override
  State<AvailableRidesScreen> createState() => _AvailableRidesScreenState();
}

class _AvailableRidesScreenState extends State<AvailableRidesScreen> {
  Timer? _pricePollTimer;
  final List<String> _joinedRides = [];
  late List<dynamic> allRides;
  late List<dynamic> displayedRides;
  String selectedFilter = 'Any'; // Any, Sedan, Bike, SUV
  String routePrefFilter = 'Any'; // Any, nonstop, shared_start, flexible
  String sortOption = 'low_to_high'; // low_to_high, high_to_low

  String? _sendingRideId;

  final List<MapEntry<String, void Function(dynamic)>> _socketListeners = [];

  void _onSocket(String event, void Function(dynamic) handler) {
    SocketService().on(event, handler);
    _socketListeners.add(MapEntry(event, handler));
  }

  @override
  void initState() {
    super.initState();
    allRides = List.from(widget.initialRides);
    _applyFiltersAndSort();
    _initSocketListeners();
    
    for (var ride in allRides) {
      final id = ride['_id']?.toString();
      if (id != null) {
        SocketService().joinRide(id);
        _joinedRides.add(id);
      }
    }
  }

  @override
  void didUpdateWidget(AvailableRidesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRides != oldWidget.initialRides) {
      setState(() {
        allRides = List.from(widget.initialRides);
      });
      _applyFiltersAndSort();
    }
  }

  @override
  void dispose() {
    _pricePollTimer?.cancel();
    
    final svc = SocketService();
    for (final entry in _socketListeners) {
      svc.off(entry.key, entry.value);
    }
    _socketListeners.clear();
    
    for (var id in _joinedRides) {
      SocketService().leaveRide(id);
    }
    
    super.dispose();
  }

  void _initSocketListeners() {
    // Remove rides that get cancelled while browsing
    _onSocket('ride_cancelled', (data) {
      if (data == null) return;
      final map = SocketService.deepConvertMap(data);
      final rideId = map['rideId']?.toString();
      if (rideId != null && mounted) {
        setState(() {
          allRides.removeWhere((r) => r['_id'].toString() == rideId);
        });
        _applyFiltersAndSort();
      }
    });

    // Update rides that change state (e.g., capacity changes after accept/decline)
    _onSocket('ride_accepted', (data) {
      if (data == null) return;
      final map = SocketService.deepConvertMap(data);
      final ride = map['ride'] != null ? SocketService.deepConvertMap(map['ride']) : null;
      if (ride != null && mounted) {
        final rideId = ride['_id']?.toString();
        // If the ride is now full or the user is now a passenger, remove it from search results
        final status = ride['status']?.toString();
        if (status == 'full') {
          setState(() {
            allRides.removeWhere((r) => r['_id'].toString() == rideId);
          });
          _applyFiltersAndSort();
        }
      }
    });

    // Update rides after decline frees up capacity or other changes
    _onSocket('ride_updated', (data) {
      if (data == null) return;
      final map = SocketService.deepConvertMap(data);
      final ride = map['ride'] != null ? SocketService.deepConvertMap(map['ride']) : null;
      if (ride != null && mounted) {
        final rideId = ride['_id']?.toString();
        setState(() {
          final idx = allRides.indexWhere((r) => r['_id'].toString() == rideId);
          if (idx >= 0) {
            // Preserve computed fields from search that the server doesn't send back
            ride['computedFare'] = allRides[idx]['computedFare'];
            ride['computedDistance'] = allRides[idx]['computedDistance'];
            ride['startIndex'] = allRides[idx]['startIndex'];
            ride['endIndex'] = allRides[idx]['endIndex'];
            allRides[idx] = ride;
          }
        });
        _applyFiltersAndSort();
      }
    });
  }

  void _applyFiltersAndSort() {
    setState(() {
      final myEmailLower = widget.userEmail.toLowerCase().trim();
      displayedRides = allRides.where((ride) {
        final List<String> reqs = (ride['requests'] as List?)?.map((e) => e.toString().toLowerCase().trim()).toList() ?? [];
        final List<String> pass = (ride['passengers'] as List?)?.map((e) => e.toString().toLowerCase().trim()).toList() ?? [];
        if (reqs.contains(myEmailLower) || pass.contains(myEmailLower)) return false;

        if (selectedFilter != 'Any') {
          final vehicleType = ride['vehicleType']?.toString().toLowerCase() ?? '';
          if (!vehicleType.contains(selectedFilter.toLowerCase())) return false;
        }

        if (routePrefFilter != 'Any') {
          final pref = ride['routePreference']?.toString() ?? 'flexible'; // Default flexible
          if (pref != routePrefFilter) return false;
        }

        return true;
      }).toList();

      displayedRides.sort((a, b) {
        final fareA = (a['computedFare'] ?? a['fare'] ?? 0) as num;
        final fareB = (b['computedFare'] ?? b['fare'] ?? 0) as num;
        if (sortOption == 'low_to_high') {
          return fareA.compareTo(fareB);
        } else {
          return fareB.compareTo(fareA);
        }
      });
    });
  }

  void _showSortOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                "Filters",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                "Price",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.arrow_upward, color: isDark ? Colors.white : Colors.black),
                title: const Text("Price: Low to High"),
                trailing: sortOption == 'low_to_high' ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() {
                    sortOption = 'low_to_high';
                  });
                  _applyFiltersAndSort();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.arrow_downward, color: isDark ? Colors.white : Colors.black),
                title: const Text("Price: High to Low"),
                trailing: sortOption == 'high_to_low' ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() {
                    sortOption = 'high_to_low';
                  });
                  _applyFiltersAndSort();
                  Navigator.pop(context);
                },
              ),
              const Text(
                "Route Preference",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.arrow_upward, color: isDark ? Colors.white : Colors.black),
                title: const Text("Nonstop"),
                trailing: routePrefFilter == 'nonstop' ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() {
                    routePrefFilter = routePrefFilter == 'nonstop' ? 'Any' : 'nonstop';
                  });
                  _applyFiltersAndSort();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.route, color: isDark ? Colors.white : Colors.black),
                title: const Text("Shared Start"),
                trailing: routePrefFilter == 'shared_start' ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() {
                    routePrefFilter = routePrefFilter == 'shared_start' ? 'Any' : 'shared_start';
                  });
                  _applyFiltersAndSort();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.alt_route, color: isDark ? Colors.white : Colors.black),
                title: const Text("Flexible Route"),
                trailing: routePrefFilter == 'flexible' ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() {
                    routePrefFilter = routePrefFilter == 'flexible' ? 'Any' : 'flexible';
                  });
                  _applyFiltersAndSort();
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> sendRideRequest(dynamic ride, String driverName) async {
    if (_sendingRideId != null) return;
    setState(() => _sendingRideId = ride['_id']);
    try {
      await RideService.requestRide(ride['_id'], {
        "riderName": widget.userName,
        "riderEmail": widget.userEmail,
        "seats": widget.selectedSeats,
        "computedFare": ride['computedFare'],
        "computedDistance": ride['computedDistance'],
        "startIndex": ride['startIndex'],
        "endIndex": ride['endIndex'],
        "pickupLat": widget.pickupLat,
        "pickupLng": widget.pickupLng,
        "destLat": widget.destLat,
        "destLng": widget.destLng,
        "pickupLocation": widget.pickupLocation,
        "destination": widget.destination
      });

      if (mounted) {
        // Successfully requested ride
        if (widget.onBack != null) {
          // It's rendered inside FindRideScreen via AnimatedSwitcher
          Navigator.pop(context); // Close the FindRideScreen wrapper entirely
        } else {
          Navigator.pop(context); // Pop Available Rides Screen
          Navigator.pop(context); // Pop Find Ride Screen, back to home
        }
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          const SnackBar(
            content: Text("Ride Requested!"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          const SnackBar(
            content: Text("Request timed out. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Request Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          const SnackBar(
            content: Text("Could not send request. Check your connection."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sendingRideId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subtitleColor = isDark ? Colors.white54 : Colors.grey[600];

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: RefreshIndicator(
        onRefresh: widget.onRefresh ?? () async {},
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: widget.onBack ?? () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Icon(Icons.arrow_back, color: primaryTextColor, size: 20),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Available Rides",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                            Text(
                              "Choose a ride that fits your journey",
                              style: TextStyle(
                                fontSize: 12,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Header Card with Locations
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.transparent),
                      boxShadow: isDark
                          ? []
                          : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined, color: Colors.green, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.pickupLocation,
                                style: TextStyle(color: primaryTextColor, fontSize: 14, fontWeight: FontWeight.w500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 9, top: 4, bottom: 4),
                          child: Container(width: 2, height: 16, color: Theme.of(context).dividerColor),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.flag_outlined, color: Colors.red, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.destination,
                                style: TextStyle(color: primaryTextColor, fontSize: 14, fontWeight: FontWeight.w500),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Filters Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: ['Any', 'Sedan', 'Bike', 'SUV'].map((filter) {
                                bool isSelected = selectedFilter == filter;
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedFilter = filter;
                                    });
                                    _applyFiltersAndSort();
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDark ? Colors.white : Colors.black)
                                          : cardColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? Colors.transparent : Theme.of(context).dividerColor,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        if (filter == 'Any') ...[
                                          Icon(Icons.grid_view, size: 16, color: isSelected ? (isDark ? Colors.black : Colors.white) : primaryTextColor),
                                          const SizedBox(width: 6),
                                        ] else if (filter == 'Sedan') ...[
                                          Icon(Icons.directions_car, size: 16, color: isSelected ? (isDark ? Colors.black : Colors.white) : primaryTextColor),
                                          const SizedBox(width: 6),
                                        ] else if (filter == 'Bike') ...[
                                          Icon(Icons.motorcycle, size: 16, color: isSelected ? (isDark ? Colors.black : Colors.white) : primaryTextColor),
                                          const SizedBox(width: 6),
                                        ] else if (filter == 'SUV') ...[
                                          Icon(Icons.airport_shuttle, size: 16, color: isSelected ? (isDark ? Colors.black : Colors.white) : primaryTextColor),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          filter,
                                          style: TextStyle(
                                            color: isSelected ? (isDark ? Colors.black : Colors.white) : primaryTextColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _showSortOptions,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Icon(Icons.filter_list, color: primaryTextColor, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            if (displayedRides.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    "No rides available for this filter.",
                    style: TextStyle(color: subtitleColor, fontSize: 16),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final ride = displayedRides[index];
                      return AvailableRideCard(
                        ride: ride,
                        isSending: _sendingRideId == ride['_id'],
                        onBook: () => sendRideRequest(ride, ride['riderName'] ?? "Driver"),
                        fallbackPickup: widget.pickupLocation,
                        fallbackDestination: widget.destination,
                      );
                    },
                    childCount: displayedRides.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

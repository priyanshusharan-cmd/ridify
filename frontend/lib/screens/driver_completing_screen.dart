import 'package:flutter/material.dart';
import '../services/ride_service.dart';
import '../widgets/completion/success_icon.dart';
import '../widgets/completion/trip_summary_card.dart';
import '../widgets/completion/performance_card.dart';
import '../widgets/completion/earnings_breakdown_card.dart';

class DriverCompletingScreen extends StatefulWidget {
  final String rideId;

  const DriverCompletingScreen({
    super.key,
    required this.rideId,
  });

  @override
  State<DriverCompletingScreen> createState() => _DriverCompletingScreenState();
}

class _DriverCompletingScreenState extends State<DriverCompletingScreen> {
  Map<String, dynamic>? rideData;
  bool isLoading = true;

  int totalRidesCompleted = 0;
  int totalDistanceDriven = 0;
  int totalOnlineTimeMins = 0;
  double driverRating = 4.8; // mock rating for now

  @override
  void initState() {
    super.initState();
    _fetchRideData();
  }

  Future<void> _fetchRideData() async {
    try {
      final data = await RideService.getRideById(widget.rideId);
      if (mounted) {
        setState(() {
          rideData = data;
          isLoading = false;
        });
        _fetchPerformanceStats();
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchPerformanceStats() async {
    try {
      final allRides = await RideService.getAllRides();
      if (mounted) {
        
        int rides = 0;
        int distance = 0;
        int time = 0;
        
        String myEmail = rideData?['riderEmail'] ?? "";
        if (myEmail.isEmpty) return;

        for (var r in allRides) {
          if (r['riderEmail'] == myEmail && r['status'] == 'completed') {
            rides++;
            if (r['distance'] != null) {
              distance += (double.tryParse(r['distance'].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0).toInt();
            } else if (r['totalDistance'] != null) {
              distance += (double.tryParse(r['totalDistance'].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0).toInt();
            }

            if (r['startedAt'] != null && r['completedAt'] != null) {
              try {
                DateTime start = DateTime.parse(r['startedAt']);
                DateTime end = DateTime.parse(r['completedAt']);
                time += end.difference(start).inMinutes;
              } catch (_) {}
            }
          }
        }
        
        setState(() {
          totalRidesCompleted = rides;
          totalDistanceDriven = distance;
          totalOnlineTimeMins = time;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Extracting data
    List boardedPassengers = rideData?['boardedPassengers'] ?? [];
    List droppedPassengers = rideData?['droppedPassengers'] ?? [];
    List kickedPassengers = rideData?['kicked'] ?? [];
    
    // Build kicked set to exclude from earnings
    Set<String> kickedSet = {};
    for (var p in kickedPassengers) {
      kickedSet.add(p.toString());
    }

    // People who were actually in the ride (boarded or dropped) — exclude kicked
    Set<String> allInRide = {};
    for (var p in boardedPassengers) {
      if (!kickedSet.contains(p.toString())) allInRide.add(p.toString());
    }
    for (var p in droppedPassengers) {
      if (!kickedSet.contains(p.toString())) allInRide.add(p.toString());
    }

    List<String> inRideNames = [];
    for (var email in allInRide) {
      String name = rideData?['riderDetails']?[email]?['riderName'] ?? email.split('@')[0];
      inRideNames.add(name);
    }

    String pickup = rideData?['pickupLocation'] ?? "Pickup Location";
    String dest = rideData?['destination'] ?? "Destination";
    
    // Format date properly if it exists, otherwise just today
    String dateStr = rideData?['departureTime'] ?? "Today";
    
    int totalEarnings = 0;
    List<Map<String, dynamic>> earningsList = [];
    for (var p in allInRide) {
      int fare = (rideData?['riderDetails']?[p]?['fare'] as num?)?.toInt() ?? 0;
      String name = rideData?['riderDetails']?[p]?['riderName'] ?? p.toString();
      earningsList.add({'name': name, 'fare': fare});
      totalEarnings += fare;
    }

    String distance = "0.0 km";
    String duration = "0 mins";
    if (rideData?['status'] == 'cancelled') {
      distance = "0.0 km";
      duration = "0 mins";
    } else {
      String d = (rideData?['totalDistance'] ?? rideData?['distance'] ?? "0.0").toString();
      double distValue = double.tryParse(d.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      distance = "${distValue.toStringAsFixed(1)} km";
      
      if (rideData?['startedAt'] != null && rideData?['completedAt'] != null) {
        try {
          DateTime start = DateTime.parse(rideData!['startedAt']);
          DateTime end = DateTime.parse(rideData!['completedAt']);
          int diffMins = end.difference(start).inMinutes;
          duration = "${diffMins < 0 ? 0 : diffMins} mins";
        } catch (e) {
          debugPrint("Error parsing dates: $e");
        }
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
      backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SuccessIcon(),
              const SizedBox(height: 24),
              Text(
                "Ride Completed!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Great job! You've completed the ride successfully.",
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              
              TripSummaryCard(
                isDark: isDark,
                dateStr: dateStr,
                pickup: pickup,
                dest: dest,
                distance: distance,
                duration: duration,
                passengers: "${allInRide.length}",
                totalEarnings: "$totalEarnings",
              ),
              const SizedBox(height: 20),

              PerformanceCard(
                isDark: isDark,
                totalRidesCompleted: totalRidesCompleted,
                totalOnlineTimeMins: totalOnlineTimeMins,
                totalDistanceDriven: totalDistanceDriven,
              ),
              const SizedBox(height: 20),

              EarningsBreakdownCard(
                isDark: isDark,
                earningsList: earningsList,
                totalEarnings: totalEarnings,
              ),
              const SizedBox(height: 32),

              // Back to Home Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.transparent),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home_filled, size: 20),
                  label: const Text(
                    "Back to Home",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}


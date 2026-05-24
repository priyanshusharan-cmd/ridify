import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ride_service.dart';
import '../core/socket_service.dart';
import '../widgets/completion/fare_summary.dart';
import '../widgets/completion/success_icon.dart';
import '../widgets/completion/trip_summary_card.dart';
import '../widgets/completion/rating_bar.dart';

class RiderCompletingScreen extends StatefulWidget {
  final bool isDriver;
  final String rideId;
  final String myName;
  final String myEmail;
  final int fareAmount;

  const RiderCompletingScreen({
    super.key,
    this.isDriver = false,
    this.rideId = "",
    this.myName = "",
    this.myEmail = "",
    this.fareAmount = 0,
  });

  @override
  State<RiderCompletingScreen> createState() => _RiderCompletingScreenState();
}

class _RiderCompletingScreenState extends State<RiderCompletingScreen> {
  bool isPaid = false;
  Map<String, dynamic>? rideData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.rideId.isNotEmpty) {
      SocketService().joinRide(widget.rideId);
      _fetchRideData();
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchRideData() async {
    try {
      final data = await RideService.getRideById(widget.rideId);
      if (mounted) {
        setState(() {
          rideData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> markAsPaid() async {
    try {
      await RideService.markPaid(widget.rideId, widget.myEmail);
      setState(() {
        isPaid = true;
      });
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // We don't use global completion anymore. If it's driver, just pop (failsafe)
    if (widget.isDriver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const Scaffold();
    }

    if (isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    String driverName = rideData?['riderName'] ?? "Driver";
    String pickup = rideData?['riderDetails']?[widget.myEmail]?['pickupLocation'] ?? rideData?['pickupLocation'] ?? "Pickup Location";
    String dest = rideData?['riderDetails']?[widget.myEmail]?['destination'] ?? rideData?['destination'] ?? "Destination";
    
    // Format date properly if it exists, otherwise just today
    String dateStr = rideData?['departureTime'] ?? "Today";

    String distance = "0.0 km";
    String duration = "0 mins";

    if (rideData?['status'] == 'cancelled') {
      distance = "0.0 km";
      duration = "0 mins";
    } else {
      String d = (rideData?['riderDetails']?[widget.myEmail.replaceAll('.', '_dot_')]?['distance'] ?? 
                 rideData?['riderDetails']?[widget.myEmail]?['distance'] ?? "0.0").toString();
      double distValue = double.tryParse(d.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      distance = "${distValue.toStringAsFixed(1)} km";
      
      String? boardedAt = rideData?['riderDetails']?[widget.myEmail]?['boardedAt'];
      String? droppedAt = rideData?['riderDetails']?[widget.myEmail]?['droppedAt'];
      if (boardedAt != null && droppedAt != null) {
        try {
          DateTime start = DateTime.parse(boardedAt);
          DateTime end = DateTime.parse(droppedAt);
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
                "Thank you for riding with Ridify.",
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
              ),
              const SizedBox(height: 20),

              FareSummary(
                isDark: isDark,
                driverName: driverName,
                fareAmount: widget.fareAmount,
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
                  onPressed: markAsPaid,
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

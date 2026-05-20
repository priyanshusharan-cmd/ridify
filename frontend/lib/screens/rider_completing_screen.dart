import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';
import '../core/socket_service.dart';

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
      final response = await http.get(Uri.parse('$kBaseUrl/api/rides/${widget.rideId}'));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          rideData = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> markAsPaid() async {
    try {
      await http.patch(Uri.parse('$kBaseUrl/api/rides/pay/${widget.rideId}/${widget.myEmail}'));
      setState(() {
        isPaid = true;
      });
      if (mounted) Navigator.pop(context);
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
      String d = (rideData?['riderDetails']?[widget.myEmail]?['computedDistance'] ?? "0.0").toString();
      distance = d.contains("km") ? d : "$d km";
      
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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Success Icon with confetti dots
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withValues(alpha: 0.1),
                    ),
                  ),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 50),
                  ),
                  // Confetti dots (simple positioning)
                  Positioned(top: 10, left: 20, child: Container(width: 8, height: 8, color: const Color(0xFF4ADE80))),
                  Positioned(top: 20, right: 15, child: Transform.rotate(angle: 0.5, child: Container(width: 10, height: 10, color: const Color(0xFF4ADE80)))),
                  Positioned(bottom: 10, right: 30, child: Container(width: 6, height: 6, color: const Color(0xFF4ADE80))),
                  Positioned(bottom: 25, left: 10, child: Transform.rotate(angle: 1, child: Container(width: 8, height: 8, color: const Color(0xFF4ADE80)))),
                ],
              ),
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
              
              // Trip Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  boxShadow: [
                    if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.list_alt_rounded, color: const Color(0xFF4ADE80), size: 24),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Trip Summary",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr.replaceAll(' at ', ' • '),
                              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Timeline - From
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF4ADE80), size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("From", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(pickup, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Connecting line
                    Padding(
                      padding: const EdgeInsets.only(left: 9),
                      child: Container(height: 20, width: 2, color: isDark ? Colors.white24 : Colors.black12),
                    ),
                    // Timeline - To
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("To", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(dest, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black), maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    
                    // Stats Grid
                    Row(
                      children: [
                        Expanded(child: _buildStatGridItem(Icons.add_road_rounded, "Distance", distance, isDark)),
                        Container(width: 1, height: 40, color: isDark ? Colors.white10 : Colors.black12),
                        Expanded(child: _buildStatGridItem(Icons.access_time_rounded, "Duration", duration, isDark)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Payment Breakdown Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  boxShadow: [
                    if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, color: const Color(0xFF4ADE80), size: 24),
                        const SizedBox(width: 12),
                        Text(
                          "Payment Summary",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Breakdown List
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Paid To", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                                    child: Text(
                                      driverName.substring(0, 1).toUpperCase(),
                                      style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(driverName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Divider
                        Container(
                          width: 1,
                          height: 60,
                          color: isDark ? Colors.white10 : Colors.black12,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        // Total
                        Expanded(
                          flex: 4,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Total Fare", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                              const SizedBox(height: 8),
                              Text("₹${widget.fareAmount}", style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
    );
  }

  Widget _buildStatGridItem(IconData icon, String label, String value, bool isDark, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isDark ? Colors.white54 : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor ?? (isDark ? Colors.white : Colors.black))),
      ],
    );
  }
}

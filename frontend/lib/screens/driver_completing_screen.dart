import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';

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
      final response = await http.get(Uri.parse('$kBaseUrl/api/rides/${widget.rideId}'));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          rideData = jsonDecode(response.body);
          isLoading = false;
        });
        _fetchPerformanceStats();
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchPerformanceStats() async {
    try {
      final response = await http.get(Uri.parse('$kBaseUrl/api/rides'));
      if (response.statusCode == 200 && mounted) {
        List<dynamic> allRides = jsonDecode(response.body);
        
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
                "Great job! You've completed the ride successfully.",
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
                        Expanded(child: _buildStatGridItem(Icons.people_outline_rounded, "Passengers", "${allInRide.length}", isDark)),
                        Container(width: 1, height: 40, color: isDark ? Colors.white10 : Colors.black12),
                        Expanded(child: _buildStatGridItem(Icons.monetization_on_outlined, "Earnings", "₹$totalEarnings", isDark, valueColor: const Color(0xFF4ADE80))),
                      ],
                    ),
                    const SizedBox(height: 16),
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

              // Performance Card
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
                        Icon(Icons.trending_up_rounded, color: const Color(0xFF4ADE80), size: 24),
                        const SizedBox(width: 12),
                        Text(
                          "Your Performance",
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildPerfStat("Rides\nCompleted", "$totalRidesCompleted", Icons.directions_car_rounded, isDark, iconColor: const Color(0xFF4ADE80))),
                        Expanded(child: _buildPerfStat("Online\nTime", "${totalOnlineTimeMins ~/ 60}h ${totalOnlineTimeMins % 60}m", Icons.access_time_filled, isDark, iconColor: Colors.deepPurpleAccent)),
                        Expanded(child: _buildPerfStat("Distance\nDriven", "$totalDistanceDriven km", Icons.add_road, isDark, iconColor: Colors.lightBlue)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Earnings Breakdown Card
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
                          "Earnings Breakdown",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Breakdown List
                          Expanded(
                            flex: 6,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: earningsList.isEmpty 
                                ? [Text("No passengers boarded", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600]))]
                                : earningsList.map((e) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(child: Text(e['name'], style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14), overflow: TextOverflow.ellipsis)),
                                          Text("₹${e['fare']}", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                            ),
                          ),
                          // Divider
                          VerticalDivider(
                            color: isDark ? Colors.white10 : Colors.black12,
                            thickness: 1,
                            width: 40,
                          ),
                          // Total
                          Expanded(
                            flex: 4,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(Icons.account_balance_wallet, color: Colors.brown[400], size: 40),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Icon(Icons.attach_money_rounded, color: const Color(0xFF4ADE80), size: 20),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text("Total Earnings", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                                const SizedBox(height: 4),
                                Text("₹$totalEarnings", style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 24, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
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


  Widget _buildPerfStat(String title, String value, IconData icon, bool isDark, {required Color iconColor, bool showStars = false}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 11, height: 1.2)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        if (showStars) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) => Icon(Icons.star, size: 10, color: index < 4 ? const Color(0xFF4ADE80) : (isDark ? Colors.white24 : Colors.black12))),
          ),
        ],
      ],
    );
  }
}

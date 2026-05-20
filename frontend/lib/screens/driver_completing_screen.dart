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
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => isLoading = false);
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
    List requests = rideData?['requests'] ?? [];
    List kicked = rideData?['kicked'] ?? [];
    List passengers = rideData?['passengers'] ?? [];
    List boardedPassengers = rideData?['boardedPassengers'] ?? [];
    List droppedPassengers = rideData?['droppedPassengers'] ?? [];
    
    // People in the ride (boarded + dropped + passengers) - uniquely
    Set<String> allInRide = {};
    for (var p in passengers) allInRide.add(p.toString());
    for (var p in boardedPassengers) allInRide.add(p.toString());
    for (var p in droppedPassengers) allInRide.add(p.toString());

    List<String> inRideNames = [];
    for (var email in allInRide) {
      String name = rideData?['riderDetails']?[email]?['riderName'] ?? email.split('@')[0];
      inRideNames.add(name);
    }

    List<String> requestNames = [];
    for (var email in requests) {
      String name = rideData?['riderDetails']?[email]?['riderName'] ?? email.split('@')[0];
      requestNames.add(name);
    }

    String pickup = rideData?['pickupLocation'] ?? "Pickup Location";
    String dest = rideData?['destination'] ?? "Destination";
    String date = rideData?['departureTime'] ?? "Today";

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Success Icon
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 60,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Ride Completed!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Thank you for driving with Ridify.",
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 40),
              // Trip Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ride Summary",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Timeline
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.location_on, color: Colors.green, size: 20),
                            Container(
                              height: 32,
                              width: 2,
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                            const Icon(Icons.location_on, color: Colors.red, size: 20),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("From", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(pickup, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 24),
                              Text("To", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(dest, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(color: isDark ? Colors.white24 : Colors.black12),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Date & Time", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
                        Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: isDark ? Colors.white24 : Colors.black12),
                    const SizedBox(height: 16),
                    // Passengers
                    _buildSummaryRow("Total Passengers", "${allInRide.length}", isDark),
                    if (inRideNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text("(${inRideNames.join(', ')})", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                    ],
                    const SizedBox(height: 16),
                    Divider(color: isDark ? Colors.white24 : Colors.black12),
                    const SizedBox(height: 16),
                    // Match Requests
                    _buildSummaryRow("Match Requests", "${requests.length}", isDark),
                    if (requestNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text("(${requestNames.join(', ')})", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                    ],
                    const SizedBox(height: 16),
                    Divider(color: isDark ? Colors.white24 : Colors.black12),
                    const SizedBox(height: 16),
                    // Kicked out
                    _buildSummaryRow("Kicked Out", "${kicked.length}", isDark),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    "Back to Home",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

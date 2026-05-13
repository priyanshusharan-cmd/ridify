import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/constants.dart';
import '../core/socket_service.dart';

class CompletionScreen extends StatefulWidget {
  final bool isDriver;
  final String rideId;
  final String myName;
  final int fareAmount;

  const CompletionScreen({
    super.key,
    this.isDriver = false,
    this.rideId = "",
    this.myName = "",
    this.fareAmount = 0,
  });

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> {
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
      await http.patch(Uri.parse('$kBaseUrl/api/rides/pay/${widget.rideId}/${widget.myName}'));
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
    String date = rideData?['departureTime'] ?? "Today";
    String pickup = rideData?['riderDetails']?[widget.myName]?['pickupLocation'] ?? rideData?['pickupLocation'] ?? "Pickup Location";
    String dest = rideData?['riderDetails']?[widget.myName]?['destination'] ?? rideData?['destination'] ?? "Destination";

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
                "Thank you for riding with Ridify.",
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
                      "Trip Summary",
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
                        const Icon(Icons.location_on, color: Colors.green, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("From", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(pickup, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          child: Center(
                            child: Container(
                              height: 24,
                              width: 2,
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: Colors.red, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Paid To", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600])),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.black,
                              child: Text(
                                driverName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: isDark ? Colors.white24 : Colors.black12),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Amount", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          "₹${widget.fareAmount}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                        ),
                      ],
                    ),
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
                  onPressed: markAsPaid,
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
}

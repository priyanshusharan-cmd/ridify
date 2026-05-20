import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/utils.dart';
import '../core/constants.dart';

class RideHistoryScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  const RideHistoryScreen({super.key, required this.userName, required this.userEmail});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  List<dynamic> myCompletedRides = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRideHistory();
  }

  Future<void> fetchRideHistory() async {
    try {
      final response = await http.get(
        Uri.parse("$kBaseUrl/api/rides"),
      );
      if (response.statusCode == 200 && mounted) {
        List<dynamic> allRides = jsonDecode(response.body);
        setState(() {
          myCompletedRides = allRides
              .where((r) {
                String uemail = widget.userEmail.trim();
                bool isDeclined =
                    r['declined'] != null &&
                    (r['declined'] as List).contains(uemail);
                bool isKicked =
                    r['kicked'] != null &&
                    (r['kicked'] as List).contains(uemail);
                bool isFinished =
                    r['status'] == 'completed' ||
                    r['status'] == 'cancelled' ||
                    isDeclined ||
                    isKicked;

                bool amIDriver =
                    r['riderEmail'] != null &&
                    r['riderEmail'].toString().trim() == uemail;
                bool amIRider =
                    (r['passengers'] != null &&
                        (r['passengers'] as List).contains(uemail)) ||
                    isDeclined ||
                    isKicked;

                return isFinished && (amIDriver || amIRider);
              })
              .toList()
              .reversed
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                "Ride History",
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
                    )
                  : myCompletedRides.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.car_crash,
                            size: 80,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No completed rides yet.",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      // 👈 THE FIX: Added 100px bottom padding to prevent hiding behind the floating bar!
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        bottom: 100,
                      ),
                      itemCount: myCompletedRides.length,
                      itemBuilder: (context, index) {
                        final ride = myCompletedRides[index];
                        String uemail = widget.userEmail.trim();

                        bool wasIDriver =
                            ride['riderEmail'] != null &&
                            ride['riderEmail'].toString().trim() == uemail;
                        bool isCancelled = ride['status'] == 'cancelled';
                        bool wasDeclined =
                            ride['declined'] != null &&
                            (ride['declined'] as List).contains(uemail);
                        bool wasKicked =
                            ride['kicked'] != null &&
                            (ride['kicked'] as List).contains(uemail);

                        final isDark = Theme.of(context).brightness == Brightness.dark;

                        String statusText = "Completed";
                        Color statusColor = isDark ? Colors.grey.shade400 : Colors.grey;
                        if (isCancelled) {
                          statusText = "Cancelled";
                          statusColor = isDark ? Colors.red.shade300 : Colors.red;
                        }
                        if (wasDeclined) {
                          statusText = "Declined";
                          statusColor = isDark ? Colors.orange.shade300 : Colors.orange;
                        }
                        if (wasKicked) {
                          statusText = "Removed from Ride";
                          statusColor = isDark ? Colors.red.shade300 : Colors.redAccent;
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 0,
                          color: Theme.of(context).cardColor,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: wasIDriver
                                            ? (isDark ? const Color(0xFF1A2633) : Colors.blue[50])
                                            : (isDark ? const Color(0xFF162B1D) : Colors.green[50]),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        wasIDriver
                                            ? "Offered (Driver)"
                                            : "Requested (Rider)",
                                        style: TextStyle(
                                          color: wasIDriver
                                              ? (isDark ? Colors.blue.shade300 : Colors.blue[700])
                                              : (isDark ? Colors.green.shade300 : Colors.green[700]),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      "₹${ride['fare'] ?? '0'}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        formatAddress(ride['pickupLocation']?.toString()),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 9,
                                    top: 4,
                                    bottom: 4,
                                  ),
                                  child: Container(
                                    height: 20,
                                    width: 2,
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        formatAddress(ride['destination']?.toString()),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(context).textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 30),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "With: ${wasIDriver ? 'Ride Group' : (ride['riderName'] ?? 'Driver')}",
                                      style: TextStyle(
                                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

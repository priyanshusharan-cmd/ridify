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
                    (r['passengers'] != null && (r['passengers'] as List).contains(uemail)) ||
                    (r['boardedPassengers'] != null && (r['boardedPassengers'] as List).contains(uemail)) ||
                    (r['droppedPassengers'] != null && (r['droppedPassengers'] as List).contains(uemail)) ||
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ride History",
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Your recent rides and earnings",
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
                  : myCompletedRides.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded, size: 80, color: isDark ? Colors.white10 : Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text("No completed rides yet.", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 18, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100),
                      itemCount: myCompletedRides.length,
                      itemBuilder: (context, index) {
                        final ride = myCompletedRides[index];
                        return _buildRideCard(ride, isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideCard(dynamic ride, bool isDark) {
    String uemail = widget.userEmail.trim();
    bool wasIDriver = ride['riderEmail'] != null && ride['riderEmail'].toString().trim() == uemail;
    bool isCancelled = ride['status'] == 'cancelled';
    bool wasDeclined = ride['declined'] != null && (ride['declined'] as List).contains(uemail);
    bool wasKicked = ride['kicked'] != null && (ride['kicked'] as List).contains(uemail);

    String statusText = "Completed";
    Color statusColor = const Color(0xFF4ADE80);
    IconData statusIcon = Icons.check_circle_outline_rounded;
    if (isCancelled) {
      statusText = "Cancelled";
      statusColor = Colors.redAccent;
      statusIcon = Icons.cancel_outlined;
    }
    if (wasDeclined) {
      statusText = "Declined";
      statusColor = Colors.orangeAccent;
      statusIcon = Icons.error_outline_rounded;
    }
    if (wasKicked) {
      statusText = "Removed";
      statusColor = Colors.redAccent;
      statusIcon = Icons.remove_circle_outline_rounded;
    }

    String pickup = formatAddress(ride['pickupLocation']?.toString());
    String dest = formatAddress(ride['destination']?.toString());
    
    // Attempt to split date/time nicely
    String rawDate = ride['departureTime']?.toString() ?? "Unknown";
    String datePart = rawDate;
    String timePart = "";
    if (rawDate.contains(" at ")) {
      var parts = rawDate.split(" at ");
      datePart = parts[0];
      timePart = parts[1];
    } else {
      timePart = rawDate; // Fallback
    }

    String distance = "0.0 km";
    String duration = "0 mins";

    if (isCancelled) {
      distance = "0.0 km";
      duration = "0 mins";
    } else {
      if (wasIDriver) {
        String d = (ride['totalDistance'] ?? ride['distance'] ?? "0.0").toString();
        distance = d.contains("km") ? d : "$d km";
        
        if (ride['startedAt'] != null && ride['completedAt'] != null) {
          try {
            DateTime start = DateTime.parse(ride['startedAt']);
            DateTime end = DateTime.parse(ride['completedAt']);
            int diff = end.difference(start).inMinutes;
            duration = "${diff < 0 ? 0 : diff} mins";
          } catch (_) {}
        }
      } else {
        String d = (ride['riderDetails']?[uemail.replaceAll('.', '_dot_')]?['computedDistance'] ?? 
                   ride['riderDetails']?[uemail]?['computedDistance'] ?? "0.0").toString();
        distance = d.contains("km") ? d : "$d km";

        String? boardedAt = ride['riderDetails']?[uemail.replaceAll('.', '_dot_')]?['boardedAt'] ?? ride['riderDetails']?[uemail]?['boardedAt'];
        String? droppedAt = ride['riderDetails']?[uemail.replaceAll('.', '_dot_')]?['droppedAt'] ?? ride['riderDetails']?[uemail]?['droppedAt'];
        if (boardedAt != null && droppedAt != null) {
          try {
            DateTime start = DateTime.parse(boardedAt);
            DateTime end = DateTime.parse(droppedAt);
            int diff = end.difference(start).inMinutes;
            duration = "${diff < 0 ? 0 : diff} mins";
          } catch (_) {}
        }
      }
    }

    // Passengers count
    Set<String> allInRide = {};
    for (var p in (ride['boardedPassengers'] ?? [])) allInRide.add(p.toString());
    for (var p in (ride['droppedPassengers'] ?? [])) allInRide.add(p.toString());
    for (var p in (ride['passengers'] ?? [])) allInRide.add(p.toString());
    int paxCount = allInRide.length;
    if (paxCount == 0 && (ride['requests'] != null && ride['requests'].isNotEmpty)) paxCount = 1;

    String fare = ride['fare']?.toString() ?? '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: wasIDriver ? (isDark ? const Color(0xFF1A2633) : Colors.blue.shade50) : (isDark ? const Color(0xFF162B1D) : Colors.green.shade50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  wasIDriver ? "Offered (Driver)" : "Requested (Rider)",
                  style: TextStyle(
                    color: wasIDriver ? (isDark ? Colors.blue.shade400 : Colors.blue.shade700) : (isDark ? Colors.green.shade400 : Colors.green.shade700),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Text("₹$fare", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF4ADE80))),
            ],
          ),
          const SizedBox(height: 20),
          
          // Locations & Date/Time
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Locations
              Expanded(
                flex: 3,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.location_on, color: Color(0xFF4ADE80), size: 16),
                        Container(height: 24, width: 2, color: isDark ? Colors.white24 : Colors.black12),
                        const Icon(Icons.location_on, color: Colors.redAccent, size: 16),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pickup, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 18),
                          Text(dest, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Date/Time
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 12, color: isDark ? Colors.white54 : Colors.grey[600]),
                        const SizedBox(width: 6),
                        Flexible(child: Text(datePart, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700], fontSize: 11), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.access_time_rounded, size: 12, color: isDark ? Colors.white54 : Colors.grey[600]),
                        const SizedBox(width: 6),
                        Flexible(child: Text(timePart, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700], fontSize: 11), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Colors.white10),
          ),
          
          // Stats Row
          Row(
            children: [
              _buildSmallStat(Icons.access_time, "Duration", duration, isDark),
              Container(width: 1, height: 30, color: isDark ? Colors.white10 : Colors.black12),
              _buildSmallStat(Icons.add_road, "Distance", distance, isDark),
              Container(width: 1, height: 30, color: isDark ? Colors.white10 : Colors.black12),
              _buildSmallStat(Icons.people_outline, "Passengers", "$paxCount", isDark),
            ],
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Colors.white10),
          ),
          
          // Bottom Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Ride Group / Driver Name
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (wasIDriver) {
                      _showRideGroupPopup(context, ride, allInRide, isDark);
                    }
                  },
                  child: wasIDriver
                      ? Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.people_alt_rounded, size: 16, color: isDark ? Colors.white : Colors.black),
                                  const SizedBox(width: 8),
                                  Text("View Passengers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05), shape: BoxShape.circle),
                              child: Icon(Icons.person_rounded, size: 16, color: isDark ? Colors.white70 : Colors.grey[700]),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Driver", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(
                                    (ride['riderName'] == null || ride['riderName'].toString().trim().isEmpty) ? "Unknown" : ride['riderName'].toString(),
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 12),
              // Status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  const SizedBox(width: 6),
                  Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(IconData icon, String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: isDark ? Colors.white54 : Colors.grey[600]),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black)),
        ],
      ),
    );
  }

  void _showRideGroupPopup(BuildContext context, dynamic ride, Set<String> allInRide, bool isDark) {
    // Collect passenger names from riderDetails if available, otherwise just use emails
    List<String> passengerNames = [];
    if (ride['riderDetails'] != null) {
      for (var email in allInRide) {
        String name = ride['riderDetails'][email]?['riderName'] ?? email.split('@')[0];
        int fare = (ride['riderDetails'][email]?['fare'] as num?)?.toInt() ?? 0;
        passengerNames.add("$name (₹$fare)");
      }
    } else {
      passengerNames = allInRide.map((e) => e.split('@')[0]).toList();
    }

    if (passengerNames.isEmpty) {
      passengerNames = ["No passengers boarded"];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.black26, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 24),
              Text("Passengers Travelled", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 16),
              ...passengerNames.map((name) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                      child: Text(name.substring(0, 1).toUpperCase(), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Text(name, style: TextStyle(fontSize: 15, color: isDark ? Colors.white70 : Colors.black87)),
                  ],
                ),
              )).toList(),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/utils.dart';
import 'package:provider/provider.dart';
import '../../core/theme_provider.dart';
import '../verified_badge.dart';
import 'stat_chip.dart';

class RideHistoryCard extends StatelessWidget {
  final dynamic ride;
  final bool isDark;
  final String userEmail;

  const RideHistoryCard({
    super.key,
    required this.ride,
    required this.isDark,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    String uemail = userEmail.trim().toLowerCase();

    List<String> getLowerList(String key) {
      return (ride[key] as List?)
              ?.map((e) => e.toString().toLowerCase())
              .toList() ??
          [];
    }

    bool wasIDriver =
        ride['riderEmail'] != null &&
        ride['riderEmail'].toString().trim().toLowerCase() == uemail;
    bool isCancelled = ride['status'] == 'cancelled';
    bool wasDeclined = getLowerList('declined').contains(uemail);
    bool wasKicked = getLowerList('kicked').contains(uemail);
    bool wasCancelledRequest = getLowerList('cancelledRequests').contains(uemail);

    // Did the ride actually start?
    bool rideWasStarted = ride['startedAt'] != null;

    bool isExpired = false;
    if (!isCancelled &&
        !wasDeclined &&
        !wasKicked &&
        ride['status'] != 'completed' &&
        ride['expiresAt'] != null) {
      final expiresAt = ride['expiresAt'] is int
          ? ride['expiresAt'] as int
          : int.tryParse(ride['expiresAt'].toString()) ?? 0;
      if (expiresAt > 0 && DateTime.now().millisecondsSinceEpoch > expiresAt) {
        bool hasAcceptedPassengers =
            (ride['passengers'] as List?)?.isNotEmpty == true ||
            (ride['boardedPassengers'] as List?)?.isNotEmpty == true ||
            (ride['droppedPassengers'] as List?)?.isNotEmpty == true;
        if (!hasAcceptedPassengers) {
          isExpired = true;
        }
      }
    }

    String statusText = "Completed";
    Color statusColor = const Color(0xFF4ADE80);
    IconData statusIcon = Icons.check_circle_outline_rounded;
    if (isCancelled || wasCancelledRequest) {
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
    if (isExpired &&
        !isCancelled &&
        !wasDeclined &&
        !wasKicked &&
        ride['status'] != 'completed') {
      statusText = "Expired";
      statusColor = Colors.grey;
      statusIcon = Icons.timer_off_outlined;
    }

    // For riders (not drivers): show THEIR pickup/dest from riderDetails
    String pickup;
    String dest;
    final uemailDot = uemail.replaceAll('.', '_dot_');
    if (!wasIDriver &&
        (ride['riderDetails']?[uemail] != null ||
            ride['riderDetails']?[uemailDot] != null)) {
      final details =
          ride['riderDetails']?[uemail] ?? ride['riderDetails']?[uemailDot];
      pickup = formatAddress(
        details['pickupLocation']?.toString() ??
            ride['pickupLocation']?.toString(),
      );
      dest = formatAddress(
        details['destination']?.toString() ?? ride['destination']?.toString(),
      );
    } else {
      pickup = formatAddress(ride['pickupLocation']?.toString());
      dest = formatAddress(ride['destination']?.toString());
    }

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

    // DECLINED: passenger never travelled → all zeros
    // KICKED: passenger was removed → distance=0, duration=boardedAt→kickedAt (if boarded)
    // CANCELLED (before start): nobody travelled → all zeros
    // CANCELLED (after start, driver): use startedAt→completedAt
    // CANCELLED REQUEST: rider cancelled before accepted → all zeros
    if (wasDeclined || wasCancelledRequest) {
      distance = "0.0 km";
      duration = "0 mins";
    } else if (wasKicked) {
      distance = "0.0 km";
      // If the kicked passenger had boarded, calculate duration as boardedAt → kickedAt
      String? boardedAt = ride['riderDetails']?[uemail]?['boardedAt'];
      String? kickedAt = ride['riderDetails']?[uemail]?['kickedAt'];
      if (boardedAt != null && kickedAt != null) {
        try {
          DateTime start = DateTime.parse(boardedAt);
          DateTime end = DateTime.parse(kickedAt);
          int diff = end.difference(start).inMinutes;
          duration = "${diff < 0 ? 0 : diff} mins";
        } catch (_) {}
      }
    } else if (isCancelled) {
      distance = "0.0 km";
      // If the ride was started before cancellation (driver view), show startedAt → completedAt
      if (wasIDriver && rideWasStarted && ride['completedAt'] != null) {
        try {
          DateTime start = DateTime.parse(ride['startedAt']);
          DateTime end = DateTime.parse(ride['completedAt']);
          int diff = end.difference(start).inMinutes;
          duration = "${diff < 0 ? 0 : diff} mins";
        } catch (_) {}
      }
    } else if (isExpired && !rideWasStarted) {
      // Expired without starting
      distance = "0.0 km";
      duration = "0 mins";
    } else {
      // Normal completed ride
      if (wasIDriver) {
        String d = (ride['totalDistance'] ?? ride['distance'] ?? "0.0")
            .toString();
        double distValue =
            double.tryParse(d.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        distance = "${distValue.toStringAsFixed(1)} km";

        if (ride['startedAt'] != null && ride['completedAt'] != null) {
          try {
            DateTime start = DateTime.parse(ride['startedAt']);
            DateTime end = DateTime.parse(ride['completedAt']);
            int diff = end.difference(start).inMinutes;
            duration = "${diff < 0 ? 0 : diff} mins";
          } catch (_) {}
        }
      } else {
        String d =
            (ride['riderDetails']?[uemail.replaceAll(
                      '.',
                      '_dot_',
                    )]?['distance'] ??
                    ride['riderDetails']?[uemail]?['distance'] ??
                    "0.0")
                .toString();
        double distValue =
            double.tryParse(d.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        distance = "${distValue.toStringAsFixed(1)} km";

        String? boardedAt =
            ride['riderDetails']?[uemail.replaceAll(
              '.',
              '_dot_',
            )]?['boardedAt'] ??
            ride['riderDetails']?[uemail]?['boardedAt'];
        String? droppedAt =
            ride['riderDetails']?[uemail.replaceAll(
              '.',
              '_dot_',
            )]?['droppedAt'] ??
            ride['riderDetails']?[uemail]?['droppedAt'];
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

    int paxCount = 0;
    Set<String> allInRide = {};
    if (wasDeclined ||
        wasKicked ||
        isCancelled ||
        wasCancelledRequest ||
        (isExpired && !rideWasStarted)) {
      paxCount = 0;
    } else if (wasIDriver) {
      Set<String> kickedSet = {};
      for (var p in (ride['kicked'] ?? [])) {
        kickedSet.add(p.toString().toLowerCase());
      }

      for (var p in (ride['boardedPassengers'] ?? [])) {
        if (!kickedSet.contains(p.toString().toLowerCase())) {
          allInRide.add(p.toString().toLowerCase());
        }
      }
      for (var p in (ride['droppedPassengers'] ?? [])) {
        if (!kickedSet.contains(p.toString().toLowerCase())) {
          allInRide.add(p.toString().toLowerCase());
        }
      }
      for (var p in (ride['passengers'] ?? [])) {
        if (!kickedSet.contains(p.toString().toLowerCase())) {
          allInRide.add(p.toString().toLowerCase());
        }
      }

      paxCount = allInRide.length;
    } else {
      final details =
          ride['riderDetails']?[uemail] ?? ride['riderDetails']?[uemailDot];
      paxCount = int.tryParse(details?['seats']?.toString() ?? '1') ?? 1;
    }

    String fare;
    if (wasDeclined || wasKicked || wasCancelledRequest) {
      fare = "0";
    } else if (isCancelled || (isExpired && !rideWasStarted)) {
      fare = "0";
    } else if (wasIDriver) {
      double driverTotalEarned = 0;
      Set<String> validPassengers = {};
      for (var p in (ride['passengers'] ?? [])) {
        validPassengers.add(p.toString().toLowerCase());
      }
      for (var p in (ride['boardedPassengers'] ?? [])) {
        validPassengers.add(p.toString().toLowerCase());
      }
      for (var p in (ride['droppedPassengers'] ?? [])) {
        validPassengers.add(p.toString().toLowerCase());
      }

      Map<String, dynamic> rDetails = ride['riderDetails'] ?? {};
      for (String pEmail in rDetails.keys) {
        String pEmailLower = pEmail.toLowerCase();
        if (validPassengers.contains(pEmailLower) && !wasKicked) {
          bool isPKicked = getLowerList('kicked').contains(pEmailLower);
          if (!isPKicked) {
            double pFarePerSeat =
                double.tryParse(rDetails[pEmail]['fare']?.toString() ?? '0') ??
                0;
            if (pFarePerSeat == 0) {
              pFarePerSeat =
                  double.tryParse(ride['fare']?.toString() ?? '0') ?? 0;
            }
            int seats =
                int.tryParse(rDetails[pEmail]['seats']?.toString() ?? '1') ?? 1;
            driverTotalEarned += (pFarePerSeat * seats);
          }
        }
      }
      fare = driverTotalEarned.toInt().toString();
    } else if (ride['riderDetails']?[uemail]?['fare'] != null ||
        ride['riderDetails']?[uemailDot]?['fare'] != null) {
      // For riders: show THEIR computed fare, multiplied by seats they booked
      final details =
          ride['riderDetails']?[uemail] ?? ride['riderDetails']?[uemailDot];
      double pFarePerSeat = double.tryParse(details['fare'].toString()) ?? 0.0;
      int seats = int.tryParse(details['seats']?.toString() ?? '1') ?? 1;
      fare = (pFarePerSeat * seats).toInt().toString();
    } else {
      fare = ride['fare']?.toString() ?? '0';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: wasIDriver
                      ? (isDark ? const Color(0xFF1A2633) : Colors.blue.shade50)
                      : (isDark
                            ? const Color(0xFF162B1D)
                            : Colors.green.shade50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  wasIDriver ? "Offered (Driver)" : "Requested (Rider)",
                  style: TextStyle(
                    color: wasIDriver
                        ? (isDark ? Colors.blue.shade400 : Colors.blue.shade700)
                        : (isDark
                              ? Colors.green.shade400
                              : Colors.green.shade700),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                "₹$fare",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xFF4ADE80),
                ),
              ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF4ADE80),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pickup,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 7),
                      child: SizedBox(
                        height: 6,
                        width: 2,
                        child: OverflowBox(
                          minHeight: 18,
                          maxHeight: 18,
                          child: Container(
                            width: 2,
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            dest,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            datePart,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey[700],
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            timePart,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.grey[700],
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),

          // Stats Row
          Row(
            children: [
              StatChip(
                icon: Icons.access_time,
                label: "Duration",
                value: duration,
                isDark: isDark,
              ),
              Container(
                width: 1,
                height: 30,
                color: isDark ? Colors.white10 : Colors.black12,
              ),
              StatChip(
                icon: Icons.add_road,
                label: "Distance",
                value: distance,
                isDark: isDark,
              ),
              if (wasIDriver)
                Container(
                  width: 1,
                  height: 30,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              if (wasIDriver)
                StatChip(
                  icon: Icons.people_outline,
                  label: "Passengers",
                  value: "$paxCount",
                  isDark: isDark,
                ),
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
                      _showRideGroupPopup(context, ride, allInRide);
                    }
                  },
                  child: wasIDriver
                      ? Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.people_alt_rounded,
                                    size: 16,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "View Passengers",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Driver",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.grey[600],
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          (ride['riderName'] == null ||
                                                  ride['riderName']
                                                      .toString()
                                                      .trim()
                                                      .isEmpty)
                                              ? "Unknown"
                                              : ride['riderName'].toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (ride['driverVerificationStatus'] ==
                                          'verified') ...[
                                        const SizedBox(width: 4),
                                        const VerifiedBadge(size: 14),
                                      ],
                                    ],
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
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRideGroupPopup(
    BuildContext context,
    dynamic ride,
    Set<String> allInRide,
  ) {
    // Build kicked set
    Set<String> kickedSet = {};
    for (var p in (ride['kicked'] ?? [])) {
      kickedSet.add(p.toString());
    }

    List<Map<String, dynamic>> allNames = [];

    // Collect passenger names from riderDetails if available, otherwise just use emails
    if (ride['riderDetails'] != null) {
      for (var email in allInRide) {
        String name =
            ride['riderDetails'][email]?['riderName'] ?? email.split('@')[0];
        int fare = (ride['riderDetails'][email]?['fare'] as num?)?.toInt() ?? 0;
        bool isVerified =
            ride['riderDetails'][email]?['verificationStatus'] == 'verified';
        allNames.add({
          'displayText': "$name (₹$fare)",
          'isRemoved': false,
          'isVerified': isVerified,
        });
      }
      // Also show kicked passengers separately
      for (var email in kickedSet) {
        String name =
            ride['riderDetails'][email]?['riderName'] ?? email.split('@')[0];
        bool isVerified =
            ride['riderDetails'][email]?['verificationStatus'] == 'verified';
        allNames.add({
          'displayText': "$name (Removed)",
          'isRemoved': true,
          'isVerified': isVerified,
        });
      }
    } else {
      for (var email in allInRide) {
        allNames.add({
          'displayText': email.split('@')[0],
          'isRemoved': false,
          'isVerified': false,
        });
      }
      for (var email in kickedSet) {
        allNames.add({
          'displayText': "${email.split('@')[0]} (Removed)",
          'isRemoved': true,
          'isVerified': false,
        });
      }
    }

    if (allNames.isEmpty) {
      allNames = [
        {
          'displayText': "No passengers boarded",
          'isRemoved': false,
          'isVerified': false,
        },
      ];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Builder(
          builder: (context) {
            final themeProvider = Provider.of<ThemeProvider>(context);
            final isSheetDark = themeProvider.themeMode == ThemeMode.dark ||
                (themeProvider.themeMode == ThemeMode.system &&
                    MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isSheetDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isSheetDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Passengers Travelled",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSheetDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ...allNames.map((passenger) {
                final isRemoved = passenger['isRemoved'] as bool;
                final isVerified = passenger['isVerified'] as bool;
                final displayText = passenger['displayText'] as String;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isRemoved
                            ? Colors.redAccent.withValues(alpha: 0.15)
                            : (isSheetDark ? Colors.white10 : Colors.black12),
                        child: Text(
                          displayText.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: isRemoved
                                ? Colors.redAccent
                                : (isSheetDark ? Colors.white : Colors.black),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        displayText,
                        style: TextStyle(
                          fontSize: 15,
                          color: isRemoved
                              ? Colors.redAccent
                              : (isSheetDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const VerifiedBadge(size: 14),
                      ],
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        );
          },
        );
      },
    );
  }
}

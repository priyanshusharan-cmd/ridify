import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../screens/live_tracking_screen.dart';
import '../screens/match_status_screen.dart';
import '../core/utils.dart';

class ActiveRidesTab extends StatelessWidget {
  final List<dynamic> rides;
  final String myName;
  final VoidCallback onRefresh;
  final VoidCallback onGoHome;

  const ActiveRidesTab({
    super.key,
    required this.rides,
    required this.myName,
    required this.onRefresh,
    required this.onGoHome,
  });

  Future<void> _action(String url, BuildContext context) async {
    try {
      final res = await http.patch(Uri.parse(url));
      if (res.statusCode == 200) onRefresh();
    } catch (e) {
      debugPrint("$e");
    }
  }

  Future<void> _cancelOfferedRide(String id, BuildContext context) async {
    try {
      final res = await http.delete(Uri.parse("$kBaseUrl/api/rides/$id"));
      if (res.statusCode == 200) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ride offer cancelled"),
            backgroundColor: Colors.red,
          ),
        );
        onRefresh();
      }
    } catch (e) {
      debugPrint("$e");
    }
  }

  Widget _buildTimelineAddress(String? pickup, String? destination, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                formatAddress(pickup),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 9, top: 4, bottom: 4),
          child: Container(
            height: 20,
            width: 2,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
        ),
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                formatAddress(destination),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> activeRidesOnly = rides
        .where((r) => r['status'] != 'cancelled' && r['status'] != 'completed')
        .toList();

    // Rider is the driver AND status is available, accepted, or full
    final List<dynamic> myOfferedRides = activeRidesOnly.where((r) {
      return r['riderName'] == myName &&
          (r['status'] == 'available' ||
              r['status'] == 'accepted' ||
              r['status'] == 'full');
    }).toList();

    final List<dynamic> myPendingRequests = activeRidesOnly
        .where((r) => (r['requests'] as List?)?.contains(myName) ?? false)
        .toList();

    final List<dynamic> liveRides = activeRidesOnly.where((r) {
      final bool isDriver = r['riderName'] == myName;
      final bool isPassenger = (r['passengers'] as List?)?.contains(myName) ?? false;

      if (isDriver) {
        return r['status'] == 'started';
      } else if (isPassenger) {
        return r['status'] == 'accepted' ||
            r['status'] == 'full' ||
            r['status'] == 'started';
      }
      return false;
    }).toList();

    final bool isEmpty =
        myOfferedRides.isEmpty && myPendingRequests.isEmpty && liveRides.isEmpty;

    if (isEmpty) {
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                "Activity",
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car,
                      size: 80,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "No active rides or requests.",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Activity",
              style: TextStyle(
                fontSize: 28, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 20),

            // ── Your posted rides (Expandable) ──────────────────────────────
            if (myOfferedRides.isNotEmpty) ...[
              const Text(
                "Your Posted Rides",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...myOfferedRides.map((r) {
                final List requests = r['requests'] as List? ?? [];
                final int reqCount = requests.length;
                final Map seatAllocations = r['seatAllocations'] as Map? ?? {};
                final List passengers = r['passengers'] as List? ?? [];

                return Card(
                  elevation: 0,
                  color: Theme.of(context).cardColor,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: reqCount > 0, // Auto-expand if there are requests!
                      tilePadding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (reqCount > 0)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                "$reqCount",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Icon(Icons.expand_more, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                        ],
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.directions_car, color: Theme.of(context).iconTheme.color),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${r['availableSeats']} Seats Left",
                                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "${r['departureTime']}",
                                            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5), fontSize: 13, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (passengers.isEmpty)
                                TextButton(
                                  onPressed: () => _cancelOfferedRide(r['_id'], context),
                                  child: const Text(
                                    "Cancel Offer",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LiveTrackingScreen(
                                        isDriver: true,
                                        isAlreadyAccepted: true,
                                        rideId: r['_id'],
                                        myName: myName,
                                        otherUserName: "Group",
                                      ),
                                    ),
                                  ).then((_) {
                                    onRefresh();
                                    onGoHome();
                                  }),
                                  child: const Text(
                                    "Open Map",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTimelineAddress(r['pickupLocation']?.toString(), r['destination']?.toString(), Theme.of(context).brightness == Brightness.dark),
                        ],
                      ),
                      children: [
                        if (reqCount == 0)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 24.0, left: 16, right: 16),
                            child: Text(
                              "No match requests yet.",
                              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                          )
                        else
                          ...requests.map((requester) {
                            final int requestedSeats = (seatAllocations[requester] as num?)?.toInt() ?? 1;
                            return Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black,
                                        child: Text(
                                          requester.toString().substring(0, 1).toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "$requester wants to join • Needs $requestedSeats Seat(s)",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Colors.red),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: () => _action(
                                            "$kBaseUrl/api/rides/decline/${r['_id']}/$requester",
                                            context,
                                          ),
                                          child: const Text(
                                            "Decline",
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: () => _action(
                                            "$kBaseUrl/api/rides/accept/${r['_id']}/$requester",
                                            context,
                                          ),
                                          child: const Text(
                                            "Accept",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                );
              }),
              const Divider(height: 30),
            ],

            // ── Passenger – pending requests ───────────────────────────────
            if (myPendingRequests.isNotEmpty) ...[
              const Text(
                "Pending Requests (Rider)",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...myPendingRequests.map(
                (r) => GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchStatusScreen(
                        driverName: r['riderName'],
                        rideId: r['_id'],
                        riderName: myName,
                      ),
                    ),
                  ),
                  child: Card(
                    elevation: 0,
                    color: Theme.of(context).cardColor,
                    margin: const EdgeInsets.only(bottom: 15),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Waiting for ${r['riderName']}",
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text("Tap to view status", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5), fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _action(
                                  "$kBaseUrl/api/rides/decline/${r['_id']}/$myName",
                                  context,
                                ),
                                child: const Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildTimelineAddress(r['pickupLocation']?.toString(), r['destination']?.toString(), Theme.of(context).brightness == Brightness.dark),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 30),
            ],

            // ── Live / ongoing rides ───────────────────────────────────────
            if (liveRides.isNotEmpty) ...[
              const Text(
                "Ongoing Rides",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...liveRides.map(
                (r) => Card(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black,
                  margin: const EdgeInsets.only(bottom: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.map,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r['status'] == 'started' ? "In Progress" : "Arriving",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          r['riderName'] == myName
                                              ? "You are Driving"
                                              : "Riding with ${r['riderName']}",
                                          style: const TextStyle(color: Colors.white70),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () =>
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LiveTrackingScreen(
                                        isDriver: r['riderName'] == myName,
                                        isAlreadyAccepted: true,
                                        rideId: r['_id'],
                                        myName: myName,
                                        otherUserName: r['riderName'] == myName
                                            ? "Group"
                                            : r['riderName'],
                                      ),
                                    ),
                                  ).then((_) {
                                    onRefresh();
                                    onGoHome();
                                  }),
                              child: Text(
                                "Open Map",
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTimelineAddress(r['pickupLocation']?.toString(), r['destination']?.toString(), true),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

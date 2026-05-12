import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../screens/live_tracking_screen.dart';
import '../screens/match_status_screen.dart';
import '../core/utils.dart';

class ActiveRidesTab extends StatefulWidget {
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

  @override
  State<ActiveRidesTab> createState() => _ActiveRidesTabState();
}

class _ActiveRidesTabState extends State<ActiveRidesTab> {
  // Track which accept/decline buttons are currently processing to prevent duplicates
  final Set<String> _processingAccepts = {};

  Future<void> _action(String url, BuildContext context) async {
    try {
      final res = await http.patch(Uri.parse(url));
      if (res.statusCode == 200) widget.onRefresh();
    } catch (e) {
      debugPrint("$e");
    }
  }

  Future<void> _acceptRider(String rideId, String requester, BuildContext context) async {
    final key = '${rideId}_$requester';
    if (_processingAccepts.contains(key)) return; // Already processing

    setState(() => _processingAccepts.add(key));

    try {
      final res = await http.patch(Uri.parse("$kBaseUrl/api/rides/accept/$rideId/$requester"));
      if (res.statusCode == 200) {
        widget.onRefresh();
      } else {
        if (context.mounted) {
          final body = res.body;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint("$e");
    } finally {
      if (mounted) setState(() => _processingAccepts.remove(key));
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
        widget.onRefresh();
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
    final List<dynamic> activeRidesOnly = widget.rides
        .where((r) => r['status'] != 'cancelled' && r['status'] != 'completed')
        .toList();

    // Rider is the driver AND status is available, accepted, or full
    final List<dynamic> myOfferedRides = activeRidesOnly.where((r) {
      return r['riderName'] == widget.myName &&
          (r['status'] == 'available' ||
              r['status'] == 'accepted' ||
              r['status'] == 'full');
    }).toList();

    final List<dynamic> myPendingRequests = activeRidesOnly
        .where((r) => (r['requests'] as List?)?.contains(widget.myName) ?? false)
        .toList();

    final List<dynamic> liveRides = activeRidesOnly.where((r) {
      final bool isDriver = r['riderName'] == widget.myName;
      final bool isPassenger = (r['passengers'] as List?)?.contains(widget.myName) ?? false;

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
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                "Activity",
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold,
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
            const Text(
              "Activity",
              style: TextStyle(
                fontSize: 28, 
                fontWeight: FontWeight.bold,
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
                                        myName: widget.myName,
                                        otherUserName: "Group",
                                      ),
                                    ),
                                  ).then((_) {
                                    widget.onRefresh();
                                    widget.onGoHome();
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
                            final riderDetail = (r['riderDetails'] as Map?)?[requester] as Map?;
                            final int requestedSeats = (riderDetail?['seats'] as num?)?.toInt() ?? ((r['seatAllocations'] as Map?)?[requester] as num?)?.toInt() ?? 1;
                            final num fare = riderDetail?['fare'] ?? r['fare'] ?? 0;
                            final num distance = riderDetail?['distance'] ?? 0;
                            final String pickupAddr = (riderDetail?['pickupLocation'] ?? '').toString();
                            final String destAddr = (riderDetail?['destination'] ?? '').toString();
                            String shortPickup = pickupAddr.length > 50 ? '${pickupAddr.substring(0, 50)}...' : pickupAddr;
                            String shortDest = destAddr.length > 50 ? '${destAddr.substring(0, 50)}...' : destAddr;

                            final String acceptKey = '${r['_id']}_$requester';
                            final bool isProcessing = _processingAccepts.contains(acceptKey);
                            
                            return Padding(
                              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black,
                                          child: Text(requester.toString().substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("$requester", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              Text("$requestedSeats Seat(s) • ${distance.toStringAsFixed(1)} km", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                                          child: Text("₹$fare", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                                        ),
                                      ],
                                    ),
                                    if (shortPickup.isNotEmpty || shortDest.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF252525) : Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Column(children: [
                                          if (shortPickup.isNotEmpty) Row(children: [const Icon(Icons.circle, color: Colors.green, size: 10), const SizedBox(width: 8), Expanded(child: Text(shortPickup, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                                          if (shortPickup.isNotEmpty && shortDest.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2), child: Container(height: 12, width: 2, color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12)),
                                          if (shortDest.isNotEmpty) Row(children: [const Icon(Icons.circle, color: Colors.red, size: 10), const SizedBox(width: 8), Expanded(child: Text(shortDest, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                                        ]),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                          onPressed: isProcessing ? null : () => _action("$kBaseUrl/api/rides/decline/${r['_id']}/$requester", context),
                                          child: const Text("Decline", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        )),
                                        const SizedBox(width: 12),
                                        Expanded(child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isProcessing ? Colors.grey : Colors.black,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: isProcessing ? null : () => _acceptRider(r['_id'], requester, context),
                                          child: isProcessing
                                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Text("Accept", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        )),
                                      ],
                                    ),
                                  ],
                                ),
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
                        riderName: widget.myName,
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
                                  "$kBaseUrl/api/rides/decline/${r['_id']}/${widget.myName}",
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
                                          r['riderName'] == widget.myName
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
                                        isDriver: r['riderName'] == widget.myName,
                                        isAlreadyAccepted: true,
                                        rideId: r['_id'],
                                        myName: widget.myName,
                                        otherUserName: r['riderName'] == widget.myName
                                            ? "Group"
                                            : r['riderName'],
                                      ),
                                    ),
                                  ).then((_) {
                                    widget.onRefresh();
                                    widget.onGoHome();
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

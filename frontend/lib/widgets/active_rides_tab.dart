import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../screens/live_tracking_screen.dart';

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
  final Set<String> _processingAccepts = {};
  String? _selectedRideId;

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
    if (_processingAccepts.contains(key)) return;

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
        setState(() => _selectedRideId = null);
        widget.onRefresh();
      }
    } catch (e) {
      debugPrint("$e");
    }
  }

  void _confirmCancelOffer(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Ride"),
        content: const Text("Do you really want to cancel the ride?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("No", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _cancelOfferedRide(id, context);
            },
            child: const Text("Yes", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openMap(Map<String, dynamic> r) {
    bool isDriver = r['riderName'] == widget.myName;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveTrackingScreen(
          isDriver: isDriver,
          isAlreadyAccepted: true,
          rideId: r['_id'].toString(),
          myName: widget.myName,
          otherUserName: isDriver ? "Group" : r['riderName'],
        ),
      ),
    ).then((_) {
      widget.onRefresh();
      widget.onGoHome();
    });
  }

  Widget _buildTimelineAddress(String? pickup, String? destination, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.circle, color: Colors.green, size: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                formatAddress(pickup),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 6, top: 4, bottom: 4),
          child: Container(
            height: 15,
            width: 2,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
        ),
        Row(
          children: [
            const Icon(Icons.circle, color: Colors.red, size: 14),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                formatAddress(destination),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRideCard(Map<String, dynamic> r, {bool isDetail = false, VoidCallback? onTap}) {
    final List requests = r['requests'] as List? ?? [];
    final int reqCount = requests.length;
    final List passengers = r['passengers'] as List? ?? [];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.directions_car, size: 28, color: isDark ? Colors.white : Colors.black),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${r['availableSeats']} Seats", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
                              const SizedBox(height: 4),
                              Text("${r['departureTime'].toString().replaceAll(' at ', ' • ')}", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (passengers.isEmpty)
                            if (isDetail)
                              GestureDetector(
                                onTap: () => _confirmCancelOffer(r['_id'].toString()),
                                child: const Icon(Icons.close, color: Colors.grey, size: 28),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  "$reqCount Request${reqCount == 1 ? '' : 's'}",
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              )
                          else
                            Material(
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: () => _openMap(r),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(Icons.map, size: 22, color: isDark ? Colors.white : Colors.black),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildTimelineAddress(r['pickupLocation']?.toString(), r['destination']?.toString(), isDark),
                ],
              ),
            ),
            if (!isDetail)
              const Padding(
                padding: EdgeInsets.only(left: 12.0),
                child: Icon(Icons.chevron_right, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> activeRidesOnly = widget.rides
        .where((r) => r['status'] != 'cancelled' && r['status'] != 'completed')
        .toList();

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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        final isDetail = child.key == const ValueKey('detail_view');
        // Slide from right for detail view, from left for list view
        final slideIn = Tween<Offset>(
          begin: isDetail ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

        return SlideTransition(
          position: slideIn,
          child: child,
        );
      },
      child: _selectedRideId != null
          ? _buildDetailView(myOfferedRides)
          : _buildListView(myOfferedRides, myPendingRequests, liveRides),
    );
  }

  Widget _buildDetailView(List<dynamic> myOfferedRides) {
    final selectedObj = myOfferedRides.cast<Map<String, dynamic>?>().firstWhere(
      (r) => r?['_id'].toString() == _selectedRideId,
      orElse: () => null,
    );

    if (selectedObj == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedRideId = null);
      });
      return const Center(key: ValueKey('loading'), child: CircularProgressIndicator());
    }

    final List requests = selectedObj['requests'] as List? ?? [];

    return SafeArea(
      key: const ValueKey('detail_view'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _selectedRideId = null),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  "Ride Detail",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildRideCard(selectedObj, isDetail: true),
            const SizedBox(height: 10),
            if (requests.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 40.0),
                  child: Text(
                    "No match requests yet.",
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 16),
                  ),
                ),
              )
            else ...[
              const Text("Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...requests.map((requester) {
                final riderDetail = (selectedObj['riderDetails'] as Map?)?[requester] as Map?;
                final int requestedSeats = (riderDetail?['seats'] as num?)?.toInt() ?? ((selectedObj['seatAllocations'] as Map?)?[requester] as num?)?.toInt() ?? 1;
                final num fare = riderDetail?['fare'] ?? selectedObj['fare'] ?? 0;
                final num distance = riderDetail?['distance'] ?? 0;
                final String pickupAddr = (riderDetail?['pickupLocation'] ?? '').toString();
                final String destAddr = (riderDetail?['destination'] ?? '').toString();
                String shortPickup = pickupAddr.length > 50 ? '${pickupAddr.substring(0, 50)}...' : pickupAddr;
                String shortDest = destAddr.length > 50 ? '${destAddr.substring(0, 50)}...' : destAddr;

                final String acceptKey = '${selectedObj['_id']}_$requester';
                final bool isProcessing = _processingAccepts.contains(acceptKey);

                return Container(
                  margin: const EdgeInsets.only(bottom: 16.0),
                  padding: const EdgeInsets.all(16),
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
                                Text("$requestedSeats Seat(s) • ${distance.toStringAsFixed(1)} km", style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 13)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                            child: Text("₹$fare", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                          ),
                        ],
                      ),
                      if (shortPickup.isNotEmpty || shortDest.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF252525) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(children: [
                            if (shortPickup.isNotEmpty) Row(children: [const Icon(Icons.circle, color: Colors.green, size: 10), const SizedBox(width: 10), Expanded(child: Text(shortPickup, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8)), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                            if (shortPickup.isNotEmpty && shortDest.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4), child: Align(alignment: Alignment.centerLeft, child: Container(height: 12, width: 2, color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black12))),
                            if (shortDest.isNotEmpty) Row(children: [const Icon(Icons.circle, color: Colors.red, size: 10), const SizedBox(width: 10), Expanded(child: Text(shortDest, style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8)), maxLines: 1, overflow: TextOverflow.ellipsis))]),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: isProcessing ? null : () => _action("$kBaseUrl/api/rides/decline/${selectedObj['_id']}/$requester", context),
                            child: const Text("Decline", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isProcessing ? Colors.grey : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: isProcessing ? null : () => _acceptRider(selectedObj['_id'], requester, context),
                            child: isProcessing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text("Accept", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          )),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<dynamic> myOfferedRides, List<dynamic> myPendingRequests, List<dynamic> liveRides) {
    final bool isEmpty =
        myOfferedRides.isEmpty && myPendingRequests.isEmpty && liveRides.isEmpty;

    if (isEmpty) {
      return SafeArea(
        key: const ValueKey('list_view'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                "Activity",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_car, size: 80, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    const Text("No active rides or requests.", style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      key: const ValueKey('list_view'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Activity",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            if (myOfferedRides.isNotEmpty) ...[
              const Text(
                "Your Posted Rides",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...myOfferedRides.map((r) => _buildRideCard(r as Map<String, dynamic>, onTap: () => setState(() => _selectedRideId = r['_id'].toString()))),
              const SizedBox(height: 30),
            ],

            // Pending requests (Rider)
            if (myPendingRequests.isNotEmpty) ...[
              const Text(
                "Pending Requests",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...myPendingRequests.map(
                (r) => Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Waiting for ${r['riderName']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color), overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).brightness == Brightness.dark ? Colors.amber.shade300.withValues(alpha: 0.15) : Colors.amber.shade800.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text("Pending", style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.amber.shade300 : Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _action("$kBaseUrl/api/rides/decline/${r['_id']}/${widget.myName}", context),
                            child: const Text("Cancel", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTimelineAddress(r['pickupLocation']?.toString(), r['destination']?.toString(), Theme.of(context).brightness == Brightness.dark),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],

            // Ongoing rides
            if (liveRides.isNotEmpty) ...[
              const Text(
                "Ongoing Rides",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...liveRides.map(
                (r) => _buildRideCard(r as Map<String, dynamic>, onTap: () => _openMap(r))
              ),
            ],
          ],
        ),
      ),
    );
  }
}

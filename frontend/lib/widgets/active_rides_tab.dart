import 'package:flutter/material.dart';
import '../services/ride_service.dart';
import '../screens/live_tracking_screen.dart';
import 'active_rides/offered_ride_card.dart';
import 'active_rides/request_detail_card.dart';
import 'active_rides/pending_request_tile.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
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
                const Text(
                  "No active rides or requests.",
                  style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ActiveRidesTab extends StatefulWidget {
  final List<dynamic> rides;
  final String myName;
  final String myEmail;
  final VoidCallback onRefresh;
  final VoidCallback onGoHome;

  const ActiveRidesTab({
    super.key,
    required this.rides,
    required this.myName,
    required this.myEmail,
    required this.onRefresh,
    required this.onGoHome,
  });

  @override
  State<ActiveRidesTab> createState() => _ActiveRidesTabState();
}

class _ActiveRidesTabState extends State<ActiveRidesTab> {
  final Set<String> _processingAccepts = {};
  String? _selectedRideId;

  Future<void> _declineRider(String rideId, String requester, BuildContext context) async {
    try {
      await RideService.declineRider(rideId, requester);
      widget.onRefresh();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _acceptRider(String rideId, String requester, BuildContext context) async {
    final key = '${rideId}_$requester';
    if (_processingAccepts.contains(key)) return;

    setState(() => _processingAccepts.add(key));

    try {
      await RideService.acceptRider(rideId, requester);
      widget.onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
      debugPrint(e.toString());
      debugPrint(e.toString());
    } finally {
      if (mounted) setState(() => _processingAccepts.remove(key));
    }
  }

  Future<void> _cancelOfferedRide(String id, BuildContext context) async {
    try {
      await RideService.cancelRide(id, callerEmail: widget.myEmail);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ride offer cancelled"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _selectedRideId = null);
      widget.onRefresh();
    } catch (e) {
      debugPrint(e.toString());
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
    bool isDriver = r['riderEmail'] == widget.myEmail;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveTrackingScreen(
          isDriver: isDriver,
          isAlreadyAccepted: true,
          rideId: r['_id'].toString(),
          myName: widget.myName,
          myEmail: widget.myEmail,
          otherUserName: isDriver ? "Group" : r['riderName'],
        ),
      ),
    ).then((_) {
      widget.onRefresh();
      widget.onGoHome();
    });
  }



  @override
  Widget build(BuildContext context) {
    final List<dynamic> activeRidesOnly = widget.rides
        .where((r) => r['status'] != 'cancelled' && r['status'] != 'completed')
        .toList();

    final List<dynamic> myOfferedRides = activeRidesOnly.where((r) {
      return r['riderEmail'] == widget.myEmail &&
          (r['status'] == 'available' ||
              r['status'] == 'accepted' ||
              r['status'] == 'full');
    }).toList();

    final List<dynamic> myPendingRequests = activeRidesOnly
        .where((r) => (r['requests'] as List?)?.contains(widget.myEmail) ?? false)
        .toList();

    final List<dynamic> liveRides = activeRidesOnly.where((r) {
      final bool isDriver = r['riderEmail'] == widget.myEmail;
      final bool isPassenger = (r['passengers'] as List?)?.contains(widget.myEmail) ?? false;

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
            ?currentChild,
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
            OfferedRideCard(
              ride: selectedObj,
              isDetail: true,
              onCancelOffer: () => _confirmCancelOffer(selectedObj['_id'].toString()),
              onOpenMap: () => _openMap(selectedObj),
            ),
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
                final String acceptKey = '${selectedObj['_id']}_$requester';
                final bool isProcessing = _processingAccepts.contains(acceptKey);
                return RequestDetailCard(
                  ride: selectedObj,
                  requester: requester.toString(),
                  isProcessing: isProcessing,
                  onAccept: () => _acceptRider(selectedObj['_id'], requester.toString(), context),
                  onDecline: () => _declineRider(selectedObj['_id'].toString(), requester.toString(), context),
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
      return const SafeArea(
        key: ValueKey('list_view'),
        child: EmptyState(),
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
              ...myOfferedRides
                .whereType<Map<String, dynamic>>()
                .map((r) => OfferedRideCard(
                ride: r,
                onTap: () => setState(() => _selectedRideId = r['_id'].toString()),
                onCancelOffer: () => _confirmCancelOffer(r['_id'].toString()),
                onOpenMap: () => _openMap(r),
              )),
              const SizedBox(height: 30),
            ],

            // Pending requests (Rider)
            if (myPendingRequests.isNotEmpty) ...[
              const Text(
                "Pending Requests",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...myPendingRequests
                .whereType<Map<String, dynamic>>()
                .map(
                  (r) => PendingRequestTile(
                    request: r,
                    myEmail: widget.myEmail,
                    onCancel: _declineRider,
                  )
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
              ...liveRides
                .whereType<Map<String, dynamic>>()
                .map(
                (r) => OfferedRideCard(
                  ride: r,
                  isOngoing: true,
                  onTap: () => _openMap(r),
                  onOpenMap: () => _openMap(r),
                )
              ),
            ],
          ],
        ),
      ),
    );
  }
}

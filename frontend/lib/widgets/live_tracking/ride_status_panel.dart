import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../screens/chat_screen.dart';
import 'passenger_tile.dart';

class RideStatusPanel extends StatelessWidget {
  final bool isDriver;
  final bool isAccepted;
  final bool isStarted;
  final bool iHaveBoarded;
  final bool iAmArrived;
  final bool iAmDropped;
  final bool canEnd;
  final String otherUserName;
  final String statusText;
  final int currentlyOccupied;
  final int totalCap;
  final Map<String, dynamic>? rideData;
  final List activePassengers;
  final String myName;
  final String myEmail;
  final String rideId;
  final bool isProcessing;
  final VoidCallback onBoardRide;
  final VoidCallback onStartRide;
  final VoidCallback onEndRide;
  final void Function(String) onDropOffPassenger;
  final void Function(String) onConfirmKickPassenger;
  final void Function(String) onDriverArriveForPassenger;

  const RideStatusPanel({
    super.key,
    required this.isDriver,
    required this.isAccepted,
    required this.isStarted,
    required this.iHaveBoarded,
    required this.iAmArrived,
    required this.iAmDropped,
    required this.canEnd,
    required this.otherUserName,
    required this.statusText,
    required this.currentlyOccupied,
    required this.totalCap,
    required this.rideData,
    required this.activePassengers,
    required this.myName,
    required this.myEmail,
    required this.rideId,
    required this.isProcessing,
    required this.onBoardRide,
    required this.onStartRide,
    required this.onEndRide,
    required this.onDropOffPassenger,
    required this.onConfirmKickPassenger,
    required this.onDriverArriveForPassenger,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final panelText = isDark ? Colors.white : Colors.black;
    final panelSub = isDark ? Colors.white54 : Colors.grey;

    double minSize = isDriver ? 0.32 : 0.25;
    double maxSize = isDriver
        ? (minSize + (activePassengers.length * 0.13)).clamp(minSize + 0.01, 0.85)
        : minSize + 0.01;

    return DraggableScrollableSheet(
      initialChildSize: minSize,
      minChildSize: minSize,
      maxChildSize: maxSize,
      snap: true,
      snapSizes: (isDriver && activePassengers.isNotEmpty) ? [minSize, maxSize] : null,
      builder: (BuildContext context, ScrollController scrollController) {
        if (rideData == null) {
          return Container(
            decoration: BoxDecoration(
              color: panelBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: panelBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ).copyWith(scrollbars: false),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              children: [
                // ── Drag handle ──
                Center(
                  child: Container(
                    width: 40, height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                // ── Header row ──
                Row(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        isAccepted ? (isDriver ? "G" : otherUserName.substring(0, 1).toUpperCase()) : "?",
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      isAccepted ? (isDriver ? "Ride Group" : otherUserName) : "Finding Match...",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: panelText),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isStarted ? Colors.blue.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isStarted ? Colors.blue : Colors.green)),
                        const SizedBox(width: 6),
                        Text(statusText, style: TextStyle(color: isStarted ? (isDark ? Colors.blue.shade300 : Colors.blue.shade700) : (isDark ? Colors.green.shade300 : Colors.green.shade700), fontWeight: FontWeight.bold, fontSize: 12)),
                      ]),
                    ),
                  ])),
                  // Rider: Board button
                  if (!isDriver && isAccepted && !iHaveBoarded && !iAmDropped)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (!iAmArrived || isProcessing) ? Colors.grey.shade300 : (isDark ? const Color(0xFF1B4332) : Colors.green.shade600),
                        foregroundColor: (!iAmArrived || isProcessing) ? Colors.grey.shade600 : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: isProcessing ? null : () {
                        if (!iAmArrived) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wait for the driver to arrive"), backgroundColor: Colors.orange));
                        } else {
                          onBoardRide();
                        }
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: isProcessing ? 0 : 1,
                            child: const Text("Board", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                          if (isProcessing)
                            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        ],
                      ),
                    ),
                  // Driver: Start / End button
                  if (isDriver) ...[
                    if (!isStarted)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isProcessing ? Colors.grey.shade300 : (isDark ? const Color(0xFF1A3A5C) : Colors.blue.shade600),
                          foregroundColor: isProcessing ? Colors.grey.shade600 : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        onPressed: isProcessing ? null : onStartRide,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: isProcessing ? 0 : 1,
                              child: const Text("Start", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            if (isProcessing)
                              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          ],
                        ),
                      )
                    else
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (canEnd && !isProcessing) ? (isDark ? const Color(0xFF5C1A1A) : Colors.red.shade600) : Colors.grey.shade300,
                          foregroundColor: (canEnd && !isProcessing) ? Colors.white : Colors.grey.shade600,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        onPressed: isProcessing ? null : () {
                          if (!canEnd) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("There are passengers still in the car"), backgroundColor: Colors.red));
                          } else {
                            onEndRide();
                          }
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Opacity(
                              opacity: isProcessing ? 0 : 1,
                              child: const Text("End", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                            if (isProcessing)
                              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          ],
                        ),
                      ),
                  ],
                ]),
                // ── Capacity indicator ──
                if (isDriver) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF252525) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    ),
                    child: Row(children: [
                      Icon(Icons.airline_seat_recline_normal, size: 20, color: Colors.blue.shade400),
                      const SizedBox(width: 8),
                      Text("$currentlyOccupied / $totalCap seats occupied", style: TextStyle(color: panelText, fontSize: 14, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
                // ── Passengers (revealed when dragged up) ──
                if (isDriver && rideData != null && activePassengers.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text("Passengers", style: TextStyle(fontWeight: FontWeight.bold, color: panelSub, fontSize: 14, letterSpacing: 0.5)),
                  const SizedBox(height: 12),
                  ...activePassengers.map<Widget>((p) {
                    bool isBoarded = (rideData!['boardedPassengers'] ?? []).contains(p);
                    bool isArrived = (rideData!['arrivedAt'] ?? []).contains(p);
                    int neededSeats = ((rideData?['riderDetails']?[p]?['seats']) ?? 1) as int;
                    bool canFit = (currentlyOccupied + neededSeats) <= totalCap;
                    String? pickupAddr = rideData?['riderDetails']?[p]?['pickupLocation'];
                    String? destAddr = rideData?['riderDetails']?[p]?['destination'];
                    String subtitle = isBoarded ? "Boarded ✓" : (isArrived ? "Arrived — waiting to board" : "Picking up soon");
                    String addrText = isBoarded ? (destAddr ?? "") : (pickupAddr ?? "");
                    String displayName = rideData?['riderDetails']?[p]?['riderName'] ?? p.toString();

                    return PassengerTile(
                      passengerId: p,
                      displayName: displayName,
                      subtitle: subtitle,
                      addrText: addrText,
                      isBoarded: isBoarded,
                      isArrived: isArrived,
                      isStarted: isStarted,
                      canFit: canFit,
                      isProcessing: isProcessing,
                      routePreference: rideData?['routePreference'] ?? 'flexible',
                      isDark: isDark,
                      onDropOff: () => onDropOffPassenger(p),
                      onKick: () => onConfirmKickPassenger(p),
                      onArrive: () => onDriverArriveForPassenger(p),
                    );
                  }),
                ],
                // ── Chat button (always at bottom of list) ──
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF333333) : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(myName: myName, myEmail: myEmail, otherName: isDriver ? "Group" : otherUserName, rideId: rideId))),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
                    label: const Text("Chat", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

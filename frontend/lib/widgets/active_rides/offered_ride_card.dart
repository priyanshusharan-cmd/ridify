import 'package:flutter/material.dart';
import '../../core/utils.dart';

class TimelineAddress extends StatelessWidget {
  final String? pickup;
  final String? destination;
  final bool isDark;

  const TimelineAddress({
    super.key,
    required this.pickup,
    required this.destination,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.circle, color: Colors.green, size: 14),
            Container(
              height: 24,
              width: 2,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const Icon(Icons.circle, color: Colors.red, size: 14),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatAddress(pickup),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.0,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                formatAddress(destination),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  height: 1.0,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class OfferedRideCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final bool isDetail;
  final bool isOngoing;
  final String? userEmail;
  final VoidCallback? onTap;
  final VoidCallback? onCancelOffer;
  final VoidCallback? onOpenMap;

  const OfferedRideCard({
    super.key,
    required this.ride,
    this.isDetail = false,
    this.isOngoing = false,
    this.userEmail,
    this.onTap,
    this.onCancelOffer,
    this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final List requests = ride['requests'] as List? ?? [];
    final int reqCount = requests.length;
    final List passengers = ride['passengers'] as List? ?? [];
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
                              Text(
                                "${ride['availableSeats']} Seats",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ride['departureTime'].toString().replaceAll(' at ', ' • '),
                                style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Builder(
                        builder: (context) {
                          bool hasRightIcon = (passengers.isEmpty && isDetail) || (!isOngoing && passengers.isNotEmpty);
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isDetail && reqCount > 0)
                                Container(
                                  margin: EdgeInsets.only(right: hasRightIcon ? 12 : 0),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "$reqCount Request${reqCount == 1 ? '' : 's'}",
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          if (passengers.isEmpty && isDetail)
                            GestureDetector(
                              onTap: onCancelOffer,
                              child: const Icon(Icons.close, color: Colors.grey, size: 28),
                            )
                          else if (!isOngoing && passengers.isNotEmpty)
                            Material(
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: onOpenMap,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  child: Icon(Icons.map, size: 22, color: isDark ? Colors.white : Colors.black),
                                ),
                              ),
                            ),
                        ],
                      );
                     }
                   ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Builder(
                    builder: (context) {
                      String pickup = ride['pickupLocation']?.toString() ?? '';
                      String destination = ride['destination']?.toString() ?? '';
                      
                      if (userEmail != null) {
                        String emailLower = userEmail!.trim().toLowerCase();
                        Map<String, dynamic>? details = ride['riderDetails']?[emailLower];
                        if (details != null) {
                          pickup = details['pickupLocation']?.toString() ?? pickup;
                          destination = details['destination']?.toString() ?? destination;
                        }
                      }
                      
                      return TimelineAddress(
                        pickup: pickup,
                        destination: destination,
                        isDark: isDark,
                      );
                    },
                  ),
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
}

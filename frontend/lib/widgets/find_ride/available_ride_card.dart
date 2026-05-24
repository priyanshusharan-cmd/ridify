import 'package:flutter/material.dart';

class AvailableRideCard extends StatelessWidget {
  final dynamic ride;
  final bool isSending;
  final VoidCallback onBook;
  final String fallbackPickup;
  final String fallbackDestination;

  const AvailableRideCard({
    super.key,
    required this.ride,
    required this.isSending,
    required this.onBook,
    required this.fallbackPickup,
    required this.fallbackDestination,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final primaryTextColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subtitleColor = isDark ? Colors.white54 : Colors.grey[600];

    final computedFare = ride['computedFare'] ?? ride['fare'];
    final computedDistance = ride['computedDistance'] != null ? ride['computedDistance'].toStringAsFixed(1) : "?";
    final driverName = ride['riderName'] ?? "Driver";
    final vehicle = ride['vehicleType'] ?? 'Sedan';
    final routePref = ride['routePreference'] == 'nonstop' ? 'Nonstop' : 'Flexible Route';
    final departs = ride['departureTime'] ?? "Now";
    final totalSeats = ride['totalSeats'] ?? 4;
    final seatsLeft = totalSeats - (ride['boardedPassengers'] as List? ?? []).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.black,
                child: const Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryTextColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$vehicle • $routePref",
                      style: TextStyle(color: primaryTextColor, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "₹$computedFare",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryTextColor),
                  ),
                  Text(
                    "Per Seat",
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Theme.of(context).dividerColor),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: subtitleColor),
                        const SizedBox(width: 8),
                        Text(
                          "Departs at $departs",
                          style: TextStyle(color: subtitleColor, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ride['pickupLocation'] ?? fallbackPickup,
                            style: TextStyle(color: primaryTextColor, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 3, top: 4, bottom: 4),
                      child: Container(width: 2, height: 12, color: Theme.of(context).dividerColor),
                    ),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ride['destination'] ?? fallbackDestination,
                            style: TextStyle(color: primaryTextColor, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.airline_seat_recline_normal, size: 14, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text(
                        "$seatsLeft Seats Left",
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.add_road, size: 14, color: subtitleColor),
                      const SizedBox(width: 4),
                      Text(
                        "$computedDistance km",
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      minimumSize: const Size(100, 40),
                    ),
                    onPressed: onBook,
                    child: isSending 
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: isDark ? Colors.black : Colors.white))
                        : const Text("Book", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

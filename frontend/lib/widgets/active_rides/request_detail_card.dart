import 'package:flutter/material.dart';

class RequestDetailCard extends StatelessWidget {
  final Map<String, dynamic> ride;
  final String requester;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const RequestDetailCard({
    super.key,
    required this.ride,
    required this.requester,
    required this.isProcessing,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final riderDetail = (ride['riderDetails'] as Map?)?[requester] as Map?;
    final String displayName = (riderDetail?['riderName'] ?? requester).toString();
    final int requestedSeats = (riderDetail?['seats'] as num?)?.toInt() ?? ((ride['seatAllocations'] as Map?)?[requester] as num?)?.toInt() ?? 1;
    final num fare = riderDetail?['fare'] ?? ride['fare'] ?? 0;
    final num distance = riderDetail?['distance'] ?? 0;
    final String pickupAddr = (riderDetail?['pickupLocation'] ?? '').toString();
    final String destAddr = (riderDetail?['destination'] ?? '').toString();
    String shortPickup = pickupAddr.length > 50 ? '${pickupAddr.substring(0, 50)}...' : pickupAddr;
    String shortDest = destAddr.length > 50 ? '${destAddr.substring(0, 50)}...' : destAddr;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.black,
                child: Text(
                  displayName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      requester,
                      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6), fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.event_seat, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text("$requestedSeats", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        const Icon(Icons.route, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text("${distance.toStringAsFixed(1)} km", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
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
                color: isDark ? const Color(0xFF252525) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (shortPickup.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.green, size: 10),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            shortPickup,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (shortPickup.isNotEmpty && shortDest.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 12,
                          width: 2,
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                      ),
                    ),
                  if (shortDest.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.red, size: 10),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            shortDest,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isProcessing ? null : onDecline,
                  child: const Text("Decline", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isProcessing ? Colors.grey : (isDark ? Colors.white : Colors.black),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isProcessing ? null : onAccept,
                  child: isProcessing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          "Accept",
                          style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

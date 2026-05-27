import 'package:flutter/material.dart';
import 'offered_ride_card.dart';

class PendingRequestTile extends StatelessWidget {
  final Map<String, dynamic> request;
  final String myEmail;
  final Function(String rideId, String requesterEmail, BuildContext context) onCancel;

  const PendingRequestTile({
    super.key,
    required this.request,
    required this.myEmail,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
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
                    Text(
                      "Waiting for ${request['riderName']}", 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16, 
                        color: Theme.of(context).textTheme.bodyLarge?.color
                      ), 
                      overflow: TextOverflow.ellipsis
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark 
                          ? Colors.amber.shade300.withValues(alpha: 0.15) 
                          : Colors.amber.shade800.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Pending", 
                        style: TextStyle(
                          color: isDark ? Colors.amber.shade300 : Colors.amber.shade800, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 12
                        )
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => onCancel(request['_id'].toString(), myEmail, context),
                child: const Text("Cancel", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Builder(
            builder: (context) {
              final String myEmailLower = myEmail.trim().toLowerCase();
              final Map<String, dynamic>? myDetails = request['riderDetails']?[myEmailLower];
              final String pickup = myDetails?['pickup']?.toString() ?? request['pickupLocation']?.toString() ?? '';
              final String destination = myDetails?['destination']?.toString() ?? request['destination']?.toString() ?? '';

              return TimelineAddress(
                pickup: pickup,
                destination: destination,
                isDark: isDark,
              );
            }
          ),
        ],
      ),
    );
  }
}

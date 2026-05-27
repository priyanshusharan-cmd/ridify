import 'package:flutter/material.dart';
import '../services/ride_service.dart';
import '../widgets/history/ride_history_card.dart';

class RideHistoryScreen extends StatelessWidget {
  final String userName;
  final String userEmail;
  final List<dynamic> allRides;

  const RideHistoryScreen({
    super.key, 
    required this.userName, 
    required this.userEmail,
    required this.allRides,
  });

  @override
  Widget build(BuildContext context) {
    String uemail = userEmail.trim();
    List<dynamic> myCompletedRides = allRides.where((r) {
      bool isDeclined = r['declined'] != null && (r['declined'] as List).contains(uemail);
      bool isKicked = r['kicked'] != null && (r['kicked'] as List).contains(uemail);
      bool isFinished = r['status'] == 'completed' || r['status'] == 'cancelled' || isDeclined || isKicked;

      bool amIDriver = r['riderEmail'] != null && r['riderEmail'].toString().trim() == uemail;
      bool amIRider = (r['passengers'] != null && (r['passengers'] as List).contains(uemail)) ||
          (r['boardedPassengers'] != null && (r['boardedPassengers'] as List).contains(uemail)) ||
          (r['droppedPassengers'] != null && (r['droppedPassengers'] as List).contains(uemail)) ||
          isDeclined || isKicked;

      return isFinished && (amIDriver || amIRider);
    }).toList().reversed.toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ride History",
                    style: TextStyle(
                      fontSize: 28, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Your recent rides and earnings",
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
                  : myCompletedRides.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_rounded, size: 80, color: isDark ? Colors.white10 : Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text("No completed rides yet.", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 18, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100),
                      itemCount: myCompletedRides.length,
                      itemBuilder: (context, index) {
                        final ride = myCompletedRides[index];
                        return RideHistoryCard(ride: ride, isDark: isDark, userEmail: widget.userEmail);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

}

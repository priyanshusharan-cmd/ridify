import 'package:flutter/material.dart';

import '../widgets/history/ride_history_card.dart';

class RideHistoryScreen extends StatelessWidget {
  final String userName;
  final String userEmail;
  final List<dynamic> allRides;
  final Future<void> Function()? onRefresh;

  const RideHistoryScreen({
    super.key, 
    required this.userName, 
    required this.userEmail,
    required this.allRides,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    String uemail = userEmail.trim().toLowerCase();
    List<dynamic> myCompletedRides = allRides.where((r) {
      List<String> getLowerList(String key) {
        return (r[key] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? [];
      }
      
      bool isDeclined = getLowerList('declined').contains(uemail);
      bool isKicked = getLowerList('kicked').contains(uemail);
      bool isDropped = getLowerList('droppedPassengers').contains(uemail);
      
      bool isExpired = false;
      if (r['status'] != 'cancelled' && r['status'] != 'completed' && r['expiresAt'] != null) {
        final expiresAt = r['expiresAt'] is int 
            ? r['expiresAt'] as int 
            : int.tryParse(r['expiresAt'].toString()) ?? 0;
        if (expiresAt > 0 && DateTime.now().millisecondsSinceEpoch > expiresAt) {
          bool hasAcceptedPassengers = (r['passengers'] as List?)?.isNotEmpty == true || 
                                       (r['boardedPassengers'] as List?)?.isNotEmpty == true || 
                                       (r['droppedPassengers'] as List?)?.isNotEmpty == true;
          if (!hasAcceptedPassengers) {
            isExpired = true;
          }
        }
      }

      bool isCancelledRequest = getLowerList('cancelledRequests').contains(uemail);
      bool isFinished = r['status'] == 'completed' || r['status'] == 'cancelled' || isDeclined || isKicked || isDropped || isExpired || isCancelledRequest;

      bool amIDriver = r['riderEmail'] != null && r['riderEmail'].toString().trim().toLowerCase() == uemail;
      bool amIRider = getLowerList('passengers').contains(uemail) ||
          getLowerList('boardedPassengers').contains(uemail) ||
          getLowerList('droppedPassengers').contains(uemail) ||
          isCancelledRequest || isDeclined || isKicked;

      return isFinished && (amIDriver || amIRider);
    }).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh ?? () async {},
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
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
              ),
              if (myCompletedRides.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded, size: 80, color: isDark ? Colors.white10 : Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text("No completed rides yet.", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 18, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final ride = myCompletedRides[index];
                        return RideHistoryCard(ride: ride, isDark: isDark, userEmail: userEmail);
                      },
                      childCount: myCompletedRides.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}

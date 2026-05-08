import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'live_tracking_screen.dart';
import '../core/constants.dart';

class MatchRequestScreen extends StatelessWidget {
  final Map<String, dynamic> rideData;

  const MatchRequestScreen({super.key, required this.rideData});

  Future<void> acceptRide(BuildContext context) async {
    try {
      final response = await http.patch(
        Uri.parse("$kBaseUrl/api/rides/accept/${rideData['_id']}"),
      );
      if (response.statusCode == 200 && context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LiveTrackingScreen(
              isDriver: true,
              isAlreadyAccepted: true,
              rideId: rideData['_id'],
              myName: rideData['riderName'],
              otherUserName:
                  rideData['requestingRider'] ??
                  "Rider", // 👈 Dynamic Rider name!
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white54 : Colors.grey;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9);
    final acceptBtnColor = isDark ? const Color(0xFF2C2C2C) : Colors.black;
    final declineBorderColor = isDark ? Colors.white54 : Colors.black;
    final declineTextColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: isDark ? const Color(0xFF1B4332) : Colors.green,
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              "Match Found!",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
            ),

            // 👈 THE FIX: Using the dynamic name
            Text(
              "${rideData['requestingRider'] ?? 'A student'} wants to join your journey",
              style: TextStyle(color: subTextColor),
            ),

            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: acceptBtnColor,
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rideData['requestingRider'] ?? "Rider",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            "Ridify Member",
                            style: TextStyle(color: subTextColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: acceptBtnColor),
                onPressed: () => acceptRide(context),
                child: const Text(
                  "Accept",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: declineBorderColor),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Decline",
                  style: TextStyle(color: declineTextColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

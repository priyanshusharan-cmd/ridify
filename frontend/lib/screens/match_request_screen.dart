import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'live_tracking_screen.dart';
import '../constants.dart';

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
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.green,
              child: Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              "Match Found!",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),

            // 👈 THE FIX: Using the dynamic name
            Text(
              "${rideData['requestingRider'] ?? 'A student'} wants to join your journey",
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.black,
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rideData['requestingRider'] ?? "Rider",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            "Ridify Member",
                            style: TextStyle(color: Colors.grey),
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
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
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Decline",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

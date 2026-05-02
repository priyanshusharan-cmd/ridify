import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'live_tracking_screen.dart';
import '../constants.dart';

class MatchStatusScreen extends StatefulWidget {
  final String driverName;
  final String rideId;
  final String riderName;

  const MatchStatusScreen({
    super.key,
    required this.driverName,
    required this.rideId,
    required this.riderName,
  });

  @override
  State<MatchStatusScreen> createState() => _MatchStatusScreenState();
}

class _MatchStatusScreenState extends State<MatchStatusScreen> {
  Timer? _pollingTimer;
  late io.Socket socket;
  bool isDeclined = false;
  String declineMessage = "Request Declined";

  @override
  void initState() {
    super.initState();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => pollRideStatus(),
    );

    socket = io.io(kBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.on('ride_accepted', (data) {
      if (mounted && data != null && data['_id'] == widget.rideId) {
        if ((data['passengers'] ?? []).contains(widget.riderName)) {
          _pollingTimer?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LiveTrackingScreen(
                isDriver: false,
                isAlreadyAccepted: true,
                rideId: widget.rideId,
                myName: widget.riderName,
                otherUserName: widget.driverName,
              ),
            ),
          );
        }
      }
    });

    socket.on('ride_cancelled', (data) {
      if (mounted && data != null && data['_id'] == widget.rideId) {
        setState(() {
          isDeclined = true;
          declineMessage = "The driver cancelled this ride offer.";
        });
        _pollingTimer?.cancel();
      }
    });

    // 👈 THE FIX: Listens for DB Wipe to reset screen!
    socket.on('database_wiped', (_) {
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    });
  }

  Future<void> pollRideStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$kBaseUrl/api/rides/${widget.rideId}'),
      );
      if (response.statusCode == 200 && mounted) {
        final ride = jsonDecode(response.body);

        if ((ride['passengers'] ?? []).contains(widget.riderName)) {
          _pollingTimer?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LiveTrackingScreen(
                isDriver: false,
                isAlreadyAccepted: true,
                rideId: widget.rideId,
                myName: widget.riderName,
                otherUserName: widget.driverName,
              ),
            ),
          );
        } else if (ride['status'] == 'cancelled') {
          setState(() {
            isDeclined = true;
            declineMessage = "The driver cancelled this ride offer.";
          });
          _pollingTimer?.cancel();
        } else if ((ride['declined'] ?? []).contains(widget.riderName)) {
          setState(() {
            isDeclined = true;
            declineMessage = "${widget.driverName} declined your request.";
          });
          _pollingTimer?.cancel();
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "Match Status",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Container(
            padding: const EdgeInsets.all(40),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: isDeclined
                  ? [
                      const Icon(Icons.cancel, color: Colors.red, size: 80),
                      const SizedBox(height: 30),
                      const Text(
                        "Declined",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        declineMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: () => Navigator.popUntil(
                            context,
                            (route) => route.isFirst,
                          ),
                          child: const Text(
                            "Go Back",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ]
                  : [
                      const SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 6,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        "Request Sent!",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Waiting for ${widget.driverName} to review your request.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

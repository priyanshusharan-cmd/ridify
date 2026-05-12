import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'live_tracking_screen.dart';
import '../core/constants.dart';

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

  late io.Socket socket;
  bool isDeclined = false;
  String declineMessage = "Request Declined";

  @override
  void initState() {
    super.initState();

    socket = io.io(kBaseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket.on('ride_accepted', (data) {
      if (mounted && data != null && data['_id'] == widget.rideId) {
        if ((data['passengers'] ?? []).contains(widget.riderName)) {
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
      }
    });

    // 👈 THE FIX: Listens for DB Wipe to reset screen!
    socket.on('database_wiped', (_) {
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    });
  }



  @override
  void dispose() {
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          "Match Status",
          style: TextStyle(color: Theme.of(context).appBarTheme.titleTextStyle?.color ?? Colors.white),
        ),
        iconTheme: IconThemeData(color: Theme.of(context).appBarTheme.iconTheme?.color ?? Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Container(
            padding: const EdgeInsets.all(40),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
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
                      Text(
                        "Declined",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
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
                              backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.black,
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
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          color: Theme.of(context).primaryColor,
                          strokeWidth: 6,
                        ),
                      ),
                      const SizedBox(height: 40),
                      Text(
                        "Request Sent!",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
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

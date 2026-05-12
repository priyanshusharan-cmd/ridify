import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:async';
import '../core/constants.dart';

class CompletionScreen extends StatefulWidget {
  final bool isDriver;
  final String rideId;
  final String myName;
  final int fareAmount;

  const CompletionScreen({
    super.key,
    this.isDriver = false,
    this.rideId = "",
    this.myName = "",
    this.fareAmount = 0,
  });

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> {
  int countdown = 5;
  Timer? _timer;
  bool isPaid = false;
  late io.Socket socket;

  @override
  void initState() {
    super.initState();
    // Connect socket to sever live ride connections properly
    socket = io.io(kBaseUrl, <String, dynamic>{'transports': ['websocket'], 'autoConnect': true});

    if (widget.isDriver || widget.fareAmount == 0) {
      // Driver green completion screen - auto countdown
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown <= 1) {
        timer.cancel();
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) setState(() => countdown--);
      }
    });
  }

  Future<void> markAsPaid() async {
    try {
      await http.patch(Uri.parse('$kBaseUrl/api/rides/pay/${widget.rideId}/${widget.myName}'));
      // Disconnect socket to sever live connections
      socket.dispose();
      setState(() {
        isPaid = true;
      });
      _startTimer();
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Rider payment screen
    if (!widget.isDriver && widget.fareAmount > 0 && !isPaid) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0F4FF),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16213E) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: isDark ? Colors.blue.shade300 : Colors.blue,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "You have arrived!",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Your ride is complete",
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B4332) : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.green.shade800 : Colors.green.shade200),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Amount to Pay",
                                style: TextStyle(
                                  color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "₹${widget.fareAmount}",
                                style: TextStyle(
                                  color: isDark ? Colors.green.shade200 : Colors.green.shade800,
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Please pay the driver the amount shown above.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF1B4332) : Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      onPressed: markAsPaid,
                      child: const Text(
                        "I have Paid",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Green completion screen (driver or post-payment)
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1B4332) : Colors.green,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 100,
              ),
              const SizedBox(height: 20),
              const Text(
                "Ride Completed!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "Returning to home in $countdown...",
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

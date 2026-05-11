import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  @override
  void initState() {
    super.initState();
    if (widget.isDriver || widget.fareAmount == 0) {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool requiresPayment = !widget.isDriver && widget.fareAmount > 0 && !isPaid;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1B4332) : Colors.green,
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
              Text(
                requiresPayment ? "You have arrived!" : "Ride Completed!",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              
              if (requiresPayment) ...[
                Text(
                  "Please pay ₹${widget.fareAmount} to the Driver.",
                  style: const TextStyle(color: Colors.white, fontSize: 22),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: markAsPaid,
                  child: const Text(
                    "I have Paid",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                )
              ] else ...[
                Text(
                  "Returning to home in $countdown...",
                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

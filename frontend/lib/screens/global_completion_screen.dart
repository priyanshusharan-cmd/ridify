import 'package:flutter/material.dart';
import 'dart:async';

class GlobalCompletionScreen extends StatefulWidget {
  const GlobalCompletionScreen({super.key});

  @override
  State<GlobalCompletionScreen> createState() => _GlobalCompletionScreenState();
}

class _GlobalCompletionScreenState extends State<GlobalCompletionScreen> {
  int countdown = 5;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown <= 1) {
        timer.cancel();
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) setState(() => countdown--);
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1B4332) : Colors.green,
      body: Center(
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
            ),
            const SizedBox(height: 10),
            Text(
              "Returning to home in $countdown...",
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class AnimatedDriverMarker extends StatelessWidget {
  final String driverLabel;

  const AnimatedDriverMarker({super.key, required this.driverLabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          color: Colors.white,
          child: Text(
            driverLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black),
          ),
        ),
        const Icon(Icons.directions_car, color: Colors.red, size: 30),
      ],
    );
  }
}

class AnimatedPassengerMarker extends StatelessWidget {
  const AnimatedPassengerMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
      ),
    );
  }
}

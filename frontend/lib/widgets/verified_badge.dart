import 'package:flutter/material.dart';

class VerifiedBadge extends StatelessWidget {
  final double size;
  const VerifiedBadge({super.key, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Icon(Icons.verified, color: Colors.green, size: size),
    );
  }
}

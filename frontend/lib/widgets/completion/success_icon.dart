import 'package:flutter/material.dart';

class SuccessIcon extends StatelessWidget {
  const SuccessIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green.withValues(alpha: 0.1),
          ),
        ),
        Container(
          width: 90,
          height: 90,
          decoration: const BoxDecoration(
            color: Color(0xFF4ADE80),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 50),
        ),
        Positioned(top: 10, left: 20, child: Container(width: 8, height: 8, color: const Color(0xFF4ADE80))),
        Positioned(top: 20, right: 15, child: Transform.rotate(angle: 0.5, child: Container(width: 10, height: 10, color: const Color(0xFF4ADE80)))),
        Positioned(bottom: 10, right: 30, child: Container(width: 6, height: 6, color: const Color(0xFF4ADE80))),
        Positioned(bottom: 25, left: 10, child: Transform.rotate(angle: 1, child: Container(width: 8, height: 8, color: const Color(0xFF4ADE80)))),
      ],
    );
  }
}

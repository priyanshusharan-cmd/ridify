import 'package:flutter/material.dart';

class StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const StatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: isDark ? Colors.white54 : Colors.grey[600]),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black)),
        ],
      ),
    );
  }
}

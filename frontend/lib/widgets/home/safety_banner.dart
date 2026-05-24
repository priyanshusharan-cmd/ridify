import 'package:flutter/material.dart';

class SafetyBanner extends StatelessWidget {
  const SafetyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final Color safetyBg = isDarkTheme ? const Color(0xFF1A2633) : Colors.blue.shade50;
    final Color safetyBorder = isDarkTheme ? const Color(0xFF26394D) : Colors.blue.shade100;
    final Color safetyText = isDarkTheme ? Colors.blue.shade300 : Colors.blue;
    final Color mainTextColor = isDarkTheme ? Colors.white : Colors.black87;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: safetyBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: safetyBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.security, color: safetyText, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Safety First",
                  style: TextStyle(
                    color: safetyText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "Always verify your co-passenger’s details and share your ride details with your family or friends.",
                  style: TextStyle(
                    color: mainTextColor,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

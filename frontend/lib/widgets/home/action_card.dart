import 'package:flutter/material.dart';

class ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isPrimary;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isPrimary 
      ? (isDarkTheme ? const Color(0xFF2C2C2C) : Colors.black)
      : Theme.of(context).cardColor;
      
    final fgColor = isPrimary 
      ? Colors.white
      : Theme.of(context).textTheme.bodyLarge?.color;
      
    final subColor = isPrimary
      ? Colors.white70
      : (isDarkTheme ? Colors.white54 : Colors.black54);
      
    final borderColor = isDarkTheme ? Colors.transparent : Colors.black12;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isPrimary ? Colors.transparent : borderColor),
        ),
        child: Row(
          children: [
            Icon(
              isPrimary ? Icons.directions_car : Icons.search,
              color: fgColor,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: fgColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

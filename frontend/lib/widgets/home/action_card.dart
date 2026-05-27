import 'package:flutter/material.dart';

class ActionCard extends StatefulWidget {
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
  State<ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<ActionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = widget.isPrimary 
      ? (isDarkTheme ? const Color(0xFF2C2C2C) : Colors.black)
      : Theme.of(context).cardColor;
      
    final fgColor = widget.isPrimary 
      ? Colors.white
      : Theme.of(context).textTheme.bodyLarge?.color;
      
    final subColor = widget.isPrimary
      ? Colors.white70
      : (isDarkTheme ? Colors.white54 : Colors.black54);
      
    final borderColor = isDarkTheme ? Colors.transparent : Colors.black12;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: widget.isPrimary ? Colors.transparent : borderColor),
          ),
          child: Row(
            children: [
              Icon(
                widget.isPrimary ? Icons.directions_car : Icons.search,
                color: fgColor,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      color: subColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

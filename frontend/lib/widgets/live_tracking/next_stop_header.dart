import 'package:flutter/material.dart';

class NextStopHeader extends StatelessWidget {
  final Map<String, dynamic> stopInfo;
  final bool isDark;
  final VoidCallback onTap;

  const NextStopHeader({
    super.key,
    required this.stopInfo,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final panelBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final panelText = isDark ? Colors.white : Colors.black;
    final panelSub = isDark ? Colors.white54 : Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text("NEXT STOP", style: TextStyle(color: panelSub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(width: 6),
              Icon(Icons.open_in_new, size: 12, color: panelSub),
            ]),
            const SizedBox(height: 4),
            Text(stopInfo['title'] as String, style: TextStyle(color: panelText, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
            if ((stopInfo['address'] as String).isNotEmpty) ...[
              const SizedBox(height: 2), 
              Text(stopInfo['address'] as String, style: TextStyle(color: panelSub, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)
            ],
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.shade900.withValues(alpha: 0.4) : Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.navigation_rounded, color: isDark ? Colors.blue.shade300 : Colors.blue, size: 20),
          ),
        ]),
      ),
    );
  }
}

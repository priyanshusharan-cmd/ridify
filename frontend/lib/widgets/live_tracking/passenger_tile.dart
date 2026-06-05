import 'package:flutter/material.dart';
import '../verified_badge.dart';

class PassengerTile extends StatelessWidget {
  final String passengerId;
  final String displayName;
  final String verificationStatus;
  final String subtitle;
  final String addrText;
  final bool isBoarded;
  final bool isArrived;
  final bool isStarted;
  final bool canFit;
  final bool isProcessing;
  final bool isAnyProcessing;
  final String routePreference;
  final bool isDark;
  final VoidCallback onDropOff;
  final VoidCallback onKick;
  final VoidCallback onArrive;

  const PassengerTile({
    super.key,
    required this.passengerId,
    required this.displayName,
    this.verificationStatus = 'none',
    required this.subtitle,
    required this.addrText,
    required this.isBoarded,
    required this.isArrived,
    required this.isStarted,
    required this.canFit,
    required this.isProcessing,
    required this.isAnyProcessing,
    required this.routePreference,
    required this.isDark,
    required this.onDropOff,
    required this.onKick,
    required this.onArrive,
  });

  @override
  Widget build(BuildContext context) {
    final panelText = isDark ? Colors.white : Colors.black;
    final panelSub = isDark ? Colors.white54 : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.blue.shade400, Colors.blue.shade700],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              displayName.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Flexible(
                child: Text(displayName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: panelText), overflow: TextOverflow.ellipsis),
              ),
              if (verificationStatus == 'verified') ...[
                const SizedBox(width: 4),
                const VerifiedBadge(size: 14),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: isBoarded ? Colors.green.shade600 : Colors.orange.shade600, fontSize: 12, fontWeight: FontWeight.w600)),
          if (addrText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.location_on, size: 12, color: panelSub),
              const SizedBox(width: 4),
              Expanded(child: Text(addrText, style: TextStyle(color: panelSub, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ])),
        const SizedBox(width: 8),
        if (isBoarded) ...[
          if (routePreference != 'nonstop') ...[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: isAnyProcessing ? Colors.grey.shade100 : Colors.red.shade50,
                foregroundColor: isAnyProcessing ? Colors.grey.shade400 : Colors.red.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isAnyProcessing ? null : onDropOff,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: isProcessing ? 0 : 1,
                    child: const Text("Drop-off", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  if (isProcessing)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: onKick,
            icon: Icon(Icons.person_remove_rounded, color: Colors.red.shade300, size: 22),
            style: IconButton.styleFrom(backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100),
          ),
        ] else ...[
          if (!isArrived && routePreference != 'nonstop' && routePreference != 'shared_start') ...[
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: (canFit && isStarted && !isAnyProcessing) ? Colors.green.shade50 : Colors.grey.shade100,
                foregroundColor: (canFit && isStarted && !isAnyProcessing) ? Colors.green.shade700 : Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: isAnyProcessing ? null : () {
                if (!isStarted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("First start the ride"), backgroundColor: Colors.orange));
                } else if (!canFit) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Car capacity reached"), backgroundColor: Colors.red));
                } else {
                  onArrive();
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: isProcessing ? 0 : 1,
                    child: Text((canFit && isStarted) ? "Arrived" : (isStarted ? "Full" : "Arrived"), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  if (isProcessing)
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: onKick,
            icon: Icon(Icons.person_remove_rounded, color: Colors.red.shade300, size: 22),
            style: IconButton.styleFrom(backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100),
          ),
        ],
      ]),
    );
  }
}

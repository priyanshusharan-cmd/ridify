import 'package:flutter/material.dart';

class PerformanceCard extends StatelessWidget {
  final bool isDark;
  final int totalRidesCompleted;
  final int totalOnlineTimeMins;
  final num totalDistanceDriven;

  const PerformanceCard({
    super.key,
    required this.isDark,
    required this.totalRidesCompleted,
    required this.totalOnlineTimeMins,
    required this.totalDistanceDriven,
  });

  Widget _buildPerfStat(String label, String value, IconData icon, bool isDark, {required Color iconColor}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? iconColor.withValues(alpha: 0.1) : iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, color: Color(0xFF4ADE80), size: 24),
              const SizedBox(width: 12),
              Text(
                "Your Performance",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildPerfStat("Rides\nCompleted", "$totalRidesCompleted", Icons.directions_car_rounded, isDark, iconColor: const Color(0xFF4ADE80))),
              Expanded(child: _buildPerfStat("Online\nTime", "${totalOnlineTimeMins ~/ 60}h ${totalOnlineTimeMins % 60}m", Icons.access_time_filled, isDark, iconColor: Colors.deepPurpleAccent)),
              Expanded(child: _buildPerfStat("Distance\nDriven", "$totalDistanceDriven km", Icons.add_road, isDark, iconColor: Colors.lightBlue)),
            ],
          ),
        ],
      ),
    );
  }
}

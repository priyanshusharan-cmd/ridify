import 'package:flutter/material.dart';

class TripSummaryCard extends StatelessWidget {
  final bool isDark;
  final String dateStr;
  final String pickup;
  final String dest;
  final String distance;
  final String duration;
  final String? passengers;
  final String? totalEarnings;

  const TripSummaryCard({
    super.key,
    required this.isDark,
    required this.dateStr,
    required this.pickup,
    required this.dest,
    required this.distance,
    required this.duration,
    this.passengers,
    this.totalEarnings,
  });

  Widget _buildStatGridItem(IconData icon, String label, String value, bool isDark, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isDark ? Colors.white54 : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: valueColor ?? (isDark ? Colors.white : Colors.black))),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.list_alt_rounded, color: Color(0xFF4ADE80), size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Trip Summary",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr.replaceAll(' at ', ' • '),
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.location_on, color: Color(0xFF4ADE80), size: 20),
                  Container(
                    height: 28,
                    width: 2,
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                  const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("From", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(pickup, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 20),
                    Text("To", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(dest, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
          ),
          if (passengers != null && totalEarnings != null) ...[
            Row(
              children: [
                Expanded(child: _buildStatGridItem(Icons.people_outline_rounded, "Passengers", passengers!, isDark)),
                Container(width: 1, height: 40, color: isDark ? Colors.white10 : Colors.black12),
                Expanded(child: _buildStatGridItem(Icons.monetization_on_outlined, "Earnings", "₹$totalEarnings", isDark, valueColor: const Color(0xFF4ADE80))),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(child: _buildStatGridItem(Icons.add_road_rounded, "Distance", distance, isDark)),
              Container(width: 1, height: 40, color: isDark ? Colors.white10 : Colors.black12),
              Expanded(child: _buildStatGridItem(Icons.access_time_rounded, "Duration", duration, isDark)),
            ],
          ),
        ],
      ),
    );
  }
}

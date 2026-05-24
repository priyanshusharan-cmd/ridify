import 'package:flutter/material.dart';

class FareSummary extends StatelessWidget {
  final bool isDark;
  final String driverName;
  final int fareAmount;

  const FareSummary({
    super.key,
    required this.isDark,
    required this.driverName,
    required this.fareAmount,
  });

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
              Icon(Icons.account_balance_wallet_outlined, color: const Color(0xFF4ADE80), size: 24),
              const SizedBox(width: 12),
              Text(
                "Payment Summary",
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
            children: [
              // Breakdown List
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Paid To", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          child: Text(
                            driverName.isNotEmpty ? driverName.substring(0, 1).toUpperCase() : "?",
                            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(driverName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
              // Divider
              Container(
                width: 1,
                height: 60,
                color: isDark ? Colors.white10 : Colors.black12,
                margin: const EdgeInsets.symmetric(horizontal: 20),
              ),
              // Total
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Total Fare", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 8),
                    Text("₹$fareAmount", style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

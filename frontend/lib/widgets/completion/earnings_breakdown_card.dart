import 'package:flutter/material.dart';

class EarningsBreakdownCard extends StatelessWidget {
  final bool isDark;
  final List<dynamic> earningsList;
  final num totalEarnings;

  const EarningsBreakdownCard({
    super.key,
    required this.isDark,
    required this.earningsList,
    required this.totalEarnings,
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
              const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF4ADE80), size: 24),
              const SizedBox(width: 12),
              Text(
                "Earnings Breakdown",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: earningsList.isEmpty 
                      ? [Text("No passengers boarded", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600]))]
                      : earningsList.map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(e['name'], style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14), overflow: TextOverflow.ellipsis)),
                                Text("₹${e['fare']}", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ),
                VerticalDivider(
                  color: isDark ? Colors.white10 : Colors.black12,
                  thickness: 1,
                  width: 40,
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.account_balance_wallet, color: Colors.brown[400], size: 40),
                          const Positioned(
                            top: 0,
                            right: 0,
                            child: Icon(Icons.attach_money_rounded, color: Color(0xFF4ADE80), size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("Total Earnings", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 4),
                      Text("₹$totalEarnings", style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
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

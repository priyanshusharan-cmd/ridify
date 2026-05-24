import 'package:flutter/material.dart';

class EarningsDisplay extends StatelessWidget {
  final double totalEarnings;
  final double totalSpending;

  const EarningsDisplay({
    super.key,
    required this.totalEarnings,
    required this.totalSpending,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    
    final Color earningsBg = isDarkTheme ? const Color(0xFF162B1D) : Colors.green.shade50;
    final Color earningsBorder = isDarkTheme ? const Color(0xFF23472C) : Colors.green.shade100;
    final Color earningsIconBg = isDarkTheme ? const Color(0xFF1E3F26) : Colors.green.shade100;
    final Color earningsText = isDarkTheme ? Colors.green.shade300 : Colors.green;
    
    final Color spendingBg = isDarkTheme ? const Color(0xFF331A1A) : Colors.red.shade50;
    final Color spendingBorder = isDarkTheme ? const Color(0xFF4D2626) : Colors.red.shade100;
    final Color spendingIconBg = isDarkTheme ? const Color(0xFF402020) : Colors.red.shade100;
    final Color spendingText = isDarkTheme ? Colors.red.shade300 : Colors.red;
    
    final Color mainTextColor = isDarkTheme ? Colors.white : Colors.black87;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: earningsBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: earningsBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: earningsIconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_downward,
                    color: earningsText,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Total Earnings",
                  style: TextStyle(
                    color: earningsText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "₹${totalEarnings.toStringAsFixed(0)}",
                  style: TextStyle(
                    color: mainTextColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: spendingBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: spendingBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: spendingIconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_upward,
                    color: spendingText,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Total Spending",
                  style: TextStyle(
                    color: spendingText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "₹${totalSpending.toStringAsFixed(0)}",
                  style: TextStyle(
                    color: mainTextColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

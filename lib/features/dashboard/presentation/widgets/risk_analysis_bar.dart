import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/glass_container.dart';

class RiskAnalysisBar extends StatelessWidget {
  final int riskScore; // 0 to 100
  final bool isLoading;

  const RiskAnalysisBar({
    super.key,
    required this.riskScore,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Risk Levels:
    // 0-30: Low (Green)
    // 31-70: Medium (Orange)
    // 71-100: High (Red)

    Color color = Colors.green;
    String label = "LOW RISK";

    if (riskScore > 70) {
      color = Colors.red;
      label = "HIGH RISK";
    } else if (riskScore > 30) {
      color = Colors.orange;
      label = "MEDIUM RISK";
    }

    return GlassContainer(
      opacity: 0.05,
      border: Border.all(color: color.withOpacity(0.5), width: 1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "SYSTEM RISK ANALYSIS",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        BoxShadow(
                          color: color.withOpacity(0.8),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 1000),
                  height: 12,
                  width:
                      MediaQuery.of(context).size.width *
                      (riskScore / 100).clamp(0.0, 1.0) *
                      0.8, // Adjust width factor if needed
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.4), color],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Current Risk Score: $riskScore/100",
              style: TextStyle(fontSize: 12, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

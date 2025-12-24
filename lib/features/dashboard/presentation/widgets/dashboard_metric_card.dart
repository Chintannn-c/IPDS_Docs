import 'package:flutter/material.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';

class DashboardMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subValue;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const DashboardMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subValue,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          subValue,
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chevron for tappable cards
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary.withOpacity(0.5),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

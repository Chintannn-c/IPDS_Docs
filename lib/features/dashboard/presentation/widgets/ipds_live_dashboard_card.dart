import 'package:flutter/material.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';

class IpdsLiveDashboardCard extends StatelessWidget {
  final List<Map<String, dynamic>> logs;
  final VoidCallback? onViewAll;

  const IpdsLiveDashboardCard({super.key, required this.logs, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.shield_outlined,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'IPDS Activity',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppTheme.successColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: AppTheme.textSecondary.withOpacity(0.1)),

          // Logs
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 40,
                    color: AppTheme.textSecondary.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recent activity',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ...logs.take(3).map((log) => _buildLogItem(log)),

          // View All Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextButton(
              onPressed: onViewAll,
              child: Text(
                'View All Activity',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final action = log['action'] ?? 'Unknown';
    final level = log['level'] ?? 'info';
    final timestamp = log['timestamp'] ?? '';

    Color levelColor;
    IconData levelIcon;

    switch (level) {
      case 'error':
      case 'danger':
        levelColor = AppTheme.errorColor;
        levelIcon = Icons.block_outlined;
        break;
      case 'warning':
        levelColor = AppTheme.warningColor;
        levelIcon = Icons.warning_amber_outlined;
        break;
      case 'success':
        levelColor = AppTheme.successColor;
        levelIcon = Icons.check_circle_outline;
        break;
      default:
        levelColor = AppTheme.successColor;
        levelIcon = Icons.check_circle_outline;
    }

    // Calculate risk points
    int riskPoints = 0;
    if (level == 'error' || level == 'danger') {
      riskPoints = 25;
    } else if (level == 'warning') {
      riskPoints = 10;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.textSecondary.withOpacity(0.08)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT ICON (Severity Indicator)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: levelColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(levelIcon, color: levelColor, size: 18),
          ),

          const SizedBox(width: 14),

          // MAIN TEXT
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  maxLines: 2,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),

          // Risk Points Badge
          if (riskPoints > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: levelColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '+$riskPoints',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: levelColor,
                ),
              ),
            ),

          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            color: AppTheme.textSecondary.withOpacity(0.5),
            size: 16,
          ),
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}

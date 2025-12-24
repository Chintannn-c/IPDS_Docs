import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/activity_log.dart';
import '../../../../core/providers/time_provider.dart';

class LogItemCard extends StatefulWidget {
  final ActivityLog log;

  const LogItemCard({super.key, required this.log});

  @override
  State<LogItemCard> createState() => _LogItemCardState();
}

class _LogItemCardState extends State<LogItemCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animController.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final timeProvider = context.watch<TimeProvider>();

    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    Color color;
    IconData icon;

    switch (log.status.toUpperCase()) {
      case 'SUCCESS':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        break;
      case 'WARNING':
        color = Colors.orange;
        icon = Icons.warning_amber_rounded;
        break;
      case 'ERROR':
        color = Colors.red;
        icon = Icons.error_outline;
        break;
      case 'INFO':
      default:
        color = Colors.blue;
        icon = Icons.info_outline;
    }

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: () => _showLogDetails(context, color, icon),
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: _isPressed
                    ? color.withOpacity(0.15)
                    : color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isPressed
                      ? color.withOpacity(0.5)
                      : color.withOpacity(0.2),
                  width: _isPressed ? 1.5 : 1.0,
                ),
                boxShadow: _isPressed
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Animated Icon
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _isPressed
                          ? color.withOpacity(0.3)
                          : color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: isMobile ? 18 : 20),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.action.replaceAll('_', ' '),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 13 : 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: isMobile ? 12 : 14,
                              color: theme.hintColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              log.actor.name,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: isMobile ? 11 : 12,
                                color: theme.textTheme.bodySmall?.color
                                    ?.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "•",
                              style: TextStyle(
                                color: theme.hintColor,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.storage_outlined,
                              size: isMobile ? 12 : 14,
                              color: theme.hintColor,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                log.target?.name ??
                                    log.target?.type ??
                                    'System',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: isMobile ? 11 : 12,
                                  color: theme.textTheme.bodySmall?.color
                                      ?.withOpacity(0.8),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Time
                  Text(
                    timeProvider.getTimeAgo(log.timestamp),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                      fontSize: isMobile ? 10 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLogDetails(BuildContext context, Color color, IconData icon) {
    final log = widget.log;
    final theme = Theme.of(context);
    final localTime = log.timestamp.toLocal();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                log.action.replaceAll('_', ' '),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  log.status.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),

              const Divider(height: 24),

              // Actor Info
              _buildDetailRow(context, Icons.person, 'Actor', log.actor.name),
              _buildDetailRow(context, Icons.badge, 'Role', log.actor.role),
              _buildDetailRow(
                context,
                Icons.wifi,
                'IP Address',
                log.actor.ipAddress ?? 'N/A',
              ),

              const Divider(height: 24),

              if (log.target != null) ...[
                _buildDetailRow(
                  context,
                  Icons.category,
                  'Target Type',
                  log.target!.type,
                ),
                _buildDetailRow(
                  context,
                  Icons.label,
                  'Target Name',
                  log.target!.name ?? 'N/A',
                ),
                _buildDetailRow(
                  context,
                  Icons.fingerprint,
                  'Target ID',
                  log.target!.id ?? 'N/A',
                ),
                const Divider(height: 24),
              ],

              _buildDetailRow(
                context,
                Icons.calendar_today,
                'Date',
                DateFormat('EEEE, MMM d, yyyy').format(localTime),
              ),
              _buildDetailRow(
                context,
                Icons.access_time,
                'Time',
                DateFormat('HH:mm:ss').format(localTime),
              ),

              // Metadata if present
              if (log.metadata != null && log.metadata!.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  'Additional Details',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...log.metadata!.entries.map(
                  (e) => _buildDetailRow(
                    context,
                    Icons.info_outline,
                    e.key.replaceAll('_', ' '),
                    e.value.toString(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.hintColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$label: ',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

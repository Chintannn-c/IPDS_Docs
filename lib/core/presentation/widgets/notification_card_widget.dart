import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:file_stroage_system/core/models/notification_model.dart';

class NotificationCardWidget extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkAsRead;
  final int? stackCount;

  const NotificationCardWidget({
    super.key,
    required this.notification,
    this.onTap,
    this.onDelete,
    this.onMarkAsRead,
    this.stackCount,
  });

  @override
  State<NotificationCardWidget> createState() => _NotificationCardWidgetState();
}

class _NotificationCardWidgetState extends State<NotificationCardWidget> {
  bool _isExpanded = false;

  IconData _getCategoryIcon() {
    switch (widget.notification.category) {
      case NotificationCategory.security:
        return Icons.security_rounded;
      case NotificationCategory.file:
        return Icons.insert_drive_file_outlined;
      case NotificationCategory.system:
        return Icons.dns_outlined;
      case NotificationCategory.info:
        return Icons.info_outline;
    }
  }

  String _formatTime() {
    return timeago.format(widget.notification.createdAt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Dark Mode (Preserved) vs Light Mode
    final bgColor = isDark
        ? const Color(0xFF2D3135)
        : theme.colorScheme.surface;
    final iconBg = isDark ? const Color(0xFF383C40) : const Color(0xFFF1F5F9);
    final shadow = isDark
        ? <BoxShadow>[]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ];

    const radius = 20.0; // Slightly reduced for cleaner look

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
        border: isDark
            ? Border.all(color: Colors.white.withOpacity(0.05))
            : Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconBg,
                  ),
                  child: Icon(
                    _getCategoryIcon(),
                    size: 24,
                    color: isDark
                        ? const Color(0xFFA6AAB4)
                        : theme.colorScheme.secondary,
                  ),
                ),

                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFF0F0F0)
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF8F9BB3)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.notification.message,
                        maxLines: _isExpanded ? null : 2,
                        overflow: _isExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: isDark
                              ? const Color(0xFFC4C7C5)
                              : theme.colorScheme.outline,
                        ),
                      ),
                      if (_isExpanded) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Only show 'Open' button if widget.onTap is provided
                            // This allows navigation while preserving expand-on-tap for the card body
                            if (widget.onTap != null)
                              TextButton(
                                onPressed: widget.onTap,
                                style: TextButton.styleFrom(
                                  foregroundColor: theme.colorScheme.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Open'),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Right Actions
                Column(
                  children: [
                    if (widget.stackCount != null && widget.stackCount! > 1)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.stackCount.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? const Color(0xFF8F9BB3)
                                : theme.colorScheme.secondary,
                          ),
                        ),
                      ),

                    SizedBox(
                      width: 24,
                      height: 24,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: Color(0xFF8F9BB3),
                        ),
                        color: iconBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'read') {
                            widget.onMarkAsRead?.call();
                          } else if (value == 'delete') {
                            _confirmDelete(context);
                          }
                        },
                        itemBuilder: (_) => [
                          if (widget.onMarkAsRead != null)
                            PopupMenuItem(
                              value: 'read',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: Color(0xFF81C995),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Mark as read',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Color(0xFFE57373),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Remove',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark
            ? const Color(0xFF2D3135)
            : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Notification?',
          style: TextStyle(
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: TextStyle(
            color: isDark ? const Color(0xFFC4C7C5) : theme.colorScheme.outline,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark
                    ? const Color(0xFF8F9BB3)
                    : theme.colorScheme.outlineVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete?.call();
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFE57373)),
            ),
          ),
        ],
      ),
    );
  }
}

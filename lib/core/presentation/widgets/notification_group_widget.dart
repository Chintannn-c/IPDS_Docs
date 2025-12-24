import 'package:flutter/material.dart';
import 'package:file_stroage_system/core/models/notification_model.dart';
import 'package:file_stroage_system/core/presentation/widgets/notification_card_widget.dart';

class NotificationGroupWidget extends StatefulWidget {
  final List<NotificationModel> notifications;
  final Function(NotificationModel) onTap;
  final Function(NotificationModel) onDelete;
  final Function(NotificationModel) onMarkAsRead;

  const NotificationGroupWidget({
    super.key,
    required this.notifications,
    required this.onTap,
    required this.onDelete,
    required this.onMarkAsRead,
  });

  @override
  State<NotificationGroupWidget> createState() =>
      _NotificationGroupWidgetState();
}

class _NotificationGroupWidgetState extends State<NotificationGroupWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.notifications.isEmpty) return const SizedBox.shrink();

    // If only 1 notification, just show the card
    if (widget.notifications.length == 1) {
      return NotificationCardWidget(
        notification: widget.notifications.first,
        onTap: () => widget.onTap(widget.notifications.first),
        onDelete: () => widget.onDelete(widget.notifications.first),
        onMarkAsRead: () => widget.onMarkAsRead(widget.notifications.first),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Column(
        children: [
          // Stack Header / Top Card
          if (!_isExpanded) _buildCollapsedStack() else _buildExpandedList(),
        ],
      ),
    );
  }

  Widget _buildCollapsedStack() {
    final topNotification = widget.notifications.first;
    final count = widget.notifications.length;

    // "Multiple notifications ... grouped into one card"
    // "Count indicator increases"
    return NotificationCardWidget(
      notification: topNotification,
      onTap: _toggleExpand,
      onDelete: () => widget.onDelete(topNotification),
      onMarkAsRead: () => widget.onMarkAsRead(topNotification),
      stackCount: count, // Pass total count to show badge [ N ]
    );
  }

  void _removeAll() {
    // specific copy to avoid concurrent modification issues if list updates synchronously
    final list = List<NotificationModel>.from(widget.notifications);
    for (var n in list) {
      widget.onDelete(n);
    }
  }

  Widget _buildExpandedList() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Header: Collapse (Center/Left) + Remove All (Right)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Collapse Action
              InkWell(
                onTap: _toggleExpand,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Collapse Group',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? theme.colorScheme.primary
                              : theme.colorScheme.primary.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_up,
                        size: 16,
                        color: isDark
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primary.withOpacity(0.9),
                      ),
                    ],
                  ),
                ),
              ),

              // Remove All Action
              TextButton(
                onPressed: _removeAll,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Remove All'),
              ),
            ],
          ),
        ),

        // List of items
        ...widget.notifications.map((notification) {
          return NotificationCardWidget(
            notification: notification,
            onTap: () => widget.onTap(notification),
            onDelete: () => widget.onDelete(notification),
            onMarkAsRead: () => widget.onMarkAsRead(notification),
            // No stack count for individual items in expanded list
            stackCount: null,
          );
        }),
      ],
    );
  }
}

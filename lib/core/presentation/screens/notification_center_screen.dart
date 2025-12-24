import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_stroage_system/core/controllers/notification_controller.dart';
import 'package:file_stroage_system/core/models/notification_model.dart';
import 'package:file_stroage_system/core/presentation/widgets/notification_group_widget.dart';
import 'package:file_stroage_system/core/presentation/theme/app_theme.dart';
import 'package:file_stroage_system/core/presentation/widgets/app_toast.dart'; // Add this import

class NotificationCenterScreen extends StatelessWidget {
  NotificationCenterScreen({super.key});

  final NotificationController controller = Get.put(NotificationController());

  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    _attachScrollListener();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.surfaceColor, AppTheme.backgroundColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              _buildFilterTabs(context),
              Expanded(child: _buildNotificationList()),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // SCROLL PAGINATION (SAFE)
  // =========================
  void _attachScrollListener() {
    if (_scrollController.hasListeners) return;

    _scrollController.addListener(() {
      final threshold = _scrollController.position.maxScrollExtent - 200;

      if (_scrollController.position.pixels >= threshold &&
          controller.hasMore.value &&
          !controller.isLoading.value) {
        controller.loadMore();
      }
    });
  }

  // =========================
  // HEADER
  // =========================
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      // No decoration for cleaner "no appbar" feel
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Text(
                'Notifications',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: AppTheme.textPrimary,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: AppTheme.textPrimary),
                  onSelected: (value) {
                    if (value == 'mark_all_read') {
                      controller.markAllAsRead();
                    } else if (value == 'clear_all') {
                      _showClearAllConfirmation(context);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'mark_all_read',
                      child: Row(
                        children: [
                          Icon(
                            Icons.done_all,
                            size: 20,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 12),
                          const Text('Mark all as read'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'clear_all',
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delete_sweep,
                            size: 20,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 12),
                          const Text('Clear all'),
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
    );
  }

  void _showClearAllConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Clear All Notifications',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete all notifications? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              controller.deleteAllNotifications();
              AppToast.success(
                context,
                'All notifications cleared',
                duration: const Duration(seconds: 2),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  // =========================
  // FILTER TABS
  // =========================
  Widget _buildFilterTabs(BuildContext context) {
    final filters = [
      {'label': 'All', 'value': 'all'},
      {'label': 'Unread', 'value': 'unread'},
      {'label': 'Security', 'value': NotificationCategory.security.value},
      {'label': 'Files', 'value': NotificationCategory.file.value},
      {'label': 'System', 'value': NotificationCategory.system.value},
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];

          return Obx(() {
            final current = controller.currentFilter.value;
            final value = filter['value']!;

            final isSelected = value == 'all'
                ? !['security', 'file', 'system', 'unread'].contains(current)
                : current == value;

            return GestureDetector(
              onTap: () {
                if (value == 'all') {
                  controller.filterByCategory('all');
                } else if (value == 'unread') {
                  controller.filterByReadStatus(false);
                } else {
                  controller.filterByCategory(value);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  filter['label']!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          });
        },
      ),
    );
  }

  // =========================
  // NOTIFICATION LIST
  // =========================
  Widget _buildNotificationList() {
    return Obx(() {
      if (controller.isLoading.value && controller.notifications.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }

      if (controller.notifications.isEmpty) {
        return _buildEmptyState();
      }

      return RefreshIndicator(
        onRefresh: () => controller.fetchNotifications(refresh: true),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          // We need to calculate grouping on the fly or distinct count
          // Grouping logic:
          itemCount:
              _calculateGroupCount(controller.notifications) +
              (controller.hasMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            final grouped = _groupNotifications(controller.notifications);

            if (index == grouped.length) {
              if (controller.hasMore.value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  controller.loadMore();
                });
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return const SizedBox.shrink();
            }

            final group = grouped[index];

            return NotificationGroupWidget(
              notifications: group,
              onTap: (notification) async {
                if (!notification.isRead) {
                  await controller.markAsRead(notification.id);
                }
                _handleNotificationTap(context, notification);
              },
              onDelete: (notification) =>
                  controller.deleteNotification(notification.id),
              onMarkAsRead: (notification) =>
                  controller.markAsRead(notification.id),
            );
          },
        ),
      );
    });
  }

  // Helper to group sequential notifications by category
  List<List<NotificationModel>> _groupNotifications(
    List<NotificationModel> notifications,
  ) {
    if (notifications.isEmpty) return [];

    List<List<NotificationModel>> groups = [];
    List<NotificationModel> currentGroup = [notifications.first];

    for (int i = 1; i < notifications.length; i++) {
      if (notifications[i].category == notifications[i - 1].category) {
        currentGroup.add(notifications[i]);
      } else {
        groups.add(currentGroup);
        currentGroup = [notifications[i]];
      }
    }
    groups.add(currentGroup);
    return groups;
  }

  int _calculateGroupCount(List<NotificationModel> notifications) {
    return _groupNotifications(notifications).length;
  }

  // =========================
  // EMPTY STATE
  // =========================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 48,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No notifications',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // TAP HANDLER
  // =========================
  void _handleNotificationTap(
    BuildContext context,
    NotificationModel notification,
  ) {
    final data = notification.data;
    if (data == null) return;

    switch (notification.category) {
      case NotificationCategory.security:
        if (data.containsKey('device_fingerprint')) {
          Navigator.pushNamed(context, '/device-trust');
        }
        break;
      case NotificationCategory.file:
        Navigator.pushNamed(context, '/all_files');
        break;
      case NotificationCategory.system:
      case NotificationCategory.info:
        break;
    }
  }
}

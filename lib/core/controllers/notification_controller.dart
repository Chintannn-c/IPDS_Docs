import 'package:file_stroage_system/core/services/local_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_stroage_system/core/models/notification_model.dart';
import 'package:file_stroage_system/core/services/notification_service.dart';
import 'package:file_stroage_system/core/services/web_socket_service.dart';
import 'dart:async';

class NotificationController extends GetxController {
  final NotificationService _notificationService = NotificationService();

  // Reactive state
  final notifications = <NotificationModel>[].obs;
  final isLoading = false.obs;
  final unreadCount = 0.obs;
  final currentFilter =
      NotificationCategory.values[0].value.obs; // 'all' handled separately
  final currentPage = 1.obs;
  final hasMore = true.obs;

  StreamSubscription? _wsSubscription;
  StreamSubscription? _unreadCountSubscription;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToWebSocket();
      _listenToUnreadCount();
    });
    // fetchNotifications() and refreshUnreadCount() should only be called
    // when a session is active. WebSocketService connection in AuthProvider
    // will trigger updates when a session starts.
  }

  @override
  void onClose() {
    _wsSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    super.onClose();
  }

  /// Listen to WebSocket for new notifications
  void _listenToWebSocket() {
    print('📡 NotificationController: Starting WebSocket listener...');

    // Listen to alert stream for notification-type messages
    _wsSubscription = WebSocketService.to.alertStream.listen((data) {
      print('📡 NotificationController: Received WebSocket message: $data');

      final type = data['type'] ?? data['event_type'] ?? '';
      print('📡 Message type: $type');

      // Handle notification types
      if (type == 'notification' ||
          type == 'new_device_login' ||
          type == 'login_attempt') {
        print('✅ [NotificationController] Matching type "$type" detected!');
        print('📦 [NotificationController] Payload content: $data');

        // Show local push notification
        try {
          _showLocalNotification(data);
          print(
            '🔔 [NotificationController] _showLocalNotification called successfully',
          );
        } catch (e) {
          print('❌ [NotificationController] Error showing notification: $e');
        }

        // Refresh notification list
        fetchNotifications(refresh: true);
        refreshUnreadCount();
      } else {
        print('⚠️ Unknown type, not showing notification: $type');
      }
    });

    print('✅ NotificationController: WebSocket listener active!');
  }

  /// Show local push notification for WebSocket events
  Future<void> _showLocalNotification(Map<String, dynamic> data) async {
    try {
      // Extract from nested 'data' if present, otherwise use root
      final notifData = data['data'] ?? data;

      final title = notifData['title'] ?? data['title'] ?? 'New Notification';
      final message = notifData['message'] ?? data['message'] ?? '';
      final categoryStr = (notifData['category'] ?? data['category'] ?? 'info')
          .toString()
          .toLowerCase();
      final priorityStr =
          (notifData['priority'] ?? data['priority'] ?? 'medium')
              .toString()
              .toLowerCase();

      print(
        '📬 Processing notification: Title="$title", Category="$categoryStr", Priority="$priorityStr"',
      );

      // Parse category
      NotificationCategory category;
      if (categoryStr.contains('security')) {
        category = NotificationCategory.security;
      } else if (categoryStr.contains('file')) {
        category = NotificationCategory.file;
      } else if (categoryStr.contains('system')) {
        category = NotificationCategory.system;
      } else {
        category = NotificationCategory.info;
      }

      // Parse priority
      NotificationPriority priority;
      if (priorityStr.contains('urgent')) {
        priority = NotificationPriority.urgent;
      } else if (priorityStr.contains('high')) {
        priority = NotificationPriority.high;
      } else if (priorityStr.contains('low')) {
        priority = NotificationPriority.low;
      } else {
        priority = NotificationPriority.medium;
      }

      print('🔔 Triggering LocalNotificationService with Priority: $priority');

      // Show local notification
      await LocalNotificationService().showSimpleNotification(
        title: title,
        body: message,
        category: category,
        priority: priority,
      );
    } catch (e, stack) {
      print('❌ Error showing local notification: $e');
      print('Stack trace: $stack');
    }
  }

  /// Listen to unread count stream
  void _listenToUnreadCount() {
    _unreadCountSubscription = _notificationService.unreadCountStream.listen((
      count,
    ) {
      unreadCount.value = count;
    });
  }

  /// Fetch notifications with optional filtering
  Future<void> fetchNotifications({
    bool refresh = false,
    String? category,
    bool? isRead,
  }) async {
    if (refresh) {
      currentPage.value = 1;
      notifications.clear();
    }

    isLoading.value = true;

    try {
      final response = await _notificationService.fetchNotifications(
        page: currentPage.value,
        pageSize: 20,
        category: category,
        isRead: isRead,
      );

      if (refresh) {
        notifications.value = response.notifications;
      } else {
        notifications.addAll(response.notifications);
      }

      hasMore.value = response.hasMore;
      currentPage.value++;
    } catch (e) {
      print('Error fetching notifications: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    if (!hasMore.value || isLoading.value) return;
    await fetchNotifications();
  }

  /// Refresh unread count
  Future<void> refreshUnreadCount() async {
    final count = await _notificationService.getUnreadCount();
    unreadCount.value = count;
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);

      // Update local state
      final index = notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        notifications[index] = notifications[index].copyWith(isRead: true);
      }
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  /// Mark all as read
  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();

      // Update local state
      notifications.value = notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      unreadCount.value = 0;
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationService.deleteNotification(notificationId);

      // Remove from local state
      notifications.removeWhere((n) => n.id == notificationId);

      // Remove from system tray
      // Using hashCode as ID since we use that when showing them
      await LocalNotificationService().cancelNotification(
        notificationId.hashCode,
      );
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    try {
      await _notificationService.deleteAllNotifications();

      // Clear local state
      notifications.clear();
      unreadCount.value = 0;

      // Clear all from system tray
      await LocalNotificationService().cancelAllNotifications();
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }

  /// Filter by category
  void filterByCategory(String category) {
    currentFilter.value = category;
    if (category == 'all') {
      fetchNotifications(refresh: true);
    } else {
      fetchNotifications(refresh: true, category: category);
    }
  }

  /// Filter by read status
  void filterByReadStatus(bool? isRead) {
    fetchNotifications(refresh: true, isRead: isRead);
  }

  /// Trigger a test notification (for debugging)
  Future<void> triggerTestNotification() async {
    print('🔔 Triggering test notification...');
    try {
      await LocalNotificationService().showSimpleNotification(
        title: 'Test Critical Alert',
        body:
            'This is a test notification to verify critical channel delivery.',
        category: NotificationCategory.security,
        priority: NotificationPriority.urgent,
      );
    } catch (e) {
      print('❌ Error triggering test notification: $e');
    }
  }
}

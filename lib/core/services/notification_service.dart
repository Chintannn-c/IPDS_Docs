import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_stroage_system/core/models/notification_model.dart';
import 'package:file_stroage_system/core/api/api_client.dart';

enum NotificationType { error, warning, success, info }

class NotificationEvent {
  final NotificationType type;
  final String message;
  final String? title;
  final Duration? duration;
  final VoidCallback? onUndo;

  NotificationEvent({
    required this.type,
    required this.message,
    this.title,
    this.duration,
    this.onUndo,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _controller = StreamController<NotificationEvent>.broadcast();
  Stream<NotificationEvent> get stream => _controller.stream;

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  void show({
    required NotificationType type,
    required String message,
    String? title,
    Duration? duration,
    VoidCallback? onUndo,
  }) {
    // Add to stream for listeners (like NotificationListenerWidget)
    _controller.add(
      NotificationEvent(
        type: type,
        message: message,
        title: title,
        duration: duration,
        onUndo: onUndo,
      ),
    );

    // Also try global messenger as fallback for screens without NotificationListenerWidget
    // (Only works if the global key is attached in MaterialApp's scaffoldMessengerKey)
    final messenger = messengerKey.currentState;
    if (messenger != null) {
      // Modern color palette with gradients
      Color primaryColor;
      Color secondaryColor;
      IconData icon;

      switch (type) {
        case NotificationType.success:
          primaryColor = const Color(0xFF10B981); // Emerald
          secondaryColor = const Color(0xFF059669);
          icon = Icons.check_circle_rounded;
          break;
        case NotificationType.error:
          primaryColor = const Color(0xFFEF4444); // Red
          secondaryColor = const Color(0xFFDC2626);
          icon = Icons.error_rounded;
          break;
        case NotificationType.warning:
          primaryColor = const Color(0xFFF59E0B); // Amber
          secondaryColor = const Color(0xFFD97706);
          icon = Icons.warning_rounded;
          break;
        case NotificationType.info:
          primaryColor = const Color(0xFF3B82F6); // Blue
          secondaryColor = const Color(0xFF2563EB);
          icon = Icons.info_rounded;
          break;
      }

      if (!messenger.mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Modern icon with gradient background
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                // Message content
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                      if (title != null) const SizedBox(height: 2),
                      Text(
                        message,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Close indicator
                Icon(
                  Icons.close_rounded,
                  color: Colors.white.withOpacity(0.5),
                  size: 18,
                ),
              ],
            ),
          ),
          backgroundColor: const Color(0xFF1E293B), // Slate dark
          duration: duration ?? const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          elevation: 8,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: primaryColor.withOpacity(0.3), width: 1),
          ),
          action: onUndo != null
              ? SnackBarAction(
                  label: 'UNDO',
                  textColor: primaryColor,
                  onPressed: onUndo,
                )
              : null,
        ),
      );
    }
  }

  void error(
    String message, {
    String? title,
    Duration? duration,
    VoidCallback? onUndo,
  }) {
    show(
      type: NotificationType.error,
      message: message,
      title: title,
      duration: duration,
      onUndo: onUndo,
    );
  }

  void warning(
    String message, {
    String? title,
    Duration? duration,
    VoidCallback? onUndo,
  }) {
    show(
      type: NotificationType.warning,
      message: message,
      title: title,
      duration: duration,
      onUndo: onUndo,
    );
  }

  void success(
    String message, {
    String? title,
    Duration? duration,
    VoidCallback? onUndo,
  }) {
    show(
      type: NotificationType.success,
      message: message,
      title: title,
      duration: duration,
      onUndo: onUndo,
    );
  }

  void info(
    String message, {
    String? title,
    Duration? duration,
    VoidCallback? onUndo,
  }) {
    show(
      type: NotificationType.info,
      message: message,
      title: title,
      duration: duration,
      onUndo: onUndo,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // API Integration Methods for Persistent Notifications
  // ═══════════════════════════════════════════════════════════

  final _unreadCountController = StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  /// Fetch notifications from server
  Future<NotificationListResponse> fetchNotifications({
    int page = 1,
    int pageSize = 20,
    String? category,
    bool? isRead,
    String? priority,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
        if (category != null) 'category': category,
        if (isRead != null) 'is_read': isRead.toString(),
        if (priority != null) 'priority': priority,
      };

      final response = await ApiClient().dio.get(
        '/notifications/notifications',
        queryParameters: queryParams,
      );

      return NotificationListResponse.fromJson(response.data);
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      rethrow;
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final response = await ApiClient().dio.get(
        '/notifications/notifications/unread-count',
      );
      final count = response.data['count'] as int;
      _unreadCountController.add(count);
      return count;
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
      return 0;
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await ApiClient().dio.put(
        '/notifications/notifications/$notificationId/read',
      );
      // Refresh unread count
      await getUnreadCount();
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await ApiClient().dio.put('/notifications/notifications/read-all');
      _unreadCountController.add(0);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await ApiClient().dio.delete(
        '/notifications/notifications/$notificationId',
      );
      // Refresh unread count
      await getUnreadCount();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      rethrow;
    }
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    try {
      await ApiClient().dio.delete('/notifications/notifications/all');
      _unreadCountController.add(0);
    } catch (e) {
      debugPrint('Error deleting all notifications: $e');
      rethrow;
    }
  }

  /// Get notification preferences
  Future<NotificationPreferences> getPreferences(String userId) async {
    try {
      final response = await ApiClient().dio.get(
        '/notifications/notifications/preferences',
      );
      return NotificationPreferences.fromJson(response.data);
    } catch (e) {
      debugPrint('Error fetching notification preferences: $e');
      // Return default preferences
      return NotificationPreferences(userId: userId);
    }
  }

  /// Update notification preferences
  Future<void> updatePreferences(NotificationPreferences preferences) async {
    try {
      await ApiClient().dio.put(
        '/notifications/notifications/preferences',
        data: preferences.toJson(),
      );
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
      rethrow;
    }
  }

  void dispose() {
    _controller.close();
    _unreadCountController.close();
  }
}

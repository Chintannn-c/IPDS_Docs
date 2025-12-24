import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_stroage_system/core/models/notification_model.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize local notifications
  Future<void> initialize() async {
    if (_initialized) {
      print('📱 LocalNotificationService: Already initialized');
      return;
    }

    print('📱 LocalNotificationService: Starting initialization...');

    // Android initialization
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    print('📱 LocalNotificationService: Initializing with settings...');

    // Initialize with callback for when notification is tapped
    final initialized = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    print('📱 LocalNotificationService: Initialize result: $initialized');

    // Request permissions for iOS
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      print('📱 LocalNotificationService: Requesting iOS permissions...');
      final iosPermission = await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      print(
        '📱 LocalNotificationService: iOS permission granted: $iosPermission',
      );
    }

    // Request permissions for Android 13+
    if (defaultTargetPlatform == TargetPlatform.android) {
      print('📱 LocalNotificationService: Requesting Android permissions...');
      final androidPermission = await _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      print(
        '📱 LocalNotificationService: Android permission granted: $androidPermission',
      );
    }

    // Create notification channels
    await _createNotificationChannels();

    _initialized = true;
    print('✅ LocalNotificationService: Initialization complete!');
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return;

    // High priority channel for security alerts
    const securityChannel = AndroidNotificationChannel(
      'security_alerts',
      'Security Alerts',
      description: 'Important security notifications',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    // Default channel for file notifications
    const fileChannel = AndroidNotificationChannel(
      'file_updates',
      'File Updates',
      description: 'File upload and download notifications',
      importance: Importance.defaultImportance,
    );

    // System notifications channel
    const systemChannel = AndroidNotificationChannel(
      'system_updates',
      'System Updates',
      description: 'General system notifications',
      importance: Importance.low,
    );

    await androidPlugin.createNotificationChannel(securityChannel);
    await androidPlugin.createNotificationChannel(fileChannel);
    await androidPlugin.createNotificationChannel(systemChannel);
  }

  /// Show a notification from NotificationModel
  Future<void> showNotification(NotificationModel notification) async {
    if (!_initialized) {
      await initialize();
    }

    final channelId = _getChannelId(notification.category);
    final channelName = _getChannelName(notification.category);
    final priority = _getPriority(notification.priority);
    final importance = _getImportance(notification.priority);

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: priority,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(
        notification.message,
        contentTitle: notification.title,
      ),
      color: _getCategoryColor(notification.category),
      enableVibration:
          notification.priority == NotificationPriority.urgent ||
          notification.priority == NotificationPriority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use notification ID from server, or generate one
    final id = notification.id.hashCode;

    await _notifications.show(
      id,
      notification.title,
      notification.message,
      details,
      payload: notification.id, // Store notification ID for tap handling
    );

    debugPrint('📬 Local notification shown: ${notification.title}');
  }

  /// Show a simple notification (for testing or quick notifications)
  Future<void> showSimpleNotification({
    required String title,
    required String body,
    NotificationCategory category = NotificationCategory.info,
    NotificationPriority priority = NotificationPriority.medium,
    String? payload,
  }) async {
    print(
      '📱 [LocalNotificationService] showSimpleNotification called: $title',
    );

    if (!_initialized) {
      print(
        '⚠️ [LocalNotificationService] Not initialized, attempting to initialize...',
      );
      await initialize();
    }

    // Determine Channel ID based on Priority (Severity)
    String channelId;
    String channelName;
    Importance importance;
    Priority androidPriority;

    switch (priority) {
      case NotificationPriority.urgent:
      case NotificationPriority.high:
        channelId = 'critical_alerts';
        channelName = 'Critical Alerts';
        importance = Importance.max;
        androidPriority = Priority.max;
        break;
      case NotificationPriority.low:
        channelId = 'silent_alerts';
        channelName = 'Silent Notifications';
        importance = Importance.low;
        androidPriority = Priority.low;
        break;
      default: // Medium
        channelId = 'standard_alerts';
        channelName = 'Standard Notifications';
        importance = Importance.defaultImportance;
        androidPriority = Priority.defaultPriority;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notification channel for $channelName',
      importance: importance,
      priority: androidPriority,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF3B82F6), // Brand Blue
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecond, // Unique ID
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Get active notifications count
  Future<int> getActiveNotificationsCount() async {
    final notifications = await _notifications.getActiveNotifications();
    return notifications.length;
  }

  // Helper methods

  String _getChannelId(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.security:
        return 'security_alerts';
      case NotificationCategory.file:
        return 'file_updates';
      case NotificationCategory.system:
        return 'system_updates';
      case NotificationCategory.info:
        return 'system_updates';
    }
  }

  String _getChannelName(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.security:
        return 'Security Alerts';
      case NotificationCategory.file:
        return 'File Updates';
      case NotificationCategory.system:
        return 'System Updates';
      case NotificationCategory.info:
        return 'Info';
    }
  }

  Priority _getPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Priority.low;
      case NotificationPriority.medium:
        return Priority.defaultPriority;
      case NotificationPriority.high:
        return Priority.high;
      case NotificationPriority.urgent:
        return Priority.max;
    }
  }

  Importance _getImportance(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Importance.low;
      case NotificationPriority.medium:
        return Importance.defaultImportance;
      case NotificationPriority.high:
        return Importance.high;
      case NotificationPriority.urgent:
        return Importance.max;
    }
  }

  Color? _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.security:
        return const Color(0xFFDC2626); // Red
      case NotificationCategory.file:
        return const Color(0xFF2563EB); // Blue
      case NotificationCategory.system:
        return const Color(0xFF9333EA); // Purple
      case NotificationCategory.info:
        return const Color(0xFF06B6D4); // Cyan
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('📱 Notification tapped with payload: $payload');

    // TODO: Navigate to notification center or specific screen based on payload
    // This can be handled by setting up a global navigation key
    // and using Get.toNamed('/notifications') or similar
  }
}

enum NotificationCategory {
  security('security'),
  file('file'),
  system('system'),
  info('info');

  final String value;
  const NotificationCategory(this.value);

  static NotificationCategory fromString(String value) {
    return NotificationCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationCategory.info,
    );
  }
}

enum NotificationPriority {
  low('low'),
  medium('medium'),
  high('high'),
  urgent('urgent');

  final String value;
  const NotificationPriority(this.value);

  static NotificationPriority fromString(String value) {
    return NotificationPriority.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationPriority.medium,
    );
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationCategory category;
  final NotificationPriority priority;
  final bool isRead;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.category,
    required this.priority,
    this.isRead = false,
    this.data,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      category: NotificationCategory.fromString(json['category'] as String),
      priority: NotificationPriority.fromString(json['priority'] as String),
      isRead: json['is_read'] as bool? ?? false,
      data: json['data'] as Map<String, dynamic>?,
      createdAt: () {
        var str = json['created_at'] as String;
        if (!str.endsWith('Z')) str += 'Z';
        return DateTime.parse(str).toLocal();
      }(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'category': category.value,
      'priority': priority.value,
      'is_read': isRead,
      'data': data,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationCategory? category,
    NotificationPriority? priority,
    bool? isRead,
    Map<String, dynamic>? data,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class NotificationPreferences {
  final String userId;
  final List<String> enabledCategories;
  final String minPriority;
  final bool soundEnabled;
  final int autoDeleteDays;

  NotificationPreferences({
    required this.userId,
    List<String>? enabledCategories,
    this.minPriority = 'low',
    this.soundEnabled = true,
    this.autoDeleteDays = 30,
  }) : enabledCategories =
           enabledCategories ?? ['security', 'file', 'system', 'info'];

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      userId: json['user_id'] as String,
      enabledCategories:
          (json['enabled_categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          ['security', 'file', 'system', 'info'],
      minPriority: json['min_priority'] as String? ?? 'low',
      soundEnabled: json['sound_enabled'] as bool? ?? true,
      autoDeleteDays: json['auto_delete_days'] as int? ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'enabled_categories': enabledCategories,
      'min_priority': minPriority,
      'sound_enabled': soundEnabled,
      'auto_delete_days': autoDeleteDays,
    };
  }
}

class NotificationListResponse {
  final List<NotificationModel> notifications;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;

  NotificationListResponse({
    required this.notifications,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    return NotificationListResponse(
      notifications: (json['notifications'] as List<dynamic>)
          .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      hasMore: json['has_more'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notifications': notifications.map((e) => e.toJson()).toList(),
      'total': total,
      'page': page,
      'page_size': pageSize,
      'has_more': hasMore,
    };
  }
}

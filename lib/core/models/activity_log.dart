class ActivityLog {
  final String title;
  final String source;
  final DateTime timestamp;
  final String type; // 'warning', 'error', 'info', 'success', 'danger'

  // Computed getters for compatibility with existing code
  String get action => title;
  String? get severity => type;
  String get status => type == 'error' || type == 'danger'
      ? 'ERROR'
      : (type == 'warning' ? 'WARNING' : 'SUCCESS');

  // Dummy compatibility getters for widgets that expect these fields
  LogActor get actor =>
      LogActor(userId: 'system', name: source, role: 'System', ipAddress: null);
  LogTarget? get target => null;
  Map<String, dynamic>? get metadata => null;

  final String? location;

  ActivityLog({
    required this.title,
    required this.source,
    required this.timestamp,
    required this.type,
    this.location,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    // Parse geo_data if available
    String? locationStr;
    if (json['geo_data'] != null && json['geo_data'] is Map) {
      final geo = json['geo_data'];
      final city = geo['city'];
      final country = geo['country'];
      if (city != null &&
          city != 'Unknown' &&
          country != null &&
          country != 'Unknown') {
        locationStr = '$city, $country';
      } else if (country != null && country != 'Unknown') {
        locationStr = country;
      }
    }

    return ActivityLog(
      // Support both 'action' (new combined) and 'title' (old format)
      title: json['action'] ?? json['title'] ?? 'Unknown Event',
      // auth-activity uses device_name, combined uses device_name, logs uses source
      source:
          json['device_name'] ?? json['source'] ?? json['filename'] ?? 'System',
      timestamp: DateTime.parse(json['timestamp']),
      // Support both 'severity' (new combined) and 'type' (old format)
      type: json['severity'] ?? json['type'] ?? 'info',
      location: locationStr,
    );
  }
}

class LogActor {
  final String userId;
  final String name;
  final String role;
  final String? ipAddress;

  LogActor({
    required this.userId,
    required this.name,
    required this.role,
    this.ipAddress,
  });

  factory LogActor.fromJson(Map<String, dynamic> json) {
    return LogActor(
      userId: json['user_id'],
      name: json['name'],
      role: json['role'] ?? 'User',
      ipAddress: json['ip_address'],
    );
  }
}

class LogTarget {
  final String type;
  final String? id;
  final String? name;

  LogTarget({required this.type, this.id, this.name});

  factory LogTarget.fromJson(Map<String, dynamic> json) {
    return LogTarget(type: json['type'], id: json['id'], name: json['name']);
  }
}

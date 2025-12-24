import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:file_stroage_system/core/api/api_client.dart';
import 'package:file_stroage_system/core/models/activity_log.dart';
import 'package:file_stroage_system/core/services/web_socket_service.dart';
import 'package:dio/dio.dart';

class IPDSProvider extends ChangeNotifier {
  final _dio = ApiClient().dio;
  final _ws = WebSocketService.to; // Keeping singleton service for now

  // Data
  List<ActivityLog> _logs = [];
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _risk = {};
  Map<String, dynamic> _userActivity = {};

  // Loading States
  bool _isLoadingLogs = false;
  bool _isLoadingStats = false;
  bool _isLoadingRisk = false;
  bool _isLoadingUserActivity = false;

  List<ActivityLog> get logs => _logs;
  Map<String, dynamic> get stats => _stats;
  Map<String, dynamic> get risk => _risk;
  Map<String, dynamic> get userActivity => _userActivity;

  bool get isLoadingLogs => _isLoadingLogs;
  bool get isLoadingStats => _isLoadingStats;
  bool get isLoadingRisk => _isLoadingRisk;
  bool get isLoadingUserActivity => _isLoadingUserActivity;

  // Security alerts from user-activity endpoint
  List<Map<String, dynamic>> get securityAlerts {
    try {
      if (_userActivity.isEmpty) return [];
      final alerts = _userActivity['security_alerts'];
      if (alerts == null || alerts is! List) return [];
      return alerts.map<Map<String, dynamic>>((e) {
        if (e is Map) {
          return Map<String, dynamic>.from(e);
        }
        return <String, dynamic>{};
      }).toList();
    } catch (e) {
      debugPrint("Error parsing security alerts: $e");
      return [];
    }
  }

  StreamSubscription? _logSub;

  IPDSProvider() {
    _listenToWSEvents();
  }

  @override
  void dispose() {
    _logSub?.cancel();
    super.dispose();
  }

  void initData() {
    fetchDashboardStats();
    fetchLogs();
    fetchRiskAnalysis();
    fetchUserActivity();
  }

  Future<void> fetchDashboardStats() async {
    try {
      _isLoadingStats = true;
      notifyListeners();
      final res = await _dio.get('/ipds/dashboard');
      if (res.data != null) {
        _stats = Map<String, dynamic>.from(res.data);
      }
      _isLoadingStats = false;
      notifyListeners();
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        // Global logout triggered. Do not notify listeners.
        return;
      }
      debugPrint("IPDS Stats Error: $e");
      _isLoadingStats = false;
      notifyListeners();
    }
  }

  Future<void> fetchLogs() async {
    try {
      _isLoadingLogs = true;
      notifyListeners();
      debugPrint("IPDS: Fetching logs from /logs/ipds-combined...");
      final res = await _dio.get('/logs/ipds-combined');

      if (res.data is List) {
        _logs = List<ActivityLog>.from(
          (res.data as List).map((x) => ActivityLog.fromJson(x)),
        );
      }
      _isLoadingLogs = false;
      notifyListeners();
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        return;
      }
      debugPrint("IPDS Logs Fetch Error: $e");
      _isLoadingLogs = false;
      notifyListeners();
    }
  }

  Future<void> fetchRiskAnalysis() async {
    try {
      _isLoadingRisk = true;
      notifyListeners();
      // Assuming endpoint exists as per Controller logic
      final res = await _dio.get('/ipds/risk');
      if (res.data != null) {
        _risk = Map<String, dynamic>.from(res.data);
      }
      _isLoadingRisk = false;
      notifyListeners();
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        return;
      }
      debugPrint("Risk Analysis Error: $e");
      _isLoadingRisk = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserActivity() async {
    try {
      _isLoadingUserActivity = true;
      notifyListeners();
      final res = await _dio.get('/ipds/user-activity');
      if (res.data != null) {
        _userActivity = Map<String, dynamic>.from(res.data);
      }
      _isLoadingUserActivity = false;
      notifyListeners();
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        return;
      }
      debugPrint("User Activity Error: $e");
      _isLoadingUserActivity = false;
      notifyListeners();
    }
  }

  void _listenToWSEvents() {
    _logSub = _ws.logStream.listen((data) {
      try {
        final newLog = ActivityLog.fromJson(data);
        _logs.insert(0, newLog);
        if (_logs.length > 200) _logs.removeLast();

        notifyListeners();

        if (newLog.severity == 'critical' || newLog.severity == 'high') {
          fetchDashboardStats();
        }
      } catch (e) {
        debugPrint("Error parsing WebSocket log: $e");
      }
    });
  }

  // Helpers
  int get safeDeviceCount {
    final devices = _stats['devices'] as List? ?? [];
    return devices.where((d) => d['is_blocked'] != true).length;
  }

  int get riskDeviceCount {
    final devices = _stats['devices'] as List? ?? [];
    return devices.where((d) => d['is_blocked'] == true).length;
  }
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:file_stroage_system/core/services/web_socket_service.dart';
import 'package:file_stroage_system/core/services/notification_service.dart';
import 'package:file_stroage_system/core/api/api_client.dart';
import 'package:file_stroage_system/features/auth/presentation/auth_provider.dart';

class DeviceProvider extends ChangeNotifier {
  final _dio = ApiClient().dio;
  final AuthProvider authProvider;

  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = false;
  bool _isDeviceBlocked = false;
  String? _deviceFingerprint;

  List<Map<String, dynamic>> get devices => _devices;
  bool get isLoading => _isLoading;
  bool get isDeviceBlocked => _isDeviceBlocked;

  StreamSubscription? _deviceSub;
  StreamSubscription? _deviceBlockedSub;

  DeviceProvider(this.authProvider) {
    _deviceFingerprint = authProvider.deviceFingerprint;
    // Listen to WS if auth changes or manually init?
    // Ideally init when provider is created.
    _listenToWSEvents();
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _deviceBlockedSub?.cancel();
    super.dispose();
  }

  Future<void> fetchDevices() async {
    try {
      _isLoading = true;
      notifyListeners();
      final response = await _dio.get('/auth/devices');
      if (response.data is List) {
        _devices = List<Map<String, dynamic>>.from(response.data);
      }
    } catch (e) {
      debugPrint('DeviceProvider: Fetch devices error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeDevice(String deviceId) async {
    try {
      final response = await _dio.post(
        '/auth/devices/remove',
        data: {'device_id': deviceId},
      );

      if (response.data['force_logout'] == true) {
        authProvider.logout();
      } else {
        NotificationService().success('Device removed');
        _devices.removeWhere((d) => d['device_id'] == deviceId);
        notifyListeners();
      }
    } catch (e) {
      NotificationService().error('Failed to remove device');
    }
  }

  Future<void> toggleDeviceBlock(String deviceId) async {
    try {
      await _dio.post('/auth/devices/block', data: {'device_id': deviceId});
    } catch (e) {
      NotificationService().error('Failed to update device status');
    }
  }

  Future<void> toggleDeviceTrust(String deviceId) async {
    try {
      await _dio.post(
        '/auth/devices/toggle-trust',
        data: {'device_id': deviceId},
      );
      await fetchDevices();
      NotificationService().success('Device trust status updated');
    } catch (e) {
      NotificationService().error('Failed to update trust status');
    }
  }

  void _listenToWSEvents() {
    final ws = WebSocketService.to;

    _deviceSub = ws.deviceStream.listen((payload) {
      fetchDevices();
    });

    _deviceBlockedSub = ws.deviceBlockedStream.listen((data) {
      final blockedFingerprint = data['device_fingerprint'];
      if (_deviceFingerprint != null &&
          blockedFingerprint == _deviceFingerprint) {
        _handleDeviceBlocked();
      }
    });
  }

  void _handleDeviceBlocked() {
    _isDeviceBlocked = true;
    notifyListeners();
    NotificationService().error(
      'This device has been blocked. Logging out...',
      title: 'Device Blocked',
    );
    authProvider.logout();
  }
}

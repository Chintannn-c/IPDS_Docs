import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:file_stroage_system/core/controllers/notification_controller.dart';
import '../api/api_client.dart';

/// A global Service for handling WebSocket connections and broadcasting events.
class WebSocketService {
  // Singleton instance
  static final WebSocketService _instance = WebSocketService._internal();
  static WebSocketService get to => _instance;

  WebSocketService._internal();

  // Observable state using ValueNotifier for checking connection status
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);

  // Internal
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _isConnecting = false;
  final _storage = const FlutterSecureStorage();

  // Reactive Streams
  final _logController = StreamController<Map<String, dynamic>>.broadcast();
  final _alertController = StreamController<Map<String, dynamic>>.broadcast();
  final _riskController = StreamController<Map<String, dynamic>>.broadcast();
  final _deviceController = StreamController<Map<String, dynamic>>.broadcast();
  final _authActivityController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _fileTrackingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _deviceBlockedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _forceLogoutController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Public Getters for Streams
  Stream<Map<String, dynamic>> get logStream => _logController.stream;
  Stream<Map<String, dynamic>> get alertStream => _alertController.stream;
  Stream<Map<String, dynamic>> get riskStream => _riskController.stream;
  Stream<Map<String, dynamic>> get deviceStream => _deviceController.stream;
  Stream<Map<String, dynamic>> get authActivityStream =>
      _authActivityController.stream;
  Stream<Map<String, dynamic>> get fileTrackingStream =>
      _fileTrackingController.stream;
  Stream<Map<String, dynamic>> get deviceBlockedStream =>
      _deviceBlockedController.stream;
  Stream<Map<String, dynamic>> get forceLogoutStream =>
      _forceLogoutController.stream;

  void dispose() {
    disconnect();
    _logController.close();
    _alertController.close();
    _riskController.close();
    _deviceController.close();
    _authActivityController.close();
    _fileTrackingController.close();
    _deviceBlockedController.close();
    _forceLogoutController.close();
  }

  Future<void> connect() async {
    print('🔌 WebSocketService: Connect called');

    // CRITICAL: Initialize NotificationController NOW so it's ready for messages
    try {
      print('🔔 Initializing NotificationController from WebSocketService...');
      Get.put(NotificationController(), permanent: true);
      print('✅ NotificationController initialized!');
    } catch (e) {
      print('⚠️ NotificationController already exists or error: $e');
    }

    if (_channel != null) {
      print('⚠️ WebSocket already connected');
      return;
    }

    if (isConnected.value || _isConnecting) return;
    _isConnecting = true;

    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) {
        debugPrint('WS: No token found, skipping connection');
        _isConnecting = false;
        return;
      }

      final base = ApiClient().baseUrl;
      final wsScheme = base.startsWith('https') ? 'wss' : 'ws';
      final wsUrl = base.replaceFirst(RegExp(r'^https?'), wsScheme);
      final url = '$wsUrl/ws/ipds/ws?token=$token';

      debugPrint('WS: Connecting to $url');
      _channel = WebSocketChannel.connect(Uri.parse(url));

      // Add timeout to prevent indefinite hang on ready
      await _channel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('WebSocket connection timed out after 10s');
        },
      );

      isConnected.value = true;
      _isConnecting = false;
      debugPrint('WS: Connected');

      _startHeartbeat();

      _channel!.stream.listen(
        (message) => _handleMessage(message),
        onDone: () {
          debugPrint('WS: Connection closed');
          _cleanup();
          _scheduleReconnect();
        },
        onError: (error) {
          debugPrint('WS: Error: $error');
          _cleanup();
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('WS: Connection failed: $e');
      _cleanup();
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = json.decode(message);
      debugPrint('WS: Received: $data');

      final type = data['type'];
      final payload = data['data'];

      switch (type) {
        case 'log':
        case 'log.new':
          _logController.add(payload);
          break;

        case 'alert':
        case 'new_device_login':
        case 'notification':
          // Enhance payload with type if missing
          final enhancedPayload = Map<String, dynamic>.from(payload ?? {});
          if (!enhancedPayload.containsKey('type')) {
            enhancedPayload['type'] = type;
          }
          // Also include top-level fields from data if present
          if (payload == null && data is Map) {
            // If there's no nested data, use the whole message
            enhancedPayload.addAll(Map<String, dynamic>.from(data));
          }
          debugPrint(
            '📬 WS: Routing notification to alertStream: $enhancedPayload',
          );
          _alertController.add(enhancedPayload);
          break;

        case 'risk':
          _riskController.add(payload);
          break;

        case 'device':
          _deviceController.add(payload);
          break;

        case 'auth_activity':
          _authActivityController.add(payload);
          break;

        case 'file.tracking_update':
          _fileTrackingController.add(payload);
          break;

        case 'force_logout':
        case 'device_blocked':
        case 'device_removed':
        case 'session_invalid':
          debugPrint('WS: 🚨 Force logout event received: $type');
          final logoutPayload = {
            if (payload != null) ...Map<String, dynamic>.from(payload),
            'event_type': type,
          };
          _forceLogoutController.add(logoutPayload);
          // Also broadcast to device blocked for compatibility
          _deviceBlockedController.add(logoutPayload);
          break;

        case 'login_attempt':
          final alertPayload = {
            if (payload != null) ...Map<String, dynamic>.from(payload),
            'event_type': type,
          };
          _alertController.add(alertPayload);
          break;

        default:
          debugPrint('WS: Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('WS: Failed to parse message: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isConnected.value && _channel != null) {
        // Ping if supported
      }
    });
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    debugPrint('WS: Scheduling reconnect in 5s');
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void _cleanup() {
    isConnected.value = false;
    _isConnecting = false;
    _heartbeatTimer?.cancel();
    _channel = null;
  }

  void disconnect() {
    debugPrint('WS: Disconnecting manually');
    _reconnectTimer?.cancel();
    _cleanup();
    _channel?.sink.close(status.goingAway);
  }
}

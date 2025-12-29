import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_stroage_system/core/api/api_client.dart';
import 'package:file_stroage_system/core/services/notification_service.dart';
import 'package:file_stroage_system/core/services/web_socket_service.dart';
import 'package:file_stroage_system/core/controllers/device_controller.dart';
import 'package:file_stroage_system/core/controllers/notification_controller.dart';
import 'package:get/get.dart' hide Response, FormData, MultipartFile;
import 'package:file_stroage_system/core/services/biometric_service.dart';

class AuthProvider with ChangeNotifier {
  final Dio _dio = ApiClient().dio;
  final _storage = const FlutterSecureStorage();

  bool _isLoggingOut = false;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? _user;
  List<dynamic> _devices = [];
  List<dynamic> _logs = [];
  List<dynamic> _authActivity = []; // Login/logout activity
  Map<String, dynamic>? _ipdsData;
  Map<String, dynamic>? _riskData;
  Map<String, dynamic>? _userActivity; // User-specific IPDS activity

  String? _currentDeviceId;
  String? _deviceFingerprint; // Added declaration

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null; // Added getter for convenience
  Map<String, dynamic>? get user => _user;
  List<dynamic> get devices => _devices;
  List<dynamic> get logs => _logs;
  List<dynamic> get authActivity => _authActivity; // Getter for auth activity
  Map<String, dynamic>? get ipdsData => _ipdsData;
  Map<String, dynamic>? get riskData => _riskData;
  Map<String, dynamic>? get userActivity =>
      _userActivity; // Getter for user activity
  String? get currentDeviceId => _currentDeviceId;
  String? get deviceFingerprint =>
      _deviceFingerprint; // Expose fingerprint for UI msg

  // ================= DEVICE DETECTION HELPER =================
  /// Check if a device is the current device
  /// Matches by device_id OR fingerprint for robust detection
  bool isCurrentDevice(Map<String, dynamic> device) {
    final deviceId = device['device_id'];
    final fingerprint = device['fingerprint'];

    // Match by device_id ONLY to distinguish between duplicates (e.g. old UA-based ID vs new UUID)
    // If we match by fingerprint, we lock both the old and new entries as "Current Device",
    // preventing the user from deleting the old ghost entry.
    return deviceId != null && deviceId == _currentDeviceId;
  }

  // ================= WEBSOCKET SUBSCRIPTIONS =================
  StreamSubscription? _logSub;
  StreamSubscription? _deviceSub;
  StreamSubscription? _riskSub;
  StreamSubscription? _alertSub;
  StreamSubscription? _authActivitySub;
  StreamSubscription? _deviceBlockedSub;
  StreamSubscription? _forceLogoutSub;

  // Periodic device status check (fallback if WebSocket fails)
  Timer? _deviceStatusTimer;

  // Device fingerprint for tracking (to check if this device is blocked)
  // Check definition at top of class

  AuthProvider() {
    // CRITICAL: Listen to global 401/403 errors for INSTANT logout
    ApiClient().authErrorStream.listen((event) async {
      final type = event['type'];
      final message = event['message'] ?? 'Authentication Error';

      debugPrint('[AuthError] Received: $type - $message');

      // Show notification FIRST
      if (type == 'blocked') {
        NotificationService().error(message, title: 'Device Blocked');
      } else if (type == 'unauthorized') {
        NotificationService().warning(message, title: 'Session Expired');
      } else {
        NotificationService().error(message, title: 'Network Error');
      }

      // Then logout (this clears state and triggers navigation via main.dart)
      await logout();
      notifyListeners(); // Ensure UI updates immediately
    });

    // Auto-initialize on construction
    _initSession();
    _initWebSocketListeners();
  }

  void _initWebSocketListeners() {
    final ws = WebSocketService.to;

    // Listen to logs
    _logSub = ws.logStream.listen((log) {
      addLog(log);
    });

    // Listen to auth activity
    _authActivitySub = ws.authActivityStream.listen((activity) {
      addAuthActivity(activity);
    });

    // LEASE NEW DEVICE LOGIN
    _alertSub = ws.alertStream.listen((alert) {
      if (alert['type'] == 'new_device_login') {
        NotificationService().info(
          'New login from ${alert['data']['device_name']}',
          title: 'New Device',
        );
        fetchDevices(); // Refresh list
      }
    });

    // Listen for Force Logout (Block/Remove)
    _forceLogoutSub = ws.forceLogoutStream.listen((event) async {
      final targetFingerprint = event['device_fingerprint'];
      final eventType = event['event_type'];

      // If no fingerprint specified (global logout?) or Matches ours
      // Note: We need to store our own fingerprint during login to compare!
      // Checking against _deviceFingerprint (we need to save this on login)
      debugPrint('Force Logout Event: ${event['event_type']}');
      debugPrint('Target Fingerprint: $targetFingerprint');
      debugPrint('Current Fingerprint: $_deviceFingerprint');

      // Check match
      if (_deviceFingerprint != null &&
          targetFingerprint == _deviceFingerprint) {
        debugPrint('Use is targeted for FORCE LOGOUT: $eventType');
        await logout();

        if (eventType == 'device_blocked') {
          NotificationService().error(
            'You are blocked and cannot login until unblocked.',
            title: 'Device Blocked',
          );
        } else if (eventType == 'device_removed') {
          NotificationService().warning(
            'You have been logged out.',
            title: 'Device Removed',
          );
        }
      } else {
        // If it's just a general update (like another device block), refresh
        fetchDevices();
      }
    });
  }

  /// Initialize session: On mobile, restore saved session. On web, always fresh start.
  Future<void> _initSession() async {
    // WEB: Always require fresh login - clear any saved token
    if (kIsWeb) {
      await _storage.delete(key: 'access_token');
      debugPrint('AuthProvider [Web]: Cleared token, fresh login required');
      return;
    }

    // MOBILE: Don't auto-restore session here
    // The LoginScreen will handle showing biometric unlock if token exists
    // We just check if token exists - user will verify identity via biometric
    try {
      final savedToken = await _storage.read(key: 'access_token');
      if (savedToken != null && savedToken.isNotEmpty) {
        debugPrint(
          'AuthProvider [Mobile]: Token exists, waiting for user verification',
        );
        // Don't restore session yet - wait for biometric unlock
      } else {
        debugPrint('AuthProvider [Mobile]: No saved token found');
      }
    } catch (e) {
      debugPrint('AuthProvider [Mobile]: Error checking session: $e');
    }

    // Always load device info/fingerprint on init
    await loadCurrentDeviceId();
  }

  /// Restore session from saved token (e.g. after biometric unlock)
  /// Fetches profile AND connects WebSocket to ensure notifications work
  Future<void> restoreSession() async {
    _isLoading = true;
    notifyListeners();
    print('Auth: restoreSession starting...');

    try {
      // Add timeout to fetchUserProfile to prevent hanging app
      await fetchUserProfile(notify: false).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          print('Auth: restoreSession - fetchUserProfile timed out');
          throw TimeoutException('Profile fetch timed out');
        },
      );

      // CRITICAL: Connect WebSocket to enable real-time notifications
      // WebSocketService already has its own timeout now
      await WebSocketService.to.connect();

      // Refresh notifications once session is restored
      try {
        if (Get.isRegistered<NotificationController>()) {
          final nc = Get.find<NotificationController>();
          nc.fetchNotifications(refresh: true);
          nc.refreshUnreadCount();
        }
      } catch (e) {
        debugPrint('Error triggering notification fetch: $e');
      }

      // Set device logged in state
      DeviceController.to.setLoggedIn(true);
      print('Auth: restoreSession completed successfully');
    } catch (e) {
      debugPrint('restoreSession error: $e');
      // Don't rethrow - UI checks isLoggedIn
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ================= DEVICE INFO =================
  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    String id = 'unknown';
    String name = 'Unknown';
    String type = 'unknown';

    try {
      if (kIsWeb) {
        final web = await deviceInfo.webBrowserInfo;

        // SYNC WITH API_CLIENT: Use persistent ID
        String? stickyId = await _storage.read(key: "unique_device_id");
        if (stickyId == null || stickyId.isEmpty) {
          stickyId =
              'web_${DateTime.now().millisecondsSinceEpoch}_${web.productSub ?? "x"}';
          await _storage.write(key: "unique_device_id", value: stickyId);
        }
        id = stickyId;
        name = web.browserName.name;
        type = 'web';
      } else {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final a = await deviceInfo.androidInfo;
            id = a.id;
            name = '${a.brand} ${a.model}';
            type = 'android';
            break;
          case TargetPlatform.iOS:
            final i = await deviceInfo.iosInfo;
            id = i.identifierForVendor ?? 'ios';
            name = i.name;
            type = 'ios';
            break;
          case TargetPlatform.windows:
            final w = await deviceInfo.windowsInfo;
            id = w.deviceId;
            name = w.computerName;
            type = 'windows';
            break;
          case TargetPlatform.macOS:
            final m = await deviceInfo.macOsInfo;
            id = m.systemGUID ?? 'mac';
            name = m.computerName;
            type = 'mac';
            break;
          case TargetPlatform.linux:
            final l = await deviceInfo.linuxInfo;
            id = l.machineId ?? 'linux';
            name = l.name;
            type = 'linux';
            break;
          default:
            type = 'unknown';
        }
      }
    } catch (_) {}

    _currentDeviceId = id;
    // Load persistent fingerprint matching ApiClient
    _deviceFingerprint = await _storage.read(key: 'device_fingerprint');

    notifyListeners();
    return {'id': id, 'name': name, 'type': type};
  }

  Future<void> loadCurrentDeviceId() => _getDeviceInfo();

  // ================= REGISTER =================
  Future<String?> register(String email, String password, String name) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _dio.post(
        '/auth/register',
        data: {
          'email': email.trim(),
          'password': password.trim(),
          'name': name.trim(),
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      _isLoading = false;
      notifyListeners();
      return null; // SUCCESS
    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();
      final detail = e.response?.data?['detail'];
      if (detail is List) return detail.join(", ");
      if (detail is String) return detail;
      return 'Registration failed';
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      return 'Unexpected error occurred';
    }
  }

  // ================= LOGIN =================
  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    String? deviceFingerprint,
    bool shouldBindDevice = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deviceInfo = await _getDeviceInfo();

      // Store fingerprint for WS identification
      if (deviceFingerprint != null) {
        _deviceFingerprint = deviceFingerprint;
      }

      final response = await _dio.post(
        '/auth/login',
        data: FormData.fromMap({
          'username': email.trim(),
          'password': password.trim(),
        }),
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'X-Device-ID': deviceInfo['id'],
            'X-Device-Name': deviceInfo['name'],
            'X-Device-Type': deviceInfo['type'],
            // Send client-generated fingerprint for biometric binding
            if (deviceFingerprint != null)
              'X-Device-Fingerprint': deviceFingerprint,
          },
        ),
      );

      // Check if MFA is required
      if (response.data['mfa_required'] == true) {
        _isLoading = false;
        if (response.data['debug_otp'] != null) {
          debugPrint('==========================================');
          debugPrint('DEV OTP (Login): ${response.data['debug_otp']}');
          debugPrint('==========================================');
        }
        notifyListeners();
        return {'mfa_required': true, 'email': response.data['email'] ?? email};
      }

      final token = response.data['access_token'];
      final isNewDevice = response.data['is_new_device'] ?? false;

      if (token != null)
        await _storage.write(key: 'access_token', value: token);

      // Reset lockout state IMMEDIATELY after getting valid token
      ApiClient.clearAuthFailure();

      // Bind device if requested (before fetching profile -> redirect)
      if (deviceFingerprint != null && shouldBindDevice) {
        try {
          // We can use the existing bindDevice method
          // Note: We need to use a separate try-catch to not fail login if binding fails
          await bindDevice(deviceFingerprint);
        } catch (e) {
          debugPrint('Failed to auto-bind device: $e');
        }
      }

      await fetchUserProfile();
      connectWS(); // Real-time connection

      // Refresh notifications once logged in
      try {
        if (Get.isRegistered<NotificationController>()) {
          final nc = Get.find<NotificationController>();
          nc.fetchNotifications(refresh: true);
          nc.refreshUnreadCount();
        }
      } catch (e) {
        debugPrint('Error triggering notification fetch: $e');
      }

      // Set fingerprint on DeviceController for real-time blocking
      if (deviceFingerprint != null) {
        DeviceController.to.setDeviceFingerprint(deviceFingerprint);
        setDeviceFingerprint(
          deviceFingerprint,
        ); // Also set on AuthProvider for force_logout matching
      }
      DeviceController.to.setLoggedIn(true);

      // Enable biometric authentication for next app startup
      BiometricService.enable();

      _isLoading = false;
      notifyListeners();
      return {'success': true, 'isNewDevice': isNewDevice};
    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();
      String errorMessage = 'Login failed';
      String errorType = 'generic';

      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        errorMessage = e.response!.data['detail'] ?? errorMessage;
        errorType = e.response!.data['error_type'] ?? errorType;
      }

      _errorMessage = errorMessage;
      return {'success': false, 'error': errorMessage, 'errorType': errorType};
    }
  }

  // ================= BIOMETRIC LOGIN =================
  /// Login using device fingerprint only (after biometric verification on device)
  Future<Map<String, dynamic>> biometricLogin(String deviceFingerprint) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deviceInfo = await _getDeviceInfo();

      final response = await _dio.post(
        '/auth/biometric-login',
        data: {
          'device_fingerprint': deviceFingerprint,
          'device_name': deviceInfo['name'],
          'device_type': deviceInfo['type'],
        },
        options: Options(contentType: Headers.jsonContentType),
      );

      final token = response.data['access_token'];
      final userEmail = response.data['user_email'];
      final userName = response.data['user_name'];

      if (token != null) {
        await _storage.write(key: 'access_token', value: token);
        await _storage.write(key: 'saved_email', value: userEmail);
      }

      // Reset lockout state IMMEDIATELY after getting valid token
      ApiClient.clearAuthFailure();

      await fetchUserProfile();
      connectWS();

      // Set fingerprint on DeviceController for real-time blocking
      DeviceController.to.setDeviceFingerprint(deviceFingerprint);
      setDeviceFingerprint(
        deviceFingerprint,
      ); // Also set on AuthProvider for force_logout matching
      DeviceController.to.setLoggedIn(true);

      _isLoading = false;
      notifyListeners();
      return {
        'success': true,
        'userEmail': userEmail,
        'userName': userName,
        'message': response.data['message'],
      };
    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();
      String errorMessage = 'Biometric login failed';
      String errorType = 'generic';

      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        errorMessage = e.response!.data['detail'] ?? errorMessage;
        // Check headers for error type
        final headers = e.response!.headers;
        errorType =
            headers.value('X-Error-Type') ??
            e.response!.data['error_type'] ??
            errorType;
      }

      _errorMessage = errorMessage;
      return {'success': false, 'error': errorMessage, 'errorType': errorType};
    }
  }

  /// Bind device fingerprint to current user (call after password login)
  Future<Map<String, dynamic>> bindDevice(String deviceFingerprint) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final response = await _dio.post(
        '/auth/bind-device',
        data: {
          'device_fingerprint': deviceFingerprint,
          'device_name': deviceInfo['name'],
          'device_type': deviceInfo['type'],
        },
        options: Options(contentType: Headers.jsonContentType),
      );
      return {'success': true, 'message': response.data['message']};
    } on DioException catch (e) {
      String errorMessage = 'Failed to bind device';
      String errorType = 'generic';
      if (e.response != null && e.response!.data is Map<String, dynamic>) {
        errorMessage = e.response!.data['detail'] ?? errorMessage;
        final headers = e.response!.headers;
        errorType = headers.value('X-Error-Type') ?? errorType;
      }
      return {'success': false, 'error': errorMessage, 'errorType': errorType};
    }
  }

  /// Check if device fingerprint is already bound to a user
  Future<Map<String, dynamic>> checkDeviceBinding(
    String deviceFingerprint,
  ) async {
    try {
      final response = await _dio.get('/auth/check-device/$deviceFingerprint');
      return {
        'isBound': response.data['is_bound'] ?? false,
        'userEmail': response.data['user_email'],
        'userName': response.data['user_name'],
      };
    } catch (e) {
      debugPrint('checkDeviceBinding error: $e');
      return {'isBound': false, 'error': 'Failed to check device binding'};
    }
  }

  // ================= PROFILE =================
  Future<void>? _profileFetchFuture;

  Future<void> fetchUserProfile({bool notify = true}) async {
    // If a request is already in progress, return the same future
    if (_profileFetchFuture != null) {
      debugPrint(
        '[Auth] fetchUserProfile: Request already in flight, awaiting...',
      );
      return _profileFetchFuture;
    }

    _profileFetchFuture = _fetchUserProfileInternal(notify: notify);
    try {
      await _profileFetchFuture;
    } finally {
      _profileFetchFuture = null;
    }
  }

  Future<void> _fetchUserProfileInternal({bool notify = true}) async {
    try {
      final res = await _dio.get('/auth/me');

      // Handle custom 429 "locked" response from backend
      if (res.statusCode == 429) {
        debugPrint(
          '[Auth] fetchUserProfile: Status 429 (Locked) - Ignoring redundant call',
        );
        return;
      }

      _user = res.data;

      // SYNC DEVICES: Populate _devices from the user profile to ensure consistency
      if (_user != null && _user!['trusted_devices'] != null) {
        _devices = List<dynamic>.from(_user!['trusted_devices']);
      }

      if (notify) notifyListeners();
    } on DioException catch (e) {
      // Gracefully handle 429 concurrency lock
      if (e.response?.statusCode == 429) {
        debugPrint('[Auth] fetchUserProfile: Dio 429 (Locked) - Ignoring');
        return;
      }
      debugPrint('[Auth] fetchUserProfile error: $e');
      rethrow;
    } catch (e) {
      debugPrint('[Auth] fetchUserProfile unexpected error: $e');
      rethrow;
    }
  }

  void notifyAuthChange() {
    notifyListeners();
  }

  Future<bool> updateProfile(String name, String email) async {
    try {
      final res = await _dio.put(
        '/auth/me',
        data: {'name': name, 'email': email},
      );
      _user = res.data;
      notifyListeners();
      NotificationService().success("Profile updated");
      return true;
    } catch (_) {
      NotificationService().error("Update failed");
      return false;
    }
  }

  // ================= PASSWORD =================
  Future<bool> changePassword(String current, String newPass) async {
    try {
      final response = await _dio.post(
        '/auth/change-password',
        data: {'current_password': current, 'new_password': newPass},
      );

      // Save the new token so current device stays logged in
      if (response.data['access_token'] != null) {
        final newToken = response.data['access_token'];
        await _storage.write(key: 'access_token', value: newToken);
        _dio.options.headers['Authorization'] = 'Bearer $newToken';
      }

      NotificationService().success("Password changed successfully");
      return true;
    } catch (_) {
      NotificationService().error("Password change failed");
      return false;
    }
  }

  // ================= FORGOT PASSWORD =================
  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    try {
      final res = await _dio.post(
        '/auth/forgot-password/request',
        queryParameters: {'email': email},
      );
      return {
        'success': true,
        'message': res.data['message'],
        'expires_in_minutes': res.data['expires_in_minutes'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['detail'] ?? 'Failed to send reset code',
      };
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred'};
    }
  }

  Future<Map<String, dynamic>> verifyPasswordResetOTP(
    String email,
    String code,
  ) async {
    try {
      final res = await _dio.post(
        '/auth/forgot-password/verify',
        queryParameters: {'email': email, 'code': code},
      );
      return {
        'success': true,
        'reset_token': res.data['reset_token'],
        'message': res.data['message'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['detail'] ?? 'Invalid code',
      };
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred'};
    }
  }

  Future<Map<String, dynamic>> resetPasswordWithToken(
    String token,
    String newPassword,
  ) async {
    try {
      final res = await _dio.post(
        '/auth/forgot-password/reset',
        queryParameters: {'reset_token': token, 'new_password': newPassword},
      );
      return {'success': true, 'message': res.data['message']};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['detail'] ?? 'Failed to reset password',
      };
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred'};
    }
  }

  // ================= IMAGE =================
  Future<bool> uploadProfileImage(FilePickerResult result) async {
    try {
      final file = result.files.single;
      final form = FormData.fromMap({
        'file': file.bytes != null
            ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
            : await MultipartFile.fromFile(file.path!, filename: file.name),
      });

      final res = await _dio.post('/auth/profile-image', data: form);
      _user = res.data;
      notifyListeners();
      NotificationService().success("Image uploaded");
      return true;
    } catch (_) {
      NotificationService().error("Upload failed");
      return false;
    }
  }

  // ================= DOCUMENT UPLOAD (Profile Test) =================
  Future<bool> uploadDocument(FilePickerResult result) async {
    try {
      final file = result.files.single;
      final form = FormData.fromMap({
        'file': file.bytes != null
            ? MultipartFile.fromBytes(file.bytes!, filename: file.name)
            : await MultipartFile.fromFile(file.path!, filename: file.name),
      });

      // Using /files/upload endpoint
      await _dio.post('/files/upload', data: form);

      NotificationService().success("Document uploaded successfully");
      await fetchUserProfile(); // Refresh profile to see storage usage update
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 413) {
        NotificationService().error("File too large. Limit is 50MB.");
      } else {
        NotificationService().error(
          "Upload failed: ${e.response?.statusMessage}",
        );
      }
      return false;
    } catch (_) {
      NotificationService().error("Upload failed");
      return false;
    }
  }

  // ================= DEVICES =================
  Future<void> fetchDevices() async {
    final res = await _dio.get('/auth/devices');
    _devices = res.data ?? [];
    notifyListeners();
  }

  Future<bool> toggleDeviceBlock(String id) async {
    // Safety: Find the device
    final device = _devices.cast<Map<String, dynamic>>().firstWhere(
      (d) => d['device_id'] == id,
      orElse: () => <String, dynamic>{},
    );

    if (device.isEmpty) {
      NotificationService().error("Device not found");
      return false;
    }

    // Safety: Prevent self-blocking
    if (isCurrentDevice(device)) {
      NotificationService().warning("Cannot block current device");
      return false;
    }

    try {
      await _dio.post('/auth/devices/toggle-block', data: {'device_id': id});
      await fetchDevices();

      final wasBlocked = device['is_blocked'] ?? false;
      NotificationService().success(
        wasBlocked ? "Device unblocked" : "Device blocked",
      );
      return true;
    } catch (err) {
      NotificationService().error("Failed to toggle block status");
      return false;
    }
  }

  Future<void> toggleDeviceTrust(String id) async {
    await _dio.post('/auth/devices/toggle-trust', data: {'device_id': id});
    fetchDevices();
    fetchIPDSDashboard();
  }

  // ================= LOGS =================
  Future<void> fetchLogs() async {
    final res = await _dio.get('/logs/logs');
    _logs = res.data ?? [];
    notifyListeners();
  }

  void addLog(Map<String, dynamic> log) {
    _logs.insert(0, log);
    if (_logs.length > 50) _logs.removeLast();
    notifyListeners();
  }

  // ================= AUTH ACTIVITY =================
  Future<void> fetchAuthActivity() async {
    try {
      final res = await _dio.get('/logs/auth-activity');
      _authActivity = res.data ?? [];
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch auth activity: $e');
    }
  }

  void addAuthActivity(Map<String, dynamic> activity) {
    _authActivity.insert(0, activity);
    if (_authActivity.length > 50) _authActivity.removeLast();
    notifyListeners();
  }

  // ================= IPDS =================
  Future<void> fetchIPDSDashboard() async {
    final res = await _dio.get('/ipds/dashboard');
    _ipdsData = res.data;
    notifyListeners();
  }

  Future<void> fetchRisk() async {
    try {
      final res = await _dio.get('/ipds/risk');
      _riskData = res.data;
      notifyListeners();
    } catch (_) {}
  }

  /// Fetch user-specific IPDS activity (latest login, file upload, logout)
  Future<void> fetchUserActivity() async {
    try {
      final res = await _dio.get('/ipds/user-activity');
      _userActivity = res.data;
      notifyListeners();
      // Show security alerts as ephemeral notifications (snackbars)
      // FIX: Removed auto-popup for fetched alerts to prevent spam on refresh.
      // Users can see active alerts in the dashboard list.
    } catch (e) {
      debugPrint('Failed to fetch user activity: $e');
    }
  }

  // ================= SYSTEM RESET =================
  Future<void> resetSystem() async {
    try {
      await _dio.post('/ipds/reset');
      NotificationService().success("System reset successfully");
      // Refresh all data to reflect the clean state
      await fetchUserProfile();
      await fetchIPDSDashboard();
      await fetchRisk();
      await fetchUserActivity();
    } catch (e) {
      debugPrint('Reset system error: $e');
      NotificationService().error("Failed to reset system");
    }
  }

  // ================= ACCOUNT =================
  Future<void> logoutAll() async {
    try {
      await _dio.post('/auth/logout-all');
      await logout();
      NotificationService().success("Logged out from all devices");
    } catch (_) {
      NotificationService().error("Failed to logout from all devices");
    }
  }

  Future<bool> deleteAccount(String password) async {
    try {
      await _dio.delete('/auth/account', data: {'password': password});
      await logout();
      NotificationService().success("Account deleted");
      return true;
    } catch (e) {
      if (e is DioException) {
        NotificationService().error(
          e.response?.data['detail'] ?? "Failed to delete account",
        );
      } else {
        NotificationService().error("Failed to delete account");
      }
      return false;
    }
  }

  // ================= MFA (EMAIL-BASED OTP) =================
  Future<Map<String, dynamic>> enableMFA() async {
    try {
      final res = await _dio.post('/auth/mfa/enable');
      if (res.data['debug_otp'] != null) {
        debugPrint('==========================================');
        debugPrint('DEV OTP (Enable): ${res.data['debug_otp']}');
        debugPrint('==========================================');
      }

      return {
        'success': true,
        'message': res.data['message'],
        'email': res.data['email'],
        'expires_in_minutes': res.data['expires_in_minutes'],
        'debug_otp': res.data['debug_otp'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['detail'] ?? 'Failed to enable MFA',
      };
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred'};
    }
  }

  Future<Map<String, dynamic>> verifyMFA(String code) async {
    try {
      final res = await _dio.post(
        '/auth/mfa/verify',
        queryParameters: {'code': code},
      );
      return {'success': true, 'mfa_enabled': res.data['mfa_enabled'] ?? true};
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['detail'] ?? 'Invalid code',
      };
    } catch (e) {
      return {'success': false, 'error': 'Verification failed'};
    }
  }

  Future<Map<String, dynamic>> resendMFAOTP({
    String purpose = 'login',
    String? email,
  }) async {
    try {
      final targetEmail = email ?? _user?['email'];
      if (targetEmail == null) {
        return {'success': false, 'error': 'User email not found'};
      }

      final res = await _dio.post(
        '/auth/mfa/resend-otp',
        queryParameters: {'email': targetEmail, 'purpose': purpose},
      );
      if (res.data['debug_otp'] != null) {
        debugPrint('==========================================');
        debugPrint('DEV OTP (Resend): ${res.data['debug_otp']}');
        debugPrint('==========================================');
      }
      return {
        'success': true,
        'message': res.data['message'],
        'expires_in_minutes': res.data['expires_in_minutes'],
        'debug_otp': res.data['debug_otp'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['detail'] ?? 'Failed to resend code',
      };
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred'};
    }
  }

  Future<Map<String, dynamic>> sendLoginOTP(String email) async {
    try {
      final res = await _dio.post(
        '/auth/mfa/send-login-otp',
        queryParameters: {'email': email},
      );
      if (res.data['debug_otp'] != null) {
        debugPrint('==========================================');
        debugPrint('DEV OTP (Send Login): ${res.data['debug_otp']}');
        debugPrint('==========================================');
      }
      return {
        'success': true,
        'message': res.data['message'],
        'expires_in_minutes': res.data['expires_in_minutes'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['detail'] ?? 'Failed to send OTP',
      };
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred'};
    }
  }

  Future<Map<String, dynamic>> disableMFA(String password, String code) async {
    try {
      await _dio.post(
        '/auth/mfa/disable',
        data: {'password': password, 'code': code},
      );
      return {'success': true};
    } on DioException catch (e) {
      String errorMessage = 'Failed to disable MFA';
      if (e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['detail'] != null) {
          errorMessage = data['detail'];
        } else if (data is List) {
          // Handle FastAPI validation errors (List of dictionaries)
          errorMessage = data
              .map((e) => e['msg'] ?? 'Invalid input')
              .join(', ');
        }
      }
      return {'success': false, 'error': errorMessage};
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred'};
    }
  }

  Future<Map<String, dynamic>> requestDisableOTP() async {
    try {
      final res = await _dio.post('/auth/mfa/request-disable-otp');
      if (res.data['debug_otp'] != null) {
        debugPrint('==========================================');
        debugPrint('DEV OTP (Disable): ${res.data['debug_otp']}');
        debugPrint('==========================================');
      }
      return {
        'success': true,
        'message': res.data['message'],
        'expires_in_minutes': res.data['expires_in_minutes'],
        'debug_otp': res.data['debug_otp'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'error': e.response?.data['detail'] ?? 'Failed to request OTP',
      };
    } catch (e) {
      return {'success': false, 'error': 'An unexpected error occurred'};
    }
  }

  Future<Map<String, dynamic>> getMFAStatus() async {
    try {
      final res = await _dio.get('/auth/mfa/status');
      return {
        'success': true,
        'mfa_enabled': res.data['mfa_enabled'] ?? false,
        'mfa_enabled_at': res.data['mfa_enabled_at'],
      };
    } catch (e) {
      return {'success': false, 'mfa_enabled': false};
    }
  }

  Future<Map<String, dynamic>> verifyMFALogin(
    String email,
    String code, {
    String? deviceFingerprint,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _dio.post(
        '/auth/mfa/login-verify',
        queryParameters: {'email': email, 'code': code},
      );
      final token = res.data['access_token'];
      await _storage.write(key: 'access_token', value: token);

      if (deviceFingerprint != null) {
        try {
          await bindDevice(deviceFingerprint);
        } catch (e) {
          debugPrint('Failed to auto-bind device in MFA: $e');
        }
      }

      // Silent fetch to prevent premature redirect
      await fetchUserProfile(notify: false);
      connectWS();

      _isLoading = false;
      // Do NOT notifyListeners() here. Let the dialog pop first.
      return {'success': true};
    } on DioException catch (e) {
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'error': e.response?.data['detail'] ?? 'MFA verification failed',
      };
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'error': 'An unexpected error occurred'};
    }
  }

  // ================= LOGOUT =================
  /// Industry-standard logout flow:
  /// 1. Prevent recursive logout calls
  /// 2. Disconnect WebSocket early (stop receiving events)
  /// 3. Call backend to clean up session (ignore errors - backend may be unreachable)
  /// 4. Clear all local state regardless of backend response
  /// 5. Reset device controller
  ///
  /// This ensures logout ALWAYS succeeds locally even if:
  /// - Token is expired
  /// - Token is invalid
  /// - Backend is unreachable
  /// - Network is offline
  Future<void> logout() async {
    // Prevent recursive logout calls
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    debugPrint('[LOGOUT] Starting safe logout...');

    // 1. Disconnect WebSocket EARLY to stop receiving events
    //    This prevents force_logout events from triggering during logout
    disconnectWS();
    debugPrint('[LOGOUT] WebSocket disconnected');

    // 2. Call backend to log the logout event
    //    IMPORTANT: We ignore ALL errors - logout must never fail
    try {
      final deviceInfo = await _getDeviceInfo();
      await _dio.post(
        '/auth/logout',
        options: Options(
          headers: {
            'X-Device-Name': deviceInfo['name'],
            'X-Device-Fingerprint': _deviceFingerprint ?? '',
          },
          // Don't throw on 4xx/5xx - we handle it gracefully
          validateStatus: (status) => true,
        ),
      );
      debugPrint('[LOGOUT] Backend logout successful');
    } catch (e) {
      // Network error, timeout, etc. - that's OK, continue with local cleanup
      debugPrint('[LOGOUT] Backend logout failed (continuing anyway): $e');
    }

    // 3. Clear ALL local state
    await _storage.delete(key: 'access_token');
    _user = null;
    _devices = [];
    _logs = [];
    _authActivity = [];
    _ipdsData = null;
    _riskData = null;
    _userActivity = null;
    _deviceFingerprint = null;

    // 4. Reset DeviceController
    DeviceController.to.reset();

    // 5. Reset Biometrics (Prevent loop)
    BiometricService.reset();

    debugPrint('[LOGOUT] ✓ Logout complete');
    _isLoggingOut = false;
    notifyListeners(); // Ensure UI updates

    // 6. Safe Navigation
    if (Get.currentRoute != '/login') {
      Get.offAllNamed('/login', predicate: (route) => false);
    }
  }

  void postLogoutNotify() {
    notifyListeners();
  }

  Future<bool> removeDevice(String id) async {
    // Safety: Find the device being removed
    final deviceToRemove = _devices.cast<Map<String, dynamic>>().firstWhere(
      (d) => d['device_id'] == id,
      orElse: () => <String, dynamic>{},
    );

    if (deviceToRemove.isEmpty) {
      NotificationService().error("Device not found");
      return false;
    }

    // Safety: Prevent self-removal
    if (isCurrentDevice(deviceToRemove)) {
      NotificationService().warning(
        "Cannot remove current device. Use logout instead.",
      );
      return false;
    }

    try {
      final response = await _dio.post(
        '/auth/devices/remove',
        data: {'device_id': id},
      );

      // Backend should never return force_logout=true since we validated above
      // But keep this as a safety fallback
      if (response.data["force_logout"] == true) {
        debugPrint('[WARN] Unexpected force_logout for non-current device');
        await logout();
      }

      await fetchIPDSDashboard();
      await fetchDevices();
      NotificationService().success("Device removed successfully");
      return true;
    } catch (err) {
      NotificationService().error("Failed to remove device");
      return false;
    }
  }

  // ================= WEBSOCKET =================
  void connectWS() {
    WebSocketService.to.connect();

    // Cancel previous subscriptions if any
    _logSub?.cancel();
    _deviceSub?.cancel();
    _riskSub?.cancel();
    _alertSub?.cancel();
    _authActivitySub?.cancel();
    _forceLogoutSub?.cancel();

    _logSub = WebSocketService.to.logStream.listen((data) {
      addLog(data);
    });

    _deviceSub = WebSocketService.to.deviceStream.listen((data) {
      fetchDevices();
    });

    _riskSub = WebSocketService.to.riskStream.listen((data) {
      fetchIPDSDashboard();
    });

    _alertSub = WebSocketService.to.alertStream.listen((data) {
      // NOTE: In-app snackbars removed - NotificationController handles push notifications
      // This prevents duplicate notifications (one in-app + one push)
      // Push notifications will appear in system tray (yellow/orange)
      // Green snackbars are reserved for in-app success notifications only

      if (data['type'] == 'new_device_login') {
        fetchDevices(); // Refresh list to show new device
        fetchIPDSDashboard(); // Refresh logs to show login event
      } else {
        fetchIPDSDashboard();
      }
    });

    // Listen for auth activity (login/logout events)
    _authActivitySub = WebSocketService.to.authActivityStream.listen((data) {
      addAuthActivity(data);
    });

    // ============ FORCE LOGOUT EVENTS ============
    // ============ FORCE LOGOUT EVENTS ============
    // Listen for force_logout, device_blocked, device_removed, session_invalid
    _forceLogoutSub = WebSocketService.to.forceLogoutStream.listen((
      data,
    ) async {
      // Backend now sends flat data or data['data'] depending on event source
      // Normalize it
      final payload = data['data'] ?? data;
      final targetFingerprint = payload['device_fingerprint'];
      final eventType = payload['event_type'] ?? data['type'] ?? 'force_logout';
      final reason = payload['reason'] ?? '';
      final message = payload['message'] ?? 'You have been logged out.';
      final title = payload['title'] ?? '⚠️ Session Ended';

      debugPrint('[WS-Connect] Force Logout Event: $eventType');
      debugPrint('[WS-Connect] Reason: $reason');
      debugPrint('[WS-Connect] Target FP: $targetFingerprint');
      debugPrint('[WS-Connect] Current FP: $_deviceFingerprint');

      // CRITICAL: Password change logs out ALL devices (no specific fingerprint)
      // If reason is password_changed, process immediately without fingerprint check
      final isPasswordChangeLogout = reason == 'password_changed';

      // STRICT CHECK: match fingerprint if provided, OR password change (all devices)
      final shouldProcessLogout =
          isPasswordChangeLogout ||
          (targetFingerprint != null &&
              targetFingerprint == _deviceFingerprint);

      if (shouldProcessLogout) {
        debugPrint(
          'Processing logout (password_changed=$isPasswordChangeLogout, fingerprintMatch=${targetFingerprint == _deviceFingerprint})...',
        );

        // Show notification
        if (isPasswordChangeLogout) {
          NotificationService().warning(message, title: '🔐 Password Changed');
        } else {
          switch (eventType) {
            case 'device_blocked':
              NotificationService().error(message, title: title);
              break;
            case 'device_removed':
              NotificationService().warning(message, title: title);
              break;
            default:
              NotificationService().warning(message, title: title);
          }
        }

        // Perform logout
        debugPrint('Calling logout()...');
        await logout();
        debugPrint('Logout complete. Notifying listeners...');
        notifyListeners();
      } else {
        debugPrint(
          'Target ($targetFingerprint) does not match current ($_deviceFingerprint). Ignoring.',
        );

        // NEW: If another device was removed/blocked, refresh our device list
        if (eventType == 'device_removed' || eventType == 'device_blocked') {
          debugPrint('[WS] Refreshing device list after other device action');
          await fetchDevices();
        }
      }
    });

    // Listen for device blocked events - auto-logout if this device is blocked (legacy)
    _deviceBlockedSub?.cancel();
    _deviceBlockedSub = WebSocketService.to.deviceBlockedStream.listen((
      data,
    ) async {
      final blockedFingerprint = data['device_fingerprint'];
      debugPrint('Device blocked event received: $blockedFingerprint');

      // Check if the blocked device is THIS device
      if (_deviceFingerprint != null &&
          blockedFingerprint == _deviceFingerprint) {
        debugPrint('This device has been blocked! Logging out...');
        NotificationService().error(
          'This device has been blocked by another device. You have been logged out.',
          title: 'Device Blocked',
        );
        await logout();
        notifyListeners();
      }
    });

    // Start periodic device status check (fallback mechanism)
    _startDeviceStatusCheck();
  }

  void disconnectWS() {
    _logSub?.cancel();
    _deviceSub?.cancel();
    _riskSub?.cancel();
    _alertSub?.cancel();
    _authActivitySub?.cancel();
    _deviceStatusTimer?.cancel();
    _deviceBlockedSub?.cancel();
    _forceLogoutSub?.cancel();
    WebSocketService.to.disconnect();
  }

  bool _isCheckingDeviceStatus = false;

  /// Start periodic device status check (fallback if WebSocket fails)
  /// Uses recursive pattern for safety and backoff
  void _startDeviceStatusCheck() {
    _deviceStatusTimer?.cancel();
    _scheduleNextDeviceCheck(const Duration(minutes: 5));
  }

  void _scheduleNextDeviceCheck(Duration delay) {
    if (_deviceStatusTimer?.isActive ?? false) _deviceStatusTimer!.cancel();
    _deviceStatusTimer = Timer(delay, _performDeviceStatusCheck);
  }

  Future<void> _performDeviceStatusCheck() async {
    if (_isCheckingDeviceStatus) return;
    if (_user == null || _deviceFingerprint == null) return;

    _isCheckingDeviceStatus = true;

    try {
      debugPrint('[DeviceCheck] Validating device status and session...');
      await _dio.post(
        '/auth/devices/check-status',
        data: {'device_fingerprint': _deviceFingerprint},
      );
      debugPrint('[DeviceCheck] ✓ Device and session valid');

      // Success - schedule next check in 5 minutes
      _isCheckingDeviceStatus = false;
      _scheduleNextDeviceCheck(const Duration(minutes: 5));
    } on DioException catch (e) {
      _isCheckingDeviceStatus = false;

      if (e.response?.statusCode == 401) {
        debugPrint('[DeviceCheck] ❌ Session expired - logging out');
        NotificationService().warning('Session Expired');
        await logout();
        return; // Stop checking
      } else if (e.response?.statusCode == 403) {
        debugPrint('[DeviceCheck] ❌ Device removed/blocked - logging out');
        NotificationService().warning('Device Removed');
        await logout();
        return; // Stop checking
      }

      // Server error (500) or network error - Backoff
      debugPrint('[DeviceCheck] Server/Network error: $e');
      debugPrint('[DeviceCheck] Backing off for 10 minutes...');
      _scheduleNextDeviceCheck(const Duration(minutes: 10));
    } catch (e) {
      _isCheckingDeviceStatus = false;
      debugPrint('[DeviceCheck] Unexpected error: $e');
      _scheduleNextDeviceCheck(const Duration(minutes: 10));
    }
  }

  // Set device fingerprint for tracking (call after login)
  void setDeviceFingerprint(String fingerprint) {
    _deviceFingerprint = fingerprint;
  }
}

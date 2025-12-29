import 'dart:async';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  Dio? _dio;
  final _storage = const FlutterSecureStorage();

  factory ApiClient() => _instance;
  ApiClient._internal();

  /// Stream to notify UI about auth errors (unauthorized / blocked)
  final _authErrorController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get authErrorStream =>
      _authErrorController.stream;

  /// Flag to stop all requests when 401/403 is detected to prevent log spam
  static bool _isAuthFailureDetected = false;

  /// Reset auth failure flag (called after successful login)
  static void clearAuthFailure() {
    _isAuthFailureDetected = false;
    debugPrint('🛡️ API Auth Lockout RESET');
  }

  /// Safe getter for dio instance with initialization check
  Dio get dio {
    if (_dio == null) {
      throw StateError(
        'ApiClient not initialized. Call ApiClient().init() before making API calls.',
      );
    }
    return _dio!;
  }

  String get baseUrl => dio.options.baseUrl;

  /// ───────────── INIT ─────────────
  Future<void> init() async {
    // Env should be loaded by main.dart before calling init()

    // Platform-specific base URL
    String baseUrl = '';
    String env(String key) => dotenv.env[key] ?? '';

    if (kIsWeb) {
      baseUrl = env('BASE_URL_WEB');
    } else {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        baseUrl = androidInfo.isPhysicalDevice
            ? env('BASE_URL_ANDROID_PHYSICAL')
            : env('BASE_URL_ANDROID');
      } else if (Platform.isIOS) {
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        baseUrl = iosInfo.isPhysicalDevice
            ? env('BASE_URL_IOS_PHYSICAL')
            : env('BASE_URL_IOS');
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        baseUrl = env('BASE_URL_DESKTOP');
      }
    }

    if (baseUrl.isEmpty) baseUrl = env('BASE_URL_WEB');

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(
          seconds: 180,
        ), // Increased for AI operations
        receiveTimeout: const Duration(
          seconds: 180,
        ), // Increased for AI operations
        // CRITICAL: Allow 401 to be handled in onResponse instead of throwing immediately
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    debugPrint('🌍 API Base URL: $baseUrl');

    // Device info logic...
    // ... (Keep existing device info logic logic, simplified here for brevity if allowed, but I must keep it) ...
    // NOTE: Attempting to preserve device info logic using original variables.
    // To safe complexity, I will only replace the Interceptor part if possible,
    // but validateStatus is in the constructor. So I must replace the Constructor block.

    // ... (Retaining Device Info Logic Code is tricky with ReplaceFileContent if I don't paste it all back) ...
    // Ideally I would use multi-replace to target specific blocks.

    // Device info
    String deviceId = 'unknown';
    String deviceName = 'Unknown';
    String deviceType = 'unknown';

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;

        // CRITICAL FIX: Use persistent ID for Web instead of User Agent
        // User Agent changes with browser updates, causing "New Device" detection
        // and bypassing blocks.
        String? stickyId = await _storage.read(key: "unique_device_id");
        if (stickyId == null || stickyId.isEmpty) {
          // Generate simpler ID for web (uuid or timestamp)
          stickyId =
              'web_${DateTime.now().millisecondsSinceEpoch}_${webInfo.productSub ?? "x"}';
          await _storage.write(key: "unique_device_id", value: stickyId);
        }

        deviceId = stickyId;
        deviceName = webInfo.browserName.name;
        deviceType = 'web';
      } else if (Platform.isAndroid) {
        final a = await deviceInfo.androidInfo;
        String platformId = a.id;
        String? stickyId = await _storage.read(key: "unique_device_id");
        if (stickyId == null || stickyId.isEmpty) {
          stickyId = platformId;
          await _storage.write(key: "unique_device_id", value: stickyId);
        }
        deviceId = stickyId;
        deviceName = "${a.brand} ${a.model}";
        deviceType = "android";
      } else if (Platform.isIOS) {
        final i = await deviceInfo.iosInfo;
        deviceId = i.identifierForVendor ?? 'ios';
        deviceName = i.name;
        deviceType = 'ios';
      } else if (Platform.isWindows) {
        final w = await deviceInfo.windowsInfo;
        deviceId = w.deviceId;
        deviceName = w.computerName;
        deviceType = 'windows';
      } else if (Platform.isMacOS) {
        final m = await deviceInfo.macOsInfo;
        deviceId = m.systemGUID ?? 'mac';
        deviceName = m.computerName;
        deviceType = 'mac';
      } else if (Platform.isLinux) {
        deviceId = 'linux';
        deviceName = 'Linux PC';
        deviceType = 'linux';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
    }

    // Interceptors
    _dio!.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: "access_token");

          // Fast-Fail: If no token and path is protected, cancel immediately
          // Add public paths exclusions here
          final isPublic =
              options.path.contains('/login') ||
              options.path.contains('/register') ||
              options.path.contains('/biometric-login') ||
              options.path.contains('/forgot-password');

          // Debug: Show token status for every request
          if (token != null && token.isNotEmpty) {
            debugPrint(
              '✅ TOKEN FOUND for ${options.method} ${options.path} (${token.substring(0, 20)}...)',
            );
          } else {
            debugPrint(
              '❌ NO TOKEN for ${options.method} ${options.path} | Public: $isPublic',
            );
          }

          // Auth Lockout: If a failure was already detected, cancel immediately
          if (_isAuthFailureDetected && !isPublic) {
            debugPrint(
              '🛡️ LOCKOUT: Blocking redundant request to ${options.path}',
            );
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                error: "Auth failure already detected",
              ),
            );
          }

          if ((token == null || token.isEmpty) && !isPublic) {
            debugPrint(
              '🛑 BLOCKED REQUEST: No token for ${options.path}. Please login first.',
            );
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                error: "No authentication token. Please login first.",
              ),
            );
          }

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // CRITICAL: Generate or retrieve persistent device fingerprint
          String? deviceFingerprint = await _storage.read(
            key: "device_fingerprint",
          );
          if (deviceFingerprint == null || deviceFingerprint.isEmpty) {
            // Generate persistent fingerprint (once per device)
            deviceFingerprint =
                '${deviceId}_${DateTime.now().millisecondsSinceEpoch}';
            await _storage.write(
              key: "device_fingerprint",
              value: deviceFingerprint,
            );
          }

          options.headers['X-Device-ID'] = deviceId;
          options.headers['X-Device-Name'] = deviceName;
          options.headers['X-Device-Type'] = deviceType;
          options.headers['X-Device-Fingerprint'] = deviceFingerprint;
          options.headers['ngrok-skip-browser-warning'] = 'true';

          handler.next(options);
        },
        onResponse: (response, handler) async {
          // CRITICAL: Handle 401/403 here because validateStatus allows them
          if (response.statusCode == 401) {
            final isLogoutPath = response.requestOptions.path.contains(
              '/auth/logout',
            );
            // SKIP auth error for login/register paths - they show their own errors
            final isLoginPath =
                response.requestOptions.path.contains('/login') ||
                response.requestOptions.path.contains('/register') ||
                response.requestOptions.path.contains('/biometric-login') ||
                response.requestOptions.path.contains('/forgot-password') ||
                response.requestOptions.path.contains('/mfa/');

            if (!isLogoutPath && !isLoginPath) {
              debugPrint(
                '🚨 401 UNAUTHORIZED: ${response.requestOptions.path} - Triggering Logout',
              );

              // Set lockout flag to stop other concurrent requests
              _isAuthFailureDetected = true;

              // Clear token immediately to stop further requests
              await _storage.delete(key: 'access_token');

              // Notify AuthProvider to clean up and redirect
              _authErrorController.add({
                'type': 'unauthorized',
                'message': 'Session expired. Please login again.',
              });

              // REJECT the promise so Providers don't try to parse "success" data
              return handler.reject(
                DioException(
                  requestOptions: response.requestOptions,
                  response: response,
                  type: DioExceptionType
                      .cancel, // Treat as Cancelled to avoid "Error" UI
                  error: "Session expired",
                ),
              );
            }
          }

          if (response.statusCode == 403) {
            final detail = response.data['detail']?.toString() ?? '';
            final isVaultError = detail.contains('Vault');

            if (!isVaultError) {
              debugPrint('🚨 403 FORBIDDEN (Blocked): Triggering Lockout');
              _isAuthFailureDetected = true;
              _authErrorController.add({
                'type': 'blocked',
                'message': detail.isNotEmpty ? detail : 'Device blocked',
              });
            } else {
              debugPrint(
                '🛡️ 403 FORBIDDEN (Vault): Ignoring for global lockout',
              );
            }

            // Re-reject for both cases so callers handle the error
            return handler.reject(
              DioException(
                requestOptions: response.requestOptions,
                response: response,
                type: DioExceptionType.cancel,
                error: detail.isNotEmpty ? detail : "Access forbidden",
              ),
            );
          }

          handler.next(response);
        },
        onError: (e, handler) {
          // Standard network errors
          debugPrint('❌ NETWORK ERROR: ${e.message}');
          handler.next(e);
        },
      ),
    );
  }

  // ───────────── IPDS ADMIN METHODS ─────────────
  Future<List<Map<String, dynamic>>> fetchLiveMetrics() async {
    final res = await dio.get('/ipds/live');
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<void> adminResetSystem() async {
    await dio.post('/ipds/reset');
  }

  Future<List<Map<String, dynamic>>> fetchIPDSHistory() async {
    final res = await dio.get('/ipds/history');
    return List<Map<String, dynamic>>.from(res.data);
  }

  // ───────────── DOCUMENT ANALYSIS ─────────────
  Future<Map<String, dynamic>> analyzeFile(String fileId) async {
    final res = await dio.post('/files/$fileId/analyze');
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> fetchFileAnalysis(String fileId) async {
    final res = await dio.get('/files/$fileId/analysis');

    // Explicitly handle 404 since validateStatus allows it through
    if (res.statusCode == 404) {
      throw DioException(
        requestOptions: res.requestOptions,
        response: res,
        type: DioExceptionType.badResponse,
        error: "Analysis not found",
      );
    }

    return Map<String, dynamic>.from(res.data);
  }

  // ───────────── SUMMARIES ─────────────
  Future<Map<String, dynamic>> saveSummary(
    String fileId,
    String filename,
    Map<String, dynamic> summaryData,
  ) async {
    final res = await dio.post(
      '/summaries/save',
      data: {
        'document_id': fileId,
        'document_name': filename,
        'summary_data': summaryData,
      },
    );
    return Map<String, dynamic>.from(res.data);
  }

  Future<List<Map<String, dynamic>>> fetchSummaryHistory({
    String? documentId,
  }) async {
    final res = await dio.get(
      '/summaries/history',
      queryParameters: documentId != null ? {'document_id': documentId} : null,
    );
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<Map<String, dynamic>> resummarize(String documentId) async {
    final res = await dio.post('/summaries/resummarize/$documentId');
    return Map<String, dynamic>.from(res.data);
  }

  Future<Uint8List> exportSummaryPdf(String summaryId) async {
    final res = await dio.get(
      '/summaries/$summaryId/export-pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data as Uint8List;
  }

  Future<void> deleteSummary(String summaryId) async {
    await dio.delete('/summaries/$summaryId');
  }

  Future<Map<String, dynamic>> summarizeNoteContent(String content) async {
    final res = await dio.post(
      '/summaries/notes/summarize',
      data: {'content': content},
    );
    return Map<String, dynamic>.from(res.data);
  }

  // Helper to fetch images with headers (Ngrok/Auth)
  Future<Uint8List?> fetchImageBytes(String url) async {
    try {
      final fullUrl =
          url; // Dio baseUrl handles relative, but if absolute, Dio handles it too

      final Response<List<int>> response = await dio.get<List<int>>(
        fullUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data != null) {
        return Uint8List.fromList(response.data!);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching image bytes: $e');
      return null;
    }
  }
}

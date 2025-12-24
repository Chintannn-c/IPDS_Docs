import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Check if the current platform is a desktop OS (Windows, macOS, Linux)
bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// Service for handling biometric authentication (fingerprint/face unlock)
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  /// Flag to prevent auto-triggering biometrics after logout
  static bool isLogout = false;

  static void reset() {
    isLogout = true;
    debugPrint('BiometricService: Logout flag set. Autochecks disabled.');
  }

  static void enable() {
    isLogout = false;
    debugPrint('BiometricService: Logout flag cleared.');
  }

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if biometric authentication is available on this device
  Future<bool> isBiometricAvailable() async {
    // Prevent auto-trigger loop after logout
    if (isLogout) {
      debugPrint('BiometricService: Skipping check due to recent logout');
      return false;
    }

    // Biometrics not available on web
    if (kIsWeb) {
      debugPrint('BiometricService: Web platform - biometrics not available');
      return false;
    }

    // Biometrics not available on desktop platforms (Windows, macOS, Linux)
    // Use password login with email OTP for MFA instead
    if (isDesktopPlatform) {
      debugPrint(
        'BiometricService: Desktop platform - biometrics not available',
      );
      return false;
    }

    try {
      // Check availability with a timeout to prevent hanging on emulators
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics
          .timeout(const Duration(seconds: 3));
      final canAuthenticate = await _localAuth.isDeviceSupported().timeout(
        const Duration(seconds: 3),
      );

      debugPrint(
        'BiometricService: canCheckBiometrics=$canAuthenticateWithBiometrics, isDeviceSupported=$canAuthenticate',
      );

      return canAuthenticateWithBiometrics || canAuthenticate;
    } on TimeoutException {
      debugPrint('BiometricService: Check timed out (likely emulator issue)');
      return false;
    } on PlatformException catch (e) {
      debugPrint('BiometricService: Platform error checking availability: $e');
      return false;
    } catch (e) {
      debugPrint('BiometricService: Generic error checking availability: $e');
      return false;
    }
  }

  /// Get list of available biometric types (fingerprint, face, iris)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb || isDesktopPlatform) return [];

    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      debugPrint('BiometricService: Error getting available biometrics: $e');
      return [];
    }
  }

  /// Authenticate the user with biometrics
  /// Returns true if authentication succeeded, false otherwise
  Future<BiometricResult> authenticate({
    String reason = 'Verify your identity to continue',
  }) async {
    // Skip biometrics on web and desktop platforms
    if (kIsWeb || isDesktopPlatform) {
      return BiometricResult(
        success: true, // Skip biometric on web/desktop
        message: 'Biometrics not available on this platform',
        skipped: true,
      );
    }

    try {
      // Check availability first
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        debugPrint('BiometricService: Biometrics not available, skipping');
        return BiometricResult(
          success: true, // Allow login if biometrics not available
          message: 'Biometric authentication not available on this device',
          skipped: true,
        );
      }

      // Authenticate
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern as fallback
          useErrorDialogs: true,
        ),
      );

      if (authenticated) {
        debugPrint('BiometricService: Authentication successful');
        return BiometricResult(
          success: true,
          message: 'Authentication successful',
          skipped: false,
        );
      } else {
        debugPrint('BiometricService: Authentication failed');
        return BiometricResult(
          success: false,
          message: 'Biometric authentication failed',
          skipped: false,
        );
      }
    } on PlatformException catch (e) {
      debugPrint('BiometricService: Authentication error: ${e.message}');

      String message;
      switch (e.code) {
        case 'NotAvailable':
          message = 'Biometric authentication not available';
          return BiometricResult(
            success: true,
            message: message,
            skipped: true,
          );
        case 'NotEnrolled':
          message = 'No biometrics enrolled on this device';
          return BiometricResult(
            success: true,
            message: message,
            skipped: true,
          );
        case 'LockedOut':
          message = 'Too many failed attempts. Biometrics locked.';
          break;
        case 'PermanentlyLockedOut':
          message = 'Biometrics permanently locked. Use device password.';
          break;
        default:
          message = e.message ?? 'Biometric authentication error';
      }

      return BiometricResult(
        success: false,
        message: message,
        skipped: false,
        error: e,
      );
    }
  }

  /// Get a friendly name for the available biometric type
  Future<String> getBiometricTypeName() async {
    final types = await getAvailableBiometrics();

    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (types.contains(BiometricType.strong) ||
        types.contains(BiometricType.weak)) {
      return 'Biometric';
    }

    return 'Biometric';
  }
}

/// Result of a biometric authentication attempt
class BiometricResult {
  final bool success;
  final String message;
  final bool skipped; // True if biometric was skipped (not available)
  final PlatformException? error;

  BiometricResult({
    required this.success,
    required this.message,
    this.skipped = false,
    this.error,
  });
}

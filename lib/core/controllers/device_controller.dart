import 'package:flutter/foundation.dart';

class DeviceController {
  // Singleton instance
  static final DeviceController _instance = DeviceController._internal();
  static DeviceController get to => _instance;

  DeviceController._internal();

  final ValueNotifier<String?> _deviceFingerprint = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<bool> _isLoggedIn = ValueNotifier<bool>(false);

  String? get deviceFingerprint => _deviceFingerprint.value;
  bool get isLoggedIn => _isLoggedIn.value;

  ValueNotifier<String?> get deviceFingerprintNotifier => _deviceFingerprint;
  ValueNotifier<bool> get isLoggedInNotifier => _isLoggedIn;

  void setDeviceFingerprint(String fingerprint) {
    _deviceFingerprint.value = fingerprint;
    debugPrint('DeviceController: Fingerprint set to $fingerprint');
  }

  void setLoggedIn(bool value) {
    _isLoggedIn.value = value;
    debugPrint('DeviceController: LoggedIn set to $value');
  }

  void reset() {
    _deviceFingerprint.value = null;
    _isLoggedIn.value = false;
    debugPrint('DeviceController: Reset');
  }
}

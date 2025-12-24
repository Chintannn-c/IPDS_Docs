import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Service for generating unique device fingerprints
class DeviceFingerprintService {
  static final DeviceFingerprintService _instance =
      DeviceFingerprintService._internal();
  factory DeviceFingerprintService() => _instance;
  DeviceFingerprintService._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  String? _cachedFingerprint;
  Map<String, dynamic>? _cachedDeviceInfo;

  /// Get the device fingerprint (cached after first generation)
  Future<String> getDeviceFingerprint() async {
    if (_cachedFingerprint != null) {
      return _cachedFingerprint!;
    }

    final info = await getDeviceInfo();
    final fingerprintData = _generateFingerprintData(info);
    _cachedFingerprint = _hashData(fingerprintData);

    debugPrint(
      'DeviceFingerprint: Generated fingerprint: ${_cachedFingerprint!.substring(0, 16)}...',
    );
    return _cachedFingerprint!;
  }

  /// Get detailed device information
  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (_cachedDeviceInfo != null) {
      return _cachedDeviceInfo!;
    }

    Map<String, dynamic> info = {};

    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        info = {
          'platform': 'web',
          'browserName': webInfo.browserName.name,
          'userAgent': webInfo.userAgent ?? '',
          'vendor': webInfo.vendor ?? '',
          'language': webInfo.language ?? '',
          'hardwareConcurrency': webInfo.hardwareConcurrency.toString(),
          'maxTouchPoints': webInfo.maxTouchPoints.toString(),
        };
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        info = {
          'platform': 'android',
          'brand': androidInfo.brand,
          'device': androidInfo.device,
          'model': androidInfo.model,
          'product': androidInfo.product,
          'androidId': androidInfo.id,
          'manufacturer': androidInfo.manufacturer,
          'fingerprint': androidInfo.fingerprint,
          'hardware': androidInfo.hardware,
          'host': androidInfo.host,
          'sdkInt': androidInfo.version.sdkInt.toString(),
          'release': androidInfo.version.release,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        info = {
          'platform': 'ios',
          'name': iosInfo.name,
          'model': iosInfo.model,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'identifierForVendor': iosInfo.identifierForVendor ?? '',
          'localizedModel': iosInfo.localizedModel,
          'utsname': iosInfo.utsname.machine,
        };
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfo.windowsInfo;
        info = {
          'platform': 'windows',
          'computerName': windowsInfo.computerName,
          'numberOfCores': windowsInfo.numberOfCores.toString(),
          'systemMemoryInMegabytes': windowsInfo.systemMemoryInMegabytes
              .toString(),
          'productName': windowsInfo.productName,
          'deviceId': windowsInfo.deviceId,
        };
      } else if (Platform.isMacOS) {
        final macInfo = await _deviceInfo.macOsInfo;
        info = {
          'platform': 'macos',
          'computerName': macInfo.computerName,
          'model': macInfo.model,
          'arch': macInfo.arch,
          'osRelease': macInfo.osRelease,
          'systemGUID': macInfo.systemGUID ?? '',
        };
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        info = {
          'platform': 'linux',
          'name': linuxInfo.name,
          'version': linuxInfo.version ?? '',
          'machineId': linuxInfo.machineId ?? '',
          'prettyName': linuxInfo.prettyName,
        };
      }
    } catch (e) {
      debugPrint('DeviceFingerprint: Error getting device info: $e');
      info = {'platform': 'unknown', 'error': e.toString()};
    }

    _cachedDeviceInfo = info;
    return info;
  }

  /// Get a friendly device name
  Future<String> getDeviceName() async {
    final info = await getDeviceInfo();

    if (kIsWeb) {
      return 'Web Browser (${info['browserName']})';
    }

    switch (info['platform']) {
      case 'android':
        return '${info['brand']} ${info['model']}';
      case 'ios':
        return info['name'] ?? 'iPhone';
      case 'windows':
        return info['computerName'] ?? 'Windows PC';
      case 'macos':
        return info['computerName'] ?? 'Mac';
      case 'linux':
        return info['prettyName'] ?? 'Linux';
      default:
        return 'Unknown Device';
    }
  }

  /// Get device type
  Future<String> getDeviceType() async {
    if (kIsWeb) return 'web';

    final info = await getDeviceInfo();
    return info['platform'] ?? 'unknown';
  }

  /// Generate fingerprint data string from device info
  String _generateFingerprintData(Map<String, dynamic> info) {
    // Sort keys for consistency
    final sortedKeys = info.keys.toList()..sort();
    final buffer = StringBuffer();

    for (final key in sortedKeys) {
      buffer.write('$key:${info[key]}|');
    }

    return buffer.toString();
  }

  /// Hash the fingerprint data using SHA-256
  String _hashData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Clear cached fingerprint (useful for testing)
  void clearCache() {
    _cachedFingerprint = null;
    _cachedDeviceInfo = null;
  }
}

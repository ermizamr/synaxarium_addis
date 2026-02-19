import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

/// Provides a simple unique device identifier used for device-binding checks.
class DeviceService {
  final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  Future<String> getDeviceId() async {
    if (Platform.isAndroid) {
      final AndroidDeviceInfo info = await _plugin.androidInfo;
      // androidId was removed; use a stable-ish id/fingerprint fallback.
      return info.id ?? info.fingerprint ?? 'unknown-android';
    }
    if (Platform.isIOS) {
      final IosDeviceInfo info = await _plugin.iosInfo;
      return info.identifierForVendor ?? 'unknown-ios';
    }

    // Fallback for other platforms; use a stable-ish generated id per install.
    return const Uuid().v4();
  }
}

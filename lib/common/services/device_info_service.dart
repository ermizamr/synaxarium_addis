import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

class DeviceInfoService {
  DeviceInfoService();

  final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  // Returns a stable identifier per device; falls back to Firebase uid when hardware data is unavailable.
  Future<String> getDeviceId({required String fallback}) async {
    try {
      if (kIsWeb) {
        final info = await _plugin.webBrowserInfo;
        final agent = info.userAgent ?? 'unknown';
        return 'web-$agent';
      }
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        final id = info.id;
        if (id.isNotEmpty) {
          return 'android-$id';
        }
        final device = info.device;
        if (device.isNotEmpty) {
          return 'android-$device';
        }
        return 'android-$fallback';
      }
      if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        final id = info.identifierForVendor ?? fallback;
        return 'ios-$id';
      }
      if (Platform.isWindows) {
        final info = await _plugin.windowsInfo;
        final id = info.deviceId;
        if (id.isNotEmpty) {
          return 'windows-$id';
        }
        return 'windows-$fallback';
      }
      if (Platform.isMacOS) {
        final info = await _plugin.macOsInfo;
        final id = info.systemGUID ?? fallback;
        return 'mac-$id';
      }
      if (Platform.isLinux) {
        final info = await _plugin.linuxInfo;
        final id = info.machineId ?? fallback;
        return 'linux-$id';
      }
    } catch (_) {
      // Ignore and fall through to fallback.
    }
    return 'fallback-$fallback';
  }
}

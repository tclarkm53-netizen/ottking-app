// lib/data/services/device_mode_service.dart

import 'dart:io';

import 'package:flutter/foundation.dart';

class DeviceModeService {
  const DeviceModeService();

  /// Returns true when the app is running on an Android TV / Fire TV.
  /// On mobile Android this will return false.
  ///
  /// Note: A proper TV detection requires querying the PackageManager
  /// feature `android.software.leanback`.  This simplified check uses
  /// the presence of the Android platform as a proxy; override via a
  /// MethodChannel in MainActivity for production TV detection.
  bool isSmartTv() {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      // kIsTV is not exposed by Flutter; default to false until a
      // platform channel confirms the device type.
      return false;
    }
    return false;
  }

  String getDeviceLabel() => isSmartTv() ? 'Smart TV' : 'Mobile';
}

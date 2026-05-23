import 'dart:io';

import 'package:flutter/foundation.dart';

class DeviceModeService {
  const DeviceModeService();

  bool isSmartTv() {
    if (kIsWeb) {
      return false;
    }

    if (Platform.isAndroid) {
      return defaultTargetPlatform == TargetPlatform.android;
    }

    return false;
  }

  String getDeviceLabel() {
    return isSmartTv() ? 'Smart TV' : 'Mobile';
  }
}

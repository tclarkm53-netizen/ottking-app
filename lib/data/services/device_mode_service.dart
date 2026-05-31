// lib/data/services/device_mode_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'; 


class DeviceModeService {
  const DeviceModeService();

  static const _channel = MethodChannel('ottking/device');

  /// MethodChannel দিয়ে Android TV / Fire TV চেক।
  /// Platform channel না থাকলে false ফেরত দেয় (exception suppress করা হয়)।
  Future<bool> isAndroidTvAsync() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('isAndroidTV');
      return result ?? false;
    } on MissingPluginException {
      // MethodChannel এখনো implement হয়নি — fallback mode
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Synchronous fallback — screen metrics পাওয়ার আগে বা
  /// MethodChannel ছাড়া TV detect করার জন্য।
  /// ব্যবহার: PlayerScreen এর build() এ MediaQuery থেকে call।
  bool isSmartTvByScreen({
    required double screenWidth,
    required Orientation orientation,
  }) {
    // 960 logical pixels ও landscape = TV / tablet attached to TV
    return screenWidth >= 960 && orientation == Orientation.landscape;
  }

  String getDeviceLabel(bool isTV) => isTV ? 'Smart TV' : 'Mobile';
}

// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  static const String appName    = 'OTTKing';
  static const String appTagline = 'Premium Live TV — Every Screen';

  // API
  static const String apiBaseUrl    = 'https://verify-app.alwaysdata.net/api';
  static const String apiKeyId      = 'ottking-mobile';
  static const String hmacSecret    = 'ottking-hmac-secret-2026';
  static const String encryptionKey = 'ottking_secure_32byte_key_2026AB';

  // Layout
  static const double tvBreakpoint = 800.0;

  // Durations
  static const Duration splashDuration   = Duration(seconds: 3);
  static const Duration toastDuration    = Duration(seconds: 3);
  static const Duration numInputDelay    = Duration(milliseconds: 1500);
  static const Duration controlsTimeout  = Duration(seconds: 4);
  static const Duration playerTimeout    = Duration(seconds: 20);
  static const int      maxRetry         = 3;

  // Fallback stream (for demo / offline)
  static const String fallbackStream =
      'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8';
}

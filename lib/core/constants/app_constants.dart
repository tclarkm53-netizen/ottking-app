// lib/core/constants/app_constants.dart

class AppConstants {
  const AppConstants._();

  static const String appName = 'OTTKing';
  static const String appTagline = 'Secure Live TV for every screen';

  // API endpoints
  static const String defaultApiBaseUrl = 'https://verify-app.alwaysdata.net/api2';
  static const String localAndroidApiBaseUrl = 'https://verify-app.alwaysdata.net/api2';
  static const String localDesktopApiBaseUrl = 'https://verify-app.alwaysdata.net/api2';

  // Security — in production, load these from environment / secure vault
  static const String apiKeyId = 'ottking-mobile';
  static const String hmacSecret = 'ottking-hmac-secret-2026';
  static const String encryptionKey = 'ottking_secure_32byte_key_2026AB'; // must be 32 chars

  // Player fallback
  static const String fallbackStreamUrl =
      'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8';

  // Misc
  static const Duration splashDuration = Duration(seconds: 3);
  static const Duration toastDuration = Duration(seconds: 3);
  static const int requestTimestampToleranceSeconds = 300;
}

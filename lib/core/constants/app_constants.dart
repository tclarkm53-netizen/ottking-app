// lib/core/constants/app_constants.dart

class AppConstants {
  const AppConstants._();

  static const String appName = 'OTTKing';
  static const String appTagline = 'Secure Live TV for every screen';

  // API endpoints
  static const String defaultApiBaseUrl = 'https://verify-app.alwaysdata.net/apps/api';
  static const String localAndroidApiBaseUrl = 'https://verify-app.alwaysdata.net/apps/api';
  static const String localDesktopApiBaseUrl = 'https://verify-app.alwaysdata.net/apps/api';

  // Security — in production, load these from environment / secure vault
  static const String apiKeyId = 'ottking_key_v1_secret_id';
  static const String hmacSecret = 'hmac_secret_key_for_version_1_apps';
  static const String encryptionKey = '12345678901234567890123456789012'; // must be 32 chars

  // Player fallback
  static const String fallbackStreamUrl =
      'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8';

  // Misc
  static const Duration splashDuration = Duration(seconds: 3);
  static const Duration toastDuration = Duration(seconds: 3);
  static const int requestTimestampToleranceSeconds = 300;
}

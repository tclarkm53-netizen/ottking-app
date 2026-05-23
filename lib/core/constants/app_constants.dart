class AppConstants {
  const AppConstants._();

  static const String appName = 'OTTKing';
  static const String appTagline = 'Secure Live TV for every screen';
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://verify-app.alwaysdata.net/api',
  );
  static const String apiKeyId = 'ottking-mobile';
  static const String hmacSecret = String.fromEnvironment(
    'HMAC_SECRET_KEY',
    defaultValue: 'ottking-hmac-secret-2026',
  );
  static const String encryptionKey = String.fromEnvironment(
    'ENCRYPTION_KEY',
    defaultValue: 'ottking_secure_32byte_key_2026AB',
  );
  static const String defaultChannelId = 'default-live-channel';
  static const Duration splashDuration = Duration(seconds: 3);
}

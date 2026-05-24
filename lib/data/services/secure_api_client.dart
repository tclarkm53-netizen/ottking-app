import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import 'encryption_service.dart';
import 'secure_storage_service.dart';

class SecureApiClient {
  SecureApiClient({
    required this.encryptionService,
    required this.secureStorage,
    String? baseUrl,
  }) : _baseUrl = baseUrl ?? _defaultBaseUrl();

  final EncryptionService encryptionService;
  final SecureStorageService secureStorage;
  final String _baseUrl;

  static String _defaultBaseUrl() {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return AppConstants.apiBaseUrl;
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> payload) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final body = jsonEncode(payload);
    final encryptedBody = encryptionService.encrypt(body);
    final signaturePayload = '$timestamp|$endpoint|$encryptedBody';
    final signature = encryptionService.sign(signaturePayload);

    final baseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final response = await http.post(
      Uri.parse('$baseUrl/$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': AppConstants.apiKeyId,
        'x-timestamp': timestamp,
        'x-signature': signature,
      },
      body: jsonEncode({
        'encrypted_payload': encryptedBody,
      }),
    );

    if (response.statusCode != 200) {
      String errorDetails = response.body;
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic> && parsed['error'] is String) {
          errorDetails = parsed['error'] as String;
        }
      } catch (_) {
        // keep raw body when JSON parsing fails
      }
      throw Exception('Secure API request failed: ${response.statusCode} - $errorDetails');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final encryptedResponse = decoded['encrypted_payload'] as String;
    final signedResponse = decoded['signature'] as String;
    final decrypted = encryptionService.decrypt(encryptedResponse);

    if (!encryptionService.verify(decrypted, signedResponse)) {
      throw Exception('Signature verification failed for response');
    }

    return jsonDecode(decrypted) as Map<String, dynamic>;
  }
}

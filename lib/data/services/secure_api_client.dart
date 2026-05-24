import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/app_constants.dart';
import 'encryption_service.dart';
import 'secure_storage_service.dart';

class SecureApiClient {
  SecureApiClient({
    required this.encryptionService,
    required this.secureStorage,
    String? baseUrl,
  }) : _baseUrl = baseUrl ?? AppConstants.defaultApiBaseUrl;

  final EncryptionService encryptionService;
  final SecureStorageService secureStorage;
  final String _baseUrl;

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> payload) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final body = jsonEncode(payload);
    final encryptedBody = encryptionService.encrypt(body);
    final signaturePayload = '$timestamp|$endpoint|$encryptedBody';
    final signature = encryptionService.sign(signaturePayload);

    final baseUrl = _baseUrl.endsWith('/') ? _baseUrl.substring(0, _baseUrl.length - 1) : _baseUrl;
    final uri = Uri.parse('$baseUrl/$endpoint');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': AppConstants.apiKeyId,
      'x-timestamp': timestamp,
      'x-signature': signature,
    };

    final authToken = await secureStorage.readAuthToken();
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    late final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'encrypted_payload': encryptedBody,
        }),
      );
    } on SocketException catch (error) {
      throw Exception('Network error connecting to ${uri.host}: ${error.message}');
    }

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

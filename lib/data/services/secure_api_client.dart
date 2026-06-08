// lib/data/services/secure_api_client.dart

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
  }) : _baseUrl = _normalise(baseUrl ?? AppConstants.defaultApiBaseUrl);

  final EncryptionService encryptionService;
  final SecureStorageService secureStorage;
  final String _baseUrl;

  static String _normalise(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  /// POSTs an AES-GCM–encrypted, HMAC-signed request to [endpoint].
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> payload,
  ) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final body = jsonEncode(payload);
    final encryptedBody = encryptionService.encrypt(body);
    final signaturePayload = '$timestamp|$endpoint|$encryptedBody';
    final signature = encryptionService.sign(signaturePayload);

    final uri = Uri.parse('$_baseUrl/$endpoint');

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

    final http.Response response;
    try {
      response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'encrypted_payload': encryptedBody}),
      );
    } on SocketException catch (e) {
      throw Exception('Network error connecting to ${uri.host}: ${e.message}');
    }

    if (response.statusCode != 200) {
      String detail = response.body;
      try {
        final parsed = jsonDecode(response.body);
        if (parsed is Map<String, dynamic> && parsed['error'] is String) {
          detail = parsed['error'] as String;
        }
      } catch (_) {}
      throw Exception('API error ${response.statusCode}: $detail');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final encryptedResponse = decoded['encrypted_payload'] as String;
    final signedResponse = decoded['signature'] as String;
    final decrypted = encryptionService.decrypt(encryptedResponse);

    if (!encryptionService.verify(decrypted, signedResponse)) {
      throw Exception('Response signature verification failed');
    }

    return jsonDecode(decrypted) as Map<String, dynamic>;
  }
}

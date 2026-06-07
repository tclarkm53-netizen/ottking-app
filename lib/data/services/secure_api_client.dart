// lib/data/services/secure_api_client.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import 'encryption_service.dart';
import 'secure_storage_service.dart';

class SecureApiClient {
  SecureApiClient({
    required this.enc,
    required this.store,
    String? baseUrl,
  }) : _base = _trim(baseUrl ?? AppConstants.apiBaseUrl);

  final EncryptionService    enc;
  final SecureStorageService store;
  final String               _base;

  static String _trim(String u) => u.endsWith('/') ? u.substring(0, u.length - 1) : u;

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    final ts     = DateTime.now().toUtc().toIso8601String();
    final raw    = jsonEncode(body);
    final enc_   = enc.encrypt(raw);
    final sig    = enc.sign('$ts|$endpoint|$enc_');
    final uri    = Uri.parse('$_base/$endpoint');
    final token  = await store.readToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key':   AppConstants.apiKeyId,
      'x-timestamp': ts,
      'x-signature': sig,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    http.Response res;
    try {
      res = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({'encrypted_payload': enc_}),
      );
    } on SocketException catch (e) {
      throw Exception('Network error: ${e.message}');
    }

    if (res.statusCode != 200) {
      String detail = res.body;
      try {
        final p = jsonDecode(res.body) as Map<String, dynamic>;
        if (p['error'] is String) detail = p['error'] as String;
      } catch (_) {}
      throw Exception('HTTP ${res.statusCode}: $detail');
    }

    final resp    = jsonDecode(res.body) as Map<String, dynamic>;
    final encResp = resp['encrypted_payload'] as String;
    final sigResp = resp['signature']         as String;
    final decrypted = enc.decrypt(encResp);
    if (!enc.verify(decrypted, sigResp)) throw Exception('Signature mismatch');
    return jsonDecode(decrypted) as Map<String, dynamic>;
  }
}

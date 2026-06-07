// lib/data/services/encryption_service.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import '../../core/constants/app_constants.dart';

class EncryptionService {
  EncryptionService({String? key})
      : _key = Key.fromUtf8(key ?? AppConstants.encryptionKey);

  final Key _key;

  String encrypt(String plain) {
    final iv        = IV.fromSecureRandom(12);
    final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(plain, iv: iv);
    return '${base64Encode(iv.bytes)}.${encrypted.base64}';
  }

  String decrypt(String payload) {
    final parts = payload.split('.');
    if (parts.length != 2) throw const FormatException('Bad payload');
    final iv        = IV(base64Decode(parts[0]));
    final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
    return encrypter.decrypt(Encrypted.fromBase64(parts[1]), iv: iv);
  }

  String sign(String data, {String? secret}) {
    final k = utf8.encode(secret ?? AppConstants.hmacSecret);
    final b = utf8.encode(data);
    return Hmac(sha256, k).convert(b).toString();
  }

  bool verify(String data, String sig) => sign(data) == sig;
}

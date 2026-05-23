import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

import '../../core/constants/app_constants.dart';

class EncryptionService {
  EncryptionService({String? secretKey})
      : _key = Key.fromUtf8(secretKey ?? AppConstants.encryptionKey),
        _ivLength = 16;

  final Key _key;
  final int _ivLength;

  String encrypt(String plainText) {
    final iv = IV.fromSecureRandom(_ivLength);
    final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${base64Encode(iv.bytes)}.${encrypted.base64}';
  }

  String decrypt(String payload) {
    final parts = payload.split('.');
    if (parts.length != 2) {
      throw const FormatException('Encrypted payload format is invalid');
    }

    final iv = IV(base64Decode(parts.first));
    final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
    final encrypted = Encrypted.fromBase64(parts.last);
    return encrypter.decrypt(encrypted, iv: iv);
  }

  String sign(String payload, {String? secret}) {
    final key = utf8.encode(secret ?? AppConstants.hmacSecret);
    final bytes = utf8.encode(payload);
    return Hmac(sha256, key).convert(bytes).toString();
  }

  bool verify(String payload, String signature, {String? secret}) {
    return sign(payload, secret: secret) == signature;
  }
}

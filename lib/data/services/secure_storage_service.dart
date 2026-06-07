// lib/data/services/secure_storage_service.dart
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class SecureStorageService {
  const SecureStorageService([FlutterSecureStorage? s])
      : _s = s ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  Future<void>    saveToken(String t)   => _s.write(key: 'token', value: t);
  Future<String?> readToken()           => _s.read(key: 'token');
  Future<bool>    hasSession() async    => (await readToken())?.isNotEmpty == true;

  Future<void> saveProfile(UserProfile p) =>
      _s.write(key: 'profile', value: jsonEncode(p.toJson()));

  Future<UserProfile?> readProfile() async {
    final r = await _s.read(key: 'profile');
    if (r == null || r.isEmpty) return null;
    return UserProfile.fromJson(jsonDecode(r) as Map<String, dynamic>);
  }

  Future<void> clearAll() async {
    await _s.delete(key: 'token');
    await _s.delete(key: 'profile');
  }
}

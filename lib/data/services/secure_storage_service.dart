import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/models/channel_model.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<void> saveUserProfile(UserProfileModel profile) async {
    await _storage.write(key: 'user_profile', value: jsonEncode(profile.toJson()));
  }

  Future<void> saveAuthToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<bool> hasUserSession() async {
    final token = await _storage.read(key: 'auth_token');
    return token != null && token.isNotEmpty;
  }

  Future<String?> readAuthToken() async {
    return _storage.read(key: 'auth_token');
  }

  Future<UserProfileModel?> readUserProfile() async {
    final raw = await _storage.read(key: 'user_profile');
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final map = jsonDecode(raw) as Map<String, dynamic>;
    return UserProfileModel.fromJson(map);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_profile');
  }
}

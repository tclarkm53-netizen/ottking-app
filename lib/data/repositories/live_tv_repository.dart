// lib/data/repositories/live_tv_repository.dart

import '../models/channel_model.dart';
import '../services/secure_api_client.dart';

class LiveTvRepository {
  const LiveTvRepository({required this.apiClient});

  final SecureApiClient apiClient;

  Future<ChannelCatalogModel> fetchCatalog() async {
  final profile = await secureStorage.readUserProfile();

  final Map<String, dynamic> payload = {
      'locale': 'en_US',
      'platform': 'Ottkibg-apps',
    };
    
    final data = await apiClient.post('catalog',payload;
    return ChannelCatalogModel.fromJson(data);
  }

  Future<Map<String, dynamic>> authenticate(
    String email,
    String password,
  ) async {
    return apiClient.post('auth/login', {
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
  ) async {
    return apiClient.post('auth/register', {
      'email': email,
      'password': password,
    });
  }
}

// lib/data/repositories/live_tv_repository.dart
import '../models/models.dart';
import '../services/secure_api_client.dart';

class LiveTvRepository {
  const LiveTvRepository(this._api);
  final SecureApiClient _api;

  Future<CatalogModel> fetchCatalog() async {
    final d = await _api.post('catalog', {'platform': 'flutter', 'locale': 'en'});
    return CatalogModel.fromJson(d);
  }

  Future<Map<String, dynamic>> login(String email, String password) =>
      _api.post('auth/login', {'email': email, 'password': password});

  Future<Map<String, dynamic>> register(String email, String password) =>
      _api.post('auth/register', {'email': email, 'password': password});
}

// lib/data/repositories/live_tv_repository.dart

import '../models/channel_model.dart';
import '../services/secure_api_client.dart';
import '../services/secure_storage_service.dart'; // ফিক্স ১: স্টোরেজ সার্ভিস ইমপোর্ট করা হলো

class LiveTvRepository {
  const LiveTvRepository({
    required this.apiClient,
    required this.secureStorage, // ফিক্স ২: কনস্ট্রাক্টরে যুক্ত করা হলো
  });

  final SecureApiClient apiClient;
  final SecureStorageService secureStorage; // ফিক্স ৩: ফাইনাল ভেরিয়েবল ডিক্লেয়ার করা হলো

  Future<ChannelCatalogModel> fetchCatalog() async {
    final profile = await secureStorage.readUserProfile();

    final Map<String, dynamic> payload = {
      'locale': 'en_US',
      'platform': 'Ottkibg-apps',
    };
    
    // ফিক্স ৪: প্রোফাইল নাল না হলে ইমেইলটি পে-লোডে যোগ করা হলো
    if (profile != null && profile.email.isNotEmpty) {
      payload['email'] = profile.email;
    }
    
    // ফিক্স ৫: ব্র্যাকেটের ভুলটি (Syntax Error) ঠিক করা হলো
    final data = await apiClient.post('catalog', payload);
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

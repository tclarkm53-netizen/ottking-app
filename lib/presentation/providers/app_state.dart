import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/channel_model.dart';
import '../../data/repositories/live_tv_repository.dart';
import '../../data/services/device_mode_service.dart';
import '../../data/services/secure_storage_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.repository,
    required this.prefs,
    required this.secureStorage,
    required this.deviceModeService,
  });

  final LiveTvRepository repository;
  final SharedPreferences prefs;
  final SecureStorageService secureStorage;
  final DeviceModeService deviceModeService;

  bool isLoading = true;
  bool isSmartTv = false;
  bool bootToPlayer = false;
  ThemeMode themeMode = ThemeMode.dark;
  String errorMessage = '';

  List<ChannelModel> channels = [];
  List<CategoryModel> categories = [];
  List<BannerModel> banners = [];
  List<SubscriptionPlanModel> plans = [];

  int currentChannelIndex = 0;
  bool showToast = false;
  String toastMessage = '';
  UserProfileModel? userProfile;
  bool isAuthenticated = false;
  bool showAuthDialog = false;

  Future<void> bootstrap() async {
    isSmartTv = deviceModeService.isSmartTv();
    themeMode = prefs.getString('themeMode') == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;
    bootToPlayer = prefs.getBool('bootToPlayer') ?? false;

    isAuthenticated = await secureStorage.hasUserSession();
    userProfile = await secureStorage.readUserProfile();

    await loadCatalog();
    isLoading = false;
    notifyListeners();
  }

  Future<void> loadCatalog() async {
    try {
      final catalog = await repository.fetchCatalog();
      channels = catalog.channels;
      categories = catalog.categories;
      banners = catalog.banners;
      plans = catalog.plans;
      if (channels.isNotEmpty && currentChannelIndex >= channels.length) {
        currentChannelIndex = 0;
      }
      errorMessage = '';
    } catch (error) {
      channels = [];
      categories = [];
      banners = [];
      plans = [];
      errorMessage = error.toString();
    }
    notifyListeners();
  }

  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    prefs.setString('themeMode', themeMode == ThemeMode.light ? 'light' : 'dark');
    notifyListeners();
  }

  Future<void> setBootToPlayer(bool enabled) async {
    bootToPlayer = enabled;
    await prefs.setBool('bootToPlayer', enabled);
    notifyListeners();
  }

  void toggleAuthDialog() {
    showAuthDialog = !showAuthDialog;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    errorMessage = '';
    notifyListeners();

    try {
      final response = await repository.authenticate(email, password);
      final token = response['token'] as String? ?? 'demo-token';
      final profile = UserProfileModel.fromJson(
        {
          'email': response['email'] as String? ?? email,
          'plan': response['plan'] as String? ?? 'Premium',
        },
      );
      await secureStorage.saveAuthToken(token);
      await secureStorage.saveUserProfile(profile);
      userProfile = profile;
      isAuthenticated = true;
      errorMessage = '';
    } catch (error) {
      errorMessage = error.toString();
    }
    notifyListeners();
  }

  Future<void> register(String email, String password) async {
    errorMessage = '';
    notifyListeners();

    try {
      final response = await repository.register(email, password);
      final token = response['token'] as String? ?? 'demo-token';
      final profile = UserProfileModel.fromJson(
        {
          'email': response['email'] as String? ?? email,
          'plan': response['plan'] as String? ?? 'Premium',
        },
      );
      await secureStorage.saveAuthToken(token);
      await secureStorage.saveUserProfile(profile);
      userProfile = profile;
      isAuthenticated = true;
      errorMessage = '';
    } catch (error) {
      errorMessage = error.toString();
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await secureStorage.clearSession();
    isAuthenticated = false;
    userProfile = null;
    notifyListeners();
  }

  void switchChannel(int direction) {
    if (channels.isEmpty) {
      return;
    }

    currentChannelIndex = (currentChannelIndex + direction) % channels.length;
    if (currentChannelIndex < 0) {
      currentChannelIndex = channels.length - 1;
    }

    toastMessage = 'Now playing ${channels[currentChannelIndex].name}';
    showToast = true;
    notifyListeners();

    Timer(const Duration(seconds: 3), () {
      showToast = false;
      notifyListeners();
    });
  }

  bool shouldBootToPlayer() {
    return isSmartTv && bootToPlayer && channels.isNotEmpty;
  }

  ChannelModel get currentChannel => channels.isEmpty
      ? ChannelModel(
          id: 'fallback',
          name: 'Live Preview',
          category: 'Preview',
          streamUrl:
              'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
          logoUrl: '',
          description: 'Secure preview channel',
          quality: 'HD',
        )
      : channels[currentChannelIndex];

  String get currentChannelName => currentChannel.name;
}

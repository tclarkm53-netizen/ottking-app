// lib/presentation/providers/app_state.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
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

  // ── State ─────────────────────────────────────────────────────────────────

  bool isLoading = true;
  bool isSmartTv = false;
  bool bootToPlayer = false;
  ThemeMode themeMode = ThemeMode.dark;
  String errorMessage = '';

  List<ChannelModel> channels = [];
  List<CategoryModel> categories = [];
  List<BannerModel> banners = [];
  List<SubscriptionPlanModel> plans = [];

  int _currentChannelIndex = 0;
  int get currentChannelIndex => _currentChannelIndex;

  /// Directly sets the active channel index (used by HomeScreen grid tap).
  set currentChannelIndex(int value) {
    if (channels.isEmpty) return;
    _currentChannelIndex = value.clamp(0, channels.length - 1);
    notifyListeners();
  }

  bool showToast = false;
  String toastMessage = '';

  UserProfileModel? userProfile;
  bool isAuthenticated = false;

  Timer? _toastTimer;

  // ── Bootstrap ─────────────────────────────────────────────────────────────

  Future<void> bootstrap() async {
    // থিম এবং বুট সেটিংস লোড
    themeMode = prefs.getString('themeMode') == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;
    bootToPlayer = prefs.getBool('bootToPlayer') ?? false;

    // ইউজার সেশন চেক
    isAuthenticated = await secureStorage.hasUserSession();
    userProfile = await secureStorage.readUserProfile();

    // ক্যাটালগ ডাটা লোড
    await loadCatalog();
    isLoading = false;
    notifyListeners();
  }

  // ── Smart TV Mode Setup ──
  Future<void> updateDeviceMode(BuildContext context) async {
    final bool detectedTv = await deviceModeService.isSmartTv(context);
    if (isSmartTv != detectedTv) {
      isSmartTv = detectedTv;
      notifyListeners();
    }
  }

  // ── Catalog ───────────────────────────────────────────────────────────────

  Future<void> loadCatalog() async {
    try {
      final catalog = await repository.fetchCatalog();
      channels = catalog.channels;
      categories = catalog.categories;
      banners = catalog.banners;
      plans = catalog.plans;
      if (_currentChannelIndex >= channels.length) {
        _currentChannelIndex = 0;
      }
      errorMessage = '';
    } catch (e) {
      channels = [];
      categories = [];
      banners = [];
      plans = [];
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  // ── Theme ─────────────────────────────────────────────────────────────────

  void toggleTheme() {
    themeMode =
        themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    prefs.setString(
      'themeMode',
      themeMode == ThemeMode.light ? 'light' : 'dark',
    );
    notifyListeners();
  }

  // ── Smart TV boot & Player Screen compatibility ───────────────────────────

  Future<void> setBootToPlayer(bool enabled) async {
    bootToPlayer = enabled;
    await prefs.setBool('bootToPlayer', enabled);
    notifyListeners();
  }

  // Player Screen-এ ব্যবহৃত গেটার ম্যাপিং
  bool get isPlayerBootEnabled => bootToPlayer;

  // Player Screen-এর সেটিংস ডায়ালগ থেকে কল করা টগল ফাংশন
  void togglePlayerBoot() {
    setBootToPlayer(!bootToPlayer);
  }

  bool shouldBootToPlayer() =>
      isSmartTv && bootToPlayer && channels.isNotEmpty;

  // ── Auth ──────────────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    errorMessage = '';
    notifyListeners();
    try {
      final res = await repository.authenticate(email, password);
      await _handleAuthResponse(res, email);
      
      // লগইন সফল হওয়ার পর তৎক্ষণাৎ নতুন প্রিমিয়াম ক্যাটালগ লোড করা হলো
      await loadCatalog(); 
    } catch (e) {
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> register(String email, String password) async {
    errorMessage = '';
    notifyListeners();
    try {
      final res = await repository.register(email, password);
      await _handleAuthResponse(res, email);
      
      // রেজিস্ট্রেশন সফল হওয়ার পর তৎক্ষণাৎ নতুন ক্যাটালগ লোড করা হলো
      await loadCatalog();
    } catch (e) {
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> _handleAuthResponse(
    Map<String, dynamic> res,
    String fallbackEmail,
  ) async {
    final token = res['token'] as String? ?? 'demo-token';
    final profile = UserProfileModel(
      email: res['email'] as String? ?? fallbackEmail,
      plan: res['plan'] as String? ?? 'Premium',
    );
    await secureStorage.saveAuthToken(token);
    await secureStorage.saveUserProfile(profile);
    userProfile = profile;
    isAuthenticated = true;
    errorMessage = '';
  }

  Future<void> logout() async {
    await secureStorage.clearSession();
    isAuthenticated = false;
    userProfile = null;
    
    // লগআউট করার পর প্রিমিয়াম চ্যানেলগুলো সরিয়ে আবার নরমাল ফ্রি ক্যাটালগ লোড করা হলো
    _currentChannelIndex = 0;
    await loadCatalog(); 
    
    notifyListeners();
  }

  // ── Channel switching ─────────────────────────────────────────────────────

  void switchChannel(int direction) {
    if (channels.isEmpty) return;

    _currentChannelIndex =
        (_currentChannelIndex + direction) % channels.length;
    if (_currentChannelIndex < 0) {
      _currentChannelIndex = channels.length - 1;
    }

    _showChannelToast(channels[_currentChannelIndex].name);
  }

  void _showChannelToast(String channelName) {
    toastMessage = 'Now playing $channelName';
    showToast = true;
    notifyListeners();

    _toastTimer?.cancel();
    _toastTimer = Timer(AppConstants.toastDuration, () {
      showToast = false;
      notifyListeners();
    });
  }

  // ── নম্বর দিয়ে সরাসরি চ্যানেল সিলেক্ট করার মেথড ─────────────────────────
  void selectChannelByIndex(int index) {
    if (channels.isEmpty) return;
    
    _currentChannelIndex = index.clamp(0, channels.length - 1);
    _showChannelToast(channels[_currentChannelIndex].name);
  }
  
  // ── Current channel ───────────────────────────────────────────────────────

  static final ChannelModel _fallbackChannel = ChannelModel(
    id: 'fallback',
    name: 'Live Preview',
    category: 'Preview',
    streamUrl: AppConstants.fallbackStreamUrl,
    logoUrl: '',
    description: 'Secure preview channel',
    quality: 'HD',
    isPremium: 0, 
  );

  ChannelModel get currentChannel =>
      channels.isEmpty ? _fallbackChannel : channels[_currentChannelIndex];

  String get currentChannelName => currentChannel.name;

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }
}

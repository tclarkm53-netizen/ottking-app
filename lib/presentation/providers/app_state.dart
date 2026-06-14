import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../data/models/channel_model.dart';
import '../../data/repositories/live_tv_repository.dart';
import '../../data/services/secure_storage_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    required this.repository,
    required this.prefs,
    required this.secureStorage,
  });

  final LiveTvRepository repository;
  final SharedPreferences prefs;
  final SecureStorageService secureStorage;

  // ── State ──────────────────────────────────────────────────────────────────

  bool isLoading = true;
  bool bootToPlayer = false;
  ThemeMode themeMode = ThemeMode.dark;
  String errorMessage = '';

  List<ChannelModel> channels = [];
  List<CategoryModel> categories = [];
  List<BannerModel> banners = [];
  List<SubscriptionPlanModel> plans = [];

  // ব্যাকগ্রাউন্ডে আসা নতুন ক্যাটালগ সাময়িকভাবে ক্যাশ করে রাখার অবজেক্ট
  Map<String, dynamic>? _nextUpdatedCatalog;

  int _currentChannelIndex = 0;
  int get currentChannelIndex => _currentChannelIndex;

  set currentChannelIndex(int value) {
    if (channels.isEmpty) return;
    _currentChannelIndex = value.clamp(0, channels.length - 1);
    _saveLastChannelId(channels[_currentChannelIndex].id);
    notifyListeners();
  }

  bool showToast = false;
  String toastMessage = '';

  UserProfileModel? userProfile;
  bool isAuthenticated = false;

  Timer? _toastTimer;
  Timer? _backgroundUpdateTimer; // ব্যাকগ্রাউন্ড অটো আপডেটের টাইমার

  // ── Bootstrap ──────────────────────────────────────────────────────────────

  Future<void> bootstrap() async {
    themeMode = prefs.getString(AppConstants.keyThemeMode) == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;

    bootToPlayer = prefs.getBool(AppConstants.keyBootToPlayer) ?? false;

    isAuthenticated = await secureStorage.hasUserSession();
    userProfile = await secureStorage.readUserProfile();

    await loadCatalog(); // প্রথমবার অ্যাপ চালুর সময় মেইন ক্যাটালগ লোড
    isLoading = false;
    notifyListeners();

    // অ্যাপ বুট সাকসেসফুল হলে ব্যাকগ্রাউন্ড সিঙ্ক চালু হবে
    _startBackgroundUpdateTimer();
  }

  // ── Catalog (মেইন ও ব্যাকগ্রাউন্ড সائلেন্ট লোড মেকানিজম) ──────────────────────

  Future<void> loadCatalog({bool isBackgroundSilent = false}) async {
    try {
      // ব্যাকগ্রাউন্ডে আপডেট হলে মূল isLoading পরিবর্তন হবে না, ফলে প্লেয়ারে স্পিনার বা বাফারিং আসবে না
      if (!isBackgroundSilent) {
        isLoading = true;
        notifyListeners();
      }

      final catalog = await repository.fetchCatalog();
      
      if (isBackgroundSilent) {
        // ইউজারের চলতি ভিডিওর কোনো ক্ষতি না করে নতুন ক্যাটালগটি ব্যাকগ্রাউন্ডে ক্যাশ করে রাখা হলো।
        // এটি মেইন লিস্টে তখন পর্যন্ত ইফেক্ট ফেলবে না, যতক্ষণ না ইউজার চ্যানেল পরিবর্তন করছেন।
        _nextUpdatedCatalog = {
          'channels': catalog.channels,
          'categories': catalog.categories,
          'banners': catalog.banners,
          'plans': catalog.plans,
        };
        debugPrint('New catalog cached silently in background. Waiting for user action.');
      } else {
        // নরমাল ফার্স্ট টাইম লোড বা ম্যানুয়াল রিফ্রেশ লজিক
        channels = catalog.channels;
        categories = catalog.categories;
        banners = catalog.banners;
        plans = catalog.plans;

        final lastId = prefs.getString(AppConstants.keyLastChannelId);
        if (lastId != null) {
          final idx = channels.indexWhere((c) => c.id == lastId);
          _currentChannelIndex = idx >= 0 ? idx : 0;
        } else {
          if (_currentChannelIndex >= channels.length) _currentChannelIndex = 0;
        }
      }

      errorMessage = '';
    } catch (e) {
      if (!isBackgroundSilent) {
        channels = [];
        categories = [];
        banners = [];
        plans = [];
        errorMessage = e.toString();
      }
      debugPrint('Background sync deferred: $e');
    }
    
    if (!isBackgroundSilent) {
      notifyListeners();
    }
  }

  // ── Background Timer ───────────────────────────────────────────────────────

  void _startBackgroundUpdateTimer() {
    _backgroundUpdateTimer?.cancel();
    // প্রতি ৬০ সেকেন্ড (১ মিনিট) পর পর ব্যাকগ্রাউন্ডে ডাটাবেজ সাইলেন্টলি চেক করে ক্যাশ করবে
    _backgroundUpdateTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      if (isAuthenticated && !isLoading) {
        await loadCatalog(isBackgroundSilent: true);
      }
    });
  }

  // ── Smart Apply Background Changes ─────────────────────────────────────────

  /// চ্যানেল চেঞ্জ করার ঠিক আগমুহূর্তে ব্যাকগ্রাউন্ডের নতুন ক্যাশ করা লিস্ট লাইভ করার মেথড
  void _applyPendingBackgroundUpdates() {
    if (_nextUpdatedCatalog != null) {
      final currentActiveChannelId = channels.isNotEmpty ? channels[_currentChannelIndex].id : null;

      // ব্যাকগ্রাউন্ডের নতুন ডাটা এবার মেইন রানিং স্টেট লিস্টে পুশ করা হলো
      channels = _nextUpdatedCatalog!['channels'] as List<ChannelModel>;
      categories = _nextUpdatedCatalog!['categories'] as List<CategoryModel>;
      banners = _nextUpdatedCatalog!['banners'] as List<BannerModel>;
      plans = _nextUpdatedCatalog!['plans'] as List<SubscriptionPlanModel>;

      // নতুন লিস্ট অ্যাসাইন করার পর কারেন্ট রানিং চ্যানেলের ইনডেক্স পজিশন পুনরায় ঠিক করা
      if (currentActiveChannelId != null) {
        final newIdx = channels.indexWhere((c) => c.id == currentActiveChannelId);
        _currentChannelIndex = newIdx >= 0 ? newIdx : 0;
      }

      _nextUpdatedCatalog = null; // ক্যাশ খালি করে দেওয়া হলো
      debugPrint('Pending background catalog applied successfully on channel switch.');
    }
  }

  // ── Boot Player ────────────────────────────────────────────────────────────

  bool shouldBootToPlayer() => bootToPlayer && channels.isNotEmpty;

  Future<void> setBootToPlayer(bool enabled) async {
    bootToPlayer = enabled;
    await prefs.setBool(AppConstants.keyBootToPlayer, enabled);
    notifyListeners();
  }

  void togglePlayerBoot() => setBootToPlayer(!bootToPlayer);
  bool get isPlayerBootEnabled => bootToPlayer;

  // ── Theme ──────────────────────────────────────────────────────────────────

  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    prefs.setString(
      AppConstants.keyThemeMode,
      themeMode == ThemeMode.light ? 'light' : 'dark',
    );
    notifyListeners();
  }

  // ── Auth ───────────────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    errorMessage = '';
    notifyListeners();
    try {
      final res = await repository.authenticate(email, password);
      await _handleAuthResponse(res, email);
      await loadCatalog();
      _startBackgroundUpdateTimer();
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
      await loadCatalog();
      _startBackgroundUpdateTimer();
    } catch (e) {
      errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> _handleAuthResponse(
      Map<String, dynamic> res, String fallbackEmail) async {
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
    _backgroundUpdateTimer?.cancel(); // লগআউট হলে ব্যাকগ্রাউন্ড টাইমার অফ হবে
    await secureStorage.clearSession();
    isAuthenticated = false;
    userProfile = null;
    _currentChannelIndex = 0;
    await loadCatalog();
    notifyListeners();
  }

  // ── Channel Switching (চ্যানেল চেঞ্জ করলেই কেবল নতুন ক্যাটালগ রেন্ডার হবে) ───────

  void switchChannel(int direction) {
    if (channels.isEmpty) return;

    // ১. রিমোট বাটন চাপার সাথে সাথে ব্যাকগ্রাউন্ডের পেন্ডিং আপডেট লাইভ হবে
    _applyPendingBackgroundUpdates();

    // ২. নতুন লিস্টের সাইজ ও সিকোয়েন্স অনুযায়ী ইনডেক্স পরিবর্তন হবে
    _currentChannelIndex =
        (_currentChannelIndex + direction + channels.length) % channels.length;
    _saveLastChannelId(channels[_currentChannelIndex].id);
    _showChannelToast(channels[_currentChannelIndex].name);
    notifyListeners();
  }

  void selectChannelByIndex(int index) {
    if (channels.isEmpty) return;

    // ১. সাইড প্যানেল বা লিস্ট থেকে ক্লিক করার মুহূর্তে ব্যাকগ্রাউন্ড আপডেট লাইভ হবে
    _applyPendingBackgroundUpdates();

    // ২. নতুন আপডেট করা লিস্টের রেঞ্জ অনুযায়ী সিলেক্টেড চ্যানেল লোড হবে
    _currentChannelIndex = index.clamp(0, channels.length - 1);
    _saveLastChannelId(channels[_currentChannelIndex].id);
    _showChannelToast(channels[_currentChannelIndex].name);
    notifyListeners();
  }

  void _saveLastChannelId(String id) {
    prefs.setString(AppConstants.keyLastChannelId, id);
  }

  void _showChannelToast(String channelName) {
    toastMessage = channelName;
    showToast = true;
    notifyListeners();
    _toastTimer?.cancel();
    _toastTimer = Timer(AppConstants.toastDuration, () {
      showToast = false;
      notifyListeners();
    });
  }

  // ── Current Channel ────────────────────────────────────────────────────────

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

  ChannelModel get currentChannel {
    if (channels.isEmpty) return _fallbackChannel;
    if (_currentChannelIndex >= channels.length || _currentChannelIndex < 0) {
      _currentChannelIndex = 0;
    }
    return channels[_currentChannelIndex];
  }

  String get currentChannelName => currentChannel.name;

  // ── Dispose ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _toastTimer?.cancel();
    _backgroundUpdateTimer?.cancel(); // টাইমার লিক রোধে ক্লোজ
    super.dispose();
  }
}

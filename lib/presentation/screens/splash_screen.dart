// lib/presentation/screens/splash_screen.dart
// ✅ UPDATED VERSION — SAFE BOOT TO PLAYER LOGIC WITH CHANNEL INITIALIZATION

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../providers/app_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // ডেটা লোড এবং নেভিগেশন প্রসেস হ্যান্ডেল করা হচ্ছে
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final appState = context.read<AppState>();

    // ১. আপনার এক্সিস্টিং চ্যানেল বা সেটিংস লোড মেথড এখানে কল করুন (যদি অলরেডি মেইন-এ করা না থাকে)
    // উদাহরণ: await appState.loadChannelsAndSettings();

    // ২. স্প্ল্যাশ স্ক্রিনের মিনিমাম ডিউরেশন পর্যন্ত অপেক্ষা করুন
    await Future.delayed(AppConstants.splashDuration);

    _navigate();
  }

  void _navigate() {
    if (!mounted) return;
    final appState = context.read<AppState>();

    // ── 🎯 ফিক্স: বুট প্লেয়ার ট্রু হলে চ্যানেল সেফটি চেক ──
    if (appState.shouldBootToPlayer() && appState.channels.isNotEmpty) {
      
      // ডিরেক্ট প্লেয়ারে যাওয়ার আগে প্রথম চ্যানেলটি (ইনডেক্স ০) সিলেক্ট করে দেওয়া হচ্ছে যেন প্লেয়ার ব্ল্যাঙ্ক না থাকে
      appState.selectChannelByIndex(0); 
      
      Navigator.pushReplacementNamed(context, '/player');
    } else {
      // বুট প্লেয়ার অফ থাকলে অথবা চ্যানেল লিস্ট খালি থাকলে সেফলি হোম পেজে যাবে
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // হোম স্ক্রিনের সাথে ম্যাচ রেখে টিভি ভিউ চেক (রেসপনসিভনেস)
    final isTV = MediaQuery.of(context).size.width > 800 && 
                 MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      // হোম স্ক্রিনের ব্যানার ও থিমের সাথে ম্যাচিং ডার্ক স্লেট ব্লু ব্যাকগ্রাউন্ড
      backgroundColor: const Color(0xFF0F172A), 
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.1), // হালকা প্রাইমারি গ্লো
              const Color(0xFF0F172A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Transform.scale(
              scale: 0.95 + (_controller.value * 0.06), // স্মুথ পালস অ্যানিমেশন
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // হোম স্ক্রিনের ফোকাস গ্লো বাটনের সাথে ম্যাচিং লোগো ডিজাইন
                  Container(
                    width: isTV ? 130 : 96,
                    height: isTV ? 130 : 96,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(26),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                      // হোম স্ক্রিনের বাটনগুলোর মতো গ্লো












                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withAlpha(60),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.live_tv_rounded, // আধুনিক রাউন্ডেড আইকন
                      size: isTV ? 54 : 44,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: isTV ? 28 : 24),
                  // অ্যাপের নাম (রেসপনসিভ ফন্ট সহ)
                  Text(
                    AppConstants.appName,
                    style: (isTV ? theme.textTheme.headlineLarge : theme.textTheme.headlineMedium)?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900, // প্রিমিয়াম বোল্ড লুক
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // অ্যাপের ট্যাগলাইন
                  Text(
                    AppConstants.appTagline,
                    style: (isTV ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)?.copyWith(
                      color: Colors.white60,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

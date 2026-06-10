// lib/presentation/screens/splash_screen.dart
// ✅ UPDATED VERSION — SPLASH WITH NETWORK & SERVER ERROR UI WITH RETRY LOGIC

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
  
  // এরর হ্যান্ডেলিং স্টেট ভেরিয়েবল
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // প্রথমবার অ্যাপ ওপেনেই ডাটা ফেচ করার চেষ্টা করবে
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // প্রতিবার রিট্রাই করার সময় এরর রিসেট হবে
    });

    final appState = context.read<AppState>();
    final startTime = DateTime.now();

    try {
      // ── 🔄 সার্ভার থেকে ডাটা বুটস্ট্র্যাপ করা হচ্ছে ──────────────────────
      await appState.bootstrap(); 
      
      // ডাটা ফেচ করতে কত সময় লাগলো তার হিসাব
      final elapsedTime = DateTime.now().difference(startTime);
      
      // মিনিমাম স্প্লাশ ডিউরেশন মেইনটেইন করা
      if (elapsedTime < AppConstants.splashDuration) {
        final remainingTime = AppConstants.splashDuration - elapsedTime;
        await Future.delayed(remainingTime);
      }

      // ডাটা সফলভাবে মেমোরিতে আসলে নেভিগেট করবে
      _navigate();

    } catch (e) {
      // নেটওয়ার্ক বা সার্ভার এরর ক্যাচ করা
      debugPrint("Splash Bootstrap Error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "নেটওয়ার্ক কানেকশন অথবা সার্ভারে সমস্যা হচ্ছে। অনুগ্রহ করে আবার চেষ্টা করুন।";
        });
      }
    }
  }

  void _navigate() {
    if (!mounted) return;
    final appState = context.read<AppState>();

    // বুট প্লেয়ার ট্রু হলে এবং চ্যানেল লিস্টে ডেটা থাকলে সরাসরি প্লেয়ারে যাবে
    if (appState.shouldBootToPlayer() && appState.channels.isNotEmpty) {
      appState.selectChannelByIndex(0); 
      Navigator.pushReplacementNamed(context, '/player');
    } else {
      // বুट প্লেয়ার অফ থাকলে অথবা চ্যানেল খালি থাকলে হোম পেজে যাবে
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
    
    // স্মার্ট টিভি এবং ল্যান্ডস্কেপ মোড ডিটেকশন
    final isTV = MediaQuery.of(context).size.width > 800 && 
                 MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), 
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              const Color(0xFF0F172A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // লোডিং স্টেট অনুযায়ী স্কেল অ্যানিমেশন কেবল লোগোতেই কাজ করবে
              return Transform.scale(
                scale: _isLoading ? (0.95 + (_controller.value * 0.06)) : 1.0,
                child: child,
              );
            },
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── ১. লোগো এরিয়া (লোডিং ও এরর উভয় স্টেটেই থাকবে) ──────────────────
                  Container(
                    width: isTV ? 130 : 96,
                    height: isTV ? 130 : 96,
                    decoration: BoxDecoration(
                      color: _isLoading 
                          ? theme.colorScheme.primary.withAlpha(26)
                          : Colors.red.withOpacity(0.1), // এরর হলে হালকা রেড গ্লো
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isLoading ? theme.colorScheme.primary : Colors.redAccent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isLoading 
                              ? theme.colorScheme.primary.withAlpha(60)
                              : Colors.redAccent.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isLoading ? Icons.live_tv_rounded : Icons.wifi_off_rounded,
                      size: isTV ? 54 : 44,
                      color: _isLoading ? theme.colorScheme.primary : Colors.redAccent,
                    ),
                  ),
                  SizedBox(height: isTV ? 28 : 24),
                  
                  Text(
                    AppConstants.appName,
                    style: (isTV ? theme.textTheme.headlineLarge : theme.textTheme.headlineMedium)?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  
                  // ── ২. ডাইনামিক উইজেট (লোডিং বনাম এরর স্টেট) ──────────────────
                  if (_isLoading) ...[
                    const SizedBox(height: 8),
                    Text(
                      AppConstants.appTagline,
                      style: (isTV ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)?.copyWith(
                        color: Colors.white60,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // ছোট একটি প্রগ্রেস ইন্ডিকেটর ব্যাকগ্রাউন্ড ফেচিং বোঝানোর জন্য
                    SizedBox(
                      width: isTV ? 28 : 22,
                      height: isTV ? 28 : 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                      ),
                    ),
                  ] else if (_errorMessage != null) ...[
                    // ── 🚨 এরর উইজেট বাটন ও মেসেজ ──────────────────
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: isTV ? 16 : 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // রিমোট ফ্রেন্ডলি রিট্রাই বাটন (টিভি সাপোর্ট)
                    ElevatedButton.icon(
                      onPressed: _initializeApp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isTV ? 32 : 24,
                          vertical: isTV ? 16 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 5,
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        "আবার চেষ্টা করুন",
                        style: TextStyle(
                          fontSize: isTV ? 16 : 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

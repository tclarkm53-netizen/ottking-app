// lib/presentation/screens/splash_screen.dart

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
    // লোগো পালস বা অ্যানিমেশন কন্ট্রোলার
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // স্প্ল্যাশ স্ক্রিন চালু হওয়ামাত্রই ব্যাকগ্রাউন্ডে ডাটা লোড করা শুরু হবে
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final appState = context.read<AppState>();
    
    // ১. ন্যূনতম স্প্ল্যাশ ডিউরেশন এবং ডাটা লোড করার কাজ সমান্তরালভাবে (Parallel) চলবে
    await Future.wait([
      Future.delayed(AppConstants.splashDuration),
      appState.loadCatalog(), // হোম স্ক্রিনে যাওয়ার আগেই ক্যাটালগ সম্পূর্ণ লোড নিশ্চিত করবে
    ]);

    // ২. ডাটা লোড শেষ হলে নেভিগেশন শুরু হবে
    _navigate();
  }

  void _navigate() {
    if (!mounted) return;
    final appState = context.read<AppState>();
    
    // ডাটা সফলভাবে লোড হোক বা এরর আসুক, স্টেট অনুযায়ী সঠিক স্ক্রিনে পাঠানো হবে
    Navigator.pushReplacementNamed(
      context,
      appState.shouldBootToPlayer() ? '/player' : '/home',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // টিভি স্ক্রিন রেসপনসিভনেস চেক
    final isTV = MediaQuery.of(context).size.width > 800 && 
                 MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF111827), Color(0xFF1F2937)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) => Transform.scale(
              scale: 0.95 + (_controller.value * 0.08),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // লোগো কন্টেইনার (টিভির জন্য সাইজ এডজাস্ট করা হয়েছে)
                  Container(
                    width: isTV ? 140 : 96,
                    height: isTV ? 140 : 96,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(31),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: isTV ? 3 : 2,
                      ),
                    ),
                    child: Icon(
                      Icons.live_tv,
                      size: isTV ? 64 : 46,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: isTV ? 30 : 20),
                  // অ্যাপের নাম
                  Text(
                    AppConstants.appName,
                    style: (isTV ? theme.textTheme.headlineLarge : theme.textTheme.headlineMedium)?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // অ্যাপের ট্যাগলাইন
                  Text(
                    AppConstants.appTagline,
                    style: (isTV ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)?.copyWith(
                      color: Colors.white70,
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

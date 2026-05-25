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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    Future.delayed(AppConstants.splashDuration, _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final appState = context.read<AppState>();
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
                      // হোম স্ক্রিনের বাটনগুলোর মতো গ্লো ইফেক্ট
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
                      fontWeight: FontWeight.w900, // আরও একটু বোল্ড ও প্রিমিয়াম লুক
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

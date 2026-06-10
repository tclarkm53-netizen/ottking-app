// lib/presentation/screens/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // সম্পূর্ণ ফুল স্ক্রিন — কোনো সিস্টেম UI নেই
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    // স্ক্রিন সাইজ অনুযায়ী adaptive scaling
    // ছোট ফোন থেকে বড় TV পর্যন্ত সব কিছু proportionally fit থাকবে
    final double baseUnit = (w * 0.12).clamp(48.0, 120.0);
    final double logoSize = baseUnit;
    final double iconSize = (logoSize * 0.45).clamp(24.0, 52.0);
    final double titleSize = (w * 0.045).clamp(18.0, 42.0);
    final double taglineSize = (w * 0.022).clamp(12.0, 20.0);
    final double spacing = (h * 0.03).clamp(12.0, 28.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      // SafeArea বাদ — immersiveSticky তে সম্পূর্ণ স্ক্রিন নেওয়া হবে
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(0.08),
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
                scale: 0.95 + (_controller.value * 0.06),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // লোগো সার্কেল
                    Container(
                      width: logoSize,
                      height: logoSize,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(26),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withAlpha(60),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.live_tv_rounded,
                        size: iconSize,
                        color: theme.colorScheme.primary,
                      ),
                    ),

                    SizedBox(height: spacing),

                    // অ্যাপের নাম
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),

                    SizedBox(height: spacing * 0.4),

                    // ট্যাগলাইন
                    Text(
                      AppConstants.appTagline,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: taglineSize,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

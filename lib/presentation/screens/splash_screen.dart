// lib/presentation/screens/splash_screen.dart
// TV-only landscape splash. Boots to player if enabled & has channels.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Force landscape on every screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final appState = context.read<AppState>();
    final start = DateTime.now();

    try {
      await appState.bootstrap();

      final elapsed = DateTime.now().difference(start);
      final remaining = AppConstants.splashDuration - elapsed;
      if (remaining > Duration.zero) await Future.delayed(remaining);

      _navigate();
    } catch (e) {
      debugPrint('Splash error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'নেটওয়ার্ক বা সার্ভারে সমস্যা হচ্ছে। আবার চেষ্টা করুন।';
        });
      }
    }
  }

  void _navigate() {
    if (!mounted) return;
    final appState = context.read<AppState>();

    if (appState.shouldBootToPlayer() && appState.channels.isNotEmpty) {
      // Boot directly to last-played channel (already restored in loadCatalog)
      Navigator.pushNamedAndRemoveUntil(
          context, '/player', (route) => false);
    } else {
      Navigator.pushNamedAndRemoveUntil(
          context, '/home', (route) => false);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.2,
            colors: [
              AppTheme.primary.withOpacity(0.08),
              AppTheme.surface,
            ],
          ),
        ),
        child: Row(
          children: [
            // Left decorative bar
            Container(
              width: 5, // একটু চিকন করা হয়েছে (৬ থেকে ৫)
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primary.withOpacity(0.0),
                    AppTheme.primary,
                    AppTheme.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
            // Center content
            Expanded(
              child: Padding(
                // চারপাশ থেকে ১৬ পিক্সেল সেফ প্যাডিং দেওয়া হয়েছে যেন সব স্ক্রিনে ডিজাইন ভেতরে থাকে
                padding: const EdgeInsets.all(16.0), 
                child: Center(
                  // ছোট স্ক্রিনেও যেন কনটেন্ট ওভারফ্লো (Overflow) না করে স্ক্রোল করা যায়
                  child: SingleChildScrollView( 
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) => Transform.scale(
                        scale: _isLoading ? 0.97 + _pulse.value * 0.03 : 1.0, // পালস ইফেক্ট সামান্য কমানো হয়েছে
                        child: child,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo ring (১২০ থেকে কমিয়ে ৯০ করা হয়েছে)
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primary.withOpacity(0.08),
                              border: Border.all(
                                color: _isLoading
                                    ? AppTheme.primary
                                    : Colors.redAccent,
                                width: 2.0, // বর্ডার কিছুটা চিকন করা হয়েছে
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isLoading
                                          ? AppTheme.primary
                                          : Colors.redAccent)
                                      .withOpacity(0.4),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isLoading
                                  ? Icons.live_tv_rounded
                                  : Icons.wifi_off_rounded,
                              size: 40, // আইকন সাইজ ৫২ থেকে ৪০ করা হয়েছে
                              color: _isLoading ? AppTheme.primary : Colors.redAccent,
                            ),
                          ),
                          const SizedBox(height: 24), // স্পেস ৩২ থেকে ২৪ করা হয়েছে

                          // App name
                          Text(
                            AppConstants.appName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36, // ফন্ট সাইজ ৪৮ থেকে ৩৬ করা হয়েছে
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                            ),
                          ),

                          const SizedBox(height: 6),
                          Text(
                            AppConstants.appTagline,
                            style: TextStyle(
                              color: AppTheme.primary.withOpacity(0.8),
                              fontSize: 14, // ফন্ট সাইজ ১৬ থেকে ১৪ করা হয়েছে
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 32), // স্পেস ৪৮ থেকে ৩২ করা হয়েছে

                          if (_isLoading) ...[
                            SizedBox(
                              width: 28, // ইন্ডিকেটর সাইজ ৩৬ থেকে ২৮ করা হয়েছে
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'চ্যানেল লোড হচ্ছে...',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 13,
                              ),
                            ),
                          ] else if (_errorMessage != null) ...[
                            Padding(
                              // ছোট স্ক্রিনের জন্য দুই পাশের প্যাডিং ৮০ থেকে কমিয়ে ২০ করা হয়েছে
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 14, // ফন্ট সাইজ ১৬ থেকে ১৪ করা হয়েছে
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20), // স্পেস ২৮ থেকে ২০ করা হয়েছে
                            ElevatedButton.icon(
                              onPressed: _boot,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 14), // বাটন প্যাডিং কমানো হয়েছে
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                                textStyle: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold), // সাইজ ১৮ থেকে ১৬
                              ),
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                              label: const Text('আবার চেষ্টা করুন'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

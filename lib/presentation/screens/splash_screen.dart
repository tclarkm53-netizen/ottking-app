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
              width: 6,
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
              child: Center(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => Transform.scale(
                    scale: _isLoading ? 0.96 + _pulse.value * 0.04 : 1.0,
                    child: child,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo ring
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary.withOpacity(0.08),
                          border: Border.all(
                            color: _isLoading
                                ? AppTheme.primary
                                : Colors.redAccent,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isLoading
                                      ? AppTheme.primary
                                      : Colors.redAccent)
                                  .withOpacity(0.4),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isLoading
                              ? Icons.live_tv_rounded
                              : Icons.wifi_off_rounded,
                          size: 52,
                          color: _isLoading ? AppTheme.primary : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // App name
                      Text(
                        AppConstants.appName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),

                      const SizedBox(height: 8),
                      Text(
                        AppConstants.appTagline,
                        style: TextStyle(
                          color: AppTheme.primary.withOpacity(0.8),
                          fontSize: 16,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 48),

                      if (_isLoading) ...[
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'চ্যানেল লোড হচ্ছে...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                      ] else if (_errorMessage != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 80),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton.icon(
                          onPressed: _boot,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 18),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('আবার চেষ্টা করুন'),
                        ),
                      ],
                    ],
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

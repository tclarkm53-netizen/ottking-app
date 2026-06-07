// lib/app/app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../presentation/providers/app_state.dart';
import '../presentation/screens/home_screen.dart';
import '../presentation/screens/player_screen.dart';
import '../presentation/screens/settings_screen.dart';
import '../presentation/screens/splash_screen.dart';

class OttKingApp extends StatelessWidget {
  const OttKingApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen only to themeMode to avoid full rebuilds
    context.select<AppState, ThemeMode>((s) => ThemeMode.dark);

    return MaterialApp(
      title: 'OTTKing',
      debugShowCheckedModeBanner: false,
      theme:     AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      initialRoute: '/splash',
      routes: {
        '/splash':   (_) => const SplashScreen(),
        '/home':     (_) => const HomeScreen(),
        '/player':   (_) => const PlayerScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}

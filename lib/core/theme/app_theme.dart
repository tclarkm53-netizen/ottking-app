// lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color bgDeep       = Color(0xFF080600);
  static const Color bgDark       = Color(0xFF100D00);
  static const Color bgCard       = Color(0xFF181300);
  static const Color bgCardLit    = Color(0xFF201900);
  static const Color gold         = Color(0xFFD4A017);
  static const Color goldLight    = Color(0xFFFFD966);
  static const Color goldDim      = Color(0xFF9B7213);
  static const Color amber        = Color(0xFFFFC107);
  static const Color red          = Color(0xFFE53935);
  static const Color green        = Color(0xFF43A047);
  static const Color textPrimary  = Color(0xFFFFF8E1);
  static const Color textSub      = Color(0xFFBFAA72);
  static const Color textMuted    = Color(0xFF7A6930);
  static const Color border       = Color(0xFF2A2000);
  static const Color borderGold   = Color(0xFF4D3C00);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient goldGrad = LinearGradient(
    colors: [goldDim, goldLight, gold],
  );
  static const LinearGradient bgGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgDark, bgDeep],
  );

  // ── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDeep,
        colorScheme: const ColorScheme.dark(
          primary: gold,
          secondary: amber,
          surface: bgCard,
          error: red,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: textPrimary,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: bgCard,
          selectedColor: Color(0x33D4A017),
          labelStyle: const TextStyle(color: textPrimary, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: borderGold),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgCard,
          labelStyle: const TextStyle(color: textMuted),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: borderGold)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: gold, width: 2)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? gold : textMuted),
          trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected)
                  ? const Color(0x66D4A017)
                  : border),
        ),
        textTheme: const TextTheme(
          displayLarge:   TextStyle(color: textPrimary, fontWeight: FontWeight.w900),
          headlineLarge:  TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
          headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
          bodyLarge:      TextStyle(color: textPrimary),
          bodyMedium:     TextStyle(color: textSub),
          labelLarge:     TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
      );
}

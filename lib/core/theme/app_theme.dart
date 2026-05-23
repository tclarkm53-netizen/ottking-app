import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color backgroundDark = Color(0xFF090B16);
  static const Color backgroundLight = Color(0xFFF4F6FB);
  static const Color surfaceDark = Color(0xFF11152A);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFF87171);

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundDark,
    colorScheme: ColorScheme.dark(
      primary: accent,
      secondary: const Color(0xFF22D3EE),
      surface: surfaceDark,
      background: backgroundDark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
    ),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: backgroundLight,
    colorScheme: ColorScheme.light(
      primary: accent,
      secondary: const Color(0xFF0F172A),
      surface: surfaceLight,
      background: backgroundLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Color(0xFF0F172A),
    ),
  );
}

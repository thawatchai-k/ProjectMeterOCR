import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryDark = Color(0xFF121212);
  static const Color accentBlue = Color(0xFF4D96FF);
  static const Color accentGreen = Color(0xFF6BCB77);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color textMain = Color(0xFFF8F9FA);
  static const Color textMuted = Color(0xFFADB5BD);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: accentBlue,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: accentBlue,
        secondary: accentGreen,
        surface: surfaceDark,
        onSurface: textMain,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentBlue,
          side: const BorderSide(color: accentBlue, width: 2),
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 4,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: textMain,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        bodyLarge: TextStyle(color: textMain, fontSize: 16),
        bodyMedium: TextStyle(color: textMuted, fontSize: 14),
      ),
    );
  }
}

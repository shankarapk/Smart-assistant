import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF2E7D32); // green, grocery/savings association

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // Elder-friendly: larger base text sizes across the app.
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 20),
        bodyMedium: TextStyle(fontSize: 18),
        titleLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        labelLarge: TextStyle(fontSize: 20),
      ),
      appBarTheme: const AppBarTheme(centerTitle: true),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 56), // large tap targets
          textStyle: const TextStyle(fontSize: 20),
        ),
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      ),
    );
  }
}

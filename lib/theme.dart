import 'package:flutter/material.dart';

/// The colours of the new site design (leylot-new: --ly-* / --nh-*).
class Ly {
  static const night = Color(0xFF0D1A3A);
  static const deep = Color(0xFF08122B);
  static const panel = Color(0xFF16264F);
  static const card = Color(0xFF1E2D55);
  static const sky = Color(0xFF37B8EB);
  static const aegean = Color(0xFF1769C2);
  static const live = Color(0xFFE5484D);
  static const fresh = Color(0xFFFFB547);
  static const muted = Color(0xFF9AA6C2);
  static const line = Color(0x33DDE3EC);
  static const wa = Color(0xFF25D366);
  static const cream = Color(0xFFFFF6DA);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Assistant',
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: aegean,
        brightness: Brightness.dark,
        primary: sky,
        surface: night,
      ),
      scaffoldBackgroundColor: deep,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(backgroundColor: deep, elevation: 0, centerTitle: false),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: night,
        indicatorColor: sky.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textTheme: base.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    );
  }
}

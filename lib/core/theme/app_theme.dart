import 'package:flutter/material.dart';

class WC {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF0F0F0F);
  static const card = Color(0xFF151515);
  static const line = Color(0xFF3A3A3A);
  static const text = Color(0xFFEDEDED);
  static const muted = Color(0xFF9A9A9A);
  static const accent = Color(0xFFFFC83D);
  static const ok = Color(0xFF4CD08C);
  static const warn = Color(0xFFFF9F43);
  static const bad = Color(0xFFFF5D6C);
}

class WT {
  static const title = TextStyle(fontFamily: 'Inter', fontSize: 34, fontWeight: FontWeight.w700, color: WC.text, height: 1.15);
  static const headline = TextStyle(fontFamily: 'Inter', fontSize: 26, fontWeight: FontWeight.w700, color: WC.text, height: 1.2);
  static const hero = TextStyle(fontFamily: 'Inter', fontSize: 40, fontWeight: FontWeight.w800, color: WC.text, height: 1.15);
  static const button = TextStyle(fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w700, height: 1.2);
  static const body = TextStyle(fontFamily: 'Inter', fontSize: 20, fontWeight: FontWeight.w400, color: WC.text, height: 1.4);
  static const label = TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600, color: WC.muted, height: 1.3);
}

final appTheme = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: WC.bg,
      colorScheme: const ColorScheme.dark(primary: WC.accent, surface: WC.surface, error: WC.bad),
      splashFactory: NoSplash.splashFactory,
    );

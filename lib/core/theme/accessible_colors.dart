import 'package:flutter/material.dart';

/// High-contrast, WCAG AAA compliant color palette tailored for visually impaired users.
class AccessibleColors {
  // Pure OLED Black background provides maximum contrast and battery conservation
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF121212);
  static const Color card = Color(0xFF1A1A1A);
  static const Color border = Color(0xFF424242);

  // High-contrast primary text (21:1 contrast ratio against black)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFE0E0E0);
  static const Color textMuted = Color(0xFFAAAAAA);

  // Tactile Yellow accent (16:1 contrast ratio against black)
  static const Color tactileAccent = Color(0xFFFFD600);

  // Safety & Hazard semantic indicators
  static const Color danger = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFF9500);
  static const Color success = Color(0xFF34C759);
  static const Color info = Color(0xFF0A84FF);
}

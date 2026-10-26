import 'package:flutter/material.dart';

/// Uygulamanın koyu tema paleti.
abstract final class AppColors {
  // Zeminler
  static const Color background = Color(0xFF080B11);
  static const Color surface = Color(0xFF111722);
  static const Color surfaceHigh = Color(0xFF1A2231);
  static const Color outline = Color(0xFF2A3446);

  // Marka renkleri
  static const Color primary = Color(0xFF7C5CFF);
  static const Color primarySoft = Color(0xFF2B2352);
  static const Color secondary = Color(0xFF22D3EE);
  static const Color danger = Color(0xFFFF5C7A);
  static const Color success = Color(0xFF34D399);

  // Metin
  static const Color textPrimary = Color(0xFFF2F4F8);
  static const Color textSecondary = Color(0xFF96A0B5);
  static const Color textMuted = Color(0xFF5F6B80);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFFB15CFF)],
  );

  static const LinearGradient backgroundGlow = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1B1638), background],
    stops: [0.0, 0.55],
  );

  static LinearGradient bubbleGradient(bool isMine) => isMine
      ? primaryGradient
      : const LinearGradient(
          colors: [surfaceHigh, surfaceHigh],
        );
}

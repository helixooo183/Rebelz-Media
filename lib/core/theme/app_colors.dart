import 'package:flutter/material.dart';

/// Rebelz Media marka paleti.
///
/// Arayüz renkleri için [Theme.of(context).colorScheme] kullanılır; bu sınıf
/// yalnızca markaya ait sabit değerleri (kırmızı tonları, gradyanlar) tutar.
abstract final class AppColors {
  /// Logo kırmızısı.
  static const Color brand = Color(0xFFFF2D2D);

  /// Koyu kırmızı (gradyanın ikinci durağı).
  static const Color brandDeep = Color(0xFFD6102E);

  /// Marka gradyanı (buton, aktif sekme, kendi mesaj balonum).
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brand, brandDeep],
  );

  // ---------------------------------------------------------------- koyu tema
  static const Color darkBackground = Color(0xFF09090B);
  static const Color darkSurface = Color(0xFF151518);
  static const Color darkSurfaceHigh = Color(0xFF1F1F24);
  static const Color darkOutline = Color(0xFF2C2C33);
  static const Color darkText = Color(0xFFF6F6F7);
  static const Color darkTextSecondary = Color(0xFFA0A0AB);

  // ---------------------------------------------------------------- açık tema
  static const Color lightBackground = Color(0xFFF6F6F8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFEFF0F3);
  static const Color lightOutline = Color(0xFFE1E2E7);
  static const Color lightText = Color(0xFF0C0C0F);
  static const Color lightTextSecondary = Color(0xFF6C6C78);

  // ------------------------------------------------------------------ durumlar
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = brand;

  /// Metin/ikon kontrastı için marka üzerine beyaz.
  static const Color onBrand = Colors.white;
}

/// Renk/ölçü kısayolları: `context.colors.primary`, `context.muted` gibi.
extension RebelzTheme on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// İkincil metin rengi.
  Color get muted => colors.onSurfaceVariant;

  /// Kart/panel zemini.
  Color get card => colors.surface;

  /// İkincil zemin (çipler, arama alanları).
  Color get cardHigh => colors.surfaceContainerHighest;

  /// İnce ayırıcı.
  Color get line => colors.outlineVariant;

  TextTheme get texts => Theme.of(this).textTheme;

  /// Kart köşe yarıçapı.
  static const double radius = 20;
}

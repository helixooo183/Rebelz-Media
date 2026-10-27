import 'package:flutter/material.dart';

import '../theme/brand_assets.dart';

/// Rebelz Media fırça logosu.
///
/// Tek parça hâli `assets/brand/rebelz-brush.png` (kırmızı R + beyaz EBELZ).
/// Açık zeminde okunabilmesi için siyah plaka üzerine yerleştirilebilir.
class RebelzLogo extends StatelessWidget {
  const RebelzLogo({
    super.key,
    this.height = 40,
    this.showWordmark = true,
    this.onBlack = false,
  });

  /// Toplam yükseklik.
  final double height;

  /// `false` ise yalnızca kırmızı "R" işareti çizilir.
  final bool showWordmark;

  /// Açık temada okunabilirlik için siyah zemin/plaka.
  final bool onBlack;

  @override
  Widget build(BuildContext context) {
    if (!showWordmark) {
      return Image.asset(
        BrandAssets.mark,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'Rebelz Media',
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final needsPlate = onBlack || !isDark;

    final logo = Image.asset(
      BrandAssets.brush,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Rebelz Media',
    );

    if (!needsPlate) return logo;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: height * 0.22,
        vertical: height * 0.14,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(height * 0.28),
      ),
      child: logo,
    );
  }
}

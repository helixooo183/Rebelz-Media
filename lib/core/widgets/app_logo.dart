import 'package:flutter/material.dart';

/// Rebelz Media logosu.
///
/// Varlıklar `tool/marka_uret.py` ile logodan üretilir:
///   assets/brand/rebelz-mark.png      kırmızı fırça "R"
///   assets/brand/rebelz-wordmark.png  "REBELZ" yazısı
class RebelzLogo extends StatelessWidget {
  const RebelzLogo({
    super.key,
    this.height = 40,
    this.showWordmark = true,
    this.onBlack = false,
  });

  /// Toplam yükseklik.
  final double height;

  /// `false` ise yalnızca "R" işareti çizilir.
  final bool showWordmark;

  /// Açık temada wordmark siyah zeminli bir kapsül içinde gösterilir.
  final bool onBlack;

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      'assets/brand/rebelz-mark.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Rebelz Media',
    );

    if (!showWordmark) return mark;

    final word = Image.asset(
      'assets/brand/rebelz-wordmark.png',
      height: height * 0.52,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Rebelz Media',
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final needsPlate = onBlack || !isDark;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: height * 0.18),
        Padding(
          padding: EdgeInsets.symmetric(vertical: height * 0.1),
          child: word,
        ),
      ],
    );

    if (!needsPlate) return content;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: height * 0.22,
        vertical: height * 0.1,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(height * 0.32),
      ),
      child: content,
    );
  }
}

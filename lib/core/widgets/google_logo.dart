import 'package:flutter/material.dart';

/// Google "G" logosu — dört renkli yay + mavi çubuk.
/// Harici görsel kullanmadan çizilir (her yoğunlukta net görünür).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - stroke) / 2,
    );

    Paint arcPaint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Açı 0 = saat 3 yönü; pozitif yön saat yönü.
    canvas.drawArc(rect, -2.28, 1.30, false, arcPaint(_red)); // üst
    canvas.drawArc(rect, -0.98, 0.86, false, arcPaint(_blue)); // sağ üst
    canvas.drawArc(rect, 0.42, 1.92, false, arcPaint(_green)); // alt-sağ
    canvas.drawArc(rect, 2.34, 1.72, false, arcPaint(_yellow)); // sol

    // G'nin yatay çubuğu (sağ orta).
    final barHeight = stroke * 0.92;
    final barLeft = size.width / 2 - stroke * 0.1;
    final barRight = size.width - stroke * 0.55;
    canvas.drawRect(
      Rect.fromLTRB(barLeft, size.height / 2 - barHeight / 2, barRight,
          size.height / 2 + barHeight / 2),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}

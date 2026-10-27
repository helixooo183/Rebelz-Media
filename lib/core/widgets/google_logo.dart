import 'package:flutter/material.dart';

/// Google'ın resmî çok renkli "G" işareti.
///
/// Harici görsel veya bağımlılık kullanmadan markanın geometrisine göre
/// çizilir: dört renkli halka + ortadan sağa uzanan mavi çubuk.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size,
      width: size,
      child: CustomPaint(painter: const _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _red = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.235;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(
      center: center,
      radius: (size.width - stroke) / 2,
    );

    Paint arc(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Açılar radyan; 0 = saat 3 yönü, pozitif = saat yönü.
    canvas.drawArc(rect, 3.49, 2.10, false, arc(_red)); // üst
    canvas.drawArc(rect, -0.70, 1.22, false, arc(_blue)); // sağ üst
    canvas.drawArc(rect, 0.52, 2.10, false, arc(_green)); // alt
    canvas.drawArc(rect, 2.62, 0.87, false, arc(_yellow)); // sol alt

    // G'nin yatay mavi çubuğu (sağ orta).
    final barHeight = stroke * 0.96;
    final barTop = center.dy - barHeight / 2;
    final barLeft = center.dx - stroke * 0.06;
    final barRight = size.width - stroke * 0.28;

    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTRB(barLeft, barTop, barRight, barTop + barHeight),
        topRight: Radius.circular(barHeight * 0.16),
        bottomRight: Radius.circular(barHeight * 0.16),
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}

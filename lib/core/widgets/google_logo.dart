import 'package:flutter/material.dart';

import '../theme/brand_assets.dart';

/// Google "G" logosu.
///
/// Uygulama içinde **asset** olarak gelir (dört renkli resmî marka görseli);
/// böylece hem koyu hem açık temada birebir aynı görünür.
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      BrandAssets.googleG,
      height: size,
      width: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Google',
    );
  }
}

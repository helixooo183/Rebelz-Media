import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/brand_assets.dart';

/// Oturum bilgisi yüklenirken gösterilen açılış ekranı.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060607),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.12),
                  radius: 0.72,
                  colors: [
                    AppColors.brand.withValues(alpha: 0.15),
                    const Color(0xFF08080A),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  BrandAssets.brush,
                  height: 96,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  semanticLabel: 'Rebelz Media',
                ),
                const SizedBox(height: 34),
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 42,
            child: Text(
              'SOHBET · KANAL · TOPLULUK',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

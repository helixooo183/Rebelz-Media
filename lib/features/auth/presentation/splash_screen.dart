import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_logo.dart';

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
                  center: const Alignment(0, -0.1),
                  radius: 0.55,
                  colors: [
                    AppColors.brand.withValues(alpha: 0.16),
                    AppColors.brandDeep.withValues(alpha: 0.05),
                    const Color(0xFF060607),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RebelzLogo(height: 48),
                SizedBox(height: 34),
                SizedBox(
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

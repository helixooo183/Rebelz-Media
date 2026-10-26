import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Uygulama logosu: gradyanlı yuvarlatılmış kare + sohbet ikonu.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Icon(
        Icons.forum_rounded,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/brand_assets.dart';

/// Marka butonu: kırmızı grunge dokulu zemin, beyaz etiket.
///
/// Doku `assets/brand/buton-grunge.png` (üretimi: `tool/marka_uret.py`).
/// Yükleme durumunda doku korunur, üzerine küçük bir ilerleme göstergesi
/// gelir; pasif durumda zemin nötr yüzeye döner.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 54,
    this.expand = true,
    this.grunge = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;
  final bool expand;

  /// `false` ise düz marka gradyanı kullanılır (ör. profil kartı).
  final bool grunge;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: height,
      width: expand ? double.infinity : null,
      padding: expand ? null : const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isEnabled ? null : context.colors.surfaceContainerHighest,
        gradient: isEnabled && !grunge ? AppColors.brandGradient : null,
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isEnabled && grunge)
              Image.asset(
                BrandAssets.grunge,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
              ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isEnabled ? onPressed : null,
                splashColor: Colors.white.withValues(alpha: 0.14),
                highlightColor: Colors.white.withValues(alpha: 0.06),
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(
                                icon,
                                size: 19,
                                color: isEnabled ? Colors.white : context.muted,
                              ),
                              const SizedBox(width: 9),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.1,
                                color: isEnabled ? Colors.white : context.muted,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return content;
  }
}

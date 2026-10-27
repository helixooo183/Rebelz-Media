import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Marka renkli, yükleme durumunu yöneten ana buton.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 54,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: height,
      width: expand ? double.infinity : null,
      padding: expand ? null : const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: isEnabled ? AppColors.brandGradient : null,
        color: isEnabled ? null : context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isEnabled ? onPressed : null,
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
                          color: isEnabled
                              ? Colors.white
                              : context.muted,
                        ),
                        const SizedBox(width: 9),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: isEnabled
                              ? Colors.white
                              : context.muted,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    return content;
  }
}

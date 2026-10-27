import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'google_logo.dart';

/// Google ile giriş butonu.
///
/// Koyu temada marka kurallarına uygun **koyu yüzey + ince çerçeve** kullanılır
/// (beyaz metin, sol tarafta gerçek dört renkli "G"); açık temada beyaz yüzey.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.label = 'Google ile devam et',
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surface = isDark ? const Color(0xFF141416) : Colors.white;
    final border = isDark ? const Color(0xFF2E2E33) : context.line;
    final labelColor = isDark ? const Color(0xFFF2F2F4) : const Color(0xFF1F1F1F);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: isEnabled ? 1 : 0.55,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
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
                        color: Color(0xFF4285F4),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const GoogleLogo(size: 22),
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                            color: labelColor,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Koyu temada vurgu rengi (buton içi ikon vb.) için kısayol.
const Color googleAccent = AppColors.brand;

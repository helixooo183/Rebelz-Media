import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// "veya" ayırıcısı.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, this.label = 'veya'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.outline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.outline)),
      ],
    );
  }
}

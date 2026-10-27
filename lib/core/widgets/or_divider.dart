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
        Expanded(child: Divider(color: context.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, color: context.muted),
          ),
        ),
        Expanded(child: Divider(color: context.line)),
      ],
    );
  }
}

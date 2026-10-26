import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// İsim baş harfinden üretilen, gradyanlı avatar.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.highlighted = false,
  });

  final String name;
  final double size;
  final bool highlighted;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: highlighted
            ? AppColors.primaryGradient
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.surfaceHigh, AppColors.outline],
              ),
        border: highlighted
            ? null
            : Border.all(color: AppColors.outline, width: 1),
      ),
      child: Text(
        _initial,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
          color: highlighted ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Yuvarlatılmış yüzey kartı (Threads'in sade blokları).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.margin,
    this.radius = 20,
    this.color,
    this.border = true,
    this.trailing,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final Color? color;
  final bool border;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final body = Row(
      children: [
        Expanded(child: child),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );

    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.card,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: context.line) : null,
      ),
      child: body,
    );

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: onTap == null && onLongPress == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: onTap,
                onLongPress: onLongPress,
                child: content,
              ),
            ),
    );
  }
}

/// Küçük bölüm başlığı + sağda aksiyon.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(4, 18, 4, 10),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: context.muted,
              ),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.colors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Yuvarlak ikon kapsülü (liste satırı önü).
class IconBubble extends StatelessWidget {
  const IconBubble({
    super.key,
    required this.icon,
    this.size = 44,
    this.color,
    this.iconColor,
    this.radius,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? iconColor;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: color ?? context.cardHigh,
        borderRadius: BorderRadius.circular(radius ?? size * 0.32),
      ),
      child: Icon(
        icon,
        size: size * 0.46,
        color: iconColor ?? context.colors.onSurfaceVariant,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

/// Alt sekmeli ana iskelet (StatefulShellRoute ile sekme durumu korunur).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _items = [
    (icon: Icons.forum_outlined, active: Icons.forum, label: 'Sohbetler'),
    (icon: Icons.campaign_outlined, active: Icons.campaign, label: 'Kanallar'),
    (icon: Icons.person_outline, active: Icons.person, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _items[i].icon,
                      activeIcon: _items[i].active,
                      label: _items[i].label,
                      selected: i == index,
                      onTap: () => navigationShell.goBranch(
                        i,
                        initialLocation: i == index,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? context.colors.primary : context.colors.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 28,
            width: 46,
            decoration: BoxDecoration(
              color: selected
                  ? context.colors.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(selected ? activeIcon : icon, size: 21, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: -0.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

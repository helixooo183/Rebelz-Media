import 'package:flutter/material.dart';

import '../../../core/theme/brand_assets.dart';

/// Giriş/kayıt ekranlarının ortak kabuğu.
///
/// Koyu zemin (#0A0A0A) + üstte grunge banner ve **büyük fırça logo**;
/// altında başlık, açıklama ve form. Tüm ekran kaydırılabilir, üstteki
/// banner içerikle birlikte yukarı kayar.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    this.footer,
    this.children,
    this.bannerHeight,
    this.logoHeight = 96,
  }) : assert(
          children != null || footer != null,
          'AuthScaffold en az bir içerik ya da alt bilgi bekler.',
        );

  final String title;
  final String subtitle;
  final Widget? footer;
  final List<Widget>? children;

  /// Banner yüksekliği (null → ekran yüksekliğinin ~%30'u).
  final double? bannerHeight;

  /// Banner üzerindeki logo yüksekliği.
  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final banner = bannerHeight ?? (size.height * 0.28).clamp(196.0, 280.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 28 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Banner(
              height: banner,
              topInset: topInset,
              logoHeight: logoHeight,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.9,
                      color: Color(0xFFF7F7F8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Color(0xFF9B9BA4),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (children != null) ...children!,
                  if (footer != null) ...[
                    const SizedBox(height: 14),
                    footer!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Üst banner: grunge doku + ortada büyük fırça logo, alta doğru kararır.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.height,
    required this.topInset,
    required this.logoHeight,
  });

  final double height;
  final double topInset;
  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            BrandAssets.banner,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
          // Banner'ı ekran zeminine bağlayan geçiş.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0A0A0A).withValues(alpha: 0.85),
                  const Color(0xFF0A0A0A).withValues(alpha: 0.10),
                  const Color(0xFF0A0A0A).withValues(alpha: 0.55),
                  const Color(0xFF0A0A0A),
                ],
                stops: const [0, 0.32, 0.72, 1],
              ),
            ),
          ),
          // Yanlardan hafif karartma (logo kontrastı).
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.45),
                ],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: topInset + 6,
            bottom: 18,
            child: Center(
              child: Image.asset(
                BrandAssets.brush,
                height: logoHeight,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                semanticLabel: 'Rebelz Media',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

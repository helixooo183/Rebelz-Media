import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Avatar renk paleti (profil düzenlemede seçilir).
abstract final class AvatarPalette {
  static const List<List<Color>> gradients = [
    [AppColors.brand, Color(0xFF7F0D17)],
    [Color(0xFFFF6B4A), Color(0xFFC2185B)],
    [Color(0xFF7C5CFF), Color(0xFF3B2A9E)],
    [Color(0xFF22D3EE), Color(0xFF1D4ED8)],
    [Color(0xFF34D399), Color(0xFF0F766E)],
    [Color(0xFFFBBF24), Color(0xFFEA580C)],
    [Color(0xFF94A3B8), Color(0xFF334155)],
  ];

  static List<Color> of(int index) {
    if (index < 0 || index >= gradients.length) return gradients.first;
    return gradients[index];
  }
}

/// İsimden deterministik bir avatar rengi üretir (grup mesajlarında gönderen
/// adı rengi için).
Color avatarColorFor(String name) {
  if (name.trim().isEmpty) return AvatarPalette.gradients.first.first;
  var hash = 0;
  for (final rune in name.trim().runes) {
    hash = (hash * 31 + rune) & 0x7fffffff;
  }
  return AvatarPalette.gradients[hash % AvatarPalette.gradients.length].first;
}

/// Avatar: profil fotoğrafı → emoji → baş harf sırasıyla gösterilir.
///
/// [ring] true ise etrafında marka rengi halka çizilir (hikâye/aktif).
/// [online] true ise sağ altta yeşil nokta görünür.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.photoUrl,
    this.emoji,
    this.colorIndex = 0,
    this.ring = false,
    this.online = false,
    this.isGroup = false,
    this.highlighted = false,
  });

  final String name;
  final double size;
  final String? photoUrl;
  final String? emoji;
  final int colorIndex;
  final bool ring;
  final bool online;
  final bool isGroup;

  /// Eski çağrılarla uyumluluk: marka gradyanlı halka.
  final bool highlighted;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  bool get _hasPhoto => (photoUrl ?? '').trim().isNotEmpty;

  /// Galeriden seçilen fotoğraflar `data:image/…;base64,…` biçiminde saklanır.
  bool get _isDataUri => (photoUrl ?? '').trim().startsWith('data:image/');

  bool get _hasEmoji => !_hasPhoto && (emoji ?? '').trim().isNotEmpty;

  /// `data:` URI'sini çözer; bozuksa `null` (baş harfe düşülür).
  static Uint8List? _decodeDataUri(String uri) {
    final comma = uri.indexOf(',');
    if (comma < 0 || comma + 1 >= uri.length) return null;
    try {
      return base64Decode(uri.substring(comma + 1));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = isGroup ? size * 0.32 : size / 2;

    final core = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: size,
        width: size,
        child: _hasPhoto ? _photo(context, radius) : _fallback(context, radius),
      ),
    );

    final showRing = ring || highlighted;

    return SizedBox(
      height: size + (showRing ? 6 : 0),
      width: size + (showRing ? 6 : 0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (showRing)
            Container(
              height: size + 6,
              width: size + 6,
              decoration: BoxDecoration(
                shape: isGroup ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isGroup
                    ? BorderRadius.circular(radius + 3)
                    : null,
                gradient: AppColors.brandGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          if (showRing)
            Container(
              height: size + 1,
              width: size + 1,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: isGroup ? BoxShape.rectangle : BoxShape.circle,
                borderRadius:
                    isGroup ? BorderRadius.circular(radius + 1) : null,
              ),
            ),
          core,
          if (online)
            Positioned(
              right: showRing ? 2 : 0,
              bottom: showRing ? 2 : 0,
              child: Container(
                height: size * 0.28,
                width: size * 0.28,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Fotoğraf: base64 (galeri) ise `Image.memory`, değilse `Image.network`.
  Widget _photo(BuildContext context, double radius) {
    final source = photoUrl!.trim();

    if (_isDataUri) {
      final bytes = _decodeDataUri(source);
      if (bytes == null) return _fallback(context, radius);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _fallback(context, radius),
      );
    }

    return Image.network(
      source,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _fallback(context, radius),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: context.cardHigh,
          alignment: Alignment.center,
          child: SizedBox(
            height: size * 0.3,
            width: size * 0.3,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }

  Widget _fallback(BuildContext context, double radius) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AvatarPalette.of(colorIndex),
        ),
      ),
      child: _hasEmoji
          ? Text(
              (emoji ?? '').trim(),
              style: TextStyle(fontSize: size * 0.46),
            )
          : Text(
              _initial,
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
    );
  }
}

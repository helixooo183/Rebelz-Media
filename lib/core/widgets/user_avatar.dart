import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Avatar renk paleti (profil düzenlemede seçilir).
abstract final class AvatarPalette {
  static const List<List<Color>> gradients = [
    [AppColors.primary, Color(0xFFB15CFF)],
    [Color(0xFF22D3EE), Color(0xFF3B82F6)],
    [Color(0xFF34D399), Color(0xFF10B981)],
    [Color(0xFFFF5C7A), Color(0xFFF97316)],
    [Color(0xFFFBBF24), Color(0xFFF97316)],
    [Color(0xFF64748B), Color(0xFF334155)],
  ];

  static List<Color> of(int index) {
    if (index < 0 || index >= gradients.length) return gradients.first;
    return gradients[index];
  }
}

/// Avatar: profil fotoğrafı → emoji → baş harf sırasıyla gösterilir.
///
/// `photoUrl` yüklenemezse (ağ hatası, silinmiş görsel) sessizce emoji/baş
/// harfe düşer; bu yüzden internete bağımlı olmadan da çalışır.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.highlighted = false,
    this.photoUrl,
    this.emoji,
    this.colorIndex = 0,
  });

  final String name;
  final double size;
  final bool highlighted;

  /// Profil fotoğrafı adresi (http/https). Boşsa emoji/baş harf çizilir.
  final String? photoUrl;

  /// Fotoğraf yoksa gösterilecek emoji (ör. "🐺").
  final String? emoji;

  /// [AvatarPalette.gradients] içindeki renk indeksi.
  final int colorIndex;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  bool get _hasPhoto => (photoUrl ?? '').trim().isNotEmpty;

  bool get _hasEmoji => !_hasPhoto && (emoji ?? '').trim().isNotEmpty;

  String get _emoji => (emoji ?? '').trim();

  @override
  Widget build(BuildContext context) {
    final gradient = highlighted
        ? AppColors.primaryGradient
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AvatarPalette.of(colorIndex),
          );

    final fallback = Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        border: highlighted
            ? null
            : Border.all(color: AppColors.outline, width: 1),
      ),
      child: _hasEmoji
          ? Text(
              _emoji,
              style: TextStyle(fontSize: size * 0.46),
            )
          : Text(
              _initial,
              style: TextStyle(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w700,
                color: highlighted ? Colors.white : AppColors.textPrimary,
              ),
            ),
    );

    if (!_hasPhoto) return fallback;

    return ClipOval(
      child: Image.network(
        photoUrl!.trim(),
        height: size,
        width: size,
        fit: BoxFit.cover,
        // Özel fotoğraf varsa da hata durumunda renkli baş harfe dön.
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: size,
            width: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceHigh,
            ),
            child: SizedBox(
              height: size * 0.35,
              width: size * 0.35,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }
}

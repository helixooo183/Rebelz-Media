import 'package:flutter/material.dart';

import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/user_repository.dart';
import '../domain/user_profile.dart';

/// Profil düzenleme: görünen ad, kullanıcı adı, hakkında, fotoğraf/emoji/renk.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profile,
    this.repository,
  });

  final UserProfile profile;
  final UserRepository? repository;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final UserRepository _users = widget.repository ?? userRepositoryInstance;

  late final _nameController =
      TextEditingController(text: widget.profile.displayName);
  late final _usernameController =
      TextEditingController(text: widget.profile.username);
  late final _bioController = TextEditingController(text: widget.profile.bio);
  late final _photoController =
      TextEditingController(text: widget.profile.photoUrl);

  late String _emoji = widget.profile.avatarEmoji;
  late int _colorIndex = widget.profile.avatarColor;
  bool _isSaving = false;
  String? _error;

  static const _emojis = [
    '🙂', '😎', '🐺', '🦊', '🐼', '🦁', '🐨', '🐯',
    '🚀', '🎧', '🎮', '⚡', '🌸', '🌙', '🔥', '💎',
  ];

  @override
  void initState() {
    super.initState();
    // Önizleme avatarı yazarken canlı güncellensin.
    for (final controller in [
      _nameController,
      _usernameController,
      _photoController,
    ]) {
      controller.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [
      _nameController,
      _usernameController,
      _photoController,
    ]) {
      controller.removeListener(_onFieldChanged);
    }
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _users.saveProfile(
        displayName: _nameController.text,
        username: _usernameController.text,
        bio: _bioController.text,
        photoUrl: _photoController.text,
        avatarEmoji: _emoji,
        avatarColor: _colorIndex,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil güncellendi.')),
      );
      Navigator.of(context).pop(true);
    } on ProfileException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Profil kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = UserProfile(
      uid: widget.profile.uid,
      displayName: _nameController.text.trim().isEmpty
          ? 'İsimsiz'
          : _nameController.text.trim(),
      username: Username.normalize(_usernameController.text),
      photoUrl: _photoController.text.trim(),
      avatarEmoji: _emoji,
      avatarColor: _colorIndex,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profili düzenle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 44),
        children: [
          Center(
            child: UserAvatar(
              name: preview.displayName,
              size: 96,
              photoUrl: preview.photoUrl,
              emoji: preview.avatarEmoji,
              colorIndex: preview.avatarColor,
              highlighted: true,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              preview.handle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 26),
          AppTextField(
            controller: _nameController,
            hintText: 'Adın Soyadın',
            labelText: 'Görünen ad',
            prefixIcon: Icons.person_outline_rounded,
            maxLines: 1,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _usernameController,
            hintText: 'ör. ayse_y',
            labelText: 'Kullanıcı adı (@ ile aranır)',
            prefixIcon: Icons.alternate_email_rounded,
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          _Hint(
            '3-20 karakter • küçük harf, rakam, alt çizgi. '
            'Başkaları seni bu adla bulur.',
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _bioController,
            hintText: 'Kendinden kısa bir not (isteğe bağlı)',
            labelText: 'Hakkında',
            prefixIcon: Icons.notes_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Avatar'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final emoji in _emojis)
                _EmojiChip(
                  emoji: emoji,
                  selected: _emoji == emoji,
                  onTap: () => setState(
                    () => _emoji = _emoji == emoji ? '' : emoji,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < AvatarPalette.gradients.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _colorIndex = i),
                  child: Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: AvatarPalette.of(i),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: _colorIndex == i
                            ? context.colors.onSurface
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: _colorIndex == i
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _photoController,
            hintText: 'https://… (isteğe bağlı)',
            labelText: 'Profil fotoğrafı bağlantısı',
            prefixIcon: Icons.image_outlined,
            keyboardType: TextInputType.url,
            maxLines: 1,
          ),
          const SizedBox(height: 6),
          _Hint(
            'Fotoğraf bağlantısı varsa avatar yerine o gösterilir. '
            'Boş bırakırsan seçtiğin emoji ve renk kullanılır.',
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.colors.error.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 13, color: context.colors.error),
              ),
            ),
          ],
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Kaydet',
            icon: Icons.check_rounded,
            isLoading: _isSaving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, height: 1.4, color: context.muted),
      ),
    );
  }
}

class _EmojiChip extends StatelessWidget {
  const _EmojiChip({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        width: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.colors.primaryContainer : context.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? context.colors.primary : context.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

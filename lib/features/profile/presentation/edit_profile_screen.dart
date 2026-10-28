import 'package:flutter/material.dart';

import '../../../core/services/firestore_errors.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/user_repository.dart';
import '../domain/user_profile.dart';

/// Profil düzenleme: görünen ad, kullanıcı adı (kotalı), hakkında ve
/// **galeriden seçilen** profil fotoğrafı.
///
/// Avatar için emoji/renk panelleri ve bağlantı (URL) alanı kaldırıldı:
/// kullanıcı yalnızca galerisinden bir fotoğraf seçer (veya kaldırır).
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

  /// Fotoğraf artık `data:image/…;base64,…` (galeri) ya da eski `https://…`.
  late String _photo = widget.profile.photoUrl;

  bool _isSaving = false;
  bool _isPickingPhoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Önizleme avatarı yazarken canlı güncellensin.
    for (final controller in [_nameController, _usernameController]) {
      controller.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final controller in [_nameController, _usernameController]) {
      controller.removeListener(_onFieldChanged);
    }
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// Kullanıcı adı uzatmasında yazılan ad, kayıtlı addan farklı mı?
  bool get _usernameEditing =>
      Username.normalize(_usernameController.text) != widget.profile.username;

  /// Bu değişiklik bir hak harcayacak mı? (ilk kez ad almak harcamaz.)
  bool get _usernameChangeCounts =>
      widget.profile.username.isNotEmpty && _usernameEditing;

  /// Kalan hak; düzenleme sırasında harcanacak hak düşülmüş hâli.
  int get _remainingUsernameRights {
    final base = widget.profile.kalanKullaniciAdiHakki;
    if (!_usernameChangeCounts) return base;
    final left = base - 1;
    return left < 0 ? 0 : left;
  }

  bool get _usernameLocked => !_usernameEditing && widget.profile.kullaniciAdiKilitli;

  Future<void> _pickPhoto() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isPickingPhoto = true;
      _error = null;
    });

    try {
      final picked = await MediaService.instance.pickAvatar();
      if (!mounted || picked == null) return;
      final dataUri = picked.dataUri;
      if (dataUri.length > UserRepository.maxPhotoLength) {
        setState(() {
          _error = 'Seçilen fotoğraf çok büyük. Daha küçük bir fotoğraf dene.';
        });
        return;
      }
      setState(() => _photo = dataUri);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Fotoğraf seçilemedi: ${friendlyFirestoreError(e)}');
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _removePhoto() {
    setState(() => _photo = '');
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
        photoUrl: _photo,
        // Avatar artık fotoğraftan geliyor; eski emoji/renk alanları
        // olduğu gibi korunur (fotoğraf kaldırılırsa geri döner).
        avatarEmoji: widget.profile.avatarEmoji,
        avatarColor: widget.profile.avatarColor,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil güncellendi.')),
      );
      Navigator.of(context).pop(true);
    } on ProfileException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Profil kaydedilemedi: ${friendlyFirestoreError(e)}');
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
      photoUrl: _photo,
      avatarEmoji: widget.profile.avatarEmoji,
      avatarColor: widget.profile.avatarColor,
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
          const SizedBox(height: 14),
          // ---- galeriden fotoğraf -------------------------------------------
          Center(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _PhotoButton(
                  label: _photo.isEmpty
                      ? 'Galeriden fotoğraf seç'
                      : 'Fotoğrafı değiştir',
                  icon: Icons.photo_library_rounded,
                  busy: _isPickingPhoto,
                  onTap: _isPickingPhoto ? null : _pickPhoto,
                ),
                if (_photo.isNotEmpty)
                  TextButton(
                    onPressed: _isPickingPhoto ? null : _removePhoto,
                    style: TextButton.styleFrom(
                      foregroundColor: context.muted,
                      textStyle: Theme.of(context).textTheme.labelLarge,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Fotoğrafı kaldır'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
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
            enabled: !_usernameLocked,
          ),
          const SizedBox(height: 6),
          const _Hint(
            '3-20 karakter • küçük harf, rakam, alt çizgi. '
            'Başkaları seni bu adla bulur.',
          ),
          const SizedBox(height: 8),
          _UsernameQuota(
            kalanHak: _remainingUsernameRights,
            kilitli: widget.profile.kullaniciAdiKilitli,
            yeniHakTarihi: widget.profile.yeniKullaniciAdiHakki,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _bioController,
            hintText: 'Kendinden kısa bir not (isteğe bağlı)',
            labelText: 'Hakkında',
            prefixIcon: Icons.notes_rounded,
            maxLines: 3,
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

/// Kullanıcı adı kotası satırı: kalan hak ya da yeni hakkın tarihi.
class _UsernameQuota extends StatelessWidget {
  const _UsernameQuota({
    required this.kalanHak,
    required this.kilitli,
    required this.yeniHakTarihi,
  });

  final int kalanHak;
  final bool kilitli;
  final DateTime? yeniHakTarihi;

  @override
  Widget build(BuildContext context) {
    final kapali = kilitli && kalanHak <= 0;
    final renk = kapali ? context.colors.error : context.muted;
    final metin = kapali
        ? 'Kullanıcı adını ${UsernameChangePolicy.maxChanges} kez değiştirdin. '
            'Yeni hak ${UsernameChangePolicy.waitText(yeniHakTarihi)} açılır.'
        : 'Kullanıcı adı değişiklik hakkı: $kalanHak/'
            '${UsernameChangePolicy.maxChanges} · '
            '${UsernameChangePolicy.windowDays} günde '
            '${UsernameChangePolicy.maxChanges} hak';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          kapali ? Icons.lock_clock_rounded : Icons.autorenew_rounded,
          size: 14,
          color: renk,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            metin,
            style: TextStyle(fontSize: 12, height: 1.35, color: renk),
          ),
        ),
      ],
    );
  }
}

/// Galeri düğmesi: koyu yüzey + marka rengi ikon.
class _PhotoButton extends StatelessWidget {
  const _PhotoButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.primary,
                  ),
                )
              else
                Icon(icon, size: 18, color: context.colors.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.onSurface,
                ),
              ),
            ],
          ),
        ),
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

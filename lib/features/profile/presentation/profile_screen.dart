import 'package:flutter/material.dart';

import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/verify_email_banner.dart';
import '../data/user_repository.dart';
import '../domain/legal_texts.dart';
import '../domain/user_profile.dart';
import 'blocked_users_screen.dart';
import 'edit_profile_screen.dart';
import 'terms_sheet.dart';

/// Kullanıcının kendi profili: düzenleme, engellenenler, koşullar, çıkış.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.repository});

  final UserRepository? repository;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSigningOut = false;

  UserRepository? _users;

  UserRepository? get _userRepo {
    if (widget.repository != null) return widget.repository;
    try {
      return _users ??= userRepositoryInstance;
    } catch (_) {
      return null;
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Çıkış yap'),
        content: const Text('Hesabından çıkmak istediğine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Çıkış yap'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSigningOut = true);
    await authServiceInstance.signOut();
    // GoRouter redirect oturumun kapandığını görüp login'e yönlendirir.
  }

  Future<void> _editProfile(UserProfile profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => EditProfileScreen(profile: profile),
      ),
    );
  }

  Future<void> _openBlocked() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BlockedUsersScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = authServiceInstance.currentUser;
    final providers = user?.providerData
            .map((info) => info.providerId)
            .where((id) => id.isNotEmpty)
            .toSet() ??
        const <String>{};
    final signInMethod = providers.contains('google.com')
        ? (providers.length > 1 ? 'Google + E-posta' : 'Google')
        : 'E-posta / şifre';

    final stream = _userRepo?.watchMyProfile();

    return StreamBuilder<UserProfile?>(
      stream: stream,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.displayName ??
            (user?.displayName?.trim().isNotEmpty == true
                ? user!.displayName!.trim()
                : authServiceInstance.displayName);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profil'),
            actions: [
              IconButton(
                tooltip: 'Profili düzenle',
                onPressed: profile == null ? null : () => _editProfile(profile),
                icon: const Icon(Icons.edit_outlined),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          name: name,
                          size: 64,
                          highlighted: true,
                          photoUrl: profile?.photoUrl,
                          emoji: profile?.avatarEmoji,
                          colorIndex: profile?.avatarColor ?? 0,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                profile?.handle ?? '@kullanıcıadıyok',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user?.email ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if ((profile?.bio ?? '').isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        profile!.bio,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed:
                          profile == null ? null : () => _editProfile(profile),
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Profili düzenle'),
                    ),
                  ],
                ),
              ),
              const VerifyEmailBanner(showWhenVerified: false),
              const SizedBox(height: 20),
              const _SectionLabel('Hesap'),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.login_outlined,
                label: 'Giriş yöntemi',
                value: signInMethod,
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.alternate_email,
                label: 'Kullanıcı adı',
                value: profile?.username.isEmpty ?? true
                    ? 'Belirlenmedi'
                    : profile!.handle,
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.verified_user_outlined,
                label: 'E-posta doğrulandı',
                value: (user?.emailVerified ?? false) ? 'Evet' : 'Hayır',
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.badge_outlined,
                label: 'Kullanıcı kimliği',
                value: user?.uid ?? '—',
              ),
              const SizedBox(height: 20),
              const _SectionLabel('Güvenlik ve gizlilik'),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.block_outlined,
                label: 'Engellenenler',
                onTap: _openBlocked,
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.description_outlined,
                label: 'Kullanım koşulları',
                trailing: 'Sürüm ${LegalTexts.version}',
                onTap: () => showTermsSheet(context),
              ),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.fact_check_outlined,
                label: 'Koşullar kabul edildi',
                value: profile?.termsAccepted == true
                    ? _formatDate(profile!.termsAcceptedAt)
                    : 'Hayır',
              ),
              const SizedBox(height: 28),
              GradientButton(
                label: 'Çıkış yap',
                icon: Icons.logout,
                isLoading: _isSigningOut,
                onPressed: _signOut,
              ),
              const SizedBox(height: 24),
              const Text(
                'Sohbet • v0.2.0\n'
                'Firebase Auth (Google + E-posta) · Cloud Firestore',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Evet';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 14.5),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
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
    await authServiceOrNull?.signOut();
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
    // Test/önizleme ortamında Firebase yoksa null döner.
    final auth = authServiceOrNull;
    final user = auth?.currentUser;
    final providers = user?.providerData
            .map((info) => info.providerId)
            .where((id) => id.isNotEmpty)
            .toSet() ??
        const <String>{};
    final signInMethod = providers.contains('google.com')
        ? (providers.length > 1 ? 'Google + E-posta' : 'Google')
        : 'E-posta / şifre';

    final stream = _userRepo?.watchMyProfile();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            tooltip: 'Çıkış yap',
            onPressed: _isSigningOut ? null : _signOut,
            icon: const Icon(Icons.logout_rounded, size: 21),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<UserProfile?>(
        stream: stream,
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final name = profile?.displayName ??
              (user?.displayName?.trim().isNotEmpty == true
                  ? user!.displayName!.trim()
                  : currentUserNameOrNull ?? 'Kullanıcı');

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
            children: [
              _ProfileHeader(
                name: name,
                profile: profile,
                email: user?.email ?? '',
                onEdit: profile == null ? null : () => _editProfile(profile),
              ),
              const SizedBox(height: 14),
              const VerifyEmailBanner(),
              const SectionHeader(title: 'Hesap'),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.alternate_email_rounded,
                    label: 'Kullanıcı adı',
                    value: (profile?.username.isEmpty ?? true)
                        ? 'Belirlenmedi'
                        : profile!.handle,
                  ),
                  _SettingsTile(
                    icon: Icons.login_rounded,
                    label: 'Giriş yöntemi',
                    value: signInMethod,
                  ),
                  _SettingsTile(
                    icon: Icons.mark_email_read_outlined,
                    label: 'E-posta doğrulandı',
                    value: (user?.emailVerified ?? false) ? 'Evet' : 'Hayır',
                  ),
                ],
              ),
              const SectionHeader(title: 'Güvenlik ve gizlilik'),
              _SettingsGroup(
                children: [
                  _ActionTile(
                    icon: Icons.block_rounded,
                    label: 'Engellenenler',
                    onTap: _openBlocked,
                  ),
                  _ActionTile(
                    icon: Icons.description_outlined,
                    label: 'Kullanım koşulları',
                    trailing: 'Sürüm ${LegalTexts.version}',
                    onTap: () => showTermsSheet(context),
                  ),
                  _SettingsTile(
                    icon: Icons.fact_check_outlined,
                    label: 'Koşullar kabul edildi',
                    value: profile?.termsAccepted == true
                        ? _formatDate(profile!.termsAcceptedAt)
                        : 'Hayır',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Çıkış yap',
                icon: Icons.logout_rounded,
                isLoading: _isSigningOut,
                onPressed: _signOut,
              ),
              const SizedBox(height: 22),
              Text(
                'Rebelz Media · v0.3.0\n'
                'Firebase Auth (Google + E-posta) · Cloud Firestore',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.profile,
    required this.email,
    required this.onEdit,
  });

  final String name;
  final UserProfile? profile;
  final String email;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.texts.headlineMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile?.handle ?? '@kullanıcıadıyok',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.colors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            UserAvatar(
              name: name,
              size: 66,
              photoUrl: profile?.photoUrl,
              emoji: profile?.avatarEmoji,
              colorIndex: profile?.avatarColor ?? 0,
              highlighted: true,
            ),
          ],
        ),
        if ((profile?.bio ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            profile!.bio,
            style: TextStyle(fontSize: 14, height: 1.5, color: context.muted),
          ),
        ],
        if (email.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.mail_outline_rounded,
                size: 15,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: context.muted),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('Profili düzenle'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 46),
            side: BorderSide(color: context.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, indent: 50, color: context.line),
          ],
        ],
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 19, color: context.colors.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 14.5))),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(fontSize: 12, color: context.muted),
              ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 19, color: context.muted),
          ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 19, color: context.colors.onSurfaceVariant),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14.5))),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12.5, color: context.muted),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSigningOut = false;

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

  @override
  Widget build(BuildContext context) {
    final user = authServiceInstance.currentUser;
    final name = authServiceInstance.displayName;
    final providers = user?.providerData
            .map((info) => info.providerId)
            .where((id) => id.isNotEmpty)
            .toSet() ??
        const <String>{};
    final signInMethod = providers.contains('google.com')
        ? (providers.length > 1 ? 'Google + E-posta' : 'Google')
        : 'E-posta / şifre';

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
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
            child: Row(
              children: [
                UserAvatar(name: name, size: 60, highlighted: true),
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
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Hesap',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.login_outlined,
            label: 'Giriş yöntemi',
            value: signInMethod,
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.badge_outlined,
            label: 'Kullanıcı kimliği',
            value: user?.uid ?? '—',
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.verified_user_outlined,
            label: 'E-posta doğrulandı',
            value: (user?.emailVerified ?? false) ? 'Evet' : 'Hayır',
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
            'Sohbet • v0.1.0\nFirebase Auth (Google + E-posta) · Cloud Firestore',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
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

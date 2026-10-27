import 'package:flutter/material.dart';

import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/user_repository.dart';
import '../domain/user_profile.dart';

/// Engellenen kullanıcılar listesi; buradan engel kaldırılabilir.
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key, this.repository});

  final UserRepository? repository;

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late final UserRepository _users = widget.repository ?? userRepositoryInstance;

  List<UserProfile> _profiles = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profiles = await _users.fetchBlockedProfiles();
      if (!mounted) return;
      setState(() => _profiles = profiles);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Liste yüklenemedi: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unblock(UserProfile profile) async {
    try {
      await _users.unblockUser(profile.uid);
      if (!mounted) return;
      setState(() {
        _profiles = _profiles.where((p) => p.uid != profile.uid).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${profile.displayName} engeli kaldırıldı.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Engel kaldırılamadı: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Engellenenler')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Yüklenemedi',
                  message: _error!,
                )
              : _profiles.isEmpty
                  ? const EmptyState(
                      icon: Icons.block_outlined,
                      title: 'Engellenen kimse yok',
                      message: 'Bir sohbetteki menüden kişiyi engelleyebilirsin. '
                          'Engellediğin kişiler burada listelenir.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: _profiles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final profile = _profiles[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              UserAvatar(
                                name: profile.displayName,
                                size: 42,
                                photoUrl: profile.photoUrl,
                                emoji: profile.avatarEmoji,
                                colorIndex: profile.avatarColor,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      profile.handle,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => _unblock(profile),
                                child: const Text('Engeli kaldır'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

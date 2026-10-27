import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/verify_email_banner.dart';
import '../../profile/data/user_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/presentation/edit_profile_screen.dart';
import '../../profile/presentation/terms_sheet.dart';
import '../data/chat_repository.dart';
import '../domain/models/chat_room.dart';
import 'new_chat_sheet.dart';

/// Sohbet listesi: kullanıcı adıyla yeni sohbet, sohbet silme, engelleme
/// ve e-posta/koşul hatırlatmaları.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({
    super.key,
    this.repository,
    this.userRepository,
    this.currentUserName,
    this.myUid,
  });

  /// Test/önizleme için enjekte edilebilir bağımlılıklar.
  /// null ise global servis kaydı kullanılır.
  final ChatRepository? repository;
  final UserRepository? userRepository;
  final String? currentUserName;
  final String? myUid;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  late final ChatRepository _repository =
      widget.repository ?? chatRepositoryInstance;

  /// Firebase başlatılmamış (önizleme/test) ortamda `null` döner.
  late final UserRepository? _users = _resolveUsers();

  late final String _currentUserName =
      widget.currentUserName ?? currentUserNameOrNull ?? 'Kullanıcı';

  late final String? _myUid = widget.myUid ?? currentUserIdOrNull;

  late final Stream<List<ChatRoom>> _roomsStream = _repository.watchRooms();

  Stream<UserProfile?>? _profileStream;
  bool _termsPromptShown = false;

  UserRepository? _resolveUsers() {
    if (widget.userRepository != null) return widget.userRepository;
    try {
      return userRepositoryInstance;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    if (_users != null && _myUid != null) {
      _profileStream = _users!.watchMyProfile();
    }
  }

  Future<void> _openNewChat() async {
    final roomId = await showNewChatSheet(context);
    if (roomId == null || !mounted) return;
    context.push(AppRoutes.chat(roomId, name: 'Sohbet'));
  }

  Future<void> _deleteChat(ChatRoom room) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Sadece benden kaldır'),
              subtitle: const Text('Karşı tarafın sohbeti silinmez.'),
              onTap: () => Navigator.pop(sheetContext, 'hide'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text('Sohbeti tamamen sil'),
              subtitle: const Text('Tüm mesajlar iki taraftan da silinir.'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Sohbet silinsin mi?'),
          content: const Text(
            'Bu sohbet ve içindeki tüm mesajlar kalıcı olarak silinir. '
            'Bu işlem geri alınamaz.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Sil'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      if (choice == 'delete') {
        await _repository.deleteChat(room.id);
      } else {
        await _repository.hideChat(room.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            choice == 'delete' ? 'Sohbet silindi.' : 'Sohbet listeden kaldırıldı.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem tamamlanamadı: $e')),
      );
    }
  }

  /// Kullanıcı adı yoksa profili düzenlemeye yönlendir.
  Future<void> _promptUsername(UserProfile profile) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kullanıcı adı seç'),
        content: const Text(
          'Başkaları seni bulabilsin diye bir kullanıcı adı belirle '
          '(ör. ayse_y). Profilinden istediğin zaman değiştirebilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Sonra'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Seç'),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => EditProfileScreen(profile: profile),
        ),
      );
    }
  }

  /// Koşullar kabul edilmemişse (ör. Google ile giriş) onay iste.
  ///
  /// Ekran başına bir kez sorulur; kullanıcı reddederse sohbet özellikleri
  /// kullanılamaz ve uygulama yeniden açıldığında tekrar sorulur.
  Future<void> _promptTerms(UserProfile profile) async {
    var accepted = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Kullanım koşulları'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Devam etmek için kullanım koşullarını ve gizlilik metnini '
                  'kabul etmen gerekiyor. Onayın tarih ve saatle birlikte '
                  'kaydedilir.',
                  style: TextStyle(fontSize: 13.5, height: 1.45),
                ),
                const SizedBox(height: 12),
                TermsCheckbox(
                  value: accepted,
                  onChanged: (value) => setDialogState(() => accepted = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Kabul etmiyorum'),
            ),
            FilledButton(
              onPressed:
                  accepted ? () => Navigator.pop(dialogContext, true) : null,
              child: const Text('Kabul ediyorum'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        await _users?.acceptTerms();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Onay kaydedilemedi: $e')),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Koşulları kabul etmeden sohbet özelliklerini kullanamazsın.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _profileStream,
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final displayName = profile?.displayName ?? _currentUserName;

        // Koşullar kabul edilmemişse bir kez sor.
        if (profile != null && !profile.termsAccepted && !_termsPromptShown) {
          // Bayrak build sırasında işaretlenir ki tekrar tekrar diyalog
          // açılmasın (diyalog ilk kare çizildikten sonra açılır).
          _termsPromptShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _promptTerms(profile);
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sohbetler'),
            actions: [
              IconButton(
                tooltip: 'Profil',
                onPressed: () => context.go(AppRoutes.profile),
                icon: UserAvatar(
                  name: displayName,
                  size: 34,
                  highlighted: true,
                  photoUrl: profile?.photoUrl,
                  emoji: profile?.avatarEmoji,
                  colorIndex: profile?.avatarColor ?? 0,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openNewChat,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Yeni sohbet'),
          ),
          body: Column(
            children: [
              const VerifyEmailBanner(),
              if (profile != null && profile.username.isEmpty)
                _UsernamePrompt(onTap: () => _promptUsername(profile)),
              Expanded(
                child: StreamBuilder<List<ChatRoom>>(
                  stream: _roomsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Sohbetler yüklenemedi',
                        message: '${snapshot.error}',
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final rooms = snapshot.data!;
                    if (rooms.isEmpty) {
                      return const EmptyState(
                        icon: Icons.forum_outlined,
                        title: 'Henüz sohbet yok',
                        message:
                            'Sağ alttaki "Yeni sohbet" butonuyla bir kullanıcı '
                            'adı ara ve sohbeti başlat.',
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: rooms.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return _RoomTile(
                          room: room,
                          onTap: () => context.push(
                            AppRoutes.chat(room.id, name: room.name),
                          ),
                          onLongPress: () => _deleteChat(room),
                          onMenu: () => _deleteChat(room),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UsernamePrompt extends StatelessWidget {
  const _UsernamePrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.alternate_email, size: 20, color: AppColors.secondary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Henüz kullanıcı adın yok. Ekleyince başkaları seni bulabilir.',
              style: TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
          TextButton(onPressed: onTap, child: const Text('Ekle')),
        ],
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
  });

  final ChatRoom room;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Row(
            children: [
              UserAvatar(
                name: room.name,
                size: 46,
                photoUrl: room.photoUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            room.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(room.lastMessageAt),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      room.preview,
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
              PopupMenuButton<String>(
                tooltip: 'Sohbet seçenekleri',
                icon: const Icon(
                  Icons.more_vert,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                onSelected: (_) => onMenu(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Sohbeti sil'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    return isToday
        ? DateFormat('HH:mm').format(date)
        : DateFormat('dd.MM').format(date);
  }
}

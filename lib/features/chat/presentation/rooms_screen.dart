import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/firestore_errors.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
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

/// Sohbet listesi — Threads'in sade akışı + WhatsApp'ın okunmamış düzeni.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({
    super.key,
    this.repository,
    this.userRepository,
    this.currentUserName,
    this.myUid,
  });

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

  late final UserRepository? _users = _resolveUsers();

  late final String _currentUserName =
      widget.currentUserName ?? currentUserNameOrNull ?? 'Kullanıcı';

  late final String? _myUid = widget.myUid ?? currentUserIdOrNull;

  late final Stream<List<ChatRoom>> _roomsStream = _repository.watchRooms();

  Stream<UserProfile?>? _profileStream;

  /// Kategori sırası; sağa/sola kaydırma bu liste üzerinde ilerler.
  static const List<String> _filters = ['all', 'dm', 'group'];

  String _filter = 'all';
  bool _isAcceptingTerms = false;

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
    final users = _users;
    if (users != null && _myUid != null) {
      _profileStream = users.watchMyProfile();
    }
  }

  Future<void> _openNewChat() async {
    final roomId = await showNewChatSheet(context);
    if (roomId == null || !mounted) return;
    context.push(AppRoutes.chat(roomId, name: 'Sohbet'));
  }

  Future<void> _openChat(ChatRoom room) async {
    await context.push(
      AppRoutes.chat(room.id, name: room.peerName(_myUid)),
    );
  }

  Future<void> _deleteChat(ChatRoom room) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Sadece benden kaldır'),
              subtitle: const Text('Karşı tarafın sohbeti silinmez.'),
              onTap: () => Navigator.pop(sheetContext, 'hide'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: sheetContext.colors.error),
              title: const Text('Sohbeti tamamen sil'),
              subtitle: const Text('Tüm mesajlar iki taraftan da silinir.'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
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
            choice == 'delete'
                ? 'Sohbet silindi.'
                : 'Sohbet listeden kaldırıldı.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem tamamlanamadı: ${friendlyFirestoreError(e)}')),
      );
    }
  }

  Future<void> _promptUsername(UserProfile profile) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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

  /// Kategoriyi bir sağa/sola kaydırır (FAB ve çiplerle aynı davranış).
  void _shiftFilter(int delta) {
    final index = _filters.indexOf(_filter);
    final next = (index + delta).clamp(0, _filters.length - 1);
    if (next == index) return;
    setState(() => _filter = _filters[next]);
  }

  /// Koşullar onayı: tek dokunuşla metin açılır, onay kaydedilir.
  ///
  /// Onay `users/{uid}` dokümanına yazılır; akış güncellendiği anda
  /// hatırlatma kendiliğinden kaybolur (bir daha çıkmaz).
  Future<void> _acceptTerms() async {
    final users = _users;
    if (users == null || _isAcceptingTerms) return;

    var checked = false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kullanım koşulları'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Devam etmek için kullanım koşullarını ve gizlilik '
                  'metnini kabul etmen gerekiyor. Onayın tarih ve saatle '
                  'birlikte kaydedilir.',
                  style: TextStyle(fontSize: 13.5, height: 1.45),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => showTermsSheet(context),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('Metni aç'),
                ),
                TermsCheckbox(
                  value: checked,
                  onChanged: (value) => setDialogState(() => checked = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed:
                  checked ? () => Navigator.pop(dialogContext, true) : null,
              child: const Text('Kabul ediyorum'),
            ),
          ],
        ),
      ),
    );

    if (accepted != true) {
      if (!mounted) return;
      if (accepted == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Koşulları kabul etmeden sohbetleri kullanamazsın.'),
          ),
        );
      }
      return;
    }

    setState(() => _isAcceptingTerms = true);
    try {
      await users.acceptTerms();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koşullar kabul edildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Onay kaydedilemedi: ${friendlyFirestoreError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _isAcceptingTerms = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile?>(
      stream: _profileStream,
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final displayName = profile?.displayName ?? _currentUserName;


        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(
                  name: displayName,
                  photoUrl: profile?.photoUrl,
                  emoji: profile?.avatarEmoji,
                  colorIndex: profile?.avatarColor ?? 0,
                  onProfile: () => context.go(AppRoutes.profile),
                  onSearch: _openNewChat,
                ),
                const VerifyEmailBanner(),
                if (profile != null && !profile.termsAccepted)
                  _TermsBanner(
                    busy: _isAcceptingTerms,
                    onAccept: _acceptTerms,
                  ),
                if (profile != null && profile.username.isEmpty)
                  _UsernamePrompt(onTap: () => _promptUsername(profile)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Row(
                    children: [
                      _FilterPill(
                        label: 'Tümü',
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Kişiler',
                        selected: _filter == 'dm',
                        onTap: () => setState(() => _filter = 'dm'),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Gruplar',
                        selected: _filter == 'group',
                        onTap: () => setState(() => _filter = 'group'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (velocity.abs() < 200) return;
                      // Sağa kaydırma (pozitif) → önceki kategori.
                      _shiftFilter(velocity > 0 ? -1 : 1);
                    },
                    child: StreamBuilder<List<ChatRoom>>(
                    stream: _roomsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'Sohbetler yüklenemedi',
                          message: friendlyFirestoreError(snapshot.error!),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final rooms = snapshot.data!.where((room) {
                        if (_filter == 'dm') return room.isDirect;
                        if (_filter == 'group') return room.isGroup;
                        return true;
                      }).toList();

                      if (rooms.isEmpty) {
                        return EmptyState(
                          icon: Icons.forum_outlined,
                          title: 'Henüz sohbet yok',
                          message:
                              'Kullanıcı adıyla ara ve ilk sohbetini başlat. '
                              'Kanallar sekmesinden topluluklara da katılabilirsin.',
                          actionLabel: 'Sohbet başlat',
                          onAction: _openNewChat,
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                        itemCount: rooms.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final room = rooms[index];
                          return _RoomTile(
                            room: room,
                            myUid: _myUid,
                            onTap: () => _openChat(room),
                            onLongPress: () => _deleteChat(room),
                          );
                        },
                      );
                    },
                    ),
                  ),
                ),
                _FilterDots(
                  count: _filters.length,
                  index: _filters.indexOf(_filter),
                  onSelect: (index) => setState(() => _filter = _filters[index]),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _openNewChat,
            backgroundColor: AppColors.brand,
            foregroundColor: Colors.white,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.edit_outlined, size: 24),
          ),
        );
      },
    );
  }
}

/// Koşullar onaylanmadıysa görünen tek satırlık hatırlatma.
///
/// Onay kaydedildiği anda `watchMyProfile` akışı güncellenir ve bu kart
/// kendiliğinden kaybolur — bir daha gösterilmez.
class _TermsBanner extends StatelessWidget {
  const _TermsBanner({required this.busy, required this.onAccept});

  final bool busy;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: context.colors.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.colors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.gavel_rounded,
            size: 17,
            color: context.colors.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Kullanım koşulları onayı bekliyor.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.3,
                color: context.colors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: busy ? null : onAccept,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: busy
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Kabul et', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

/// Kategori noktaları: kaydırmanın hangi kategoriye geçtiğini gösterir.
class _FilterDots extends StatelessWidget {
  const _FilterDots({
    required this.count,
    required this.index,
    required this.onSelect,
  });

  final int count;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            GestureDetector(
              onTap: () => onSelect(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 5,
                width: i == index ? 18 : 5,
                decoration: BoxDecoration(
                  color: i == index
                      ? context.colors.primary
                      : context.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.onProfile,
    required this.onSearch,
    this.photoUrl,
    this.emoji,
    this.colorIndex = 0,
  });

  final String name;
  final String? photoUrl;
  final String? emoji;
  final int colorIndex;
  final VoidCallback onProfile;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Sohbetler',
              style: context.texts.displaySmall,
            ),
          ),
          IconButton(
            tooltip: 'Yeni sohbet',
            onPressed: onSearch,
            icon: const Icon(Icons.search_rounded, size: 24),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: onProfile,
            child: UserAvatar(
              name: name,
              size: 38,
              photoUrl: photoUrl,
              emoji: emoji,
              colorIndex: colorIndex,
              highlighted: true,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? context.colors.onSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : context.line,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? context.colors.surface : context.muted,
          ),
        ),
      ),
    );
  }
}

class _UsernamePrompt extends StatelessWidget {
  const _UsernamePrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      radius: 16,
      child: Row(
        children: [
          Icon(Icons.alternate_email_rounded, size: 20, color: context.colors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Kullanıcı adın yok. Ekleyince başkaları seni bulabilir.',
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
    required this.myUid,
    required this.onTap,
    required this.onLongPress,
  });

  final ChatRoom room;
  final String? myUid;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final name = room.isDirect ? room.peerName(myUid) : room.name;
    final photo = room.isDirect ? room.peerPhoto(myUid) : room.photoUrl;
    final isMineLast = room.lastSenderId == myUid;
    final typing = room.isPeerTyping(myUid);
    final unread = !isMineLast && room.lastSenderId.isNotEmpty;

    return AppCard(
      onTap: onTap,
      onLongPress: onLongPress,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          UserAvatar(
            name: name,
            size: 50,
            photoUrl: photo,
            isGroup: room.isGroup,
            colorIndex: _colorIndexFor(name),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight:
                              unread ? FontWeight.w800 : FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(room.lastMessageAt),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                        color: unread
                            ? context.colors.primary
                            : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (isMineLast) ...[
                      Icon(
                        room.isReadByPeer(myUid, room.lastMessageAt)
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        size: 15,
                        color: room.isReadByPeer(myUid, room.lastMessageAt)
                            ? context.colors.primary
                            : context.muted,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        typing ? 'yazıyor…' : room.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle:
                              typing ? FontStyle.italic : FontStyle.normal,
                          color: typing
                              ? context.colors.primary
                              : context.muted,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        height: 8,
                        width: 8,
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _colorIndexFor(String name) {
    if (name.trim().isEmpty) return 0;
    var hash = 0;
    for (final rune in name.trim().runes) {
      hash = (hash * 31 + rune) & 0x7fffffff;
    }
    return hash % AvatarPalette.gradients.length;
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) return DateFormat('HH:mm').format(date);
    if (now.difference(date).inDays < 7) {
      const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      return days[date.weekday - 1];
    }
    return DateFormat('dd.MM').format(date);
  }
}

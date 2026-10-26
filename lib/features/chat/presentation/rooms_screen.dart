import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/chat_repository.dart';
import '../domain/models/chat_room.dart';

/// Sohbet odalarının listesi. Firestore akışına bağlıdır.
class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key, this.repository, this.currentUserName});

  /// Test/önizleme için enjekte edilebilir bağımlılıklar.
  /// null ise global servis kaydı kullanılır.
  final ChatRepository? repository;
  final String? currentUserName;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  late final ChatRepository _repository =
      widget.repository ?? chatRepositoryInstance;

  late final String _currentUserName =
      widget.currentUserName ?? authServiceInstance.displayName;

  late final Stream<List<ChatRoom>> _roomsStream = _repository.watchRooms();

  Future<void> _createRoom() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Yeni sohbet'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Sohbet adı'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );

    controller.dispose();

    final trimmed = name?.trim() ?? '';
    if (trimmed.length < 2) return;

    try {
      await _repository.createRoom(trimmed);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sohbet oluşturulamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sohbetler'),
        actions: [
          IconButton(
            tooltip: 'Profil',
            onPressed: () => context.go(AppRoutes.profile),
            icon: UserAvatar(
              name: _currentUserName,
              size: 34,
              highlighted: true,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createRoom,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Yeni sohbet'),
      ),
      body: StreamBuilder<List<ChatRoom>>(
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
                  'Sağ alttaki "Yeni sohbet" butonuyla ilk sohbeti başlat.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: rooms.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _RoomTile(room: rooms[index]),
          );
        },
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room});

  final ChatRoom room;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(
          AppRoutes.chat(room.id, name: room.name),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              UserAvatar(name: room.name, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
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
              const SizedBox(width: 8),
              Text(
                _formatTime(room.lastMessageAt),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
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

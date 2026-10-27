import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../profile/data/user_repository.dart';
import '../data/chat_repository.dart';
import '../domain/models/chat_message.dart';
import '../domain/models/chat_room.dart';

/// Tek bir sohbet odasının mesaj ekranı.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.repository,
    this.currentUserId,
  });

  final String roomId;
  final String roomName;

  /// Test/önizleme için enjekte edilebilir bağımlılıklar.
  final ChatRepository? repository;
  final String? currentUserId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  late final ChatRepository _repository =
      widget.repository ?? chatRepositoryInstance;

  late final String? _myUid =
      widget.currentUserId ?? currentUserIdOrNull;

  late final Stream<List<ChatMessage>> _messagesStream =
      _repository.watchMessages(widget.roomId);

  late final Stream<ChatRoom?> _roomStream = _repository.watchRoom(widget.roomId);

  UserRepository? _users;
  bool _iBlockedPeer = false;
  bool _isBusy = false;
  bool _isSending = false;

  /// Karşı tarafın uid'si (yalnızca doğrudan sohbetlerde).
  String? _peerUid;

  UserRepository? get _userRepo {
    if (_users != null) return _users;
    try {
      return _users = userRepositoryInstance;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBlockState();
  }

  Future<void> _loadBlockState() async {
    final repo = _userRepo;
    if (repo == null || _myUid == null) return;
    try {
      final room = await _repository.watchRoom(widget.roomId).first;
      final peer = room?.peerUid(_myUid);
      if (peer == null) return;
      final blocked = await repo.fetchBlockedUids();
      if (!mounted) return;
      setState(() {
        _peerUid = peer;
        _iBlockedPeer = blocked.contains(peer);
      });
    } catch (_) {
      // Engel durumu okunamazsa sohbet normal çalışır.
    }
  }

  Future<void> _toggleBlock({required bool block}) async {
    final repo = _userRepo;
    if (repo == null || _peerUid == null) return;

    if (block) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Kişiyi engelle'),
          content: Text(
            '${widget.roomName} senden mesaj gönderemez ve sohbetiniz '
            'listenden kaldırılır. Engeli istediğin zaman kaldırabilirsin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Engelle'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isBusy = true);
    try {
      if (block) {
        await repo.blockUser(_peerUid!);
        await _repository.hideChat(widget.roomId);
      } else {
        await repo.unblockUser(_peerUid!);
      }
      if (!mounted) return;
      setState(() => _iBlockedPeer = block);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            block ? 'Kişi engellendi.' : 'Engel kaldırıldı.',
          ),
        ),
      );
      if (block) Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('İşlem tamamlanamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sohbet silinsin mi?'),
        content: const Text(
          'Bu sohbet ve tüm mesajları kalıcı olarak silinir. '
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

    setState(() => _isBusy = true);
    try {
      await _repository.deleteChat(widget.roomId);
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sohbet silinemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _repository.sendMessage(widget.roomId, text);
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _messageController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ChatException ? e.message : 'Mesaj gönderilemedi: $e',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: StreamBuilder<ChatRoom?>(
          stream: _roomStream,
          builder: (context, roomSnapshot) {
            final room = roomSnapshot.data;
            final name = room?.name.isNotEmpty == true ? room!.name : widget.roomName;
            return Row(
              children: [
                UserAvatar(name: name, size: 38, photoUrl: room?.photoUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _iBlockedPeer ? 'engellendi' : 'sohbet',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: _iBlockedPeer
                              ? AppColors.danger
                              : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          if (_peerUid != null)
            PopupMenuButton<String>(
              enabled: !_isBusy,
              tooltip: 'Sohbet seçenekleri',
              onSelected: (value) {
                if (value == 'block') {
                  _toggleBlock(block: !_iBlockedPeer);
                } else if (value == 'delete') {
                  _deleteChat();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'block',
                  child: Text(
                    _iBlockedPeer ? 'Engeli kaldır' : 'Kişiyi engelle',
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Sohbeti sil'),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (_iBlockedPeer)
            Container(
              width: double.infinity,
              color: AppColors.danger.withValues(alpha: 0.12),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.block, size: 18, color: AppColors.danger),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Bu kişiyi engelledin. Mesaj gönderemezsin.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                  TextButton(
                    onPressed: _isBusy ? null : () => _toggleBlock(block: false),
                    child: const Text('Engeli kaldır'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Mesajlar yüklenemedi',
                    message: '${snapshot.error}',
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const EmptyState(
                    icon: Icons.waving_hand_outlined,
                    title: 'İlk mesajı sen yaz',
                    message: 'Bu sohbette henüz mesaj yok. Buzu kırmak için '
                        'aşağıdaki alandan yazabilirsin.',
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.senderId == _myUid;
                    final showAvatar = !isMine &&
                        (index == messages.length - 1 ||
                            messages[index + 1].senderId != message.senderId);

                    return _MessageBubble(
                      message: message,
                      isMine: isMine,
                      showAvatar: showAvatar,
                    );
                  },
                );
              },
            ),
          ),
          _MessageComposer(
            controller: _messageController,
            isSending: _isSending,
            onSend: _send,
            enabled: !_iBlockedPeer,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showAvatar,
  });

  final ChatMessage message;
  final bool isMine;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine)
            SizedBox(
              width: 32,
              child: showAvatar
                  ? UserAvatar(name: message.senderName, size: 30)
                  : null,
            ),
          if (!isMine) const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppColors.bubbleGradient(isMine),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMine ? 18 : 4),
                    bottomRight: Radius.circular(isMine ? 4 : 18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showAvatar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.senderName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    Text(
                      message.text,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: isMine
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        message.createdAt == null
                            ? '  '
                            : DateFormat('HH:mm').format(message.createdAt!),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isMine
                              ? Colors.white.withValues(alpha: 0.75)
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText:
                        enabled ? 'Mesaj yaz…' : 'Engel nedeniyle yazılamaz',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 10),
              _SendButton(
                isSending: isSending,
                onPressed: onSend,
                enabled: enabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isSending,
    required this.onPressed,
    this.enabled = true,
  });

  final bool isSending;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isActive = enabled && !isSending;

    return GestureDetector(
      onTap: isActive ? onPressed : null,
      child: Container(
        height: 48,
        width: 48,
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
          shape: BoxShape.circle,
        ),
        foregroundDecoration: isActive
            ? null
            : BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
        child: isSending
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded, color: Colors.white, size: 21),
      ),
    );
  }
}

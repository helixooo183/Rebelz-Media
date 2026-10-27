import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/media_service.dart';
import '../../../core/services/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../moderation/presentation/report_sheet.dart';
import '../../profile/data/user_repository.dart';
import '../data/chat_repository.dart';
import '../domain/models/chat_message.dart';
import '../domain/models/chat_room.dart';
import 'room_settings_screen.dart';

/// Tek bir sohbet odasının mesaj ekranı.
///
/// WhatsApp alışkanlıkları: balon kuyruğu, alıntılı yanıt, tepkiler,
/// ✓✓ okundu bilgisi, "yazıyor…", fotoğraf ve sesli mesaj.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    this.repository,
    this.userRepository,
    this.currentUserId,
    this.mediaService,
  });

  final String roomId;
  final String roomName;

  /// Test/önizleme için enjekte edilebilir bağımlılıklar.
  final ChatRepository? repository;
  final UserRepository? userRepository;
  final String? currentUserId;
  final MediaService? mediaService;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _composerFocus = FocusNode();
  final _scrollController = ScrollController();

  late final ChatRepository _repository =
      widget.repository ?? chatRepositoryInstance;

  late final String? _myUid = widget.currentUserId ?? currentUserIdOrNull;

  late final Stream<List<ChatMessage>> _messagesStream =
      _repository.watchMessages(widget.roomId);

  late final Stream<ChatRoom?> _roomStream =
      _repository.watchRoom(widget.roomId);

  UserRepository? _users;
  MediaService? _mediaInstance;

  bool _iBlockedPeer = false;
  bool _isBusy = false;
  bool _isSending = false;

  /// Yanıtlanan mesaj (alıntı).
  ChatMessage? _replyTo;

  /// Sesli mesaj kaydı durumu.
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  /// O an oynatılan sesli mesaj.
  String? _playingMessageId;

  /// Karşı tarafın uid'si (yalnızca doğrudan sohbetlerde).
  String? _peerUid;

  Timer? _typingTimer;
  bool _typingSent = false;
  bool _readMarked = false;

  /// "Benden sil" ile gizlenen mesaj kimlikleri (yalnızca bu kullanıcıda).
  Set<String> _hiddenIds = const <String>{};
  StreamSubscription<Set<String>>? _hiddenSub;

  MediaService get _media => _mediaInstance ??= widget.mediaService ??
      MediaService.instance;

  UserRepository? get _userRepo {
    if (widget.userRepository != null) return widget.userRepository;
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
    _messageController.addListener(_onComposerChanged);
    _hiddenSub = _repository.watchHiddenMessageIds(widget.roomId).listen(
      (ids) {
        if (mounted) setState(() => _hiddenIds = ids);
      },
      onError: (_) {
        // Kural/deploy eksikse gizleme olmadan devam et.
      },
    );
  }

  @override
  void dispose() {
    _hiddenSub?.cancel();
    _recordTimer?.cancel();
    _typingTimer?.cancel();
    _messageController.removeListener(_onComposerChanged);
    _messageController.dispose();
    _composerFocus.dispose();
    _scrollController.dispose();
    _mediaInstance?.dispose();
    super.dispose();
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

  // -------------------------------------------------------------- yazıyor…

  void _onComposerChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (!hasText) {
      _typingSent = false;
      return;
    }
    if (!_typingSent) {
      _typingSent = true;
      _repository.setTyping(widget.roomId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _typingSent = false;
      _repository.setTyping(widget.roomId, false);
    });
  }

  // ------------------------------------------------------------------- engel

  Future<void> _toggleBlock({required bool block}) async {
    final repo = _userRepo;
    if (repo == null || _peerUid == null) return;

    if (block) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Kişiyi engelle'),
          content: Text(
            '${widget.roomName} sana mesaj gönderemez ve sohbetiniz '
            'listenden kaldırılır. Engeli istediğin zaman kaldırabilirsin.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: dialogContext.colors.error,
              ),
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
        SnackBar(content: Text(block ? 'Kişi engellendi.' : 'Engel kaldırıldı.')),
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

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomSettingsScreen(
          roomId: widget.roomId,
          repository: widget.repository,
          userRepository: widget.userRepository,
          currentUserId: _myUid,
        ),
      ),
    );
  }

  Future<void> _reportPeer(ChatRoom? room) async {
    final peer = _peerUid;
    if (peer == null) return;
    final sent = await showReportSheet(
      context,
      targetUid: peer,
      targetName: room?.peerName(_myUid) ?? '',
      roomId: widget.roomId,
    );
    if (sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Şikayetin incelemeye iletildi.')),
      );
    }
  }

  Future<void> _reportMessage(ChatMessage message) async {
    final sent = await showReportSheet(
      context,
      targetUid: message.senderId,
      targetName: message.senderName,
      roomId: widget.roomId,
      messageId: message.id,
      messageSnippet: message.text.isNotEmpty
          ? message.text
          : (message.type == 'image' ? '[fotoğraf]' : '[sesli mesaj]'),
      isMessage: true,
    );
    if (sent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj şikayeti iletildi.')),
      );
    }
  }

  /// 5 saniyelik "Geri al" bildirimi (ekranın altından çıkar).
  void _showUndo({
    required String text,
    required Future<void> Function() onUndo,
    String undoLabel = 'Geri al',
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: SnackBarAction(
            label: undoLabel,
            onPressed: () async {
              try {
                await onUndo();
                if (mounted) _toast('Mesaj geri alındı.');
              } catch (e) {
                if (mounted) _toast('Geri alınamadı: $e');
              }
            },
          ),
        ),
      );
  }

  /// "Benden sil": mesaj yalnızca bu kullanıcıda kaybolur.
  Future<void> _hideForMe(ChatMessage message) async {
    try {
      await _repository.hideMessageForMe(widget.roomId, message.id);
      if (!mounted) return;
      setState(() => _hiddenIds = {..._hiddenIds, message.id});
      _showUndo(
        text: 'Mesaj senden gizlendi.',
        onUndo: () async {
          await _repository.unhideMessage(widget.roomId, message.id);
          if (!mounted) return;
          setState(() => _hiddenIds = {..._hiddenIds}..remove(message.id));
        },
      );
    } catch (e) {
      _toast('Mesaj gizlenemedi: $e');
    }
  }

  /// "Herkesten sil": onay ister, sonra tüm üyelerden kaldırır.
  Future<void> _deleteForEveryone(ChatMessage message, {required bool mine}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Herkesten silinsin mi?'),
        content: Text(
          mine
              ? 'Mesaj tüm üyelerden silinecek. 5 saniye içinde geri '
                  'alabilirsin.'
              : 'Bu mesaj tüm üyelerden silinecek (moderatör işlemi). '
                  '5 saniye içinde geri alabilirsin.',
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

    try {
      if (mine) {
        await _repository.deleteMessage(widget.roomId, message.id);
      } else {
        await _repository.deleteMessageAsModerator(widget.roomId, message.id);
      }
      if (!mounted) return;
      _showUndo(
        text: 'Mesaj herkesten silindi.',
        onUndo: () => _repository.restoreMessage(widget.roomId, message),
      );
    } catch (e) {
      _toast('Mesaj silinemedi: $e');
    }
  }

  /// Görsele dokununca tam ekran görüntüleyici.
  void _openImage(ChatMessage message) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ImageViewerScreen(
          bytes: message.mediaBytes,
          senderName: message.senderName,
        ),
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _deleteChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            style: FilledButton.styleFrom(
              backgroundColor: dialogContext.colors.error,
            ),
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

  // ---------------------------------------------------------------- gönderme

  Future<void> _scrollToLatest() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final reply = _replyTo;
    setState(() {
      _isSending = true;
      _replyTo = null;
    });
    _messageController.clear();

    try {
      await _repository.sendMessage(
        widget.roomId,
        text: text,
        reply: reply == null ? null : _replyInfoOf(reply),
      );
      await _scrollToLatest();
    } catch (e) {
      if (!mounted) return;
      _messageController.text = text;
      _snack(e is ChatException ? e.message : 'Mesaj gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  ReplyInfo _replyInfoOf(ChatMessage message) {
    return ReplyInfo(
      id: message.id,
      senderName: message.senderId == _myUid ? 'Sen' : message.senderName,
      preview: message.preview,
    );
  }

  Future<void> _sendPhoto() async {
    try {
      final picked = await _media.pickImage();
      if (picked == null) return;
      setState(() => _isSending = true);
      await _repository.sendMessage(
        widget.roomId,
        type: MessageType.image,
        mediaBase64: picked.base64,
        mediaMime: picked.mime,
        reply: _replyTo == null ? null : _replyInfoOf(_replyTo!),
      );
      if (mounted) setState(() => _replyTo = null);
      await _scrollToLatest();
    } catch (e) {
      if (!mounted) return;
      _snack('Fotoğraf gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _finishRecording();
      return;
    }

    final started = await _media.startRecording();
    if (!started) {
      _snack('Mikrofon izni olmadan sesli mesaj kaydedilemez.');
      return;
    }

    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _recordSeconds++);
    });
  }

  Future<void> _finishRecording() async {
    _recordTimer?.cancel();
    setState(() => _isRecording = false);

    final voice = await _media.stopRecording();
    if (voice == null) {
      _snack('Kayıt alınamadı. Tekrar dene.');
      return;
    }
    if (voice.durationMs < 900) {
      _snack('Çok kısa kayıt. Biraz daha uzun konuş.');
      return;
    }

    setState(() => _isSending = true);
    try {
      await _repository.sendMessage(
        widget.roomId,
        type: MessageType.audio,
        mediaBase64: voice.base64,
        mediaMime: voice.mime,
        durationMs: voice.durationMs,
        reply: _replyTo == null ? null : _replyInfoOf(_replyTo!),
      );
      if (mounted) setState(() => _replyTo = null);
      await _scrollToLatest();
    } catch (e) {
      if (!mounted) return;
      _snack(e is ChatException ? e.message : 'Ses gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await _media.cancelRecording();
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _playVoice(ChatMessage message) async {
    if (message.mediaBase64.isEmpty) return;
    if (_playingMessageId == message.id) {
      await _media.stopPlayback();
      if (mounted) setState(() => _playingMessageId = null);
      return;
    }

    try {
      await _media.playVoice(message.mediaBase64, message.mediaMime);
      if (!mounted) return;
      setState(() => _playingMessageId = message.id);
      _media.finishedStream.listen((_) {
        if (mounted) setState(() => _playingMessageId = null);
      });
    } catch (e) {
      if (mounted) _snack('Ses oynatılamadı: $e');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _markReadIfNeeded(List<ChatMessage> messages) {
    if (_readMarked || messages.isEmpty || _myUid == null) return;
    _readMarked = true;
    _repository.markRead(widget.roomId);
  }

  // ------------------------------------------------------------------ görünüm

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ChatRoom?>(
      stream: _roomStream,
      builder: (context, roomSnapshot) {
        final room = roomSnapshot.data;
        final title = _titleOf(room);
        final subtitle = _subtitleOf(room);

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                UserAvatar(
                  name: title,
                  size: 38,
                  photoUrl: room?.isDirect == true
                      ? room?.peerPhoto(_myUid)
                      : room?.photoUrl,
                  isGroup: room?.isGroup ?? false,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: subtitle.startsWith('yazıyor')
                              ? context.colors.primary
                              : context.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                enabled: !_isBusy,
                tooltip: 'Sohbet seçenekleri',
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (value) {
                  switch (value) {
                    case 'block':
                      _toggleBlock(block: !_iBlockedPeer);
                    case 'delete':
                      _deleteChat();
                    case 'settings':
                      _openSettings();
                    case 'report':
                      _reportPeer(room);
                  }
                },
                itemBuilder: (_) => [
                  if (room != null &&
                      !room.isDirect &&
                      room.hasMember(_myUid))
                    const PopupMenuItem(
                      value: 'settings',
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 19),
                          SizedBox(width: 10),
                          Text('Kanal/grup ayarları'),
                        ],
                      ),
                    ),
                  if (_peerUid != null)
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, size: 19),
                          SizedBox(width: 10),
                          Text('Profili şikayet et'),
                        ],
                      ),
                    ),
                  if (_peerUid != null)
                    PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(
                            _iBlockedPeer
                                ? Icons.lock_open_rounded
                                : Icons.block_rounded,
                            size: 19,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _iBlockedPeer ? 'Engeli kaldır' : 'Kişiyi engelle',
                          ),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 19),
                        SizedBox(width: 10),
                        Text('Sohbeti sil'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              if (_iBlockedPeer) _BlockedBanner(onUnblock: () => _toggleBlock(block: false)),
              if (room?.isChannel == true && room!.paylasabilirMi(_myUid))
                const _ChannelBanner(),
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Mesajlar yüklenemedi',
                        message: '${snapshot.error}',
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!
                        .where((m) => !_hiddenIds.contains(m.id))
                        .toList();
                    _markReadIfNeeded(messages);

                    if (messages.isEmpty) {
                      return EmptyState(
                        icon: Icons.waving_hand_rounded,
                        title: 'İlk mesajı sen yaz',
                        message: room?.isChannel == true
                            ? 'Kanala ilk paylaşımı yap; abonelerin görecek.'
                            : 'Bu sohbette henüz mesaj yok. Buzu kırmak için '
                                'aşağıdaki alandan yazabilirsin.',
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final older =
                            index + 1 < messages.length ? messages[index + 1] : null;
                        final isMine = message.senderId == _myUid;
                        final showAvatar = !isMine &&
                            (older == null || older.senderId != message.senderId);

                        if (message.isSystem) {
                          return _SystemMessage(text: message.displayText);
                        }

                        final canDeleteForEveryone = isMine ||
                            (room != null &&
                                room.moderatorlerMesajSilebilir &&
                                room.yonetebilirMi(_myUid));

                        return _MessageBubble(
                          message: message,
                          isMine: isMine,
                          canDeleteForEveryone: canDeleteForEveryone,
                          onOpenImage: () => _openImage(message),
                          onHideForMe: () => _hideForMe(message),
                          onDeleteForEveryone: () => _deleteForEveryone(
                            message,
                            mine: isMine,
                          ),
                          showAvatar: showAvatar,
                          showSender: room?.isDirect == false && showAvatar,
                          readByPeer: room == null
                              ? false
                              : room.isReadByPeer(_myUid, message.createdAt),
                          isFirstInGroup: older == null ||
                              older.senderId != message.senderId,
                          isPlaying: _playingMessageId == message.id,
                          onPlay: () => _playVoice(message),
                          onReply: () {
                            setState(() => _replyTo = message);
                            _composerFocus.requestFocus();
                          },
                          onReport: () => _reportMessage(message),
                          onReact: (emoji) => _repository.toggleReaction(
                            widget.roomId,
                            message.id,
                            emoji,
                          ),
                          myReaction: message.reactions[_myUid],
                        );
                      },
                    );
                  },
                ),
              ),
              if (_isRecording)
                _RecordingBar(
                  seconds: _recordSeconds,
                  onCancel: _cancelRecording,
                  onSend: _finishRecording,
                )
              else if (room != null && !room.paylasabilirMi(_myUid))
                _ReadOnlyBar(room: room)
              else
                _Composer(
                  controller: _messageController,
                  focusNode: _composerFocus,
                  replyTo: _replyTo,
                  onCancelReply: () => setState(() => _replyTo = null),
                  replyName: _replyTo == null
                      ? ''
                      : (_replyTo!.senderId == _myUid
                          ? 'Kendine yanıt'
                          : _replyTo!.senderName),
                  isSending: _isSending,
                  enabled: !_iBlockedPeer,
                  onSend: _send,
                  onPhoto: _sendPhoto,
                  onVoice: _toggleRecording,
                ),
            ],
          ),
        );
      },
    );
  }

  String _titleOf(ChatRoom? room) {
    if (room == null) return widget.roomName;
    if (room.isDirect) {
      final peer = room.peerName(_myUid);
      return peer.trim().isEmpty ? widget.roomName : peer;
    }
    return room.name;
  }

  String _subtitleOf(ChatRoom? room) {
    if (_iBlockedPeer) return 'engellendi';
    if (room != null && room.isPeerTyping(_myUid)) return 'yazıyor…';
    if (room == null) return 'sohbet';
    if (room.isChannel) {
      return room.subscriberCount <= 1
          ? 'kanal · ${room.subscriberCount} abone'
          : 'kanal · ${room.subscriberCount} abone';
    }
    if (room.isGroup) return 'grup · ${room.memberIds.length} üye';
    return 'kişisel sohbet';
  }
}

// --------------------------------------------------------------------------- //
// Balon
// --------------------------------------------------------------------------- //

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showAvatar,
    required this.showSender,
    required this.readByPeer,
    required this.isFirstInGroup,
    required this.isPlaying,
    required this.onPlay,
    required this.onReply,
    required this.onReact,
    required this.onReport,
    required this.onHideForMe,
    required this.onDeleteForEveryone,
    required this.onOpenImage,
    this.canDeleteForEveryone = false,
    this.myReaction,
  });

  final ChatMessage message;
  final bool isMine;

  /// "Herkesten sil" gösterilsin mi? (kendi mesajı veya yetkili moderatör)
  final bool canDeleteForEveryone;

  final VoidCallback onHideForMe;
  final VoidCallback onDeleteForEveryone;
  final VoidCallback onOpenImage;
  final bool showAvatar;
  final bool showSender;
  final bool readByPeer;
  final bool isFirstInGroup;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onReply;
  final ValueChanged<String> onReact;
  final VoidCallback onReport;
  final String? myReaction;

  static const _quickReactions = ['❤️', '😂', '👍', '😮', '😢', '🙏'];

  @override
  Widget build(BuildContext context) {
    final mineBubble = context.isDark
        ? const Color(0xFF2A1115)
        : const Color(0xFFFDE7EA);
    final otherBubble = context.isDark
        ? const Color(0xFF1B1B20)
        : Colors.white;

    final bubbleColor = isMine ? mineBubble : otherBubble;
    final textColor = isMine
        ? (context.isDark ? const Color(0xFFFFE9EC) : const Color(0xFF241014))
        : context.colors.onSurface;

    final reactions = message.reactionCounts;
    final hasMediaImage = message.type == MessageType.image && message.hasMedia;
    final isVoice = message.type == MessageType.audio;

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMine ? 18 : (isFirstInGroup ? 6 : 18)),
      bottomRight: Radius.circular(isMine ? (isFirstInGroup ? 6 : 18) : 18),
    );

    Widget bubbleBody = Container(
      padding: EdgeInsets.fromLTRB(
        hasMediaImage ? 4 : 13,
        hasMediaImage ? 4 : 8,
        hasMediaImage ? 4 : 12,
        7,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: radius,
        border: Border.all(
          color: isMine
              ? AppColors.brand.withValues(alpha: 0.22)
              : context.line,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.28 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSender)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 3),
              child: Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                  color: avatarColorFor(message.senderName),
                ),
              ),
            ),
          if (message.reply != null)
            _QuoteBlock(reply: message.reply!, isMine: isMine),
          if (hasMediaImage) ...[
            GestureDetector(
              onTap: onOpenImage,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _ImageContent(
                  bytes: message.mediaBytes,
                  onOpen: onOpenImage,
                ),
              ),
            ),
            if (message.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(9, 8, 9, 2),
                child: Text(
                  message.text,
                  style: TextStyle(fontSize: 14.5, height: 1.35, color: textColor),
                ),
              ),
          ] else if (isVoice)
            _VoiceContent(
              message: message,
              isPlaying: isPlaying,
              onPlay: onPlay,
              textColor: textColor,
              accent: context.colors.primary,
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
              child: Text(
                message.displayText,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.34,
                  color: message.deleted ? context.muted : textColor,
                  fontStyle: message.deleted ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, top: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (message.editedAt != null && !message.deleted)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      'düzenlendi',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: textColor.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                Text(
                  message.createdAt == null
                      ? ''
                      : DateFormat('HH:mm').format(message.createdAt!),
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withValues(alpha: 0.55),
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    readByPeer ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 15,
                    color: readByPeer
                        ? context.colors.primary
                        : textColor.withValues(alpha: 0.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    // Saat + okundu bilgisi tek yerde: balonun alt satırında.

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine)
            SizedBox(
              width: 30,
              child: showAvatar
                  ? UserAvatar(name: message.senderName, size: 28)
                  : null,
            ),
          if (!isMine) const SizedBox(width: 7),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.76,
              ),
              child: GestureDetector(
                onLongPress: () => _showMessageActions(context),
                onDoubleTap: () => onReact('❤️'),
                child: Column(
                  crossAxisAlignment:
                      isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    bubbleBody,
                    if (reactions.isNotEmpty)
                      Transform.translate(
                        offset: const Offset(0, -6),
                        child: Container(
                          margin: EdgeInsets.only(
                            left: isMine ? 0 : 6,
                            right: isMine ? 6 : 0,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.line),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final entry in reactions.entries)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 1),
                                  child: Text(
                                    '${entry.key}${entry.value > 1 ? ' ${entry.value}' : ''}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 2),
        ],
      ),
    );
  }

  Future<void> _showMessageActions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final emoji in _quickReactions)
                    InkResponse(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onReact(emoji);
                      },
                      radius: 26,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 12),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Yanıtla'),
              onTap: () {
                Navigator.pop(sheetContext);
                onReply();
              },
            ),
            if (myReaction != null)
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined),
                title: const Text('Tepkimi kaldır'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onReact(myReaction!);
                },
              ),
            if (!isMine)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Mesajı şikayet et'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onReport();
                },
              ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Benden sil'),
              subtitle: const Text('Yalnızca sen görmezsin.'),
              onTap: () {
                Navigator.pop(sheetContext);
                onHideForMe();
              },
            ),
            if (canDeleteForEveryone && !message.deleted)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: sheetContext.colors.error,
                ),
                title: Text(
                  'Herkesten sil',
                  style: TextStyle(color: sheetContext.colors.error),
                ),
                subtitle: const Text('Tüm üyelerden kaldırılır.'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onDeleteForEveryone();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.reply, required this.isMine});

  final ReplyInfo reply;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6, top: 1),
      padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: context.colors.primary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.senderName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            reply.preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, height: 1.3, color: context.muted),
          ),
        ],
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.bytes, this.onOpen});

  final Uint8List? bytes;

  /// Görsele dokununca tam ekran açılır.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final data = bytes;
    if (data == null) {
      return const SizedBox(
        height: 160,
        width: 220,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      );
    }

    return Stack(
      children: [
        Image.memory(
          data,
          width: 230,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const SizedBox(
            height: 140,
            width: 200,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
        if (onOpen != null)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.42),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.open_in_full_rounded,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _VoiceContent extends StatelessWidget {
  const _VoiceContent({
    required this.message,
    required this.isPlaying,
    required this.onPlay,
    required this.textColor,
    required this.accent,
  });

  final ChatMessage message;
  final bool isPlaying;
  final VoidCallback onPlay;
  final Color textColor;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 3, 6, 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkResponse(
            onTap: onPlay,
            radius: 24,
            child: Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 22,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 130,
                height: 22,
                child: Row(
                  children: [
                    for (var i = 0; i < 22; i++)
                      Container(
                        margin: const EdgeInsets.only(right: 2.4),
                        width: 2.6,
                        height: 6 + ((i * 7) % 14).toDouble(),
                        decoration: BoxDecoration(
                          color: textColor.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatDuration(message.durationMs),
                style: TextStyle(
                  fontSize: 10.5,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.cardHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: context.muted),
          ),
        ),
      ),
    );
  }
}

class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner({required this.onUnblock});

  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.colors.error.withValues(alpha: 0.10),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Icon(Icons.block_rounded, size: 18, color: context.colors.error),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Bu kişiyi engelledin. Mesaj gönderemezsin.',
              style: TextStyle(fontSize: 12.5),
            ),
          ),
          TextButton(onPressed: onUnblock, child: const Text('Engeli kaldır')),
        ],
      ),
    );
  }
}

class _ChannelBanner extends StatelessWidget {
  const _ChannelBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.cardHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.campaign_rounded, size: 17, color: context.colors.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Yayın kanalı — gönderileri tüm aboneler görür.',
              style: TextStyle(fontSize: 11.5, color: context.muted),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Yazma alanı
// --------------------------------------------------------------------------- //

/// Yalnızca moderatörlerin paylaşabildiği odalarda üyeler için alt bar.
class _ReadOnlyBar extends StatelessWidget {
  const _ReadOnlyBar({required this.room});

  final ChatRoom room;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: context.card,
        border: Border(top: BorderSide(color: context.line)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: context.muted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              room.isChannel
                  ? 'Yalnızca moderatörler paylaşım yapabilir.'
                  : 'Bu grupta yalnızca moderatörler yazabilir.',
              style: TextStyle(fontSize: 12.5, color: context.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.replyTo,
    required this.onCancelReply,
    required this.replyName,
    required this.isSending,
    required this.enabled,
    required this.onSend,
    required this.onPhoto,
    required this.onVoice,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ChatMessage? replyTo;
  final VoidCallback onCancelReply;
  final String replyName;
  final bool isSending;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onPhoto;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (replyTo != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                decoration: BoxDecoration(
                  color: context.cardHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(
                    left: BorderSide(color: context.colors.primary, width: 3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            replyName,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: context.colors.primary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            replyTo!.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: context.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onCancelReply,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: enabled ? onPhoto : null,
                    tooltip: 'Fotoğraf',
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.cardHigh,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: context.line),
                      ),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: enabled,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(fontSize: 15, height: 1.3),
                        decoration: InputDecoration(
                          hintText: enabled
                              ? 'Mesaj yaz…'
                              : 'Engel nedeniyle yazılamaz',
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (!hasText)
                    IconButton(
                      onPressed: enabled ? onVoice : null,
                      tooltip: 'Sesli mesaj',
                      icon: const Icon(Icons.mic_none_rounded),
                    ),
                  _SendButton(
                    isSending: isSending,
                    enabled: enabled,
                    onPressed: hasText ? onSend : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.seconds,
    required this.onCancel,
    required this.onSend,
  });

  final int seconds;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              Container(
                height: 10,
                width: 10,
                decoration: BoxDecoration(
                  color: context.colors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Kayıt  ${formatDuration(seconds * 1000)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(onPressed: onCancel, child: const Text('İptal')),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Gönder'),
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
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final isActive = enabled && onPressed != null && !isSending;

    return GestureDetector(
      onTap: isActive ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.brandGradient : null,
          color: isActive ? null : context.cardHigh,
          shape: BoxShape.circle,
        ),
        child: isSending
            ? const Padding(
                padding: EdgeInsets.all(13),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                Icons.arrow_upward_rounded,
                color: isActive ? Colors.white : context.muted,
                size: 22,
              ),
      ),
    );
  }
}

/// Fotoğraf tam ekran görüntüleyici.
///
/// Siyah zemin, yakınlaştırma (pinch) ve kaydırma; dokununca kapanır.
class _ImageViewerScreen extends StatefulWidget {
  const _ImageViewerScreen({this.bytes, this.senderName = ''});

  final Uint8List? bytes;
  final String senderName;

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  bool _chromeVisible = true;

  @override
  Widget build(BuildContext context) {
    final data = widget.bytes;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _chromeVisible = !_chromeVisible),
                child: data == null
                    ? const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 42,
                        ),
                      )
                    : InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        child: Center(
                          child: Image.memory(
                            data,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
              ),
            ),
            if (_chromeVisible) ...[
              Positioned(
                left: 8,
                right: 8,
                top: 4,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const Spacer(),
                    if (widget.senderName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          widget.senderName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Text(
                  'Yakınlaştırmak için iki parmakla aç · kapatmak için dokun',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 11.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

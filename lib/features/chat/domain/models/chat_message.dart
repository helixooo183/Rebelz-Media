import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Yanıtlanan mesajın özeti (alıntı baloncuğu için).
class ReplyInfo {
  const ReplyInfo({
    required this.id,
    required this.senderName,
    required this.preview,
    this.isMine = false,
  });

  final String id;
  final String senderName;
  final String preview;
  final bool isMine;

  factory ReplyInfo.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return ReplyInfo(
      id: (map['id'] as String?) ?? '',
      senderName: (map['senderName'] as String?) ?? '',
      preview: (map['preview'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderName': senderName,
        'preview': preview,
      };
}

/// Mesaj türleri.
abstract final class MessageType {
  static const text = 'text';
  static const image = 'image';
  static const audio = 'audio';
  static const system = 'system';
}

/// `rooms/{roomId}/messages/{id}` dokümanının modeli.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.senderPhotoUrl = '',
    this.type = MessageType.text,
    this.mediaBase64 = '',
    this.mediaMime = '',
    this.durationMs = 0,
    this.reply,
    this.reactions = const <String, String>{},
    this.readBy = const <String>[],
    this.editedAt,
    this.deleted = false,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final String senderPhotoUrl;

  /// text | image | audio | system
  final String type;

  /// Görsel/ses içeriği (base64). Boşsa metin mesajıdır.
  final String mediaBase64;
  final String mediaMime;

  /// Sesli mesaj süresi (milisaniye).
  final int durationMs;

  final ReplyInfo? reply;

  /// uid → emoji
  final Map<String, String> reactions;

  /// Mesajı okuyan üyeler (doğrudan sohbette okundu bilgisi).
  final List<String> readBy;

  final DateTime? editedAt;
  final bool deleted;
  final DateTime? createdAt;

  bool get isSystem => type == MessageType.system;

  bool get hasMedia => mediaBase64.isNotEmpty;

  Uint8List? get mediaBytes {
    if (mediaBase64.isEmpty) return null;
    try {
      return base64Decode(mediaBase64);
    } catch (_) {
      return null;
    }
  }

  /// Balonda gösterilecek metin (silinmişse açıklama).
  String get displayText => deleted ? 'Bu mesaj silindi' : text;

  /// Tepki özeti: emoji → kaç kişi.
  Map<String, int> get reactionCounts {
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      if (emoji.isEmpty) continue;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    return counts;
  }

  /// Baloncuk önizlemesi (sohbet listesi / alıntı için).
  String get preview {
    if (deleted) return 'Bu mesaj silindi';
    switch (type) {
      case MessageType.image:
        return '📷 Fotoğraf';
      case MessageType.audio:
        return '🎙 Sesli mesaj';
      default:
        return text;
    }
  }

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    final rawReactions = (data['reactions'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      senderName: (data['senderName'] as String?)?.trim().isNotEmpty == true
          ? (data['senderName'] as String).trim()
          : 'Kullanıcı',
      text: (data['text'] as String?) ?? '',
      senderPhotoUrl: (data['senderPhotoUrl'] as String?)?.trim() ?? '',
      type: _typeOf(data['type']),
      mediaBase64: (data['mediaBase64'] as String?) ?? '',
      mediaMime: (data['mediaMime'] as String?) ?? '',
      durationMs: (data['durationMs'] as num?)?.toInt() ?? 0,
      reply: data['reply'] == null
          ? null
          : ReplyInfo.fromMap((data['reply'] as Map?)?.cast<String, dynamic>()),
      reactions: {
        for (final entry in rawReactions.entries)
          entry.key: (entry.value ?? '').toString(),
      },
      readBy: (data['readBy'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
      deleted: (data['deleted'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static String _typeOf(Object? value) {
    return switch (value) {
      'image' => MessageType.image,
      'audio' => MessageType.audio,
      'system' => MessageType.system,
      _ => MessageType.text,
    };
  }
}

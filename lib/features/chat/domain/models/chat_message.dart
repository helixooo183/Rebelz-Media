import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore `rooms/{roomId}/messages/{messageId}` dokümanının modeli.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.senderPhotoUrl = '',
    this.type = 'text',
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;

  /// Avatar için gönderenin o anki fotoğrafı (kopya).
  final String senderPhotoUrl;

  /// 'text' ya da 'system' (sohbet başlangıcı gibi bilgi satırları).
  final String type;

  final DateTime? createdAt;

  bool get isSystem => type == 'system';

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      senderName: (data['senderName'] as String?)?.trim().isNotEmpty == true
          ? (data['senderName'] as String).trim()
          : 'Kullanıcı',
      text: (data['text'] as String?) ?? '',
      senderPhotoUrl: (data['senderPhotoUrl'] as String?)?.trim() ?? '',
      type: (data['type'] as String?) == 'system' ? 'system' : 'text',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

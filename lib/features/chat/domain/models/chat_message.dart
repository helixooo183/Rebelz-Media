import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore `rooms/{roomId}/messages/{messageId}` dokümanının modeli.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String text;

  /// Sunucu zaman damgası; mesaj gönderilir gönderilmez yerelde null olabilir.
  final DateTime? createdAt;

  factory ChatMessage.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      senderName: (data['senderName'] as String?) ?? 'Anonim',
      text: (data['text'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

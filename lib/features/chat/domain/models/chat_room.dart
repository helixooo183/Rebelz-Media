import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore `rooms/{roomId}` dokümanının modeli.
class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberIds,
    this.lastMessage,
    this.lastMessageAt,
    this.createdAt,
  });

  final String id;
  final String name;
  final String createdBy;
  final List<String> memberIds;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  factory ChatRoom.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};

    return ChatRoom(
      id: doc.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? (data['name'] as String).trim()
          : 'İsimsiz sohbet',
      createdBy: (data['createdBy'] as String?) ?? '',
      memberIds:
          (data['memberIds'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toList(growable: false),
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String get preview => lastMessage ?? 'Henüz mesaj yok';
}

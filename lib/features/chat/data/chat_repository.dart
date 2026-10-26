import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/auth_service.dart';
import '../domain/models/chat_message.dart';
import '../domain/models/chat_room.dart';

/// Sohbet verisiyle ilgili tüm Firestore okuma/yazmaları.
class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore, AuthService? authService})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = authService ?? AuthService();

  final FirebaseFirestore _db;
  final AuthService _auth;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');

  /// Son mesaja göre sıralanmış sohbet odaları.
  Stream<List<ChatRoom>> watchRooms() {
    return _rooms
        .orderBy('lastMessageAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatRoom.fromDoc).toList());
  }

  /// Bir odanın son 100 mesajı, yeniden eskiye.
  Stream<List<ChatMessage>> watchMessages(String roomId) {
    return _rooms
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<String> createRoom(String name) async {
    final user = _requireUser();
    final doc = await _rooms.add({
      'name': name.trim(),
      'createdBy': user.uid,
      'memberIds': [user.uid],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': 'Sohbet oluşturuldu',
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> sendMessage({
    required String roomId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final user = _requireUser();
    final room = _rooms.doc(roomId);
    final batch = _db.batch();

    batch.set(room.collection('messages').doc(), {
      'senderId': user.uid,
      'senderName': _auth.displayName,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(room, {
      'lastMessage': trimmed,
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Bu işlem için giriş yapmalısınız.');
    }
    return user;
  }
}

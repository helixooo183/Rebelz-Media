import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/models/chat_message.dart';
import '../domain/models/chat_room.dart';

/// Sohbet, mesaj ve kanal verileriyle ilgili tüm Firestore işlemleri.
///
/// Model:
///   rooms/{roomId}                        memberIds, type, typing, readAt…
///   rooms/{roomId}/messages/{msgId}       metin / fotoğraf / ses
class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection('rooms');

  String? get _myUid => _auth.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Okuma
  // ---------------------------------------------------------------------------

  /// Oturum açan kullanıcının sohbetleri (kanallar hariç, en yeni üstte).
  Stream<List<ChatRoom>> watchRooms() {
    final uid = _myUid;
    if (uid == null) return Stream<List<ChatRoom>>.value(const <ChatRoom>[]);

    return _rooms
        .where('memberIds', arrayContains: uid)
        .limit(60)
        .snapshots()
        .map((snapshot) {
      final rooms = <ChatRoom>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final room = ChatRoom.fromDoc(doc, viewerUid: uid);
        if (room.isChannel) continue;

        final hiddenFor =
            (data['hiddenFor'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<String>();
        if (hiddenFor.contains(uid)) continue;
        rooms.add(room);
      }
      _sortRooms(rooms);
      return rooms;
    });
  }

  /// Herkese açık kanallar.
  Stream<List<ChatRoom>> watchChannels() {
    final uid = _myUid;
    return _rooms
        .where('type', isEqualTo: RoomType.channel)
        .limit(60)
        .snapshots()
        .map((snapshot) {
      final channels = snapshot.docs
          .map((doc) => ChatRoom.fromDoc(doc, viewerUid: uid))
          .toList();
      _sortRooms(channels);
      return channels;
    });
  }

  Stream<ChatRoom?> watchRoom(String roomId) {
    return _rooms.doc(roomId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChatRoom.fromDoc(doc, viewerUid: _myUid);
    });
  }

  Stream<List<ChatMessage>> watchMessages(String roomId) {
    return _rooms
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatMessage.fromDoc).toList());
  }

  void _sortRooms(List<ChatRoom> rooms) {
    rooms.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.createdAt ?? DateTime(1970);
      final bTime = b.lastMessageAt ?? b.createdAt ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
  }

  /// Doğrudan sohbet doküman kimliği (iki uid sıralı yazılır).
  static String directChatId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return 'dm_${ids[0]}_${ids[1]}';
  }

  // ---------------------------------------------------------------------------
  // Sohbet başlatma
  // ---------------------------------------------------------------------------

  Future<String> openDirectChat({
    required String peerUid,
    required String peerName,
    String peerPhotoUrl = '',
  }) async {
    final uid = _requireUid();
    if (uid == peerUid) {
      throw const ChatException('Kendinle sohbet başlatamazsın.');
    }

    final roomId = directChatId(uid, peerUid);
    final roomRef = _rooms.doc(roomId);

    var exists = false;
    try {
      exists = (await roomRef.get()).exists;
    } catch (_) {
      exists = false;
    }

    final myName = (_auth.currentUser?.displayName ?? '').trim();

    if (!exists) {
      await roomRef.set({
        'name': 'Doğrudan sohbet',
        'photoUrl': peerPhotoUrl.trim(),
        'type': RoomType.direct,
        'createdBy': uid,
        'memberIds': [uid, peerUid],
        'hiddenFor': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'memberNames': {uid: myName, peerUid: peerName.trim()},
        'memberPhotos': {uid: '', peerUid: peerPhotoUrl.trim()},
      });
      return roomId;
    }

    await roomRef.set({
      'type': RoomType.direct,
      'hiddenFor': FieldValue.arrayRemove([uid]),
      'memberNames.$uid': myName,
      'memberNames.$peerUid': peerName.trim(),
      'memberPhotos.$peerUid': peerPhotoUrl.trim(),
    }, SetOptions(merge: true));

    return roomId;
  }

  // ---------------------------------------------------------------------------
  // Mesaj gönderme
  // ---------------------------------------------------------------------------

  /// Metin, fotoğraf veya sesli mesaj gönderir.
  Future<void> sendMessage(
    String roomId, {
    String text = '',
    String type = MessageType.text,
    String mediaBase64 = '',
    String mediaMime = '',
    int durationMs = 0,
    ReplyInfo? reply,
  }) async {
    final uid = _requireUid();
    final body = text.trim();

    if (type == MessageType.text && body.isEmpty) return;
    if (body.length > 2000) {
      throw const ChatException('Mesaj en fazla 2000 karakter olabilir.');
    }
    if (mediaBase64.length > 850000) {
      throw const ChatException('Medya çok büyük. Daha küçük bir dosya seç.');
    }

    final user = _auth.currentUser!;
    final roomRef = _rooms.doc(roomId);
    final roomSnapshot = await roomRef.get();
    final room = roomSnapshot.exists ? ChatRoom.fromDoc(roomSnapshot) : null;

    if (room == null) throw const ChatException('Sohbet bulunamadı.');
    if (room.isChannel) {
      if (room.ownerUid != uid) {
        throw const ChatException('Bu kanalda yalnızca sahibi paylaşım yapar.');
      }
    } else if (!room.hasMember(uid)) {
      throw const ChatException('Bu sohbete erişimin yok.');
    }

    final peerUid = room.peerUid(uid);
    if (peerUid != null && await hasBlocked(peerUid)) {
      throw const ChatException(
        'Bu kişiyi engelledin. Mesaj göndermek için engeli kaldır.',
      );
    }

    final senderName = (user.displayName ?? '').trim().isEmpty
        ? 'Kullanıcı'
        : user.displayName!.trim();

    var senderPhotoUrl = user.photoURL ?? '';
    try {
      final profile = await _db.collection('users').doc(uid).get();
      final stored = (profile.data()?['photoUrl'] as String?)?.trim() ?? '';
      if (stored.isNotEmpty) senderPhotoUrl = stored;
    } catch (_) {
      // Profil okunamazsa Auth fotoğrafıyla devam.
    }

    final preview = switch (type) {
      MessageType.image => '📷 Fotoğraf',
      MessageType.audio => '🎙 Sesli mesaj',
      _ => body,
    };

    final batch = _db.batch();
    batch.set(roomRef.collection('messages').doc(), {
      'senderId': uid,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': body,
      'type': type,
      'mediaBase64': mediaBase64,
      'mediaMime': mediaMime,
      'durationMs': durationMs,
      'readBy': <String>[uid],
      'deleted': false,
      if (reply != null) 'reply': reply.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(roomRef, {
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'hiddenFor': <String>[],
      'typing.$uid': FieldValue.delete(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// "yazıyor…" göstergesi (gönderen kendi alanını yönetir).
  Future<void> setTyping(String roomId, bool typing) async {
    final uid = _myUid;
    if (uid == null) return;
    try {
      await _rooms.doc(roomId).set({
        'typing.$uid':
            typing ? FieldValue.serverTimestamp() : FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Gösterge kritik değil.
    }
  }

  /// Sohbeti okundu olarak işaretler (✓✓ için).
  Future<void> markRead(String roomId) async {
    final uid = _myUid;
    if (uid == null) return;
    try {
      await _rooms.doc(roomId).set({
        'readAt.$uid': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Sessiz geç.
    }
  }

  /// Tepki ekler; aynı tepki tekrar seçilirse kaldırır.
  Future<void> toggleReaction(
    String roomId,
    String messageId,
    String emoji,
  ) async {
    final uid = _requireUid();
    final ref = _rooms.doc(roomId).collection('messages').doc(messageId);
    final snapshot = await ref.get();
    final current = (snapshot.data()?['reactions'] as Map?)
        ?.cast<String, dynamic>()?[uid]
        ?.toString();

    await ref.set({
      'reactions.$uid':
          current == emoji ? FieldValue.delete() : emoji,
    }, SetOptions(merge: true));
  }

  /// Mesajı siler (içerik temizlenir, "silindi" olarak görünür).
  Future<void> deleteMessage(String roomId, String messageId) async {
    _requireUid();
    await _rooms.doc(roomId).collection('messages').doc(messageId).set({
      'text': '',
      'mediaBase64': '',
      'mediaMime': '',
      'durationMs': 0,
      'deleted': true,
      'editedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Kendi metin mesajını düzenler.
  Future<void> editMessage(
    String roomId,
    String messageId,
    String text,
  ) async {
    _requireUid();
    final body = text.trim();
    if (body.isEmpty) return;
    await _rooms.doc(roomId).collection('messages').doc(messageId).set({
      'text': body,
      'editedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Kanallar
  // ---------------------------------------------------------------------------

  /// Yeni yayın kanalı oluşturur (sahibi otomatik abone olur).
  Future<String> createChannel({
    required String name,
    String about = '',
  }) async {
    final uid = _requireUid();
    final trimmed = name.trim();
    if (trimmed.length < 3) {
      throw const ChatException('Kanal adı en az 3 karakter olmalı.');
    }

    final ref = _rooms.doc();
    await ref.set({
      'name': trimmed,
      'about': about.trim(),
      'type': RoomType.channel,
      'createdBy': uid,
      'ownerUid': uid,
      'memberIds': [uid],
      'subscriberCount': 1,
      'photoUrl': '',
      'hiddenFor': <String>[],
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'memberNames': {uid: (_auth.currentUser?.displayName ?? '').trim()},
    });
    return ref.id;
  }

  /// Kanala abone olur.
  Future<void> joinChannel(String roomId) async {
    final uid = _requireUid();
    await _rooms.doc(roomId).set({
      'memberIds': FieldValue.arrayUnion([uid]),
      'subscriberCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  /// Kanaldan ayrılır.
  Future<void> leaveChannel(String roomId) async {
    final uid = _requireUid();
    await _rooms.doc(roomId).set({
      'memberIds': FieldValue.arrayRemove([uid]),
      'subscriberCount': FieldValue.increment(-1),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Engelleme kontrolü
  // ---------------------------------------------------------------------------

  Future<bool> hasBlocked(String otherUid) async {
    final uid = _myUid;
    if (uid == null) return false;
    try {
      final doc = await _db
          .collection('users')
          .doc(uid)
          .collection('blocked')
          .doc(otherUid)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Silme
  // ---------------------------------------------------------------------------

  Future<void> hideChat(String roomId) async {
    final uid = _requireUid();
    await _rooms.doc(roomId).set({
      'hiddenFor': FieldValue.arrayUnion([uid]),
    }, SetOptions(merge: true));
  }

  Future<void> deleteChat(String roomId) async {
    _requireUid();
    final roomRef = _rooms.doc(roomId);

    while (true) {
      final snapshot = await roomRef.collection('messages').limit(300).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < 300) break;
    }

    await roomRef.delete();
  }

  String _requireUid() {
    final uid = _myUid;
    if (uid == null) {
      throw const ChatException('Bu işlem için giriş yapmalısın.');
    }
    return uid;
  }
}

class ChatException implements Exception {
  const ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

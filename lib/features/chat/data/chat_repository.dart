import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/models/chat_message.dart';
import '../domain/models/chat_room.dart';

/// Sohbet verileriyle ilgili tüm Firestore işlemleri.
///
/// Model:
///   rooms/{roomId}                     memberIds, type ('dm'|'group'), hiddenFor
///   rooms/{roomId}/messages/{msgId}    mesajlar
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

  /// Oturum açan kullanıcının sohbetleri (en son mesaj üstte).
  ///
  /// Kaldırılan sohbetler `hiddenFor` alanında tutulur; karşı taraf yeni
  /// mesaj yazdığında alan temizlenir ve sohbet geri gelir.
  Stream<List<ChatRoom>> watchRooms() {
    final uid = _myUid;
    if (uid == null) return Stream<List<ChatRoom>>.value(const <ChatRoom>[]);

    // Not: `arrayContains` + `orderBy` bileşik indeks gerektirdiği için
    // sıralama istemci tarafında yapılır (ilk kurulumda ek adım gerekmez).
    return _rooms
        .where('memberIds', arrayContains: uid)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      final rooms = <ChatRoom>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final hiddenFor =
            (data['hiddenFor'] as List<dynamic>? ?? const <dynamic>[])
                .whereType<String>();
        if (hiddenFor.contains(uid)) continue;
        rooms.add(ChatRoom.fromDoc(doc, viewerUid: uid));
      }
      rooms.sort((a, b) {
        final aTime = a.lastMessageAt ?? a.createdAt ?? DateTime(1970);
        final bTime = b.lastMessageAt ?? b.createdAt ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      return rooms;
    });
  }

  /// Tek sohbetin canlı kaydı (karşı tarafın adı/fotoğrafı değişirse güncellenir).
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

  /// Doğrudan sohbet doküman kimliği (iki uid sıralı yazılır, tek kayıt olur).
  static String directChatId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return 'dm_${ids[0]}_${ids[1]}';
  }

  // ---------------------------------------------------------------------------
  // Sohbet başlatma
  // ---------------------------------------------------------------------------

  /// Verilen kullanıcıyla doğrudan sohbeti açar (yoksa oluşturur).
  ///
  /// Sohbetin `name`/`photoUrl` alanları karşı tarafın profiline göre
  /// tazelenir, böylece adını değiştiren kullanıcı listede doğru görünür.
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

    // Var olmayan dokümanı okumak güvenlik kuralı tarafından reddedilebilir;
    // bu yüzden "yok" kabul edip sohbeti oluştururuz.
    var exists = false;
    try {
      exists = (await roomRef.get()).exists;
    } catch (_) {
      exists = false;
    }

    final myName = (_auth.currentUser?.displayName ?? '').trim();

    if (!exists) {
      await roomRef.set({
        'name': peerName.trim().isEmpty ? 'Sohbet' : peerName.trim(),
        'photoUrl': peerPhotoUrl.trim(),
        'type': 'dm',
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

    // Mevcut sohbet: iki tarafın güncel ad/fotoğrafını yaz, gizlemeyi kaldır.
    await roomRef.set({
      'type': 'dm',
      'photoUrl': peerPhotoUrl.trim(),
      'name': peerName.trim().isEmpty ? 'Sohbet' : peerName.trim(),
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

  /// Mesajı yazar; boş mesaj gönderilmez. Hata durumunda [ChatException].
  Future<void> sendMessage(String roomId, String text) async {
    final uid = _requireUid();
    final body = text.trim();
    if (body.isEmpty) return;
    if (body.length > 2000) {
      throw const ChatException('Mesaj en fazla 2000 karakter olabilir.');
    }

    final user = _auth.currentUser!;
    final roomRef = _rooms.doc(roomId);
    final roomSnapshot = await roomRef.get();
    final room = roomSnapshot.exists
        ? ChatRoom.fromDoc(roomSnapshot)
        : null;
    if (room == null || !room.hasMember(uid)) {
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

    // Gönderenin güncel fotoğrafı (avatar için kopya).
    var senderPhotoUrl = user.photoURL ?? '';
    try {
      final profile = await _db.collection('users').doc(uid).get();
      final stored = (profile.data()?['photoUrl'] as String?)?.trim() ?? '';
      if (stored.isNotEmpty) senderPhotoUrl = stored;
    } catch (_) {
      // Profil okunamazsa Auth fotoğrafıyla devam.
    }

    final batch = _db.batch();
    batch.set(roomRef.collection('messages').doc(), {
      'senderId': uid,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': body,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(roomRef, {
      'lastMessage': body,
      'lastMessageAt': FieldValue.serverTimestamp(),
      // Silinmiş sohbeti iki taraf için de geri getir.
      'hiddenFor': <String>[],
    }, SetOptions(merge: true));

    await batch.commit();
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

  /// Sohbeti yalnızca bu kullanıcı için kaldırır (karşı taraf etkilenmez).
  Future<void> hideChat(String roomId) async {
    final uid = _requireUid();
    await _rooms.doc(roomId).set({
      'hiddenFor': FieldValue.arrayUnion([uid]),
    }, SetOptions(merge: true));
  }

  /// Sohbeti ve tüm mesajlarını kalıcı olarak siler.
  ///
  /// Doğrudan sohbette iki taraf da silebilir; grup sohbetinde yalnızca
  /// oluşturan (kural tarafından da doğrulanır).
  Future<void> deleteChat(String roomId) async {
    _requireUid();
    final roomRef = _rooms.doc(roomId);

    while (true) {
      final snapshot =
          await roomRef.collection('messages').limit(300).get();
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

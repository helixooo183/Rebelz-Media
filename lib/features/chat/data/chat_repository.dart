import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/models/chat_message.dart';
import '../domain/models/chat_room.dart';
import '../domain/models/room_invite.dart';

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
    final myPhoto = (_auth.currentUser?.photoURL ?? '').trim();

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
        // Kendi fotoğrafımız da yazılır; aksi hâlde karşı taraf bizi
        // fotoğrafsız görüyordu (bizim kaydımız boş bırakılıyordu).
        'memberPhotos': {uid: myPhoto, peerUid: peerPhotoUrl.trim()},
      });
      return roomId;
    }

    // Doküman zaten var: noktalı alan yolları yalnızca `update()` ile
    // iç içe alan olarak yorumlanır (`set()` bunları adı nokta içeren
    // ayrı bir üst alan sayar ve güvenlik kuralları reddeder).
    await roomRef.update({
      'type': RoomType.direct,
      'hiddenFor': FieldValue.arrayRemove([uid]),
      'memberNames.$uid': myName,
      'memberNames.$peerUid': peerName.trim(),
      'memberPhotos.$peerUid': peerPhotoUrl.trim(),
      if (myPhoto.isNotEmpty) 'memberPhotos.$uid': myPhoto,
    });

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
    // Güvenlik kuralları bu sınırları ister; aşılırsa ham
    // `permission-denied` yerine anlaşılır mesaj gösterilir.
    if (mediaMime.length > 80) {
      throw const ChatException('Medya türü geçersiz görünüyor.');
    }
    if (durationMs < 0 || durationMs > 300000) {
      throw const ChatException('Sesli mesaj en fazla 5 dakika olabilir.');
    }

    final user = _auth.currentUser!;
    final roomRef = _rooms.doc(roomId);
    final roomSnapshot = await roomRef.get();
    final room = roomSnapshot.exists ? ChatRoom.fromDoc(roomSnapshot) : null;

    if (room == null) throw const ChatException('Sohbet bulunamadı.');
    // Üyelik her türde şart; kanalda ayrıca paylaşım izni aranır.
    // `paylasabilirMi` sahip + moderatör + `onlyModsPost` kapalıyken
    // tüm aboneleri kapsar (arayüz ve güvenlik kurallarıyla aynı karar).
    if (!room.hasMember(uid)) {
      throw const ChatException('Bu sohbete erişimin yok.');
    }
    if (room.isChannel && !room.paylasabilirMi(uid)) {
      throw const ChatException(
        'Bu kanalda yalnızca moderatörler paylaşım yapar.',
      );
    }

    final peerUid = room.peerUid(uid);
    if (peerUid != null && await hasBlocked(peerUid)) {
      throw const ChatException(
        'Bu kişiyi engelledin. Mesaj göndermek için engeli kaldır.',
      );
    }

    // Kural `senderName` için en fazla 80 karakter ister; uzun görünen
    // adlar sessizce kırpılır (mesaj bu yüzden reddedilmesin).
    final rawSenderName = (user.displayName ?? '').trim().isEmpty
        ? 'Kullanıcı'
        : user.displayName!.trim();
    final senderName = rawSenderName.runes.length > 80
        ? String.fromCharCodes(rawSenderName.runes.take(80))
        : rawSenderName;

    var senderPhotoUrl = user.photoURL ?? '';
    try {
      final profile = await _db.collection('users').doc(uid).get();
      final stored = (profile.data()?['photoUrl'] as String?)?.trim() ?? '';
      if (stored.isNotEmpty) senderPhotoUrl = stored;
    } catch (_) {
      // Profil okunamazsa Auth fotoğrafıyla devam.
    }

    // Galeriden seçilen avatar `data:image/…;base64,…` olarak saklanır.
    // Aynı blob'u **her mesaja** kopyalamak dokümanları şişirir; mesaj
    // satırlarında avatar zaten ad/baş harften çizildiği için burada
    // gönderilmez (oda ve profil kayıtları avatary taşımaya devam eder).
    if (senderPhotoUrl.startsWith('data:')) senderPhotoUrl = '';

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

    // Noktalı alan yolu (`typing.$uid`) için `update` şart; oda
    // dokümanının varlığı yukarıda doğrulandı.
    batch.update(roomRef, {
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'hiddenFor': <String>[],
      'typing.$uid': FieldValue.delete(),
    });

    await batch.commit();
  }

  /// "yazıyor…" göstergesi (gönderen kendi alanını yönetir).
  Future<void> setTyping(String roomId, bool typing) async {
    final uid = _myUid;
    if (uid == null) return;
    try {
      await _rooms.doc(roomId).update({
        'typing.$uid':
            typing ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });
    } catch (_) {
      // Gösterge kritik değil.
    }
  }

  /// Sohbeti okundu olarak işaretler (✓✓ için).
  Future<void> markRead(String roomId) async {
    final uid = _myUid;
    if (uid == null) return;
    try {
      await _rooms.doc(roomId).update({
        'readAt.$uid': FieldValue.serverTimestamp(),
      });
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
    final rawReactions = snapshot.data()?['reactions'];
    final current = rawReactions is Map
        ? rawReactions[uid]?.toString()
        : null;

    await ref.update({
      'reactions.$uid':
          current == emoji ? FieldValue.delete() : emoji,
    });
  }

  /// Mesajı siler (içerik temizlenir, "silindi" olarak görünür).
  ///
  /// `deletedBy` alanı kimin sildiğini tutar; 5 saniyelik "geri al" bildirimi
  /// [restoreMessage] ile içeriği geri yazar.
  Future<void> deleteMessage(String roomId, String messageId) async {
    final uid = _requireUid();
    await _rooms.doc(roomId).collection('messages').doc(messageId).set({
      'text': '',
      'mediaBase64': '',
      'mediaMime': '',
      'durationMs': 0,
      'deleted': true,
      'deletedBy': uid,
      'editedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Moderatör/sahip: başkasının mesajını herkesten siler.
  ///
  /// Doküman **kaldırılmaz**, içerik temizlenip `deleted` işaretlenir; böylece
  /// 5 saniyelik "geri al" çalışabilir. Kural: `modsDeleteMessages` izni varsa
  /// sahip/moderatör bu alanları güncelleyebilir.
  Future<void> deleteMessageAsModerator(
    String roomId,
    String messageId,
  ) async {
    final uid = _requireUid();
    await _rooms.doc(roomId).collection('messages').doc(messageId).set({
      'text': '',
      'mediaBase64': '',
      'mediaMime': '',
      'durationMs': 0,
      'deleted': true,
      'deletedBy': uid,
      'editedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Silme işlemini geri alır: mesajın içeriğini yeniden yazar.
  ///
  /// "Geri al" bildirimi 5 saniye görünür; süre bitmeden çağrılırsa mesaj
  /// eski hâline döner (metin, fotoğraf, ses süresi, düzenleme zamanı).
  Future<void> restoreMessage(String roomId, ChatMessage message) async {
    _requireUid();
    final data = <String, dynamic>{
      'text': message.text,
      'mediaBase64': message.mediaBase64,
      'mediaMime': message.mediaMime,
      'durationMs': message.durationMs,
      'deleted': false,
      'deletedBy': FieldValue.delete(),
      'editedAt': message.editedAt == null
          ? FieldValue.delete()
          : Timestamp.fromDate(message.editedAt!),
    };
    await _rooms
        .doc(roomId)
        .collection('messages')
        .doc(message.id)
        .set(data, SetOptions(merge: true));
  }

  /// "Benden sil": mesaj yalnızca bu kullanıcıda gizlenir.
  ///
  /// Kayıt `users/{uid}/hiddenMessages/{roomId__messageId}` altında tutulur;
  /// başka kimse göremez ve mesaj diğer üyeler için silinmez.
  Future<void> hideMessageForMe(String roomId, String messageId) async {
    final uid = _requireUid();
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('hiddenMessages')
        .doc('${roomId}__$messageId');
    // Kural bu dokümanlarda `update` kabul etmez (kanıt niteliği);
    // kayıt zaten varsa ikinci kez yazmak reddedilir — sessizce geç.
    if ((await ref.get()).exists) return;
    await ref.set({
      'roomId': roomId,
      'messageId': messageId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// "Benden sil" işlemini geri alır (gizleme kaydı silinir).
  Future<void> unhideMessage(String roomId, String messageId) async {
    final uid = _requireUid();
    await _db
        .collection('users')
        .doc(uid)
        .collection('hiddenMessages')
        .doc('${roomId}__$messageId')
        .delete();
  }

  /// Bu sohbette benim gizlediğim mesaj kimlikleri.
  Stream<Set<String>> watchHiddenMessageIds(String roomId) {
    final uid = _myUid;
    if (uid == null) return Stream<Set<String>>.value(const <String>{});
    return _db
        .collection('users')
        .doc(uid)
        .collection('hiddenMessages')
        .where('roomId', isEqualTo: roomId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => (doc.data()['messageId'] as String?) ?? '')
            .where((id) => id.isNotEmpty)
            .toSet());
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
    bool isPrivate = false,
  }) async {
    final uid = _requireUid();
    final trimmed = name.trim();
    if (trimmed.length < 3) {
      throw const ChatException('Kanal adı en az 3 karakter olmalı.');
    }
    if (trimmed.length > 80) {
      throw const ChatException('Kanal adı en fazla 80 karakter olabilir.');
    }

    final myPhoto = (_auth.currentUser?.photoURL ?? '').trim();
    final ref = _rooms.doc();
    await ref.set({
      'name': trimmed,
      'about': about.trim(),
      'type': RoomType.channel,
      'createdBy': uid,
      'ownerUid': uid,
      'memberIds': [uid],
      'subscriberCount': 1,
      'isPrivate': isPrivate,
      'photoUrl': '',
      'hiddenFor': <String>[],
      'lastMessage': '',
      'lastMessageAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'memberNames': {uid: (_auth.currentUser?.displayName ?? '').trim()},
      // Yalnızca http(s) fotoğraf: galeriden seçilen base64 avatar oda
      // dokümanına kopyalanmaz (arayüz canlı profilden çözer).
      if (myPhoto.startsWith('http'))
        'memberPhotos': {uid: myPhoto},
    });
    return ref.id;
  }

  /// Odanın varlığı + türü + üye listesi (tek okumayla).
  ///
  /// `subscriberCount` güvenlik kurallarında yalnızca kanallarda
  /// değiştirilebilir; grup işlemlerinde bu alanın yazılmaması için
  /// oda türünün önceden bilinmesi gerekir.
  Future<({bool exists, bool isChannel, List<String> memberIds})>
      _fetchRoomState(String roomId) async {
    final doc = await _rooms.doc(roomId).get();
    if (!doc.exists) {
      return (exists: false, isChannel: false, memberIds: const <String>[]);
    }
    final data = doc.data() ?? const <String, dynamic>{};
    return (
      exists: true,
      isChannel: data['type'] == RoomType.channel,
      memberIds: (data['memberIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }

  /// Kanala abone olur. Zaten üyeyken tekrar çağrılırsa sayaç
  /// artmaz ve işlem sessizce biter (çift dokunuş/yenileme güvenli).
  /// (Sohbet ekranındaki "katıl" akışı gruplar için de bu yolu
  /// kullanır; sayaç bu yüzden yalnız kanalda yazılır.)
  Future<void> joinChannel(String roomId) async {
    final uid = _requireUid();
    final state = await _fetchRoomState(roomId);
    if (!state.exists) {
      throw const ChatException('Kanal bulunamadı.');
    }
    if (state.memberIds.contains(uid)) return;
    final myName = (_auth.currentUser?.displayName ?? '').trim();
    await _rooms.doc(roomId).update({
      'memberIds': FieldValue.arrayUnion([uid]),
      if (state.isChannel) 'subscriberCount': FieldValue.increment(1),
      // Üye listesinde "Kullanıcı" yerine gerçek ad görünsün diye ad da
      // yazılır (katılma bloğu `memberNames` değişimine izin verir;
      // `memberPhotos` bu blokta yazılamaz — fotoğraflar arayüzde canlı
      // profilden çözülür).
      if (myName.isNotEmpty) 'memberNames.$uid': myName,
    });
  }

  /// Kanaldan ayrılır. Üye değilken çağrılırsa sayaç azalmaz.
  Future<void> leaveChannel(String roomId) async {
    final uid = _requireUid();
    final state = await _fetchRoomState(roomId);
    if (!state.memberIds.contains(uid)) return;
    await _rooms.doc(roomId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
      if (state.isChannel) 'subscriberCount': FieldValue.increment(-1),
    });
  }

  // ---------------------------------------------------------------------------
  // Kanal / grup yönetimi
  // ---------------------------------------------------------------------------

  /// Kanal veya grubun adını/açıklamasını günceller.
  Future<void> updateRoomInfo(
    String roomId, {
    String? name,
    String? about,
  }) async {
    _requireUid();
    final data = <String, dynamic>{};
    if (name != null) {
      final trimmed = name.trim();
      if (trimmed.length < 3) {
        throw const ChatException('Ad en az 3 karakter olmalı.');
      }
      if (trimmed.length > 80) {
        throw const ChatException('Ad en fazla 80 karakter olabilir.');
      }
      data['name'] = trimmed;
    }
    if (about != null) data['about'] = about.trim();
    if (data.isEmpty) return;
    await _rooms.doc(roomId).set(data, SetOptions(merge: true));
  }

  /// Kanal/grup fotoğrafı için üst sınır (kuraldaki `isPhoto` ile aynı).
  /// 400 000 karakter ≈ 390 KB; tipik avatar 10-25 KB.
  static const int maxRoomPhotoLength = 400000;

  /// Kanal/grup fotoğrafını değiştirir.
  ///
  /// [dataUri] boş verilirse fotoğraf kaldırılır. Firestore'a base64
  /// `data:` URI'si olarak yazılır (Storage kullanılmıyor), bu yüzden boyut
  /// sınırı burada da kontrol edilir.
  Future<void> setRoomPhoto(String roomId, String dataUri) async {
    _requireUid();
    final value = dataUri.trim();
    if (value.isEmpty) {
      await _rooms.doc(roomId).set({
        'photoUrl': '',
      }, SetOptions(merge: true));
      return;
    }
    if (!value.startsWith('data:image/')) {
      throw const ChatException('Fotoğraf okunamadı, tekrar deneyin.');
    }
    if (value.length > maxRoomPhotoLength) {
      throw const ChatException('Fotoğraf çok büyük (en fazla ~390 KB).');
    }
    await _rooms.doc(roomId).set({
      'photoUrl': value,
    }, SetOptions(merge: true));
  }

  /// Bir izni açar/kapatır (bkz. `ChatRoom.permOnlyModsPost`).
  Future<void> setPermission(
    String roomId,
    String key, {
    required bool value,
  }) async {
    _requireUid();
    await _rooms.doc(roomId).update({
      'permissions.$key': value,
    });
  }

  /// Üyeyi moderatör yapar ya da moderatörlüğünü kaldırır.
  ///
  /// Moderatörlük yalnızca halihazırda oda üyesi olan birine verilebilir;
  /// kanal dışından biri bu yolla (otomatik üye yapılarak) moderatör
  /// olamaz. Moderatörlüğü kaldırmak için üyelik şartı aranmaz — ayrılmış
  /// birinin eski rol kaydı da temizlenebilmeli.
  Future<void> setModerator(
    String roomId,
    String uid, {
    required bool moderator,
  }) async {
    _requireUid();
    if (moderator) {
      final state = await _fetchRoomState(roomId);
      if (!state.exists) {
        throw const ChatException('Kanal/grup bulunamadı.');
      }
      if (!state.memberIds.contains(uid)) {
        throw const ChatException(
          'Yalnızca kanal üyeleri moderatör yapılabilir. '
          'Kişi önce kanala katılmalı.',
        );
      }
    }
    await _rooms.doc(roomId).update({
      'roles.$uid': moderator ? ChatRoom.roleModerator : ChatRoom.roleMember,
    });
  }

  /// Üyeyi odadan çıkarır (mesajları silinmez).
  ///
  /// Hedef zaten üye değilse abone sayacı azaltılmaz; yalnızca
  /// kalmış rol/ad kayıtları temizlenir. Sayaç yalnız kanalda yazılır.
  Future<void> removeMember(String roomId, String uid) async {
    _requireUid();
    final state = await _fetchRoomState(roomId);
    if (!state.exists) return;

    final data = <String, dynamic>{
      'roles.$uid': FieldValue.delete(),
      'memberNames.$uid': FieldValue.delete(),
      'memberPhotos.$uid': FieldValue.delete(),
    };
    if (state.memberIds.contains(uid)) {
      data['memberIds'] = FieldValue.arrayRemove([uid]);
      if (state.isChannel) {
        data['subscriberCount'] = FieldValue.increment(-1);
      }
    }
    await _rooms.doc(roomId).update(data);
  }

  /// Odaya üye ekler (profil bilgisi verilirse adı da yazılır).
  ///
  /// Kişi zaten üyeyse liste ve abone sayacı tekrar değişmez;
  /// sayaç yalnız kanalda yazılır (kural gruplarda kabul etmez).
  Future<void> addMember(
    String roomId, {
    required String uid,
    String name = '',
    String photoUrl = '',
  }) async {
    _requireUid();
    final state = await _fetchRoomState(roomId);
    if (!state.exists) {
      throw const ChatException('Kanal/grup bulunamadı.');
    }

    final data = <String, dynamic>{};
    if (!state.memberIds.contains(uid)) {
      data['memberIds'] = FieldValue.arrayUnion([uid]);
      if (state.isChannel) {
        data['subscriberCount'] = FieldValue.increment(1);
      }
    }
    if (name.trim().isNotEmpty) data['memberNames.$uid'] = name.trim();
    if (photoUrl.trim().isNotEmpty) {
      // base64 avatarlar oda dokümanını şişirmesin.
      if (!photoUrl.startsWith('data:')) {
        data['memberPhotos.$uid'] = photoUrl.trim();
      }
    }
    if (data.isEmpty) return;
    await _rooms.doc(roomId).update(data);
  }

  /// Kanalın/grupların sahipliğini devreder; eski sahip moderatör olur.
  Future<void> transferOwnership(String roomId, String newOwnerUid) async {
    final uid = _requireUid();
    await _rooms.doc(roomId).update({
      'ownerUid': newOwnerUid,
      'roles.$newOwnerUid': FieldValue.delete(),
      'roles.$uid': ChatRoom.roleModerator,
    });
  }

  /// Odadan ayrılır (sahip önce devretmeli — arayüz uyarır).
  ///
  /// Üye değilken çağrılırsa yalnızca liste görünümü temizlenir;
  /// sayaç yalnız kanalda (ve gerçekten ayrılırken) azalır.
  Future<void> leaveRoom(String roomId) async {
    final uid = _requireUid();
    final state = await _fetchRoomState(roomId);
    if (!state.exists) return;

    if (!state.memberIds.contains(uid)) {
      await _rooms.doc(roomId).update({
        'hiddenFor': FieldValue.arrayUnion([uid]),
      });
      return;
    }

    await _rooms.doc(roomId).update({
      'memberIds': FieldValue.arrayRemove([uid]),
      if (state.isChannel)
        'subscriberCount': FieldValue.increment(-1),
      'hiddenFor': FieldValue.arrayUnion([uid]),
      'roles.$uid': FieldValue.delete(),
    });
  }

  /// Bir üyenin oda içindeki profil bilgisi (ad/fotoğraf).
  ///
  /// Fotoğraf olduğu gibi döndürülür (galeriden seçilmiş `data:` URI'si
  /// dahil): avatar gösteriminde kullanılmak içindir. Oda dokümanına
  /// yazarken base64'ü elemek çağıranın sorumluluğudur ([addMember] eler).
  Future<Map<String, String>> fetchMemberInfo(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data() ?? const <String, dynamic>{};
      final photo = (data['photoUrl'] as String?)?.trim() ?? '';
      return {
        'name': (data['displayName'] as String?)?.trim() ?? '',
        'photoUrl': photo,
      };
    } catch (_) {
      return const <String, String>{};
    }
  }

  // ---------------------------------------------------------------------------
  // Davet bağlantıları
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('room_invites');

  /// Kanal/grup için yeni bir davet kodu üretir ve döndürür.
  ///
  /// Kod `room_invites/{code}` dokümanına yazılır; katılmak isteyen kişi
  /// kodu (ya da `rebelzmedia://katil/<kod>` bağlantısını) girer.
  Future<RoomInvite> createInvite({
    required String roomId,
    String roomName = '',
    String roomType = '',
  }) async {
    final uid = _requireUid();
    final code = generateInviteCode();
    final ref = _invites.doc(code);
    await ref.set({
      'roomId': roomId,
      'createdBy': uid,
      'roomName': roomName.trim(),
      'roomType': roomType,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return RoomInvite(
      code: code,
      roomId: roomId,
      createdBy: uid,
      roomName: roomName.trim(),
      roomType: roomType,
      createdAt: DateTime.now(),
    );
  }

  /// Kullanıcının bu oda için oluşturduğu davet bağlantıları.
  ///
  /// Firestore kuralları listelemeye yalnızca `createdBy == kendi uid`
  /// kayıtlarında izin verir (davet kodlarının başkasına sızmasını engeller),
  /// bu yüzden sorgu iki eşitlik filtresi içerir — bileşik indeks gerekmez.
  Stream<List<RoomInvite>> watchInvites(String roomId) {
    final uid = _myUid;
    if (uid == null) return Stream<List<RoomInvite>>.value(const <RoomInvite>[]);
    return _invites
        .where('roomId', isEqualTo: roomId)
        .where('createdBy', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map(RoomInvite.fromDoc).toList();
      list.sort((a, b) {
        final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
      return list;
    });
  }

  /// Davet kodunu iptal eder.
  Future<void> revokeInvite(String code) async {
    _requireUid();
    await _invites.doc(code).delete();
  }

  /// Kod/bağlantı ile odaya katılır ve oda kimliğini döndürür.
  Future<String> joinByInviteCode(String rawCode) async {
    final uid = _requireUid();
    final code = normalizeInviteCode(rawCode);
    if (code.length < 6) {
      throw const ChatException('Davet kodu geçersiz görünüyor.');
    }

    final inviteDoc = await _invites.doc(code).get();
    if (!inviteDoc.exists) {
      throw const ChatException(
        'Davet bulunamadı. Bağlantı iptal edilmiş olabilir.',
      );
    }

    final roomId = (inviteDoc.data()?['roomId'] as String?)?.trim() ?? '';
    if (roomId.isEmpty) {
      throw const ChatException('Davet geçersiz.');
    }

    final roomDoc = await _rooms.doc(roomId).get();
    if (!roomDoc.exists) {
      throw const ChatException('Davet edilen kanal/grup artık yok.');
    }

    final data = roomDoc.data() ?? const <String, dynamic>{};
    final members = (data['memberIds'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();

    if (!members.contains(uid)) {
      final myName = (_auth.currentUser?.displayName ?? '').trim();
      // Noktalı alan yolu için `update` şart. Abone sayacı yalnız
      // kanalda yazılır; gruplarda bu alan dokümana eklenmez.
      await _rooms.doc(roomId).update({
        'memberIds': FieldValue.arrayUnion([uid]),
        if (data['type'] == RoomType.channel)
          'subscriberCount': FieldValue.increment(1),
        'hiddenFor': FieldValue.arrayRemove([uid]),
        if (myName.isNotEmpty) 'memberNames.$uid': myName,
      });
    } else {
      // Zaten üye: yalnızca listede görünmesini sağla.
      await _rooms.doc(roomId).update({
        'hiddenFor': FieldValue.arrayRemove([uid]),
      });
    }

    return roomId;
  }

  /// Kanalı özel (yalnızca davetle) ya da herkese açık yapar.
  Future<void> setChannelPrivacy(
    String roomId, {
    required bool isPrivate,
  }) async {
    _requireUid();
    await _rooms.doc(roomId).set({
      'isPrivate': isPrivate,
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
    final uid = _requireUid();
    final roomRef = _rooms.doc(roomId);

    // DM'i iki taraf da silebilir; grup/kanalı yalnızca sahibi.
    // Yetkisiz denemede mesajlar yarıda hata verene kadar silinmek
    // yerine en başta anlaşılır mesaj döner.
    final roomDoc = await roomRef.get();
    if (roomDoc.exists) {
      final room = ChatRoom.fromDoc(roomDoc, viewerUid: uid);
      if (!room.isDirect && !room.sahipMi(uid)) {
        throw ChatException(
          room.isChannel
              ? 'Kanalı yalnızca sahibi silebilir.'
              : 'Grubu yalnızca sahibi silebilir.',
        );
      }
    }

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

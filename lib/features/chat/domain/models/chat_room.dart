import 'package:cloud_firestore/cloud_firestore.dart';

/// Sohbet türleri.
abstract final class RoomType {
  static const direct = 'dm';
  static const group = 'group';
  static const channel = 'channel';
}

/// Firestore `rooms/{roomId}` dokümanının modeli.
///
/// dm      : iki kişilik sohbet (kimlik: `dm_<uidA>_<uidB>`)
/// group   : çok kişili grup
/// channel : tek yönlü yayın kanalı (sahibi yazar, herkes okur)
class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberIds,
    this.type = RoomType.group,
    this.photoUrl = '',
    this.about = '',
    this.ownerUid = '',
    this.subscriberCount = 0,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderId = '',
    this.createdAt,
    this.memberNames = const <String, String>{},
    this.memberPhotos = const <String, String>{},
    this.typing = const <String, DateTime>{},
    this.readAt = const <String, DateTime>{},
  });

  final String id;
  final String name;
  final String createdBy;
  final List<String> memberIds;

  /// dm | group | channel
  final String type;

  final String photoUrl;

  /// Kanal açıklaması / grup hakkında.
  final String about;

  /// Kanal sahibi (yalnızca kanallarda dolu).
  final String ownerUid;

  final int subscriberCount;

  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String lastSenderId;
  final DateTime? createdAt;

  final Map<String, String> memberNames;
  final Map<String, String> memberPhotos;

  /// uid → son yazma zamanı ("yazıyor…" göstergesi).
  final Map<String, DateTime> typing;

  /// uid → sohbeti son okuma zamanı (✓✓ için).
  final Map<String, DateTime> readAt;

  bool get isDirect => type == RoomType.direct;
  bool get isGroup => type == RoomType.group;
  bool get isChannel => type == RoomType.channel;

  bool hasMember(String? uid) => uid != null && memberIds.contains(uid);

  String? peerUid(String? myUid) {
    if (!isDirect || myUid == null) return null;
    for (final uid in memberIds) {
      if (uid != myUid) return uid;
    }
    return null;
  }

  /// Karşı tarafın adı (dm'de memberNames'ten).
  String peerName(String? myUid) {
    final peer = peerUid(myUid);
    if (peer == null) return name;
    final value = memberNames[peer]?.trim() ?? '';
    return value.isEmpty ? name : value;
  }

  String peerPhoto(String? myUid) {
    final peer = peerUid(myUid);
    if (peer == null) return photoUrl;
    return memberPhotos[peer]?.trim() ?? '';
  }

  /// Karşı taraf şu an yazıyor mu? (son 5 saniye)
  bool isPeerTyping(String? myUid) {
    if (myUid == null) return false;
    final now = DateTime.now();
    for (final entry in typing.entries) {
      if (entry.key == myUid) continue;
      if (now.difference(entry.value).inSeconds <= 5) return true;
    }
    return false;
  }

  /// Karşı taraf bu zamanı okudu mu?
  bool isReadByPeer(String? myUid, DateTime? at) {
    if (myUid == null || at == null) return false;
    for (final entry in readAt.entries) {
      if (entry.key == myUid) continue;
      if (!entry.value.isBefore(at)) return true;
    }
    return false;
  }

  ChatRoom copyWith({
    String? name,
    String? photoUrl,
    String? about,
  }) {
    return ChatRoom(
      id: id,
      name: name ?? this.name,
      createdBy: createdBy,
      memberIds: memberIds,
      type: type,
      photoUrl: photoUrl ?? this.photoUrl,
      about: about ?? this.about,
      ownerUid: ownerUid,
      subscriberCount: subscriberCount,
      lastMessage: lastMessage,
      lastMessageAt: lastMessageAt,
      lastSenderId: lastSenderId,
      createdAt: createdAt,
      memberNames: memberNames,
      memberPhotos: memberPhotos,
      typing: typing,
      readAt: readAt,
    );
  }

  /// [viewerUid] verilirse doğrudan sohbette karşı tarafın adı/fotoğrafı
  /// kullanılır; böylece her iki taraf da karşısındakini görür.
  factory ChatRoom.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String? viewerUid,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};

    final memberIds = (data['memberIds'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false);

    final type = switch (data['type']) {
      RoomType.direct => RoomType.direct,
      RoomType.channel => RoomType.channel,
      _ => RoomType.group,
    };

    final rawNames = (data['memberNames'] as Map?)?.cast<String, dynamic>();
    final rawPhotos = (data['memberPhotos'] as Map?)?.cast<String, dynamic>();
    final rawTyping = (data['typing'] as Map?)?.cast<String, dynamic>();
    final rawRead = (data['readAt'] as Map?)?.cast<String, dynamic>();

    final memberNames = {
      for (final entry in (rawNames ?? const <String, dynamic>{}).entries)
        entry.key: (entry.value ?? '').toString(),
    };
    final memberPhotos = {
      for (final entry in (rawPhotos ?? const <String, dynamic>{}).entries)
        entry.key: (entry.value ?? '').toString(),
    };
    final typing = <String, DateTime>{};
    for (final entry in (rawTyping ?? const <String, dynamic>{}).entries) {
      final value = entry.value;
      if (value is Timestamp) typing[entry.key] = value.toDate();
    }
    final readAt = <String, DateTime>{};
    for (final entry in (rawRead ?? const <String, dynamic>{}).entries) {
      final value = entry.value;
      if (value is Timestamp) readAt[entry.key] = value.toDate();
    }

    var name = (data['name'] as String?)?.trim().isNotEmpty == true
        ? (data['name'] as String).trim()
        : 'İsimsiz sohbet';
    var photoUrl = (data['photoUrl'] as String?)?.trim() ?? '';

    if (type == RoomType.direct && viewerUid != null) {
      String? peer;
      for (final uid in memberIds) {
        if (uid != viewerUid) {
          peer = uid;
          break;
        }
      }
      if (peer != null) {
        final peerName = (memberNames[peer] ?? '').trim();
        if (peerName.isNotEmpty) name = peerName;
        photoUrl = (memberPhotos[peer] ?? '').trim();
      }
    }

    return ChatRoom(
      id: doc.id,
      name: name,
      createdBy: (data['createdBy'] as String?) ?? '',
      memberIds: memberIds,
      type: type,
      photoUrl: photoUrl,
      about: (data['about'] as String?)?.trim() ?? '',
      ownerUid: (data['ownerUid'] as String?) ?? '',
      subscriberCount: (data['subscriberCount'] as num?)?.toInt() ?? 0,
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastSenderId: (data['lastSenderId'] as String?) ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      memberNames: memberNames,
      memberPhotos: memberPhotos,
      typing: typing,
      readAt: readAt,
    );
  }

  String get preview =>
      (lastMessage ?? '').trim().isEmpty ? 'Henüz mesaj yok' : lastMessage!;
}

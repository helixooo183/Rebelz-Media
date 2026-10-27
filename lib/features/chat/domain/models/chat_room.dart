import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore `rooms/{roomId}` dokümanının modeli.
///
/// İki tür oda vardır:
///  * `dm`  — iki kişilik doğrudan sohbet (kimlik: `dm_<uidA>_<uidB>`)
///  * `group` — eski grup sohbetleri (geriye dönük uyumluluk)
class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.memberIds,
    this.type = 'group',
    this.photoUrl = '',
    this.lastMessage,
    this.lastMessageAt,
    this.createdAt,
  });

  final String id;
  final String name;
  final String createdBy;
  final List<String> memberIds;

  /// 'dm' ya da 'group'.
  final String type;

  /// Sohbet listesinde gösterilen avatar (karşı tarafın fotoğrafı).
  final String photoUrl;

  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  bool get isDirect => type == 'dm';

  /// Doğrudan sohbette karşı tarafın uid'si; grup ise `null`.
  String? peerUid(String? myUid) {
    if (!isDirect || myUid == null) return null;
    for (final uid in memberIds) {
      if (uid != myUid) return uid;
    }
    return null;
  }

  bool hasMember(String? uid) => uid != null && memberIds.contains(uid);

  /// [viewerUid] verilirse doğrudan sohbette **karşı tarafın** adı ve
  /// fotoğrafı (`memberNames` / `memberPhotos`) kullanılır; böylece sohbet
  /// listesinde her iki taraf da karşısındakinin adını görür.
  factory ChatRoom.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    String? viewerUid,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};

    final memberIds =
        (data['memberIds'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<String>()
            .toList(growable: false);

    var name = (data['name'] as String?)?.trim().isNotEmpty == true
        ? (data['name'] as String).trim()
        : 'İsimsiz sohbet';
    var photoUrl = (data['photoUrl'] as String?)?.trim() ?? '';

    final type = (data['type'] as String?) == 'dm' ? 'dm' : 'group';

    if (type == 'dm' && viewerUid != null) {
      String? peer;
      for (final uid in memberIds) {
        if (uid != viewerUid) {
          peer = uid;
          break;
        }
      }

      if (peer != null) {
        final names = (data['memberNames'] as Map?)?.cast<String, dynamic>();
        final photos = (data['memberPhotos'] as Map?)?.cast<String, dynamic>();

        final peerName = names?[peer]?.toString().trim() ?? '';
        if (peerName.isNotEmpty) name = peerName;

        final peerPhoto = photos?[peer]?.toString().trim() ?? '';
        photoUrl = peerPhoto;
      }
    }

    return ChatRoom(
      id: doc.id,
      name: name,
      createdBy: (data['createdBy'] as String?) ?? '',
      memberIds: memberIds,
      type: type,
      photoUrl: photoUrl,
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String get preview => lastMessage ?? 'Henüz mesaj yok';
}

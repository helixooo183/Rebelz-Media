import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Kanal/grup davet bağlantısı.
///
/// Firestore: `room_invites/{code}` → `roomId`, `createdBy`, `createdAt`,
/// `type`. Kod 8 karakterdir ve karıştırılabilen karakterler (0/O, 1/I)
/// kullanılmaz. Bağlantı biçimi: `rebelzmedia://katil/<code>` ya da
/// uygulama içinde "Kod ile katıl" alanına yazılan `<code>`.
class RoomInvite {
  const RoomInvite({
    required this.code,
    required this.roomId,
    required this.createdBy,
    this.roomName = '',
    this.roomType = '',
    this.createdAt,
  });

  /// Davet kodu (doküman kimliği).
  final String code;

  final String roomId;
  final String createdBy;

  /// Paylaşım metninde gösterilen ad (opsiyonel, kayıtta tutulur).
  final String roomName;
  final String roomType;

  final DateTime? createdAt;

  /// Paylaşılabilir bağlantı.
  String get link => linkFor(code);

  /// Kodu bağlantıya çevirir.
  static String linkFor(String code) => 'rebelzmedia://katil/$code';

  /// Paylaşım metni (WhatsApp, e-posta vb. için).
  String get shareText {
    final kind = roomType == 'channel' ? 'kanalına' : 'grubuna';
    final ad = roomName.isEmpty ? 'Rebelz Media' : roomName;
    return '$ad $kind katıl: $link\n'
        'Uygulamada: Katıl → kodu gir → $code';
  }

  factory RoomInvite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return RoomInvite(
      code: doc.id,
      roomId: (data['roomId'] as String?)?.trim() ?? '',
      createdBy: (data['createdBy'] as String?)?.trim() ?? '',
      roomName: (data['roomName'] as String?)?.trim() ?? '',
      roomType: (data['roomType'] as String?)?.trim() ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Davet kodu üretir: 8 karakter, karışmayan alfabe.
String generateInviteCode([Random? random]) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rnd = random ?? Random.secure();
  return List<String>.generate(
    8,
    (_) => alphabet[rnd.nextInt(alphabet.length)],
  ).join();
}

/// Kullanıcının yazdığı bağlantıyı/kodu normalize eder.
///
/// Kabul edilen biçimler:
///  * `ABCD2345`
///  * `rebelzmedia://katil/ABCD2345`
///  * `https://…/katil/ABCD2345`
String normalizeInviteCode(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return '';
  final slash = value.lastIndexOf('/');
  if (slash >= 0 && slash < value.length - 1) {
    value = value.substring(slash + 1);
  }
  value = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  return value;
}

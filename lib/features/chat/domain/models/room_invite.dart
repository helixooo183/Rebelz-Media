import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Kanal/grup davet bağlantısı.
///
/// Firestore: `room_invites/{code}` → `roomId`, `createdBy`, `createdAt`,
/// `type`. Kod 8 karakterdir ve karıştırılabilen karakterler (0/O, 1/I)
/// kullanılmaz. Paylaşılan bağlantı **https**'tir
/// (`https://helixooo183.github.io/Rebelz-Media/katil/?k=<code>`); bu adres
/// `rebelzmedia://katil/<code>` şemasına yönlendirir. Uygulama içinde "Kod ile
/// katıl" alanına doğrudan `<code>` da yazılabilir.
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

  /// Paylaşılabilir bağlantı (https — WhatsApp/SMS/e-postada tıklanabilir).
  String get link => linkFor(code);

  /// Yönlendirme sayfasının kökü (Firebase Hosting → `docs/katil/index.html`).
  /// Kod `?k=` parametresiyle taşınır. Yayınlamak için:
  /// `firebase deploy --only hosting`
  static const String webBase = 'https://rebelz-media.web.app';

  /// Uygulamayı doğrudan açan özel şema.
  static String deepLinkFor(String code) => 'rebelzmedia://katil/$code';

  /// Kodu paylaşılabilir https bağlantısına çevirir.
  static String linkFor(String code) => '$webBase/katil/?k=$code';

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

/// Bağlantıdan (`rebelzmedia://katil/ABCD2345`) davet kodunu çıkarır.
///
/// Özel şemada `host` bilgisi `path` içine karışabildiği için hem
/// `katil/<kod>` hem `/katil/<kod>` biçimi denenir. Kod bulunamazsa `null`.
String? inviteCodeFromUri(Uri uri) {
  // https bağlantısı: .../katil/?k=KOD (veya ?kod= / ?code=)
  for (final key in const ['k', 'kod', 'code']) {
    final fromQuery = normalizeInviteCode(uri.queryParameters[key] ?? '');
    if (fromQuery.length >= 6) return fromQuery;
  }

  final raw = uri.toString();
  if (!raw.toLowerCase().contains('katil')) return null;

  // `rebelzmedia://katil/KOD` biçiminde "katil" host'ta kalır, http
  // bağlantılarında ise yolun ilk parçasıdır — ikisini tek listede tara.
  final segments = <String>[
    if (uri.host.isNotEmpty) uri.host,
    ...uri.pathSegments,
  ];

  for (var i = 0; i < segments.length; i++) {
    if (segments[i].toLowerCase() == 'katil' && i + 1 < segments.length) {
      final code = normalizeInviteCode(segments[i + 1]);
      if (code.length >= 6) return code;
    }
  }
  return null;
}

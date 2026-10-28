import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Şikayet sebepleri (hem profil hem mesaj için ortak liste).
abstract final class ReportReasons {
  static const List<String> all = [
    'Spam / reklam',
    'Taciz veya zorbalık',
    'Nefret söylemi',
    'Cinsel içerik',
    'Şiddet tehdidi',
    'Sahte hesap',
    'Diğer',
  ];
}

/// Destek talebi konuları.
abstract final class SupportTopics {
  static const List<String> all = [
    'Hata bildirimi',
    'Giriş / hesap sorunu',
    'Bildirim gelmiyor',
    'Öneri',
    'Diğer',
  ];
}


/// Şikayet durumları.
abstract final class ReportStatus {
  static const String open = 'open';
  static const String resolved = 'resolved';
  static const String dismissed = 'dismissed';

  static String label(String status) => switch (status) {
        resolved => 'Çözüldü',
        dismissed => 'Reddedildi',
        _ => 'Açık',
      };
}

/// `reports/{id}` dokümanı (inceleme paneli için).
class ReportItem {
  const ReportItem({
    required this.id,
    required this.reporterUid,
    required this.targetUid,
    required this.reason,
    required this.status,
    this.reporterName = '',
    this.targetName = '',
    this.details = '',
    this.roomId = '',
    this.messageId = '',
    this.messageSnippet = '',
    this.createdAt,
  });

  final String id;
  final String reporterUid;
  final String reporterName;
  final String targetUid;
  final String targetName;
  final String reason;
  final String details;
  final String status;
  final String roomId;
  final String messageId;
  final String messageSnippet;
  final DateTime? createdAt;

  bool get isMesaj => messageId.isNotEmpty;
  bool get isAcik => status == ReportStatus.open;
  String get durumEtiketi => ReportStatus.label(status);

  factory ReportItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    String text(String key) => (data[key] as String?)?.trim() ?? '';
    return ReportItem(
      id: doc.id,
      reporterUid: text('reporterUid'),
      reporterName: text('reporterName'),
      targetUid: text('targetUid'),
      targetName: text('targetName'),
      reason: text('reason'),
      details: text('details'),
      status: text('status').isEmpty ? ReportStatus.open : text('status'),
      roomId: text('roomId'),
      messageId: text('messageId'),
      messageSnippet: text('messageSnippet'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Gönderilen destek talebi (geçmiş listesi için).
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.topic,
    required this.message,
    required this.status,
    this.createdAt,
    this.uid = '',
    this.name = '',
    this.email = '',
    this.adminReply = '',
    this.repliedAt,
  });

  final String id;
  final String topic;
  final String message;
  final String status;
  final DateTime? createdAt;

  /// Talebi açan kullanıcı (yönetici panelinde gösterilir).
  final String uid;
  final String name;
  final String email;

  /// Yöneticinin yanıtı (boşsa henüz yanıtlanmadı).
  final String adminReply;
  final DateTime? repliedAt;

  /// Yönetici yanıtladı mı?
  bool get yanitlandi => adminReply.isNotEmpty || status == 'answered';

  String get durumEtiketi => switch (status) {
        'answered' => 'Yanıtlandı',
        'closed' => 'Kapatıldı',
        _ => 'İncelemede',
      };

  factory SupportTicket.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return SupportTicket(
      id: doc.id,
      topic: (data['topic'] as String?)?.trim() ?? '',
      message: (data['message'] as String?)?.trim() ?? '',
      status: (data['status'] as String?)?.trim() ?? 'open',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      uid: (data['uid'] as String?)?.trim() ?? '',
      name: (data['name'] as String?)?.trim() ?? '',
      email: (data['email'] as String?)?.trim() ?? '',
      adminReply: (data['adminReply'] as String?)?.trim() ?? '',
      repliedAt: (data['repliedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Şikayet ve destek talepleri.
///
/// * Şikayetler `reports/{id}` koleksiyonuna yazılır (yalnızca gönderen
///   kendi kaydını okuyabilir).
/// * Destek talepleri `support_requests/{id}` koleksiyonuna yazılır.
///
/// Her iki koleksiyon da yalnızca **ekleme** kabul eder; kayıt sonradan
/// değiştirilemez (kanıt niteliği).
class ModerationRepository {
  ModerationRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');

  CollectionReference<Map<String, dynamic>> get _support =>
      _db.collection('support_requests');

  /// Bir kullanıcıyı veya mesajı şikayet eder.
  ///
  /// [roomId]/[messageId] verilirse şikayet mesaja bağlanır ve mesajın
  /// kısa bir özeti de saklanır (kanıt için).
  Future<void> sendReport({
    required String targetUid,
    required String reason,
    String targetName = '',
    String details = '',
    String roomId = '',
    String messageId = '',
    String messageSnippet = '',
  }) async {
    final uid = _requireUid();
    if (targetUid.isEmpty) {
      throw const ModerationException('Şikayet edilecek kişi bulunamadı.');
    }
    if (reason.trim().isEmpty) {
      throw const ModerationException('Bir şikayet sebebi seç.');
    }

    await _reports.doc().set({
      'reporterUid': uid,
      'reporterName': (_auth.currentUser?.displayName ?? '').trim(),
      'targetUid': targetUid,
      'targetName': targetName.trim(),
      'reason': reason.trim(),
      'details': details.trim(),
      'roomId': roomId,
      'messageId': messageId,
      'messageSnippet': _snippet(messageSnippet),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Destek talebi oluşturur.
  Future<void> sendSupportRequest({
    required String topic,
    required String message,
  }) async {
    final uid = _requireUid();
    final body = message.trim();
    if (body.length < 10) {
      throw const ModerationException('Talebi en az 10 karakterle anlat.');
    }

    final user = _auth.currentUser;
    await _support.doc().set({
      'uid': uid,
      'name': (user?.displayName ?? '').trim(),
      'email': (user?.email ?? '').trim(),
      'topic': topic.trim().isEmpty ? 'Diğer' : topic.trim(),
      'message': body,
      'status': 'open',
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Kullanıcının kendi destek talepleri (en yeni üstte).
  Stream<List<SupportTicket>> watchMySupportTickets() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream<List<SupportTicket>>.empty();
    try {
      // NOT: `orderBy('createdAt')` ile birleşince Firestore bileşik indeks
      // istiyor (FAILED_PRECONDITION). Tek alanlı eşitlik sorgusu + istemci
      // sıralaması hem indeks gerektirmez hem de aynı sonucu verir.
      return _support
          .where('uid', isEqualTo: uid)
          .limit(30)
          .snapshots()
          .map((snapshot) {
            final tickets =
                snapshot.docs.map(SupportTicket.fromDoc).toList();
            tickets.sort((a, b) {
              final aTime = a.createdAt ?? DateTime(1970);
              final bTime = b.createdAt ?? DateTime(1970);
              return bTime.compareTo(aTime);
            });
            return List<SupportTicket>.unmodifiable(tickets);
          });
    } catch (_) {
      return const Stream<List<SupportTicket>>.empty();
    }
  }

  // ---------------------------------------------------------------------------
  // İnceleme (yönetici)
  // ---------------------------------------------------------------------------

  /// Oturumdaki kullanıcı yönetici mi? (`admins/{uid}` dokümanı varsa evet.)
  Future<bool> isAdmin() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final doc = await _db.collection('admins').doc(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Tüm destek talepleri (yalnızca yönetici; kurallar da bunu ister).
  ///
  /// Sorgu tek koleksiyon taramasıdır (filtre yok) → bileşik indeks gerekmez.
  Stream<List<SupportTicket>> watchAllSupportTickets() {
    try {
      return _support.limit(200).snapshots().map((snapshot) {
        final tickets = snapshot.docs.map(SupportTicket.fromDoc).toList();
        tickets.sort((a, b) {
          final aTime = a.createdAt ?? DateTime(1970);
          final bTime = b.createdAt ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });
        return List<SupportTicket>.unmodifiable(tickets);
      });
    } catch (_) {
      return const Stream<List<SupportTicket>>.empty();
    }
  }

  /// Yönetici destek talebini yanıtlar.
  ///
  /// Yalnızca `adminReply`, `repliedAt`, `repliedBy`, `status` alanları
  /// yazılır; kural da başka alanı kabul etmez.
  Future<void> replyToSupportTicket(String ticketId, String reply) async {
    final uid = _requireUid();
    final body = reply.trim();
    if (body.length < 2) {
      throw const ModerationException('Yanıt çok kısa.');
    }
    if (body.length > 2000) {
      throw const ModerationException('Yanıt en fazla 2000 karakter olabilir.');
    }
    await _support.doc(ticketId).set({
      'adminReply': body,
      'repliedAt': FieldValue.serverTimestamp(),
      'repliedBy': uid,
      'status': 'answered',
    }, SetOptions(merge: true));
  }

  /// Tüm şikayetler (yalnızca yöneticiye açıktır — kurallar da bunu ister).
  Stream<List<ReportItem>> watchReports() {
    try {
      return _reports
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map(ReportItem.fromDoc).toList(growable: false));
    } catch (_) {
      return const Stream<List<ReportItem>>.empty();
    }
  }

  /// Şikayetin durumunu günceller (açık / çözüldü / reddedildi).
  Future<void> updateReportStatus(String reportId, String status) async {
    _requireUid();
    await _reports.doc(reportId).update({
      'status': status,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': _auth.currentUser?.uid ?? '',
    });
  }

  String _snippet(String raw) {
    final text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= 140) return text;
    return '${text.substring(0, 140)}…';
  }

  String _requireUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ModerationException('Bu işlem için giriş yapmalısın.');
    }
    return uid;
  }
}

/// Kullanıcıya doğrudan gösterilebilen hata.
class ModerationException implements Exception {
  const ModerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

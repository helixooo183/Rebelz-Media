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

/// Gönderilen destek talebi (geçmiş listesi için).
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.topic,
    required this.message,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String topic;
  final String message;
  final String status;
  final DateTime? createdAt;

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
      return _support
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map(SupportTicket.fromDoc)
              .toList(growable: false));
    } catch (_) {
      return const Stream<List<SupportTicket>>.empty();
    }
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

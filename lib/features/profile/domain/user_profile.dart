import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanıcı adı kuralları ve normalizasyonu.
///
/// Firestore'da arama yapılabilmesi için `usernameLower` alanı ayrı tutulur;
/// tekilliği `usernames/{usernameLower}` dokümanı garanti eder.
abstract final class Username {
  /// 3-20 karakter, yalnızca küçük harf, rakam ve alt çizgi.
  static final RegExp pattern = RegExp(r'^[a-z0-9_]{3,20}$');

  /// Ayıklama: başındaki `@`, boşluklar ve büyük harfler normalize edilir.
  static String normalize(String raw) {
    var value = raw.trim().toLowerCase();
    while (value.startsWith('@')) {
      value = value.substring(1);
    }
    return value.replaceAll(RegExp(r'\s+'), '');
  }

  static bool isValid(String raw) => pattern.hasMatch(normalize(raw));

  /// Kullanıcıya gösterilecek hata; geçerliyse `null`.
  static String? validate(String raw) {
    final value = normalize(raw);
    if (value.isEmpty) return 'Kullanıcı adı gerekli.';
    if (value.length < 3) return 'En az 3 karakter olmalı.';
    if (value.length > 20) return 'En fazla 20 karakter olabilir.';
    if (!pattern.hasMatch(value)) {
      return 'Yalnızca küçük harf, rakam ve alt çizgi kullanılabilir.';
    }
    return null;
  }
}

/// `users/{uid}` dokümanının modeli.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    this.username = '',
    this.bio = '',
    this.photoUrl = '',
    this.avatarEmoji = '',
    this.avatarColor = 0,
    this.email = '',
    this.termsVersion = '',
    this.termsAcceptedAt,
    this.createdAt,
    this.lastSeenAt,
  });

  final String uid;
  final String displayName;
  final String username;
  final String bio;

  /// Profil fotoğrafı (http/https URL). Boşsa emoji/baş harf avatarı çizilir.
  final String photoUrl;

  /// Fotoğraf yoksa gösterilen emoji (ör. "🐺"). Boşsa baş harf kullanılır.
  final String avatarEmoji;

  /// 0..5 arası hazır avatar renk paleti indeksi.
  final int avatarColor;

  final String email;

  /// Kabul edilen koşul sürümü (ör. "2026-10-27") ve zamanı — kanıt kaydı.
  final String termsVersion;
  final DateTime? termsAcceptedAt;

  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  String get usernameLower => username.toLowerCase();

  String get handle => username.isEmpty ? '@kullanici' : '@$username';

  bool get hasPhoto => photoUrl.trim().isNotEmpty;

  bool get termsAccepted => termsAcceptedAt != null;

  /// Baş harf (fotoğraf/emoji yoksa).
  String get initial {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  /// Avatar bileşeninin ihtiyaç duyduğu alanlar.
  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String).trim()
          : 'Kullanıcı',
      username: (data['username'] as String?)?.trim() ?? '',
      bio: (data['bio'] as String?)?.trim() ?? '',
      photoUrl: (data['photoUrl'] as String?)?.trim() ?? '',
      avatarEmoji: (data['avatarEmoji'] as String?)?.trim() ?? '',
      avatarColor: (data['avatarColor'] as num?)?.toInt() ?? 0,
      email: (data['email'] as String?)?.trim() ?? '',
      termsVersion: (data['termsVersion'] as String?)?.trim() ?? '',
      termsAcceptedAt: (data['termsAcceptedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate(),
    );
  }

  factory UserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserProfile.fromMap(doc.id, doc.data() ?? const <String, dynamic>{});
  }

  UserProfile copyWith({
    String? displayName,
    String? username,
    String? bio,
    String? photoUrl,
    String? avatarEmoji,
    int? avatarColor,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarColor: avatarColor ?? this.avatarColor,
      email: email,
      termsVersion: termsVersion,
      termsAcceptedAt: termsAcceptedAt,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt,
    );
  }
}

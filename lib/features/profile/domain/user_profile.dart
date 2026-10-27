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

/// Kullanıcı adı değiştirme kotası.
///
/// Kural: **30 günlük dönemde en fazla 2 değişiklik**. Haklar bitince dönem
/// kapanana kadar kullanıcı adı kilitlidir; dönem dolduğunda haklar yeniden
/// 2'ye döner (sayaç sıfırlanır, yeni dönem başlar).
///
/// Sayaç Firestore'da `users/{uid}` dokümanındaki `usernameChanges` ve
/// `usernameWindowStart` alanlarında tutulur; kontrol `saveProfile`
/// transaction'ının içinde yapılır ki iki cihaz aynı anda hak harcamasın.
abstract final class UsernameChangePolicy {
  /// Bir dönemde tanınan değişiklik hakkı.
  static const int maxChanges = 2;

  /// Dönem uzunluğu (gün).
  static const int windowDays = 30;

  /// Dönem başlangıcından bitiş zamanı.
  static DateTime? windowEnd(DateTime? start) =>
      start?.add(const Duration(days: windowDays));

  /// Verilen sayaca göre kalan hak (0..[maxChanges]).
  static int remaining({
    required int used,
    DateTime? windowStart,
    DateTime? now,
  }) {
    if (windowStart == null) return maxChanges;
    final moment = now ?? DateTime.now();
    if (moment.difference(windowStart).inDays >= windowDays) return maxChanges;
    final left = maxChanges - used;
    return left < 0 ? 0 : left;
  }

  /// Kilitliyse yeni hakkın açılacağı zaman, değilse `null`.
  static DateTime? unlockAt({
    required int used,
    DateTime? windowStart,
    DateTime? now,
  }) {
    if (remaining(used: used, windowStart: windowStart, now: now) > 0) {
      return null;
    }
    return windowEnd(windowStart);
  }

  /// "12 gün sonra" / "bugün" biçiminde kalan süre.
  static String waitText(DateTime? until, {DateTime? now}) {
    if (until == null) return 'kısa süre sonra';
    final moment = now ?? DateTime.now();
    final days = until.difference(moment).inDays;
    if (days <= 0) return 'bugün';
    return '$days gün sonra';
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
    this.usernameChanges = 0,
    this.usernameWindowStart,
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

  /// Profil fotoğrafı. İki biçim desteklenir:
  ///  * `https://…` → dış bağlantı (`Image.network`)
  ///  * `data:image/…;base64,…` → galeriden seçilip küçültülmüş görsel
  ///    (`Image.memory`). Storage kullanılmadığı için küçük bir küçültme
  ///    (en fazla 320 px) base64 olarak doğrudan dokümana yazılır.
  ///
  /// Boşsa emoji/baş harf avatarı çizilir.
  final String photoUrl;

  /// Fotoğraf yoksa gösterilen emoji (ör. "🐺"). Boşsa baş harf kullanılır.
  ///
  /// Eski kayıtlarla uyumluluk için korunur; düzenleme ekranında artık
  /// değiştirilemez (avatar yalnızca galeriden seçilir).
  final String avatarEmoji;

  /// 0..5 arası hazır avatar renk paleti indeksi (yalnızca fotoğraf yokken).
  final int avatarColor;

  /// Bu dönemde harcanan kullanıcı adı değişiklik hakkı.
  final int usernameChanges;

  /// Dönemin başlangıcı; `null` ise hiç değiştirilmemiş.
  final DateTime? usernameWindowStart;

  final String email;

  /// Kabul edilen koşul sürümü (ör. "2026-10-27") ve zamanı — kanıt kaydı.
  final String termsVersion;
  final DateTime? termsAcceptedAt;

  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  String get usernameLower => username.toLowerCase();

  String get handle => username.isEmpty ? '@kullanici' : '@$username';

  bool get hasPhoto => photoUrl.trim().isNotEmpty;

  /// Fotoğraf galeriden seçilmiş base64 verisi mi?
  bool get hasDataPhoto => photoUrl.trim().startsWith('data:image/');

  bool get termsAccepted => termsAcceptedAt != null;

  /// Kalan kullanıcı adı değişiklik hakkı (0..[UsernameChangePolicy.maxChanges]).
  int get kalanKullaniciAdiHakki => UsernameChangePolicy.remaining(
        used: usernameChanges,
        windowStart: usernameWindowStart,
      );

  /// Kullanıcı adı şu an kilitli mi?
  bool get kullaniciAdiKilitli => kalanKullaniciAdiHakki <= 0;

  /// Kilitliyse yeni hakkın açılacağı zaman.
  DateTime? get yeniKullaniciAdiHakki => UsernameChangePolicy.unlockAt(
        used: usernameChanges,
        windowStart: usernameWindowStart,
      );

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
      usernameChanges: (data['usernameChanges'] as num?)?.toInt() ?? 0,
      usernameWindowStart:
          (data['usernameWindowStart'] as Timestamp?)?.toDate(),
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
    int? usernameChanges,
    DateTime? usernameWindowStart,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarColor: avatarColor ?? this.avatarColor,
      usernameChanges: usernameChanges ?? this.usernameChanges,
      usernameWindowStart: usernameWindowStart ?? this.usernameWindowStart,
      email: email,
      termsVersion: termsVersion,
      termsAcceptedAt: termsAcceptedAt,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt,
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../domain/legal_texts.dart';
import '../domain/user_profile.dart';

/// Profil, kullanıcı arama, engelleme ve onay kayıtlarıyla ilgili
/// tüm Firestore işlemleri.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  /// Avatar alanının (`photoUrl`) üst sınırı: base64 data URI ~390 KB.
  /// Galeriden seçilen fotoğraf 320 px'e küçültüldüğü için tipik değer
  /// 10-25 KB; sınır yalnızca yanlış kullanımı engeller.
  static const int maxPhotoLength = 400000;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection('usernames');

  String? get _myUid => _auth.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Okuma
  // ---------------------------------------------------------------------------

  /// Tek kullanıcı profilinin canlı akışı.
  Stream<UserProfile?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromDoc(doc);
    });
  }

  /// Oturum açan kullanıcının profili.
  Stream<UserProfile?> watchMyProfile() {
    final uid = _myUid;
    if (uid == null) return const Stream<UserProfile?>.empty();
    return watchProfile(uid);
  }

  Future<UserProfile?> fetchProfile(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) return null;
      return UserProfile.fromDoc(doc);
    } catch (_) {
      return null;
    }
  }

  /// Kullanıcı adı ve görünen ada göre arama (en çok 20 sonuç).
  ///
  /// Firestore tek alanda aralık sorgusu desteklediği için iki sorgu
  /// çalıştırılıp birleştirilir; kendisi ve engellenenler elenir.
  Future<List<UserProfile>> searchUsers(
    String rawQuery, {
    Set<String> excludeUids = const <String>{},
  }) async {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return const <UserProfile>[];

    final upperBound = '$query\uf8ff';
    final results = <String, UserProfile>{};

    Future<void> run(Query<Map<String, dynamic>> q) async {
      try {
        final snapshot = await q.limit(20).get();
        for (final doc in snapshot.docs) {
          final profile = UserProfile.fromDoc(doc);
          if (profile.uid == _myUid) continue;
          if (excludeUids.contains(profile.uid)) continue;
          results[profile.uid] = profile;
        }
      } catch (_) {
        // Tek alan indeksi yoksa sorgu hata verebilir; diğerini dene.
      }
    }

    await run(
      _users
          .where('usernameLower', isGreaterThanOrEqualTo: query)
          .where('usernameLower', isLessThan: upperBound),
    );
    await run(
      _users
          .where('displayNameLower', isGreaterThanOrEqualTo: query)
          .where('displayNameLower', isLessThan: upperBound),
    );

    final list = results.values.toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ));
    return list;
  }

  // ---------------------------------------------------------------------------
  // Profil düzenleme
  // ---------------------------------------------------------------------------

  /// Profil alanlarını günceller ve kullanıcı adının tekilliğini garanti eder.
  ///
  /// Kullanıcı adı değişiyorsa `usernames/{usernameLower}` kaydı da taşınır;
  /// başkası tarafından alınmışsa [ProfileException] fırlatılır.
  Future<void> saveProfile({
    required String displayName,
    required String username,
    String bio = '',
    String photoUrl = '',
    String avatarEmoji = '',
    int avatarColor = 0,
  }) async {
    final uid = _requireUid();
    final trimmedName = displayName.trim();
    if (trimmedName.length < 2) {
      throw const ProfileException('Görünen ad en az 2 karakter olmalı.');
    }

    final normalizedUsername = Username.normalize(username);
    final usernameError = Username.validate(normalizedUsername);
    if (usernameError != null) throw ProfileException(usernameError);

    final trimmedPhoto = photoUrl.trim();
    if (trimmedPhoto.length > maxPhotoLength) {
      throw const ProfileException(
        'Profil fotoğrafı çok büyük. Galeriden daha küçük bir fotoğraf seç.',
      );
    }

    final userRef = _users.doc(uid);
    final usernameRef = _usernames.doc(normalizedUsername);

    await _db.runTransaction((transaction) async {
      final currentUserDoc = await transaction.get(userRef);
      final currentData = currentUserDoc.data() ?? const <String, dynamic>{};
      final previousUsername =
          (currentData['usernameLower'] as String?)?.trim() ?? '';

      // ---- kullanıcı adı değişiklik kotası -------------------------------
      // 30 günlük dönemde en fazla 2 değişiklik. İlk kez ad almak (henüz ad
      // yokken seçmek) hak harcamaz.
      final isUsernameChange =
          previousUsername.isNotEmpty && previousUsername != normalizedUsername;

      var usedChanges = (currentData['usernameChanges'] as num?)?.toInt() ?? 0;
      var windowStart =
          (currentData['usernameWindowStart'] as Timestamp?)?.toDate();

      if (isUsernameChange) {
        final now = DateTime.now();
        final windowExpired = windowStart == null ||
            now.difference(windowStart).inDays >= UsernameChangePolicy.windowDays;
        if (windowExpired) {
          usedChanges = 0;
          windowStart = now;
        }

        if (usedChanges >= UsernameChangePolicy.maxChanges) {
          final unlock = UsernameChangePolicy.windowEnd(windowStart);
          throw ProfileException(
            'Kullanıcı adını ${UsernameChangePolicy.maxChanges} kez değiştirdin. '
            'Yeni hak ${UsernameChangePolicy.waitText(unlock)} açılır.',
          );
        }
        usedChanges += 1;
      }

      final claim = await transaction.get(usernameRef);
      if (claim.exists) {
        final ownerUid = (claim.data()?['uid'] as String?) ?? '';
        if (ownerUid.isNotEmpty && ownerUid != uid) {
          throw const ProfileException('Bu kullanıcı adı zaten alınmış.');
        }
      }

      if (previousUsername.isNotEmpty && previousUsername != normalizedUsername) {
        transaction.delete(_usernames.doc(previousUsername));
      }

      transaction.set(usernameRef, {
        'uid': uid,
        'usernameLower': normalizedUsername,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final profileData = <String, dynamic>{
        'displayName': trimmedName,
        'displayNameLower': trimmedName.toLowerCase(),
        'username': normalizedUsername,
        'usernameLower': normalizedUsername,
        'bio': bio.trim(),
        'photoUrl': trimmedPhoto,
        'avatarEmoji': avatarEmoji.trim(),
        'avatarColor': avatarColor,
        'lastSeenAt': FieldValue.serverTimestamp(),
      };

      // Kota alanları yalnızca gerçek bir değişiklikte yazılır; böylece adı
      // aynı bırakan kayıtlar sayacı/penceresi bozmaz.
      if (isUsernameChange) {
        profileData['usernameChanges'] = usedChanges;
        if (windowStart != null) {
          profileData['usernameWindowStart'] = Timestamp.fromDate(windowStart);
        }
      }

      transaction.set(userRef, profileData, SetOptions(merge: true));
    });

    final user = _auth.currentUser;
    if (user != null && user.displayName != trimmedName) {
      try {
        await user.updateDisplayName(trimmedName);
      } catch (_) {
        // Görünen ad Firebase Auth'ta güncellenemezse Firestore kaydı yeterli.
      }
    }
  }

  Future<void> touchLastSeen() async {
    final uid = _myUid;
    if (uid == null) return;
    try {
      await _users.doc(uid).set({
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Sessiz geç: son görülme kritik değil.
    }
  }

  // ---------------------------------------------------------------------------
  // Koşul onayı (kanıt kaydı)
  // ---------------------------------------------------------------------------

  /// Kullanım koşullarını kabul eder.
  ///
  /// İki yere yazılır:
  ///  * `users/{uid}` → `termsAcceptedAt`, `termsVersion` (hızlı kontrol)
  ///  * `users/{uid}/consents/{auto}` → değiştirilemez onay kaydı
  ///    (uid, e-posta, sürüm, cihaz, zaman)
  Future<void> acceptTerms({String version = LegalTexts.version}) async {
    final uid = _requireUid();
    final user = _auth.currentUser;
    final batch = _db.batch();

    batch.set(_users.doc(uid), {
      'termsAcceptedAt': FieldValue.serverTimestamp(),
      'termsVersion': version,
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(_users.doc(uid).collection('consents').doc(), {
      'uid': uid,
      'email': user?.email ?? '',
      'version': version,
      'accepted': true,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // Engelleme
  // ---------------------------------------------------------------------------

  CollectionReference<Map<String, dynamic>> _blockedCol(String uid) =>
      _users.doc(uid).collection('blocked');

  /// Engellenen kullanıcı kimlikleri (canlı).
  Stream<Set<String>> watchBlockedUids() {
    final uid = _myUid;
    if (uid == null) return Stream<Set<String>>.value(const <String>{});
    return _blockedCol(uid).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => doc.id).toSet(),
        );
  }

  Future<Set<String>> fetchBlockedUids() async {
    final uid = _myUid;
    if (uid == null) return const <String>{};
    try {
      final snapshot = await _blockedCol(uid).get();
      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (_) {
      return const <String>{};
    }
  }

  Future<void> blockUser(String blockedUid) async {
    final uid = _requireUid();
    if (uid == blockedUid) {
      throw const ProfileException('Kendini engelleyemezsin.');
    }
    await _blockedCol(uid).doc(blockedUid).set({
      'blockedUid': blockedUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unblockUser(String blockedUid) async {
    final uid = _requireUid();
    await _blockedCol(uid).doc(blockedUid).delete();
  }

  /// Engellenen kullanıcıların profilleri (liste ekranı için).
  Future<List<UserProfile>> fetchBlockedProfiles() async {
    final uids = await fetchBlockedUids();
    final profiles = <UserProfile>[];
    for (final uid in uids) {
      final profile = await fetchProfile(uid);
      if (profile != null) profiles.add(profile);
    }
    profiles.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return profiles;
  }

  String _requireUid() {
    final uid = _myUid;
    if (uid == null) {
      throw const ProfileException('Bu işlem için giriş yapmalısın.');
    }
    return uid;
  }
}

/// Kullanıcıya doğrudan gösterilebilen profil hatası.
class ProfileException implements Exception {
  const ProfileException(this.message);

  final String message;

  @override
  String toString() => message;
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../features/profile/domain/avatar_policy.dart';
import '../config/google_sign_in_config.dart';

/// Kimlik doğrulama işlemlerini tek noktada toplar
/// (e-posta/şifre + Google Sign-In).
///
/// Hata mesajları kullanıcıya gösterilebilecek Türkçe metinlere çevrilir.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void>? _googleInit;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  String get displayName {
    final user = _auth.currentUser;
    return user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : (user?.email?.split('@').first ?? 'Misafir');
  }

  // ---------------------------------------------------------------------------
  // E-posta / şifre
  // ---------------------------------------------------------------------------

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _upsertUserProfile(credential.user);
      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  Future<UserCredential> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(displayName.trim());
        await user.reload();
        await _upsertUserProfile(_auth.currentUser, fallbackName: displayName);

        // Doğrulama bağlantısı gönderilir; gönderilemezse kayıt yine de
        // tamamlanır (kullanıcı uygulamadan "tekrar gönder" diyebilir).
        try {
          await user.sendEmailVerification();
        } on FirebaseAuthException {
          // Sessiz geç: e-posta doğrulama akışı ayrı ekrandan yönetilir.
        }
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  /// Şifre sıfırlama bağlantısı gönderir.
  ///
  /// Firebase, kayıtlı olmayan adreslerde de aynı yanıtı döndürür
  /// (hesap varlığını sızdırmamak için); bu yüzden kullanıcıya "gönderildi"
  /// mesajı verilirken spam/gereksiz klasörü kontrol etmesi önerilir.
  Future<void> sendPasswordResetEmail(String email) async {
    final address = email.trim();
    if (address.isEmpty) {
      throw const AuthException('E-posta adresi gerekli.');
    }
    try {
      await _auth.sendPasswordResetEmail(email: address);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  /// Doğrulama e-postasını (yeniden) gönderir.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('Bu işlem için giriş yapmalısın.');
    }
    if (user.emailVerified) {
      throw const AuthException('E-posta adresin zaten doğrulanmış.');
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  /// Firebase'deki güncel kullanıcıyı çeker; doğrulama durumu değişmişse
  /// `true` döner. Bağlantıya tıklandıktan sonra bunu çağırmak gerekir.
  Future<bool> refreshEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final before = user.emailVerified;
    try {
      await user.reload();
    } on FirebaseAuthException {
      return before;
    }
    final current = _auth.currentUser;
    if (current != null && current.emailVerified && !before) {
      try {
        await _upsertUserProfile(current);
      } catch (_) {
        // Profil yazımı başarısız olsa da doğrulama geçerli.
      }
    }
    return current?.emailVerified ?? false;
  }

  bool get emailVerified => _auth.currentUser?.emailVerified ?? false;

  String? get email => _auth.currentUser?.email;

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------

  /// google_sign_in 7.x: eklenti kullanılmadan önce bir kez `initialize()`
  /// çağrılmalı. Android'de `idToken` alabilmek için `serverClientId`
  /// (Web client ID) verilmelidir. Web'de bu paket hiç başlatılmaz,
  /// Firebase'in kendi popup akışı kullanılır.
  Future<void> _ensureGoogleInitialized() {
    if (kIsWeb) return Future<void>.value();

    return _googleInit ??= GoogleSignIn.instance.initialize(
      serverClientId: GoogleSignInConfig.isConfigured
          ? GoogleSignInConfig.serverClientId
          : null,
    );
  }

  /// Google ile giriş. Kullanıcı iptal ederse `null` döner.
  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      try {
        final credential = await _auth.signInWithPopup(GoogleAuthProvider());
        await _upsertUserProfile(credential.user);
        return credential;
      } on FirebaseAuthException catch (e) {
        throw AuthException(_messageFor(e));
      }
    }

    if (!GoogleSignInConfig.isConfigured) {
      throw const AuthException(
        'Google girişi yapılandırılmadı: Web client ID eksik. '
        'README → "Google Sign-In" bölümüne bakın.',
      );
    }

    await _ensureGoogleInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const AuthException(
        'Bu platformda Google ile giriş desteklenmiyor.',
      );
    }

    final GoogleSignInAccount googleUser;
    try {
      googleUser = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null; // Kullanıcı vazgeçti: hata gösterme.
      }
      throw AuthException(_googleMessageFor(e));
    }

    final idToken = googleUser.authentication.idToken;
    if (idToken == null) {
      throw const AuthException(
        'Google kimlik doğrulaması tamamlanamadı (idToken alınamadı). '
        'SHA-1 parmak izinin Firebase projesine eklendiğinden emin olun.',
      );
    }

    try {
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await _auth.signInWithCredential(credential);
      await _upsertUserProfile(result.user);
      return result;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Çıkış
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    // Web'de GoogleSignIn başlatılmadığı için signOut() çağrılmamalı.
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } on GoogleSignInException {
        // Google oturumu yoksa yoksay.
      }
    }
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Yardımcılar
  // ---------------------------------------------------------------------------

  /// `users/{uid}` dokümanını oluşturur/günceller.
  /// Profil ekranı ve güvenlik kuralları bu dokümana dayanır.
  Future<void> _upsertUserProfile(User? user, {String? fallbackName}) async {
    if (user == null) return;

    final name = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : (fallbackName?.trim().isNotEmpty == true
            ? fallbackName!.trim()
            : user.email?.split('@').first ?? 'Misafir');

    final docRef = _firestore.collection('users').doc(user.uid);

    // Mevcut kayıt: kullanıcının kendi seçtiği ad/fotoğraf ezilmesin.
    var existing = const <String, dynamic>{};
    var isNew = false;
    try {
      final snapshot = await docRef.get();
      isNew = !snapshot.exists;
      existing = snapshot.data() ?? const <String, dynamic>{};
    } catch (_) {
      // Okuma engellenirse yalnızca var olan kayıt varsayımıyla devam et.
      isNew = false;
    }

    final resolvedName = AvatarPolicy.displayNameOnLogin(
          existingName: (existing['displayName'] as String?) ?? '',
          googleName: name,
        ) ??
        name;

    final data = <String, dynamic>{
      'displayName': resolvedName,
      'displayNameLower': resolvedName.toLowerCase(),
      'emailVerified': user.emailVerified,
      'lastSeenAt': FieldValue.serverTimestamp(),
    };

    // Kullanıcı kendi fotoğrafını seçtiyse/kaldırdıysa Google fotoğrafı
    // yazılmaz (bkz. [AvatarPolicy]).
    final photo = AvatarPolicy.photoOnLogin(
      existingPhoto: (existing['photoUrl'] as String?) ?? '',
      existingSource: (existing['photoSource'] as String?) ?? '',
      googlePhoto: user.photoURL ?? '',
    );
    if (photo != null) data['photoUrl'] = photo;

    // `createdAt` ve `email` yalnızca ilk kayıtta yazılır: güvenlik
    // kuralı `users` güncellemesinde bu iki alanın değişmesine izin
    // vermez. Her girişte yeniden yazmak, kayıttaki e-posta farklı/eksik
    // olduğunda tüm yazımın `permission-denied` almasına yol açıyordu.
    if (isNew) {
      data['createdAt'] = FieldValue.serverTimestamp();
      data['email'] = user.email ?? '';
    }

    await docRef.set(data, SetOptions(merge: true));
  }

  String _googleMessageFor(GoogleSignInException e) {
    return switch (e.code) {
      GoogleSignInExceptionCode.canceled => 'Google girişi iptal edildi.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Google istemci yapılandırması hatalı. SHA-1 parmak izini ve '
            'Web client ID ayarını kontrol edin.',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google sağlayıcı yapılandırması hatalı.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google giriş ekranı açılamadı.',
      GoogleSignInExceptionCode.userMismatch =>
        'Farklı bir Google hesabıyla oturum açılmış.',
      _ => 'Google ile giriş yapılamadı (${e.code.name}).',
    };
  }

  String _messageFor(FirebaseAuthException e) {
    return switch (e.code) {
      'invalid-email' => 'E-posta adresi geçersiz görünüyor.',
      'user-disabled' => 'Bu hesap devre dışı bırakılmış.',
      'user-not-found' => 'Bu e-posta ile kayıtlı bir hesap bulunamadı.',
      'wrong-password' || 'invalid-credential' => 'E-posta veya şifre hatalı.',
      'email-already-in-use' => 'Bu e-posta ile bir hesap zaten var.',
      'weak-password' => 'Şifre çok zayıf, en az 6 karakter kullanın.',
      'too-many-requests' =>
        'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.',
      'network-request-failed' => 'İnternet bağlantınızı kontrol edin.',
      'quota-exceeded' =>
        'Günlük e-posta gönderim kotası doldu. Yarın tekrar deneyin.',
      'missing-email' => 'Hesaba bağlı bir e-posta adresi bulunamadı.',
      'requires-recent-login' =>
        'Bu işlem için tekrar giriş yapman gerekiyor.',
      'internal-error' =>
        'Firebase sunucusunda hata oluştu. Biraz sonra tekrar deneyin.',
      'operation-not-allowed' =>
        'İlgili giriş yöntemi Firebase konsolunda etkin değil.',
      'account-exists-with-different-credential' =>
        'Bu e-posta farklı bir giriş yöntemiyle kayıtlı. O yöntemle giriş yapın.',
      'unauthorized-domain' =>
        'Bu alan adı Firebase Auth yetkili alan adları listesinde değil.',
      'popup-closed-by-user' => 'Google penceresi kapatıldı.',
      _ => e.message ?? 'Beklenmeyen bir hata oluştu (${e.code}).',
    };
  }
}

/// Kullanıcıya doğrudan gösterilebilen auth hatası.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

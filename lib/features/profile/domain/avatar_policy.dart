/// Giriş sırasında profil bilgilerinin korunması.
///
/// Google ile giriş yapıldığında hesabın gösterilen adı ve fotoğrafı
/// `users/{uid}` dokümanına yazılır. Kullanıcı uygulama içinden kendi
/// fotoğrafını seçtiyse (ya da bilerek kaldırdıysa) **Google fotoğrafı bu
/// seçimi ezmemeli** — bu sınıf o kararı tek yerde tutar.
abstract final class AvatarPolicy {
  /// Kullanıcı galeriden kendi fotoğrafını seçti.
  static const String sourceCustom = 'custom';

  /// Kullanıcı fotoğrafı bilerek kaldırdı (Google fotoğrafı geri gelmesin).
  static const String sourceNone = 'none';

  /// Giriş sırasında `photoUrl`ye yazılacak değer; `null` = dokunma.
  ///
  /// * `custom`/`none` işaretli kayıtlar korunur.
  /// * Alan yoksa (bu sürümden önce seçilmiş avatarlar) `data:` URI'si
  ///   özel fotoğraf sayılır.
  /// * Aksi halde Google fotoğrafı (varsa ve farklıysa) yazılır.
  static String? photoOnLogin({
    required String existingPhoto,
    required String existingSource,
    required String googlePhoto,
  }) {
    final source = existingSource.trim();
    if (source == sourceCustom || source == sourceNone) return null;

    final current = existingPhoto.trim();
    if (current.startsWith('data:')) return null;

    final google = googlePhoto.trim();
    if (google.isEmpty || google == current) return null;
    return google;
  }

  /// Giriş sırasında `displayName`ye yazılacak değer; `null` = dokunma.
  ///
  /// Kullanıcı uygulama içinden adını belirlediyse Google adı onu ezmez;
  /// ad henüz yoksa (ilk kayıt) Google adı kullanılır.
  static String? displayNameOnLogin({
    required String existingName,
    required String googleName,
  }) {
    final current = existingName.trim();
    if (current.isNotEmpty) return null;
    final google = googleName.trim();
    return google.isEmpty ? null : google;
  }

  /// `saveProfile` yazarken kullanılacak kaynak işareti.
  static String sourceFor(String photoUrl) =>
      photoUrl.trim().isEmpty ? sourceNone : sourceCustom;
}

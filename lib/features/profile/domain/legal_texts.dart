/// Uygulama içinde gösterilen hukuki metinler.
///
/// Metinler hukukçu onayından geçmiş değildir; yayına çıkmadan önce
/// güncellenmeli ve [version] her değişiklikte artırılmalıdır. Sürüm bilgisi
/// kullanıcı onayıyla birlikte Firestore'da saklanır (kanıt kaydı).
abstract final class LegalTexts {
  /// Onay kaydıyla birlikte saklanan sürüm.
  static const String version = '2026-10-27';

  static const String title = 'Kullanım Koşulları ve Gizlilik';

  static const String intro =
      'Uygulamayı kullanmadan önce aşağıdaki koşulları okuman ve kabul etmen '
      'gerekir. Kabul ettiğinde, kullanıcı kimliğinle birlikte tarih ve saat '
      'kaydedilir.';

  static const List<(String, String)> sections = [
    (
      '1. Uygun kullanım',
      'Uygulamayı yalnızca yasalara uygun amaçlarla kullanacaksın. Tehdit, '
          'hakaret, nefret söylemi, taciz, spam, dolandırıcılık, çocukların '
          'istismarına yönelik içerik, telif hakkı ihlali veya başkalarının '
          'özel bilgilerini paylaşma yasaktır.',
    ),
    (
      '2. Hesap güvenliği',
      'Hesabın ve şifren sana aittir. Şifreni kimseyle paylaşmamak, hesabında '
          'gerçekleşen işlemlerden sorumlu olmak senin yükümlülüğündedir.',
    ),
    (
      '3. İçerik ve kayıtlar',
      'Paylaştığın mesajlar hizmetin çalışması için sunucularda saklanır. '
          'Kurallara aykırı kullanım, güvenlik veya yasal yükümlülük hallerinde '
          'hesap kısıtlanabilir; ilgili kayıtlar (kullanıcı kimliği, zaman '
          'damgası, onay sürümü) yetkili mercilerle paylaşılabilir.',
    ),
    (
      '4. Engelleme ve silme',
      'Diğer kullanıcıları engelleyebilir, sohbetleri silebilirsin. '
          'Engellediğin kullanıcı senden mesaj gönderemez; sildiğin sohbet '
          'kaydı iki taraftan da kaldırılır.',
    ),
    (
      '5. Gizlilik',
      'Hesap bilgilerin (ad, kullanıcı adı, e-posta, profil fotoğrafı) yalnızca '
          'uygulamanın çalışması için işlenir; reklam amaçlı satılmaz. '
          'Yetkisiz erişimi önlemek için Firestore güvenlik kuralları '
          'uygulanır.',
    ),
    (
      '6. Yaş sınırı',
      '13 yaşından küçük kullanıcılar uygulamayı kullanamaz. 18 yaşından '
          'küçüksen yasal temsilcinin onayı gerekir.',
    ),
    (
      '7. Değişiklikler',
      'Koşullar güncellenebilir. Önemli değişikliklerde yeniden onay istenir; '
          'onay kayıtları sürüm numarasıyla saklanır.',
    ),
    (
      '8. İletişim',
      'Kurallara aykırı içerik veya hesap bildirimi için uygulama içindeki '
          'şikâyet/engelleme araçlarını kullanabilirsin.',
    ),
  ];

  static const String checkboxLabel =
      'Kullanım koşullarını ve gizlilik metnini okudum, kabul ediyorum.';

  static String get plainText {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln('Sürüm: $version')
      ..writeln()
      ..writeln(intro);
    for (final section in sections) {
      buffer
        ..writeln()
        ..writeln(section.$1)
        ..writeln(section.$2);
    }
    return buffer.toString();
  }
}

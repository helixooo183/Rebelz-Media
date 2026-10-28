import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanıcıya gösterilecek anlaşılır hata metni.
///
/// Firestore hataları ("permission-denied", "failed-precondition" gibi) ham
/// hâlde gösterildiğinde ne yapılacağı anlaşılmıyordu; burada tek yerde
/// Türkçeleştirilir ve çözüm ipucu eklenir.
String friendlyFirestoreError(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Yetki hatası: Firestore kuralları güncel değil olabilir. '
            'Yönetici "firebase deploy --only firestore:rules" çalıştırmalı.';
      case 'failed-precondition':
        return 'Firestore koşul hatası (indeks gerekebilir): '
            '${error.message ?? error.code}';
      case 'unavailable':
        return 'Bağlantı kurulamadı. İnterneti kontrol edip tekrar dene.';
      case 'not-found':
        return 'Kayıt bulunamadı; silinmiş olabilir.';
      case 'deadline-exceeded':
        return 'İstek zaman aşımına uğradı. Tekrar dene.';
      case 'resource-exhausted':
        return 'Çok fazla istek gönderildi. Biraz bekleyip tekrar dene.';
    }
    return 'İşlem tamamlanamadı (${error.code}): ${error.message ?? ''}';
  }

  final text = error.toString();
  return text
      .replaceFirst('Exception: ', '')
      .replaceFirst('ModerationException: ', '')
      .replaceFirst('ChatException: ', '');
}

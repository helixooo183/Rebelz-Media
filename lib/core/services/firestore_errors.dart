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
        return 'Bu işlemi yapma yetkin yok (ya da oturumun yenilenmesi '
            'gerekiyor). Çıkış yapıp tekrar girmeyi dene; sorun sürerse '
            'destek talebi oluştur.';
      case 'failed-precondition':
        return 'İşlem şu an tamamlanamıyor. Biraz bekleyip tekrar dene.';
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

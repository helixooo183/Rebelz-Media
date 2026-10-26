// Bu dosya tool/firebase_from_services_json.py tarafından üretildi.
// Kaynak: android/app/google-services.json — elle düzenlemeyin.
// `flutterfire configure` çalıştırırsanız bu dosyayı kendisi yeniden yazar.

import 'package:firebase_core/firebase_core.dart';

abstract final class DefaultFirebaseOptions {
  static const String projectId = 'rebelz-media';
  static const String apiKey = 'AIzaSyAGkOLzq0nnWVYbZEBWt9nMW5OOWreveKk';
  static const String appId = '1:824723400047:android:4f0919a943290bf905749a';
  static const String messagingSenderId = '824723400047';
  static const String storageBucket = 'rebelz-media.firebasestorage.app';

  static bool get isConfigured =>
      apiKey.isNotEmpty && projectId.isNotEmpty && appId.isNotEmpty;

  static FirebaseOptions get currentPlatform => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
      );
}

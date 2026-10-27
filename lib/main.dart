import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'features/setup/setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseReady = false;
  try {
    if (Firebase.apps.isEmpty) {
      if (DefaultFirebaseOptions.isConfigured) {
        // flutterfire configure çalıştırıldıysa: platforma özel seçenekler.
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        // Yalnızca google-services.json / GoogleService-Info.plist varsa
        // çalışır: native yapılandırma okunur.
        await Firebase.initializeApp();
      }
    }
    firebaseReady = true;
  } catch (error, stack) {
    debugPrint('Firebase başlatılamadı: $error\n$stack');
  }

  runApp(SohbetApp(firebaseReady: firebaseReady));
}

class SohbetApp extends StatelessWidget {
  const SohbetApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    // Firebase yapılandırılmadan router'a dokunmuyoruz: authStateChanges
    // FirebaseAuth.instance ister ve bu durumda hata verir.
    if (!firebaseReady) {
      return MaterialApp(
        title: 'Rebelz Media',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const SetupScreen(),
      );
    }

    return MaterialApp.router(
      title: 'Rebelz Media',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/chat/presentation/channels_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/join_invite_screen.dart';
import '../../features/chat/presentation/rooms_screen.dart';
import '../../features/chat/domain/models/room_invite.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../widgets/home_shell.dart';
import 'auth_notifier.dart';

final AuthNotifier authNotifier = AuthNotifier();

/// Derin bağlantıyla gelen davet kodu.
///
/// Kullanıcı giriş yapmamışsa kod burada tutulur; giriş yaptıktan sonra
/// `/katil/<kod>` ekranına yönlendirilir (kod kaybolmaz).
final ValueNotifier<String?> pendingInviteCode = ValueNotifier<String?>(null);

/// Rota isimleri/sabitleri tek yerde.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';
  static const chats = '/chats';
  static const channels = '/channels';
  static const profile = '/profile';

  static String chat(String roomId, {required String name}) =>
      '/chats/$roomId?name=${Uri.encodeComponent(name)}';

  /// Davet ekranı (derin bağlantı: `rebelzmedia://katil/<kod>`).
  ///
  /// `auto` true ise ekran açılır açılmaz katılmayı dener ve başarılı olunca
  /// doğrudan sohbeti açar (bağlantıyla gelen kullanıcı için varsayılan).
  static String joinInvite(String code, {bool auto = true}) =>
      '/katil/$code${auto ? '?auto=1' : ''}';
}

/// Bilinen bir uygulama rotası mı? (yakalayıcı rotaya düşen çöp adresleri
/// ayıklamak için)
bool _isKnownLocation(String location) {
  const exact = {
    AppRoutes.splash,
    AppRoutes.login,
    AppRoutes.register,
    AppRoutes.chats,
    AppRoutes.channels,
    AppRoutes.profile,
  };
  if (exact.contains(location)) return true;
  return location.startsWith('/chats/') || location.startsWith('/katil/');
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  refreshListenable: authNotifier,
  debugLogDiagnostics: false,

  /// Oturum durumuna göre yönlendirme:
  /// - henüz auth cevabı yok  -> splash
  /// - giriş yok              -> login/register
  /// - giriş var              -> sohbetler
  redirect: (context, state) {
    final location = state.matchedLocation;

    // 1) Derin bağlantı adresi: `rebelzmedia://katil/KOD`.
    //
    // GoRouter bu adresi rota olarak eşleştiremediği için ("no routes for
    // location") önce kodu çıkarıp saklıyoruz. Kimlik hazır olduğunda
    // kullanıcı doğrudan `/katil/KOD?auto=1` ekranına gider, oradan da
    // katılıp sohbete düşer.
    final code = inviteCodeFromUri(state.uri);
    if (code != null) pendingInviteCode.value = code;
    final inviteRoute = code == null ? null : '/katil/$code?auto=1';

    // Özel şema (rebelzmedia://…) bir uygulama rotası değildir.
    final scheme = state.uri.scheme.toLowerCase();
    final isCustomScheme =
        scheme.isNotEmpty && scheme != 'http' && scheme != 'https';

    if (!authNotifier.isReady) {
      // Kimlik cevabı bekleniyor: splash'ta kal (kod yukarıda saklandı).
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    }

    final isAuthRoute =
        location == AppRoutes.login || location == AppRoutes.register;

    if (!authNotifier.isAuthenticated) {
      // Giriş gerekli; kod `pendingInviteCode`da bekliyor.
      return isAuthRoute ? null : AppRoutes.login;
    }

    // Giriş var: davet bağlantısıysa doğrudan davet ekranına (otomatik katıl).
    //
    // Yalnız özel şema (`rebelzmedia://…`) için: bu adres her zaman bir
    // bağlantı dokunuşudur. `/katil/…` rotasında ise zaten davet ekranı
    // açıktır; tekrar yönlendirme yapılmaz (döngü olmaz).
    if (isCustomScheme && inviteRoute != null) {
      return inviteRoute;
    }

    // Tanınmayan bir derin bağlantı ya da çöp adres: hata ekranı yerine
    // sohbetler. (Yakalayıcı rota sayesinde GoException da oluşmaz.)
    if (isCustomScheme || !_isKnownLocation(location)) {
      return AppRoutes.chats;
    }

    if (isAuthRoute || location == AppRoutes.splash) {
      final pending = pendingInviteCode.value;
      if (pending != null) {
        // Bekleyen kod tek seferlik kullanılır (giriş sonrası davet ekranı).
        pendingInviteCode.value = null;
        return AppRoutes.joinInvite(pending);
      }
      return AppRoutes.chats;
    }

    return null;
  },

  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => const RegisterScreen(),
    ),

    // Alt sekmeli ana iskelet: Sohbetler + Profil
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          HomeShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.chats,
              builder: (context, state) => const RoomsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.channels,
              builder: (context, state) => const ChannelsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // Davet: derin bağlantı ya da elle girilen kod.
    GoRoute(
      path: '/katil/:code',
      builder: (context, state) {
        final code = state.pathParameters['code'] ?? '';
        return JoinInviteScreen(
          code: code,
          // Yalnızca bağlantıdan gelindiyse otomatik katılmayı dene;
          // elle girilen kodda kullanıcı onaylasın.
          autoJoin: state.uri.queryParameters['auto'] == '1',
          onJoined: (roomId) {
            pendingInviteCode.value = null;
            context.go(AppRoutes.chat(roomId, name: 'Sohbet'));
          },
        );
      },
    ),

    // Sohbet ekranı tam ekran açılır.
    GoRoute(
      path: '/chats/:roomId',
      builder: (context, state) => ChatScreen(
        roomId: state.pathParameters['roomId']!,
        roomName: state.uri.queryParameters['name'] ?? 'Sohbet',
      ),
    ),

    // Yakalayıcı: `rebelzmedia://katil/KOD` gibi adresler GoRouter'da rota
    // olarak bulunamaz ve "no routes for location" hatası verirdi. Bu rota
    // hepsini eşleştirir; `redirect` yukarıda doğru ekrana yönlendirir.
    GoRoute(
      path: '/:rest(.*)',
      builder: (context, state) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    ),
  ],

  // Beklenmeyen adresler: davet bağlantısıysa davet ekranı, değilse sade
  // bir hata ekranı (ham GoException metni gösterilmez).
  errorBuilder: (context, state) {
    final code = inviteCodeFromUri(state.uri);
    if (code != null) {
      return JoinInviteScreen(
        code: code,
        autoJoin: true,
        onJoined: (roomId) {
          pendingInviteCode.value = null;
          context.go(AppRoutes.chat(roomId, name: 'Sohbet'));
        },
      );
    }
    return const _RouteErrorScreen();
  },
);

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sayfa bulunamadı',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Bu bağlantı açılamadı. Davet bağlantıları uygulama '
                'açıldıktan sonra otomatik olarak işlenir.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go(AppRoutes.chats),
                child: const Text('Sohbetlere dön'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  static String joinInvite(String code) => '/katil/$code';
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

    if (!authNotifier.isReady) {
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    }

    final isAuthRoute =
        location == AppRoutes.login || location == AppRoutes.register;

    // Derin bağlantı: rebelzmedia://katil/<kod> → /katil/<kod>
    final inviteCode = inviteCodeFromUri(state.uri);
    if (inviteCode != null) pendingInviteCode.value = inviteCode;

    if (!authNotifier.isAuthenticated) {
      return isAuthRoute ? null : AppRoutes.login;
    }

    if (isAuthRoute || location == AppRoutes.splash) {
      final pending = pendingInviteCode.value;
      if (pending != null) return AppRoutes.joinInvite(pending);
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
  ],

  errorBuilder: (context, state) => _RouteErrorScreen(message: '${state.error}'),
);

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sayfa bulunamadı\n\n$message',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

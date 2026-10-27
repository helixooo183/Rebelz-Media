import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/chat/presentation/channels_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/presentation/rooms_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../widgets/home_shell.dart';
import 'auth_notifier.dart';

final AuthNotifier authNotifier = AuthNotifier();

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

    if (!authNotifier.isAuthenticated) {
      return isAuthRoute ? null : AppRoutes.login;
    }

    if (isAuthRoute || location == AppRoutes.splash) {
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

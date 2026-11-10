import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/home_shell.dart';
import 'package:orbit/features/chat/presentation/inbox_screen.dart';
import 'package:orbit/features/discovery/presentation/nearby_screen.dart';
import 'package:orbit/features/onboarding/presentation/sign_in_screen.dart';
import 'package:orbit/features/onboarding/presentation/welcome_screen.dart';
import 'package:orbit/features/profile/presentation/me_screen.dart';

/// Route paths, so screens never hard-code strings.
abstract final class AppRoutes {
  /// W1 Welcome.
  static const welcome = '/welcome';

  /// W2 Sign in.
  static const signIn = '/welcome/sign-in';

  /// W6 Nearby grid.
  static const nearby = '/nearby';

  /// W10 Inbox.
  static const inbox = '/inbox';

  /// W13 Me.
  static const me = '/me';
}

/// The app's single [GoRouter]. Auth redirects are added with the identity
/// feature.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.welcome,
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
        routes: [
          GoRoute(
            path: 'sign-in',
            builder: (context, state) => const SignInScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.nearby,
                builder: (context, state) => const NearbyScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.inbox,
                builder: (context, state) => const InboxScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.me,
                builder: (context, state) => const MeScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

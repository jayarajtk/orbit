import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/home_shell.dart';
import 'package:orbit/core/network/account_restriction.dart';
import 'package:orbit/features/albums/presentation/album_screen.dart';
import 'package:orbit/features/albums/presentation/my_albums_screen.dart';
import 'package:orbit/features/albums/presentation/share_album_screen.dart';
import 'package:orbit/features/chat/presentation/chat_screen.dart';
import 'package:orbit/features/chat/presentation/inbox_screen.dart';
import 'package:orbit/features/discovery/presentation/nearby_screen.dart';
import 'package:orbit/features/discovery/presentation/profile_screen.dart';
import 'package:orbit/features/onboarding/presentation/age_gate_screen.dart';
import 'package:orbit/features/onboarding/presentation/location_primer_screen.dart';
import 'package:orbit/features/onboarding/presentation/profile_setup_screen.dart';
import 'package:orbit/features/onboarding/presentation/sign_in_screen.dart';
import 'package:orbit/features/onboarding/presentation/welcome_screen.dart';
import 'package:orbit/features/plus/presentation/orbit_plus_screen.dart';
import 'package:orbit/features/profile/presentation/edit_profile_screen.dart';
import 'package:orbit/features/profile/presentation/favorites_screen.dart';
import 'package:orbit/features/profile/presentation/me_screen.dart';
import 'package:orbit/features/profile/presentation/my_photos_viewer.dart';
import 'package:orbit/features/profile/presentation/my_profile_controller.dart';
import 'package:orbit/features/safety/presentation/blocked_users_screen.dart';
import 'package:orbit/features/safety/presentation/safety_centre_screen.dart';
import 'package:orbit/features/settings/presentation/settings_screen.dart';
import 'package:orbit/features/standing/presentation/restricted_screen.dart';
import 'package:orbit/features/status/presentation/status_viewer.dart';

/// Route paths, so screens never hard-code strings.
abstract final class AppRoutes {
  /// W1 Welcome.
  static const welcome = '/welcome';

  /// W2 Sign in.
  static const signIn = '/welcome/sign-in';

  /// W3 Birthday.
  static const onboardingBirthday = '/onboarding/birthday';

  /// W4 Profile setup.
  static const onboardingProfile = '/onboarding/profile';

  /// W5 Location primer.
  static const onboardingLocation = '/onboarding/location';

  /// W6 Nearby grid.
  static const nearby = '/nearby';

  /// W10 Inbox.
  static const inbox = '/inbox';

  /// W13 Me.
  static const me = '/me';

  /// W14 Edit profile.
  static const editProfile = '/me/edit';

  /// The member's own photos, full screen. Query parameter `index` is the
  /// photo to open on.
  static const myPhotos = '/me/photos';

  /// My albums.
  static const myAlbums = '/me/albums';

  /// Favorites.
  static const favorites = '/me/favorites';

  /// W15 Settings.
  static const settings = '/me/settings';

  /// Blocked users.
  static const blockedUsers = '/me/settings/blocked';

  /// W16 Safety centre.
  static const safety = '/me/safety';

  /// W17 Orbit+.
  static const plus = '/plus';

  /// Why the account is suspended or banned, and the appeal (ADR-0007).
  static const restricted = '/restricted';

  /// The user's own statuses, full screen.
  static const myStatuses = '/status/me';

  /// Member [id]'s statuses, full screen.
  static String statuses(String id) => '/status/$id';

  /// W8 Profile of member [id].
  static String profile(String id) => '/profile/$id';

  /// W11 Chat with member [id].
  static String chat(String id) => '/chat/$id';

  /// W12 Share an album with member [id].
  static String shareAlbum(String id) => '/chat/$id/share-album';

  /// An album, the user's own or one shared with them.
  static String album(String id) => '/album/$id';

  /// A safety centre topic.
  static String safetyTopic(SafetyTopic topic) => '/me/safety/${topic.name}';
}

/// The app's single [GoRouter]. Signed-out users are sent to Welcome.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.welcome,
    redirect: (context, state) {
      final path = state.uri.path;
      if (ref.read(accountRestrictedProvider)) {
        return path == AppRoutes.restricted ||
                path.startsWith(AppRoutes.welcome)
            ? null
            : AppRoutes.restricted;
      }
      final signedIn = ref.read(myProfileProvider) != null;
      final public =
          path.startsWith(AppRoutes.welcome) || path.startsWith('/onboarding');
      return signedIn || public ? null : AppRoutes.welcome;
    },
    routes: [
      GoRoute(
        path: AppRoutes.restricted,
        builder: (context, state) => const RestrictedScreen(),
      ),
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
      GoRoute(
        path: AppRoutes.onboardingBirthday,
        builder: (context, state) => const AgeGateScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingProfile,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboardingLocation,
        builder: (context, state) => const LocationPrimerScreen(),
      ),
      GoRoute(
        path: '/profile/:id',
        builder: (context, state) =>
            ProfileScreen(profileId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/status/:profileId',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          opaque: false,
          fullscreenDialog: true,
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          child: StatusViewerScreen(
            profileId: state.pathParameters['profileId']!,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              MediaQuery.disableAnimationsOf(context)
              ? child
              : FadeTransition(
                  opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
                  child: child,
                ),
        ),
      ),
      GoRoute(
        path: '/album/:id',
        builder: (context, state) =>
            AlbumScreen(albumId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) =>
            ChatScreen(profileId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'share-album',
            builder: (context, state) =>
                ShareAlbumScreen(profileId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.plus,
        builder: (context, state) => const OrbitPlusScreen(),
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
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'photos',
                    pageBuilder: (context, state) => CustomTransitionPage<void>(
                      key: state.pageKey,
                      opaque: false,
                      fullscreenDialog: true,
                      transitionDuration: const Duration(milliseconds: 250),
                      reverseTransitionDuration: const Duration(
                        milliseconds: 250,
                      ),
                      child: MyPhotosViewer(
                        initialIndex:
                            int.tryParse(
                              state.uri.queryParameters['index'] ?? '',
                            ) ??
                            0,
                      ),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) =>
                              MediaQuery.disableAnimationsOf(context)
                              ? child
                              : FadeTransition(
                                  opacity: animation.drive(
                                    CurveTween(curve: Curves.easeOut),
                                  ),
                                  child: child,
                                ),
                    ),
                  ),
                  GoRoute(
                    path: 'albums',
                    builder: (context, state) => const MyAlbumsScreen(),
                  ),
                  GoRoute(
                    path: 'favorites',
                    builder: (context, state) => const FavoritesScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) => const SettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'blocked',
                        builder: (context, state) => const BlockedUsersScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'safety',
                    builder: (context, state) => const SafetyCentreScreen(),
                    routes: [
                      GoRoute(
                        path: ':topic',
                        builder: (context, state) => SafetyTopicScreen(
                          topic: SafetyTopic.values.byName(
                            state.pathParameters['topic']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  // A suspension or ban can arrive mid-session (any API call, or the chat
  // socket closing): move straight to the restriction screen.
  ref
    ..listen(accountRestrictedProvider, (_, restricted) {
      if (restricted) router.go(AppRoutes.restricted);
    })
    ..onDispose(router.dispose);
  return router;
});

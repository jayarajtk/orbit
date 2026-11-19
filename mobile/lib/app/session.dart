import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/auth/auth_repository.dart';
import 'package:orbit/core/network/account_restriction.dart';
import 'package:orbit/features/albums/presentation/albums_controller.dart';
import 'package:orbit/features/chat/data/chat_gateway.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/discovery/data/location_repository.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/features/onboarding/presentation/onboarding_controller.dart';
import 'package:orbit/features/plus/presentation/plus_controller.dart';
import 'package:orbit/features/profile/data/account_repository.dart';
import 'package:orbit/features/profile/presentation/my_profile_controller.dart';
import 'package:orbit/features/safety/presentation/safety_providers.dart';
import 'package:orbit/features/settings/presentation/settings_controller.dart';

/// Sign-in, restore on launch, and sign-out.
final sessionProvider = Provider<SessionController>(SessionController.new);

/// Where to send the member after sign-in or launch.
enum SessionDestination {
  /// Not signed in: stay on Welcome.
  welcome,

  /// No account: birthday step.
  birthday,

  /// Account but no profile: profile step.
  profileSetup,

  /// Fully onboarded: the grid.
  home,

  /// Suspended or banned: the restriction screen.
  restricted,
}

/// Coordinates auth, the account repository and per-member state.
class SessionController {
  /// Creates the controller.
  SessionController(this._ref);

  final Ref _ref;

  /// Runs the identity provider's sign-in, then works out where to go.
  /// Throws [SignInCancelled] if the member backs out.
  Future<SessionDestination> signIn() async {
    await _ref.read(authRepositoryProvider).signIn();
    return _resume();
  }

  /// On launch: resumes a stored session if there is one.
  Future<SessionDestination> restore() async {
    final token = await _ref.read(authRepositoryProvider).accessToken();
    if (token == null) return SessionDestination.welcome;
    return _resume();
  }

  Future<SessionDestination> _resume() async {
    final snapshot = await _ref.read(accountRepositoryProvider).load();
    _ref.read(accountRestrictedProvider.notifier).clear();
    switch (snapshot.stage) {
      case AccountStage.restricted:
        _ref.read(accountRestrictedProvider.notifier).flag();
        return SessionDestination.restricted;
      case AccountStage.noAccount:
        return SessionDestination.birthday;
      case AccountStage.needsProfile:
        _ref.read(onboardingProvider.notifier).markAccountCreated();
        return SessionDestination.profileSetup;
      case AccountStage.ready:
        _ref.read(myProfileProvider.notifier).save(snapshot.profile!);
        await Future.wait([
          _ref.read(favoritesProvider.notifier).load(),
          _ref.read(blockedProvider.notifier).load(),
        ]);
        // Refresh the location in the background; the grid works with the
        // last stored one in the meantime.
        unawaited(
          _ref
              .read(locationRepositoryProvider)
              .shareCurrentLocation()
              .then(
                (_) => _ref.invalidate(allProfilesProvider),
                onError: (_) {},
              ),
        );
        return SessionDestination.home;
    }
  }

  /// Ends the session and clears every piece of per-member state.
  Future<void> signOut() async {
    await _ref.read(authRepositoryProvider).signOut();
    _ref
      ..invalidate(accountRestrictedProvider)
      ..invalidate(myProfileProvider)
      ..invalidate(onboardingProvider)
      ..invalidate(chatProvider)
      ..invalidate(chatGatewayProvider)
      ..invalidate(typingProvider)
      ..invalidate(favoritesProvider)
      ..invalidate(blockedProvider)
      ..invalidate(blockedNamesProvider)
      ..invalidate(reportsProvider)
      ..invalidate(filtersProvider)
      ..invalidate(albumsProvider)
      ..invalidate(settingsProvider)
      ..invalidate(plusProvider)
      ..invalidate(allProfilesProvider);
  }
}

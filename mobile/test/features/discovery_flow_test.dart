import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/app/theme.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/core/widgets/glass_icon_button.dart';
import 'package:orbit/core/widgets/media_image.dart';
import 'package:orbit/core/widgets/photo_viewer.dart';
import 'package:orbit/core/widgets/profile_avatar.dart';
import 'package:orbit/core/widgets/skeleton.dart';
import 'package:orbit/features/chat/domain/conversation.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/chat/presentation/wave_limit.dart';
import 'package:orbit/features/discovery/data/dummy_profiles.dart';
import 'package:orbit/features/discovery/data/fake_profile_repository.dart';
import 'package:orbit/features/discovery/domain/discovery_filters.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/presentation/profile_tile.dart';
import 'package:orbit/features/status/domain/status.dart';
import 'package:orbit/l10n/app_localizations_en.dart';

import '../helpers/pump_app.dart';
import '../helpers/status_bar.dart';

/// Serves the grid a one-photo copy of Alex and the profile endpoint the
/// two-photo one, as when a member adds a photo after the grid loaded.
class _PhotoAddedRepository extends FakeProfileRepository {
  _PhotoAddedRepository() : super(latency: Duration.zero);

  static Profile _alex(int photoCount) => Profile(
    id: dummyProfiles.first.id,
    name: dummyProfiles.first.name,
    age: dummyProfiles.first.age,
    distanceKm: dummyProfiles.first.distanceKm,
    online: true,
    bio: dummyProfiles.first.bio,
    lookingFor: dummyProfiles.first.lookingFor,
    tags: dummyProfiles.first.tags,
    photoCount: photoCount,
    isNew: false,
  );

  @override
  Future<List<Profile>> nearby(DiscoveryFilters filters) async => [_alex(1)];

  @override
  Future<Profile?> byId(String id) async => _alex(2);
}

/// Serves Alex with two real photos.
class _PhotosRepository extends FakeProfileRepository {
  _PhotosRepository() : super(latency: Duration.zero);

  static Profile _alex() => Profile(
    id: dummyProfiles.first.id,
    name: dummyProfiles.first.name,
    age: dummyProfiles.first.age,
    distanceKm: dummyProfiles.first.distanceKm,
    online: true,
    bio: dummyProfiles.first.bio,
    lookingFor: dummyProfiles.first.lookingFor,
    tags: dummyProfiles.first.tags,
    photoCount: 2,
    isNew: false,
    photos: const [
      ProfilePhoto(id: 'ph1', url: 'http://x/ph1'),
      ProfilePhoto(id: 'ph2', url: 'http://x/ph2'),
    ],
  );

  @override
  Future<List<Profile>> nearby(DiscoveryFilters filters) async => [_alex()];

  @override
  Future<Profile?> byId(String id) async => _alex();
}

/// Serves the grid, but every single-profile fetch fails as on a weak
/// connection.
class _OfflineByIdRepository extends FakeProfileRepository {
  _OfflineByIdRepository() : super(latency: Duration.zero);

  @override
  Future<Profile?> byId(String id) async =>
      throw const ApiException(status: 0, type: 'network');
}

/// Counts grid loads and, while [gate] is set, holds them open.
class _GatedRepository extends FakeProfileRepository {
  _GatedRepository() : super(latency: Duration.zero);

  int nearbyCalls = 0;
  Completer<void>? gate;

  @override
  Future<List<Profile>> nearby(DiscoveryFilters filters) async {
    nearbyCalls++;
    await gate?.future;
    return super.nearby(filters);
  }
}

Profile _member(
  String id,
  String name, {
  List<ProfilePhoto> photos = const [],
  bool online = false,
  StatusRing status = StatusRing.none,
}) => Profile(
  id: id,
  name: name,
  age: 25,
  distanceKm: 0,
  online: online,
  bio: '',
  lookingFor: const {},
  tags: const [],
  photoCount: photos.length,
  isNew: false,
  photos: photos,
  status: status,
);

/// Demo chat where the user has already waved at Alex twice in the last hour.
class _WavedTwiceChat extends DemoChatController {
  @override
  Map<String, Conversation> build() {
    final alexId = dummyProfiles.first.id;
    return {
      ...super.build(),
      alexId: Conversation(
        profileId: alexId,
        messages: [
          for (final (i, minutes) in [40, 20].indexed)
            Message(
              id: 'w$i',
              fromMe: true,
              kind: MessageKind.wave,
              sentAt: testNow.subtract(Duration(minutes: minutes)),
            ),
        ],
      ),
    };
  }
}

void main() {
  test('waitLabel rounds hours and minutes up', () {
    expect(waitLabel(const Duration(hours: 5, minutes: 1)), '6h');
    expect(waitLabel(const Duration(minutes: 24, seconds: 10)), '25m');
    expect(waitLabel(const Duration(hours: 1)), '1h');
    expect(waitLabel(Duration.zero), '1m');
  });

  testWidgets('opening a profile reports no framework errors', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final original = FlutterError.onError;
    await pumpOrbit(tester);
    await onboard(tester);
    FlutterError.onError = errors.add;
    try {
      await tapText(tester, 'Alex 27');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      // The grid reloads while the profile is closed, so the cached profile
      // is stale by the time it is opened again.
      await tapText(tester, 'Online');
      await tapText(tester, 'Alex 27');
    } finally {
      FlutterError.onError = original;
    }

    expect(find.text('Alex, 27'), findsOneWidget);
    expect(errors.map((e) => e.exceptionAsString()), isEmpty);
  });

  testWidgets('a failed profile refetch keeps the grid copy on profile and '
      'chat', (tester) async {
    await pumpOrbit(tester, profiles: _OfflineByIdRepository());
    await onboard(tester);

    // Long enough for Riverpod's automatic retries to give up.
    Future<void> settleRetries() async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 10));
      }
      await tester.pumpAndSettle();
    }

    await tapText(tester, 'Alex 27');
    await settleRetries();
    expect(find.text('Alex, 27'), findsOneWidget);
    expect(find.text("This profile isn't available."), findsNothing);

    await tapText(tester, 'Message');
    await settleRetries();
    expect(find.widgetWithText(TextField, 'Message…'), findsOneWidget);
    expect(find.text("This profile isn't available."), findsNothing);
  });

  testWidgets('profile shows photos added since the grid loaded', (
    tester,
  ) async {
    await pumpOrbit(tester, profiles: _PhotoAddedRepository());
    await onboard(tester);

    await tapText(tester, 'Alex 27');

    expect(
      find.bySemanticsLabel(AppLocalizationsEn().photoOf(1, 2)),
      findsOneWidget,
    );
  });

  testWidgets('profile shows one segment per photo and advances on tap', (
    tester,
  ) async {
    await pumpOrbit(tester, profiles: _PhotoAddedRepository());
    await onboard(tester);
    await tapText(tester, 'Alex 27');

    expect(find.byKey(const ValueKey('photo-segment-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-segment-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-segment-2')), findsNothing);
    expect(find.bySemanticsLabel('1 of 2'), findsOneWidget);

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(size.width - 20, 250));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('2 of 2'), findsOneWidget);
    expect(
      find.bySemanticsLabel(AppLocalizationsEn().photoOf(2, 2)),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(20, 250));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('1 of 2'), findsOneWidget);
  });

  testWidgets('tapping the middle of a profile photo opens the viewer', (
    tester,
  ) async {
    await pumpOrbit(tester, profiles: _PhotosRepository());
    await onboard(tester);
    await tapText(tester, 'Alex 27');

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.tapAt(Offset(size.width / 2, 250));
    await tester.pumpAndSettle();

    final viewer = tester.widget<PhotoViewer>(find.byType(PhotoViewer));
    expect(viewer.initialIndex, 0);
    expect(viewer.items.map((i) => i.mediaId), ['ph1', 'ph2']);
  });

  for (final brightness in Brightness.values) {
    testWidgets('the photo viewer has light status bar icons in '
        '${brightness.name} mode', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpOrbit(tester, profiles: _PhotosRepository());
      await onboard(tester);
      await tapText(tester, 'Alex 27');

      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.tapAt(Offset(size.width / 2, 250));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoViewer), findsOneWidget);
      expect(hasLightIcons(effectiveStatusBarStyle(tester)), isTrue);
    });
  }

  testWidgets('a screen reader opens the viewer from a profile photo', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpOrbit(tester, profiles: _PhotosRepository());
    await onboard(tester);
    await tapText(tester, 'Alex 27');

    tester.semantics.tap(
      find.semantics.byLabel(AppLocalizationsEn().photoOf(1, 2)),
    );
    await tester.pumpAndSettle();

    final viewer = tester.widget<PhotoViewer>(find.byType(PhotoViewer));
    expect(viewer.initialIndex, 0);
    semantics.dispose();
  });

  testWidgets('profile app bar buttons sit on glass backings', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);

    await tapText(tester, 'Alex 27');

    expect(find.byType(GlassIconButton), findsNWidgets(3));
    for (final tooltip in [
      'Back',
      'Add to favorites',
      'More: block or report',
    ]) {
      expect(
        find.descendant(
          of: find.byType(GlassIconButton),
          matching: find.byTooltip(tooltip),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('Wave button counts down after the limit', (tester) async {
    await pumpOrbit(
      tester,
      overrides: [chatProvider.overrideWith(_WavedTwiceChat.new)],
    );
    await onboard(tester);

    await tapText(tester, 'Alex 27');

    // The oldest wave was 40 minutes ago, so waving unlocks in 23h20m.
    final button = find.widgetWithText(OutlinedButton, 'Wave in 24h');
    expect(button, findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('You waved at Alex'), findsNothing);
  });

  testWidgets('the Online chip hides offline members', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    expect(find.text('Sam 31'), findsOneWidget);

    await tapText(tester, 'Online');

    expect(find.text('Sam 31'), findsNothing);
    expect(find.text('Alex 27'), findsOneWidget);
  });

  testWidgets('opens a profile with bio, details and tags', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);

    await tapText(tester, 'Alex 27');

    expect(find.text('Alex, 27'), findsOneWidget);
    expect(find.text('he/him · 180 cm · Single'), findsOneWidget);
    expect(find.text('#climbing'), findsOneWidget);
  });

  testWidgets('favoriting a profile lists it under Favorites', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Alex 27');

    await tester.tap(find.byTooltip('Add to favorites'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from favorites'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Me');
    await tapText(tester, 'Favorites');
    expect(find.text('Alex, 27'), findsOneWidget);
  });

  testWidgets('blocking removes the member from the grid and inbox', (
    tester,
  ) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Alex 27');

    await tester.tap(find.byTooltip('More: block or report'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Block Alex');
    await tester.tap(find.widgetWithText(FilledButton, 'Block'));
    await tester.pumpAndSettle();

    expect(find.text('Alex 27'), findsNothing);
    expect(find.text('Alex is blocked'), findsOneWidget);
    await tapText(tester, 'Inbox');
    expect(find.text('Alex'), findsNothing);
  });

  testWidgets('reporting needs a reason and can also block', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Sam 31');
    await tester.tap(find.byTooltip('More: block or report'));
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(FilledButton, 'Submit report');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tapText(tester, 'Harassment');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(
      find.text('Thanks. A moderator will review your report.'),
      findsOneWidget,
    );
    expect(find.text('Sam 31'), findsNothing);
  });

  testWidgets('the distance filter is an Orbit+ feature', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);

    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Maximum distance'), findsNothing);

    await tapText(tester, 'Distance and more filters');
    await tapText(tester, 'Subscribe');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Maximum distance'), findsOneWidget);
  });

  group('grid tiles', () {
    testWidgets(
      'tile shows name, age, distance and online dot over the photo',
      (
        tester,
      ) async {
        await pumpOrbit(
          tester,
          profiles: FakeProfileRepository(
            profiles: [
              _member(
                'p1',
                'Sam',
                online: true,
                photos: const [
                  ProfilePhoto(
                    id: 'm1',
                    url: 'https://img.test/m1.jpg',
                    thumbUrl: 'https://img.test/m1-thumb.jpg',
                  ),
                ],
              ),
            ],
            latency: Duration.zero,
          ),
        );
        await onboard(tester);

        final tile = find.byType(ProfileTile);
        expect(tile, findsOneWidget);
        expect(
          find.descendant(of: tile, matching: find.byType(MediaImage)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tile, matching: find.text('Sam 25')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tile, matching: find.text('<1 km')),
          findsOneWidget,
        );
        final dot = find.descendant(of: tile, matching: find.byType(OnlineDot));
        expect(dot, findsOneWidget);
        final context = tester.element(tile);
        final decoration =
            tester
                    .widget<Container>(
                      find.descendant(
                        of: dot,
                        matching: find.byType(Container),
                      ),
                    )
                    .decoration!
                as BoxDecoration;
        expect(decoration.color, context.tokens.online);
        final name = tester.widget<Text>(find.text('Sam 25'));
        expect(name.style!.fontSize, 15);
        expect(name.style!.fontWeight, FontWeight.w600);
        expect(tester.widget<Text>(find.text('<1 km')).style!.fontSize, 13);
      },
    );

    testWidgets('member without photo shows a gradient and initial, not a '
        'person icon', (tester) async {
      await pumpOrbit(
        tester,
        profiles: FakeProfileRepository(
          profiles: [_member('p1', 'Sam')],
          latency: Duration.zero,
        ),
      );
      await onboard(tester);

      final tile = find.byType(ProfileTile);
      expect(
        find.descendant(of: tile, matching: find.byIcon(Icons.person_outline)),
        findsNothing,
      );
      expect(
        find.descendant(of: tile, matching: find.text('S')),
        findsOneWidget,
      );
      final gradients = tester.element(tile).tokens.avatarGradients;
      final fills = tester
          .widgetList<Container>(
            find.descendant(of: tile, matching: find.byType(Container)),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.gradient)
          .whereType<LinearGradient>();
      expect(
        fills.any(
          (g) =>
              gradients.any((pair) => listEquals(g.colors, [pair.$1, pair.$2])),
        ),
        isTrue,
      );
    });

    testWidgets('pull to refresh reloads the grid', (tester) async {
      final repository = _GatedRepository();
      await pumpOrbit(tester, profiles: repository);
      await onboard(tester);
      expect(repository.nearbyCalls, 1);

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(repository.nearbyCalls, 2);
    });

    testWidgets('skeletons show while the grid loads', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final repository = _GatedRepository()..gate = Completer<void>();
      await pumpOrbit(tester, profiles: repository);
      await onboard(tester);

      expect(find.byType(Skeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ProfileTile), findsNothing);

      repository.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(Skeleton), findsNothing);
      expect(find.byType(ProfileTile), findsWidgets);
    });

    testWidgets('tile semantics label reads naturally', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOrbit(
        tester,
        profiles: FakeProfileRepository(
          profiles: [
            _member('p1', 'Sam', online: true, status: StatusRing.unseen),
          ],
          latency: Duration.zero,
        ),
      );
      await onboard(tester);

      expect(
        find.bySemanticsLabel('Sam, 25, <1 km, Online, has a new status'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}

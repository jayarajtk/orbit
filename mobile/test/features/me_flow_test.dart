import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/media/domain/media.dart';
import 'package:orbit/features/profile/data/account_repository.dart';
import 'package:orbit/features/profile/domain/my_profile.dart';
import 'package:orbit/features/profile/presentation/my_photos_actions.dart';
import 'package:orbit/features/profile/presentation/my_profile_controller.dart';

import '../helpers/fake_api.dart';
import '../helpers/fake_image_cache.dart';
import '../helpers/pump_app.dart';

class _CountingPicker implements MediaPicker {
  int calls = 0;

  @override
  Future<PickedMedia?> pickPhoto({required bool camera}) async {
    calls++;
    return null;
  }

  @override
  Future<PickedMedia?> pickVideo({required Duration maxDuration}) async {
    calls++;
    return null;
  }
}

class _NoUploads implements MediaRepository {
  @override
  Future<Never> upload(
    MediaPurpose purpose,
    Uint8List bytes,
    String contentType, {
    int? durationMs,
  }) => throw StateError('no upload expected');
}

/// Demo onboarding, but `PUT /me/photos` goes to the fake API.
class _DemoWithPhotosApi extends DemoAccountRepository {
  _DemoWithPhotosApi(FakeAdapter adapter)
    : _api = ApiAccountRepository(dioWith(adapter));

  final ApiAccountRepository _api;

  @override
  Future<MyProfile> setPhotos(List<String> mediaIds) =>
      _api.setPhotos(mediaIds);
}

const _ids = ['a', 'b', 'c'];

MyProfile _profileWith(List<String> ids) => MyProfile(
  displayName: 'Robin',
  age: 36,
  photos: [for (final id in ids) ProfilePhoto(id: id, url: 'http://x/$id')],
);

Map<String, Object?> _profileJson(List<String> ids) => {
  'displayName': 'Robin',
  'age': 36,
  'photos': [
    for (final id in ids) {'id': id, 'url': 'http://x/$id'},
  ],
};

FakeAdapter _photosApi({int status = 200}) => FakeAdapter(
  const {},
  handlers: {
    'PUT /me/photos': (options) => status >= 400
        ? (status, problem('server', status))
        : (
            200,
            _profileJson([
              for (final id in (options.data as Map)['mediaIds'] as List)
                id as String,
            ]),
          ),
  },
);

List<Override> _photoOverrides(FakeAdapter adapter, _CountingPicker picker) => [
  accountRepositoryProvider.overrideWithValue(_DemoWithPhotosApi(adapter)),
  mediaRepositoryProvider.overrideWithValue(_NoUploads()),
  mediaPickerProvider.overrideWithValue(picker),
];

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

Future<void> _openEditProfile(WidgetTester tester) async {
  await onboard(tester);
  _container(tester).read(myProfileProvider.notifier).save(_profileWith(_ids));
  await tapText(tester, 'Me');
  await tapText(tester, 'Edit profile');
}

void main() {
  testWidgets('editing the profile updates the Me tab', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Me');
    expect(find.text('Profile 33% complete'), findsOneWidget);

    await tapText(tester, 'Edit profile');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Display name'),
      'Robin K',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'About me'),
      'Hello there',
    );
    await tapText(tester, 'Save');

    expect(find.text('Robin K, 36'), findsOneWidget);
    expect(find.text('Profile 50% complete'), findsOneWidget);
  });

  testWidgets('rejects an implausible height', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Me');
    await tapText(tester, 'Edit profile');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Height (cm)'),
      '999',
    );
    await tapText(tester, 'Save');

    expect(find.text('Enter a height between 120 and 230 cm'), findsOneWidget);
  });

  testWidgets('blocked users can be unblocked from settings', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Sam 31');
    await tester.tap(find.byTooltip('More: block or report'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Block Sam');
    await tester.tap(find.widgetWithText(FilledButton, 'Block'));
    await tester.pumpAndSettle();

    await tapText(tester, 'Me');
    await tapText(tester, 'Settings & privacy');
    await tester.scrollUntilVisible(find.text('Blocked users'), 200);
    await tapText(tester, 'Blocked users');
    await tapText(tester, 'Unblock');

    expect(find.text("You haven't blocked anyone."), findsOneWidget);
  });

  testWidgets('safety centre topics open', (tester) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Me');
    await tapText(tester, 'Safety centre');

    await tapText(tester, 'Meeting someone new');

    expect(
      find.textContaining('Meet somewhere public the first time'),
      findsOneWidget,
    );
  });

  testWidgets('sign-out clears the image cache', (tester) async {
    final cache = FakeImageCache();
    await pumpOrbit(tester, imageCache: cache);
    await onboard(tester);
    await tapText(tester, 'Me');
    await tapText(tester, 'Settings & privacy');

    await tester.scrollUntilVisible(find.text('Sign out'), 200);
    await tapText(tester, 'Sign out');

    expect(cache.calls, ['clearAll']);
  });

  testWidgets('signing out returns to Welcome and clears state', (
    tester,
  ) async {
    await pumpOrbit(tester);
    await onboard(tester);
    await tapText(tester, 'Me');
    await tapText(tester, 'Settings & privacy');

    await tester.scrollUntilVisible(find.text('Sign out'), 200);
    await tapText(tester, 'Sign out');

    expect(find.text('Meet people nearby.'), findsOneWidget);
  });

  test('photo list helpers', () {
    expect(movePhoto(['a', 'b', 'c'], 2, 0), ['c', 'a', 'b']);
    expect(movePhoto(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
    expect(makeMain(['a', 'b', 'c'], 'b'), ['b', 'a', 'c']);
    expect(replacePhoto(['a', 'b'], 'b', 'z'), ['a', 'z']);
    expect(withoutPhoto(['a', 'b'], 'a'), ['b']);
  });

  test('a failed save keeps the old order', () async {
    final container = ProviderContainer(
      overrides: _photoOverrides(_photosApi(status: 500), _CountingPicker()),
    );
    addTearDown(container.dispose);
    container.read(myProfileProvider.notifier).save(_profileWith(_ids));

    await expectLater(
      container.read(myPhotosActionsProvider).reorder(0, 1),
      throwsA(isA<ApiException>()),
    );

    final photos = container.read(myProfileProvider)!.photos;
    expect([for (final p in photos) p.id], _ids);
  });

  testWidgets('tapping a photo in Edit profile opens the viewer at it', (
    tester,
  ) async {
    final picker = _CountingPicker();
    await pumpOrbit(
      tester,
      overrides: _photoOverrides(_photosApi(), picker),
    );
    await _openEditProfile(tester);

    await tester.tap(find.bySemanticsLabel(RegExp('Photo 2 of 3')));
    await tester.pumpAndSettle();

    final router = _container(tester).read(routerProvider);
    expect(
      router.state.uri.toString(),
      '${AppRoutes.myPhotos}?index=1',
    );
    expect(picker.calls, 0);
  });

  testWidgets('dragging a photo to the front makes it main', (tester) async {
    final adapter = _photosApi();
    await pumpOrbit(
      tester,
      overrides: _photoOverrides(adapter, _CountingPicker()),
    );
    await _openEditProfile(tester);
    expect(find.text('Main'), findsOneWidget);

    final second = find.bySemanticsLabel(RegExp('Photo 2 of 3'));
    final first = find.bySemanticsLabel(RegExp('Photo 1 of 3'));
    final gesture = await tester.startGesture(tester.getCenter(second));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(first));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final put = adapter.requests.singleWhere((r) => r.method == 'PUT');
    expect((put.data as Map)['mediaIds'], ['b', 'a', 'c']);
    final photos = _container(tester).read(myProfileProvider)!.photos;
    expect([for (final p in photos) p.id], ['b', 'a', 'c']);
  });
}

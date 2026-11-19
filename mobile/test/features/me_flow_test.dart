import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/app/theme.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/core/widgets/media_image.dart';
import 'package:orbit/core/widgets/photo_viewer.dart';
import 'package:orbit/features/albums/data/album_repository.dart';
import 'package:orbit/features/albums/presentation/album_screen.dart';
import 'package:orbit/features/albums/presentation/albums_controller.dart';
import 'package:orbit/features/chat/presentation/wave_limit.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/media/domain/media.dart';
import 'package:orbit/features/profile/data/account_repository.dart';
import 'package:orbit/features/profile/domain/my_profile.dart';
import 'package:orbit/features/profile/presentation/me_screen.dart';
import 'package:orbit/features/profile/presentation/my_photos_actions.dart';
import 'package:orbit/features/profile/presentation/my_photos_viewer.dart';
import 'package:orbit/features/profile/presentation/my_profile_controller.dart';
import 'package:orbit/l10n/app_localizations.dart';
import 'package:orbit/l10n/app_localizations_en.dart';

import '../helpers/fake_api.dart';
import '../helpers/fake_image_cache.dart';
import '../helpers/photo_bytes.dart';
import '../helpers/pump_app.dart';

class _CountingPicker implements MediaPicker {
  _CountingPicker({this.result});

  /// What the member "picks"; null means they cancelled.
  final PickedMedia? result;
  int calls = 0;

  @override
  Future<PickedMedia?> pickPhoto({required bool camera}) async {
    calls++;
    return result;
  }

  @override
  Future<List<PickedMedia>> pickPhotos({int limit = 10}) async => const [];

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

class _PendingUploads implements MediaRepository {
  final Completer<UploadedMedia> result = Completer();

  @override
  Future<UploadedMedia> upload(
    MediaPurpose purpose,
    Uint8List bytes,
    String contentType, {
    int? durationMs,
  }) => result.future;
}

class _RefusedUploads implements MediaRepository {
  @override
  Future<Never> upload(
    MediaPurpose purpose,
    Uint8List bytes,
    String contentType, {
    int? durationMs,
  }) => throw const ApiException(status: 500, type: 'server');
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

List<Override> _photoOverrides(
  FakeAdapter adapter,
  _CountingPicker picker, {
  MediaRepository? uploads,
}) => [
  accountRepositoryProvider.overrideWithValue(_DemoWithPhotosApi(adapter)),
  mediaRepositoryProvider.overrideWithValue(uploads ?? _NoUploads()),
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

Future<void> _openMeWith(WidgetTester tester, List<String> ids) async {
  await onboard(tester);
  _container(tester).read(myProfileProvider.notifier).save(_profileWith(ids));
  await tapText(tester, 'Me');
}

Future<void> _openMyPhotos(WidgetTester tester, List<String> ids) async {
  await _openMeWith(tester, ids);
  await tester.tap(find.byType(MeAvatar));
  await tester.pumpAndSettle();
}

/// Holds back the album reload while [reloadGate] is set.
class _GatedAlbumAdapter extends FakeAdapter {
  _GatedAlbumAdapter(super.routes, {super.handlers});

  Completer<void>? reloadGate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET' && options.path == '/albums/a1') {
      await reloadGate?.future;
    }
    return super.fetch(options, requestStream, cancelFuture);
  }
}

/// The album endpoints of the API, with the album's photo ids in memory.
class _AlbumServer {
  _AlbumServer(List<String> initial) : photoIds = [...initial] {
    adapter = _GatedAlbumAdapter(
      const {},
      handlers: {
        'GET /albums': (_) => (
          200,
          [
            {
              'id': 'a1',
              'name': 'Travel',
              'photoCount': photoIds.length,
              'grants': <Object?>[],
            },
          ],
        ),
        'GET /albums/a1': (_) => failReload
            ? (500, problem('server', 500))
            : (
                200,
                {
                  'id': 'a1',
                  'ownerId': 'me',
                  'name': 'Travel',
                  'viewOnce': false,
                  'photos': [
                    for (final id in photoIds)
                      {
                        'id': id,
                        'links': {
                          'url': 'http://x/$id',
                          'thumbUrl': 'http://x/t$id',
                          'expiresAt': '2030-01-01T00:00:00Z',
                        },
                      },
                  ],
                },
              ),
        'POST /albums/a1/photos': (options) {
          photoIds.add((options.data as Map)['mediaId'] as String);
          return (204, null);
        },
        for (final id in ['p1', 'p2', 'p3', 'm1', 'm2', 'm3'])
          'DELETE /albums/a1/photos/$id': (_) {
            photoIds.remove(id);
            return (204, null);
          },
      },
    );
  }

  final List<String> photoIds;
  bool failReload = false;
  late final _GatedAlbumAdapter adapter;

  List<String> get deletes => [
    for (final r in adapter.requests)
      if (r.method == 'DELETE') r.path,
  ];
}

/// Uploads that finish only when the test says so; [failFirst] refuses the
/// first one.
class _GatedUploads implements MediaRepository {
  _GatedUploads({this.failFirst = false});

  final bool failFirst;
  final List<Completer<UploadedMedia>> calls = [];

  @override
  Future<UploadedMedia> upload(
    MediaPurpose purpose,
    Uint8List bytes,
    String contentType, {
    int? durationMs,
  }) {
    final call = Completer<UploadedMedia>();
    calls.add(call);
    if (failFirst && calls.length == 1) {
      call.completeError(const ApiException(status: 500, type: 'server'));
    }
    return call.future;
  }

  void finish(int index) => calls[index].complete(
    UploadedMedia(
      id: 'm${index + 1}',
      links: MediaLinks(
        url: 'http://x/m${index + 1}',
        expiresAt: DateTime.utc(2030),
      ),
    ),
  );
}

class _ManyPicker implements MediaPicker {
  _ManyPicker(this.count);

  final int count;

  @override
  Future<PickedMedia?> pickPhoto({required bool camera}) async => null;

  @override
  Future<List<PickedMedia>> pickPhotos({int limit = 10}) async => [
    for (var i = 0; i < count; i++)
      PickedMedia(bytes: plainJpeg(), contentType: 'image/jpeg'),
  ];

  @override
  Future<PickedMedia?> pickVideo({required Duration maxDuration}) async => null;
}

Future<void> _pumpAlbum(
  WidgetTester tester,
  _AlbumServer server, {
  MediaRepository? uploads,
  MediaPicker? picker,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        albumRepositoryProvider.overrideWithValue(
          ApiAlbumRepository(dioWith(server.adapter)),
        ),
        mediaRepositoryProvider.overrideWithValue(uploads ?? _NoUploads()),
        mediaPickerProvider.overrideWithValue(picker ?? _ManyPicker(0)),
        orbitImageCacheProvider.overrideWithValue(FakeImageCache()),
      ],
      child: MaterialApp(
        theme: buildOrbitTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AlbumScreen(albumId: 'a1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _albumTile(String id) => find.byKey(ValueKey('album-tile-$id'));

Finder _uploadingTiles() => find.bySemanticsLabel('Uploading photo');

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

  testWidgets('sign-out still ends the session if clearing the cache fails', (
    tester,
  ) async {
    final cache = FakeImageCache()..failure = const FormatException('disk');
    await pumpOrbit(tester, imageCache: cache);
    await onboard(tester);
    await tapText(tester, 'Me');
    await tapText(tester, 'Settings & privacy');

    await tester.scrollUntilVisible(find.text('Sign out'), 200);
    await tapText(tester, 'Sign out');

    expect(cache.calls, ['clearAll']);
    expect(find.text('Meet people nearby.'), findsOneWidget);
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

  testWidgets('signing out clears wave locks and album upload tiles', (
    tester,
  ) async {
    await pumpOrbit(tester);
    await onboard(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final retryAt = testNow.add(const Duration(hours: 6));
    container.read(waveLimitProvider('p1').notifier).block(retryAt);
    container.read(waveRefusalProvider.notifier).refusal = WaveRefusal(
      'p1',
      retryAt,
    );
    container.read(albumUploadsProvider.notifier).add('a1', [
      AlbumUpload(localId: 'upload-0', preview: plainJpeg()),
    ]);
    expect(container.read(waveBlockedUntilProvider('p1')), retryAt);

    await tapText(tester, 'Me');
    await tapText(tester, 'Settings & privacy');
    await tester.scrollUntilVisible(find.text('Sign out'), 200);
    await tapText(tester, 'Sign out');

    expect(container.read(waveBlockedUntilProvider('p1')), isNull);
    expect(container.read(waveRefusalProvider), isNull);
    expect(container.read(albumUploadsProvider), isEmpty);
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

  testWidgets('tapping my avatar opens my photos', (tester) async {
    await pumpOrbit(
      tester,
      overrides: _photoOverrides(_photosApi(), _CountingPicker()),
    );
    await _openMyPhotos(tester, ['a', 'b']);

    expect(find.byType(MyPhotosViewer), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('tapping my avatar with no photos opens the picker', (
    tester,
  ) async {
    final picker = _CountingPicker();
    await pumpOrbit(tester, overrides: _photoOverrides(_photosApi(), picker));
    await _openMyPhotos(tester, []);

    expect(picker.calls, 1);
    expect(find.byType(MyPhotosViewer), findsNothing);
  });

  testWidgets('the add-status badge is labelled and hidden without a handler', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: _photoOverrides(_photosApi(), _CountingPicker()),
    );
    addTearDown(container.dispose);
    container.read(myProfileProvider.notifier).save(_profileWith(['a']));

    Future<void> pumpAvatar(MeAvatar avatar) => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: avatar),
        ),
      ),
    );

    await pumpAvatar(MeAvatar(onAddStatus: () {}));
    expect(find.byTooltip('Add a status'), findsOneWidget);

    await pumpAvatar(const MeAvatar());
    expect(find.byTooltip('Add a status'), findsNothing);
  });

  testWidgets('make main from the viewer saves the new order', (tester) async {
    final adapter = _photosApi();
    await pumpOrbit(
      tester,
      overrides: _photoOverrides(adapter, _CountingPicker()),
    );
    await _openMyPhotos(tester, ['a', 'b']);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Make main photo'));
    await tester.pumpAndSettle();

    final put = adapter.requests.singleWhere((r) => r.method == 'PUT');
    expect((put.data as Map)['mediaIds'], ['b', 'a']);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byTooltip('Make main photo'), findsNothing);
  });

  testWidgets('deleting my only photo warns first', (tester) async {
    final adapter = _photosApi();
    await pumpOrbit(
      tester,
      overrides: _photoOverrides(adapter, _CountingPicker()),
    );
    await _openMyPhotos(tester, ['a']);

    await tester.tap(find.byTooltip('Delete photo'));
    await tester.pumpAndSettle();
    expect(find.textContaining('This is your only photo'), findsOneWidget);
    expect(adapter.requests.where((r) => r.method == 'PUT'), isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    final put = adapter.requests.singleWhere((r) => r.method == 'PUT');
    expect((put.data as Map)['mediaIds'], <Object?>[]);
    expect(find.byType(MyPhotosViewer), findsNothing);
  });

  testWidgets('a failed replace shows an error and keeps the photo', (
    tester,
  ) async {
    final adapter = _photosApi();
    final picker = _CountingPicker(
      result: PickedMedia(bytes: Uint8List(3), contentType: 'image/jpeg'),
    );
    await pumpOrbit(
      tester,
      overrides: _photoOverrides(adapter, picker, uploads: _RefusedUploads()),
    );
    await _openMyPhotos(tester, ['a', 'b']);

    await tester.tap(find.byTooltip('Replace photo'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't reach Orbit"), findsOneWidget);
    expect(find.byType(MyPhotosViewer), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(adapter.requests.where((r) => r.method == 'PUT'), isEmpty);
    final photos = _container(tester).read(myProfileProvider)!.photos;
    expect([for (final p in photos) p.id], ['a', 'b']);
  });

  testWidgets('while an action runs the page shows progress and locks', (
    tester,
  ) async {
    final uploads = _PendingUploads();
    final picker = _CountingPicker(
      result: PickedMedia(bytes: Uint8List(3), contentType: 'image/jpeg'),
    );
    await pumpOrbit(
      tester,
      overrides: _photoOverrides(_photosApi(), picker, uploads: uploads),
    );
    await _openMyPhotos(tester, ['a', 'b']);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byTooltip('Replace photo'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    for (final icon in [Icons.swap_horiz, Icons.delete_outline]) {
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, icon),
      );
      expect(button.onPressed, isNull);
    }
    final pager = tester.widget<PageView>(find.byType(PageView));
    expect(pager.physics, isA<NeverScrollableScrollPhysics>());

    uploads.result.completeError(const ApiException(status: 500, type: 'x'));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    final again = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.delete_outline),
    );
    expect(again.onPressed, isNotNull);
  });

  group('album photos', () {
    testWidgets('adding three photos shows three progress tiles then three '
        'photos', (tester) async {
      final server = _AlbumServer([]);
      final uploads = _GatedUploads();
      await _pumpAlbum(
        tester,
        server,
        uploads: uploads,
        picker: _ManyPicker(3),
      );

      await tester.tap(find.text('Add photos'));
      await tester.pump();
      await tester.pump();

      expect(_uploadingTiles(), findsNWidgets(3));
      expect(uploads.calls, hasLength(1));

      for (var i = 0; i < 3; i++) {
        uploads.finish(i);
        // The next tile's spinner never settles, so pump a fixed few frames.
        for (var frame = 0; frame < 5; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(_uploadingTiles(), findsNWidgets(2 - i));
      }

      expect(uploads.calls, hasLength(3));
      expect(server.photoIds, ['m1', 'm2', 'm3']);
      expect(_albumTile('m1'), findsOneWidget);
      expect(_albumTile('m2'), findsOneWidget);
      expect(_albumTile('m3'), findsOneWidget);
    });

    testWidgets('a finished upload tile is replaced in place by its photo', (
      tester,
    ) async {
      final server = _AlbumServer(['p1']);
      final uploads = _GatedUploads();
      await _pumpAlbum(
        tester,
        server,
        uploads: uploads,
        picker: _ManyPicker(1),
      );
      await tester.tap(find.text('Add photos'));
      await tester.pump();
      await tester.pump();

      // The reload is slow: the slot must stay filled until it lands.
      server.adapter.reloadGate = Completer();
      uploads.finish(0);
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          _uploadingTiles().evaluate().length +
              _albumTile('m1').evaluate().length,
          1,
          reason: 'frame $frame',
        );
        expect(_albumTile('p1'), findsOneWidget);
      }
      expect(_albumTile('m1'), findsNothing);

      server.adapter.reloadGate!.complete();
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(_uploadingTiles(), findsNothing);
      expect(_albumTile('m1'), findsOneWidget);
      expect(_albumTile('p1'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the album on screen', (tester) async {
      final server = _AlbumServer(['p1']);
      final uploads = _GatedUploads();
      await _pumpAlbum(
        tester,
        server,
        uploads: uploads,
        picker: _ManyPicker(1),
      );
      await tester.tap(find.text('Add photos'));
      await tester.pump();
      await tester.pump();

      server.failReload = true;
      uploads.finish(0);
      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text(AppLocalizationsEn().albumGone), findsNothing);
      expect(_albumTile('p1'), findsOneWidget);
    });

    testWidgets('a failed upload tile offers retry', (tester) async {
      final server = _AlbumServer([]);
      final uploads = _GatedUploads(failFirst: true);
      await _pumpAlbum(
        tester,
        server,
        uploads: uploads,
        picker: _ManyPicker(1),
      );

      await tester.tap(find.text('Add photos'));
      await tester.pumpAndSettle();

      final retry = find.bySemanticsLabel('Upload failed. Tap to retry');
      expect(retry, findsOneWidget);
      expect(server.photoIds, isEmpty);

      await tester.tap(retry);
      await tester.pump();
      await tester.pump();
      uploads.finish(1);
      await tester.pumpAndSettle();

      expect(retry, findsNothing);
      expect(server.photoIds, ['m2']);
      expect(_albumTile('m2'), findsOneWidget);
    });

    testWidgets('long-press selects photos and deletes them', (tester) async {
      final server = _AlbumServer(['p1', 'p2', 'p3']);
      await _pumpAlbum(tester, server);

      await tester.longPress(_albumTile('p1'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(_albumTile('p3'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.byType(PhotoViewer), findsNothing);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete 2 photos?'), findsOneWidget);
      expect(server.deletes, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(server.deletes, [
        '/albums/a1/photos/p1',
        '/albums/a1/photos/p3',
      ]);
      expect(find.text('2 selected'), findsNothing);
      expect(_albumTile('p1'), findsNothing);
      expect(_albumTile('p2'), findsOneWidget);
    });

    testWidgets('tapping an album photo opens the viewer at that photo', (
      tester,
    ) async {
      final server = _AlbumServer(['p1', 'p2', 'p3']);
      await _pumpAlbum(tester, server);

      await tester.tap(_albumTile('p2'));
      await tester.pumpAndSettle();

      final viewer = tester.widget<PhotoViewer>(find.byType(PhotoViewer));
      expect(viewer.initialIndex, 1);
      expect(viewer.items.map((i) => i.mediaId), ['p1', 'p2', 'p3']);
    });
  });
}

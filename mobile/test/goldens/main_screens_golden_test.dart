// Pixel-exact images made on macOS; Linux anti-aliases text differently,
// so CI runs this tag on a macOS runner only.
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/app/theme.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/widgets/media_image.dart';
import 'package:orbit/features/albums/data/album_repository.dart';
import 'package:orbit/features/albums/domain/album.dart';
import 'package:orbit/features/albums/presentation/album_screen.dart';
import 'package:orbit/features/discovery/data/fake_profile_repository.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/features/media/domain/media.dart';
import 'package:orbit/features/safety/data/safety_repository.dart';
import 'package:orbit/features/status/data/status_repository.dart';
import 'package:orbit/features/status/presentation/status_viewer.dart';
import 'package:orbit/l10n/app_localizations.dart';

import '../helpers/fake_api.dart';
import '../helpers/pump_app.dart';
import '../helpers/sdk_fonts.dart';

/// The phone every golden is taken on, in logical pixels.
const _phone = Size(393, 852);

const _pixelRatio = 3.0;

/// Solid colours the fake images cycle through, so tiles are told apart.
const _swatches = [
  Color(0xFF3E7CB1),
  Color(0xFFB1593E),
  Color(0xFF5B9E6B),
  Color(0xFF8A5FB1),
  Color(0xFFC9A227),
  Color(0xFF4F9DA6),
];

/// Serves a solid-colour image for every URL and never touches the network
/// or the real cache database.
class _SolidImages extends Fake implements BaseCacheManager {
  _SolidImages(this._files);

  final List<FileInfo> _files;

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    final index = url.codeUnits.fold<int>(0, (a, b) => a + b) % _files.length;
    final swatch = _files[index];
    return Stream.value(
      FileInfo(swatch.file, FileSource.Cache, swatch.validTill, url),
    );
  }
}

/// Writes one solid PNG per swatch through the cache's own file system, which
/// a fake `path_provider` points at [dir].
Future<List<FileInfo>> _writeSwatches(Directory dir) async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => dir.path,
      );
  final system = IOFileSystem('golden-solid-images');
  final files = <FileInfo>[];
  for (final (i, color) in _swatches.indexed) {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 64, 64),
      Paint()..color = color,
    );
    final image = await recorder.endRecording().toImage(64, 64);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = await system.createFile('swatch$i.png');
    await file.writeAsBytes(data!.buffer.asUint8List());
    files.add(FileInfo(file, FileSource.Cache, DateTime(2100), 'swatch$i'));
  }
  return files;
}

final DateTime _now = testNow;

const _sam = Profile(
  id: 'p1',
  name: 'Sam',
  age: 30,
  distanceKm: 2,
  online: true,
  bio: '',
  lookingFor: {},
  tags: [],
  photoCount: 0,
  isNew: false,
);

class _NoBlocks implements SafetyRepository {
  @override
  Future<void> block(String id) async {}

  @override
  Future<void> unblock(String id) async {}

  @override
  Future<void> report(
    String id,
    ReportReason reason, {
    required bool alsoBlock,
    String? statusId,
  }) async {}

  @override
  Future<Map<String, String>> blocked() async => {};
}

class _OneAlbum implements AlbumRepository {
  @override
  Future<List<Album>> mine() async => const [
    Album(id: 'a1', name: 'Weekend trip', photoCount: 6, isPrivate: true),
  ];

  @override
  Future<OpenedAlbum> open(String albumId) async => OpenedAlbum(
    id: 'a1',
    ownerId: 'me',
    name: 'Weekend trip',
    viewOnce: false,
    photos: [
      for (var i = 1; i <= 6; i++)
        AlbumPhoto(
          id: 'photo$i',
          links: MediaLinks(
            url: 'https://img.test/album/photo$i.jpg',
            expiresAt: DateTime.utc(2030),
          ),
        ),
    ],
  );

  @override
  Future<String> create(String name) async => 'a1';

  @override
  Future<void> addPhoto(String albumId, String mediaId) async {}

  @override
  Future<void> removePhoto(String albumId, String mediaId) async {}

  @override
  Future<void> share(
    String albumId,
    String profileId,
    AlbumAccess access, {
    required bool viewOnce,
  }) async {}

  @override
  Future<void> revoke(String albumId, String profileId) async {}

  @override
  Future<List<SharedAlbum>> sharedWithMe() async => const [];
}

Map<String, Object?> _status(int n) => {
  'id': 's$n',
  'url': 'https://img.test/status/s$n.jpg',
  'caption': 'Sunset at the river $n',
  'createdAt': _now.subtract(Duration(hours: 4 - n)).toUtc().toIso8601String(),
  'seen': false,
};

/// Waits until at least [count] images have decoded and none is still
/// loading. File reads and decoding happen outside the test clock, so each
/// round yields to real asynchronous work and then pumps zero time; the
/// clock never advances, which keeps animations frozen. Fails after a bounded
/// number of rounds instead of capturing a half-loaded screen.
Future<void> _loadImages(WidgetTester tester, {int count = 0}) async {
  if (count == 0) return;
  var loaded = 0;
  for (var round = 0; round < 200; round++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    final images = tester.allRenderObjects.whereType<RenderImage>();
    loaded = images.where((image) => image.image != null).length;
    if (loaded >= count && loaded == images.length) return;
  }
  fail('Only $loaded of $count images decoded after 200 rounds.');
}

void _setUpPhone(WidgetTester tester, Brightness brightness) {
  tester.view
    ..physicalSize = _phone * _pixelRatio
    ..devicePixelRatio = _pixelRatio;
  tester.platformDispatcher
    ..platformBrightnessTestValue = brightness
    ..accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher
      ..clearPlatformBrightnessTestValue()
      ..clearAccessibilityFeaturesTestValue();
  });
}

Future<void> _pumpStandalone(
  WidgetTester tester,
  Brightness brightness,
  Widget home,
  List<FileInfo> swatches, {
  List<Override> overrides = const [],
}) async {
  _setUpPhone(tester, brightness);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => _now),
        orbitImageCacheProvider.overrideWithValue(
          OrbitImageCache(
            manager: _SolidImages(swatches),
            statusManager: _SolidImages(swatches),
          ),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: buildOrbitTheme(Brightness.light),
        darkTheme: buildOrbitTheme(Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
}

Future<void> _pumpApp(
  WidgetTester tester,
  Brightness brightness,
  List<FileInfo> swatches,
) async {
  _setUpPhone(tester, brightness);
  await pumpOrbit(
    tester,
    imageCache: OrbitImageCache(
      manager: _SolidImages(swatches),
      statusManager: _SolidImages(swatches),
    ),
  );
  // `pumpOrbit` sizes the view for its own tests; this suite owns the size.
  tester.view
    ..physicalSize = _phone * _pixelRatio
    ..devicePixelRatio = _pixelRatio;
  await tester.pumpAndSettle();
  await onboard(tester);
}

Future<void> _matches(WidgetTester tester, String name) async {
  // The test binding draws every elevation shadow as a solid outline in the
  // shadow colour, which showed as a hard black ring round the album's
  // "Add photos" button. Paint real shadows, as a phone does, for the
  // capture only: the binding checks the flag is back when the test ends.
  final bindingDefault = debugDisableShadows;
  debugDisableShadows = false;
  try {
    await _repaint(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('$name.png'));
  } finally {
    debugDisableShadows = bindingDefault;
  }
}

Future<void> _repaint(WidgetTester tester) async {
  for (final object in tester.allRenderObjects) {
    object.markNeedsPaint();
  }
  await tester.pump();
}

void main() {
  late Directory dir;
  late List<FileInfo> swatches;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('orbit-golden-');
    await loadSdkFonts();
    swatches = await _writeSwatches(dir);
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  setUp(() {
    WidgetsApp.debugAllowBannerOverride = false;
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  for (final brightness in Brightness.values) {
    final mode = brightness.name;

    group('$mode mode', () {
      testWidgets('Nearby', (tester) async {
        await _pumpApp(tester, brightness, swatches);
        await _matches(tester, 'nearby_$mode');
      });

      testWidgets('Profile', (tester) async {
        await _pumpApp(tester, brightness, swatches);
        await tapText(tester, 'Alex');
        await _matches(tester, 'profile_$mode');
      });

      testWidgets('Inbox', (tester) async {
        await _pumpApp(tester, brightness, swatches);
        await tapText(tester, 'Inbox');
        await _matches(tester, 'inbox_$mode');
      });

      testWidgets('Chat', (tester) async {
        await _pumpApp(tester, brightness, swatches);
        await tapText(tester, 'Inbox');
        await tapText(tester, 'Alex');
        await _matches(tester, 'chat_$mode');
      });

      testWidgets('Me', (tester) async {
        await _pumpApp(tester, brightness, swatches);
        await tapText(tester, 'Me');
        await _matches(tester, 'me_$mode');
      });

      testWidgets('Status viewer', (tester) async {
        final adapter = FakeAdapter(
          {'PUT /statuses/s1/view': (204, null)},
          handlers: {
            'GET /profiles/p1/statuses': (_) =>
                (200, [_status(1), _status(2), _status(3)]),
            'GET /me/statuses': (_) => (200, const []),
          },
        );
        await _pumpStandalone(
          tester,
          brightness,
          const StatusViewerScreen(profileId: 'p1'),
          swatches,
          overrides: [
            statusRepositoryProvider.overrideWithValue(
              ApiStatusRepository(dioWith(adapter)),
            ),
            safetyRepositoryProvider.overrideWithValue(_NoBlocks()),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(profiles: [_sam], latency: Duration.zero),
            ),
          ],
        );
        await tester.pump(const Duration(milliseconds: 100));
        await _loadImages(tester, count: 1);
        // The loading above pumps no time. With animations disabled the
        // viewer runs its 5 s segment at 1/20 speed (250 ms), so this fixed
        // pump freezes the bar part-way through the first status.
        await tester.pump(const Duration(milliseconds: 50));
        await _matches(tester, 'status_viewer_$mode');
      });

      testWidgets('Album', (tester) async {
        await _pumpStandalone(
          tester,
          brightness,
          const AlbumScreen(albumId: 'a1'),
          swatches,
          overrides: [albumRepositoryProvider.overrideWithValue(_OneAlbum())],
        );
        await tester.pumpAndSettle();
        await _loadImages(tester, count: 6);
        await _matches(tester, 'album_$mode');
      });
    });
  }
}

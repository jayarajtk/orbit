import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/widgets/media_image.dart';
import 'package:orbit/core/widgets/photo_viewer.dart';
import 'package:orbit/features/safety/data/safety_repository.dart';
import 'package:orbit/features/safety/presentation/safety_providers.dart';
import 'package:orbit/l10n/app_localizations.dart';

import '../helpers/fake_image_cache.dart';

class _AcceptingSafety implements SafetyRepository {
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

class _RecordingManager extends CacheManager {
  _RecordingManager() : super(Config('photo-viewer-test'));

  final List<String> removed = [];

  @override
  Future<void> removeFile(String key) async => removed.add(key);
}

class _ManagedCache extends OrbitImageCache {
  _ManagedCache(_RecordingManager manager) : super(manager: manager);
}

const _items = [
  PhotoViewerItem(mediaId: 'a', url: 'https://x.test/a'),
  PhotoViewerItem(mediaId: 'b', url: 'https://x.test/b'),
  PhotoViewerItem(mediaId: 'c', url: 'https://x.test/c'),
];

Future<void> _open(
  WidgetTester tester, {
  int initialIndex = 0,
  Widget Function(BuildContext, int)? bottomBar,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        orbitImageCacheProvider.overrideWithValue(FakeImageCache()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openPhotos(
                context,
                _items,
                initialIndex: initialIndex,
                bottomBar: bottomBar,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _show(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        orbitImageCacheProvider.overrideWithValue(FakeImageCache()),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
}

void main() {
  testWidgets('viewer opens at the given index and pages', (tester) async {
    await _open(tester, initialIndex: 1);

    expect(find.text('2 / 3'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();

    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('the bottom bar is built for the current page', (tester) async {
    await _open(
      tester,
      bottomBar: (context, index) => Text('bar $index'),
    );

    expect(find.text('bar 0'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1500);
    await tester.pumpAndSettle();

    expect(find.text('bar 1'), findsOneWidget);
  });

  testWidgets('dragging down past the threshold closes the viewer', (
    tester,
  ) async {
    await _open(tester);
    expect(find.byType(PhotoViewer), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewer), findsNothing);
  });

  testWidgets('a short, slow drag springs back and keeps the viewer open', (
    tester,
  ) async {
    await _open(tester);

    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewer), findsOneWidget);
  });

  testWidgets('double tap zooms in at the tap point and back out', (
    tester,
  ) async {
    await _open(tester);
    final viewer = find.byType(InteractiveViewer);
    double scale() => tester
        .widget<InteractiveViewer>(viewer)
        .transformationController!
        .value
        .getMaxScaleOnAxis();

    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(viewer);
    await tester.pumpAndSettle();
    expect(scale(), closeTo(2.5, 0.01));

    await tester.tap(viewer);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(viewer);
    await tester.pumpAndSettle();
    expect(scale(), 1);
  });

  testWidgets('view-once photos are not cached', (tester) async {
    await _show(
      tester,
      const SizedBox(
        width: 100,
        height: 100,
        child: MediaImage(
          mediaId: 'm1',
          url: 'https://x.test/m1',
          cache: false,
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('cache key ignores the signed URL', (tester) async {
    await _show(
      tester,
      const Column(
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: MediaImage(mediaId: 'm1', url: 'https://x.test/m1?sig=1'),
          ),
          SizedBox(
            width: 50,
            height: 50,
            child: MediaImage(mediaId: 'm1', url: 'https://x.test/m1?sig=2'),
          ),
        ],
      ),
    );

    final keys = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .map((image) => image.cacheKey)
        .toList();
    expect(keys, ['m1:full', 'm1:full']);
  });

  testWidgets('a full image shows its thumbnail under it, keyed apart', (
    tester,
  ) async {
    await _show(
      tester,
      const SizedBox(
        width: 100,
        height: 100,
        child: MediaImage(
          mediaId: 'm1',
          url: 'https://x.test/full',
          thumbUrl: 'https://x.test/thumb',
        ),
      ),
    );

    final keys = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .map((image) => image.cacheKey)
        .toList();
    expect(keys, ['m1:thumb', 'm1:full']);
  });

  test("evicts a member's images when blocked", () async {
    final cache = FakeImageCache();
    final container = ProviderContainer(
      overrides: [
        orbitImageCacheProvider.overrideWithValue(cache),
        safetyRepositoryProvider.overrideWithValue(_AcceptingSafety()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(blockedProvider.notifier).block('p1', name: 'Alex');

    expect(cache.calls, ['evictOwner:p1']);
  });

  test(
    'reporting with a block evicts the member, without one does not',
    () async {
      final cache = FakeImageCache();
      final container = ProviderContainer(
        overrides: [
          orbitImageCacheProvider.overrideWithValue(cache),
          safetyRepositoryProvider.overrideWithValue(_AcceptingSafety()),
        ],
      );
      addTearDown(container.dispose);
      final blocked = container.read(blockedProvider.notifier);

      await blocked.report(
        'p1',
        ReportReason.fake,
        name: 'A',
        alsoBlock: false,
      );
      await blocked.report('p2', ReportReason.fake, name: 'B', alsoBlock: true);

      expect(cache.calls, ['evictOwner:p2']);
    },
  );

  testWidgets('images opened in the viewer are registered to their owner', (
    tester,
  ) async {
    final manager = _RecordingManager();
    final cache = _ManagedCache(manager);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [orbitImageCacheProvider.overrideWithValue(cache)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PhotoViewer(
            items: [
              PhotoViewerItem(
                mediaId: 'z9',
                url: 'https://x.test/z9',
                ownerId: 'bob',
              ),
            ],
          ),
        ),
      ),
    );

    await cache.evictOwner('bob');

    expect(manager.removed, containsAll(['z9:full', 'z9:thumb']));
  });

  test('a failing eviction does not make a successful block fail', () async {
    final cache = FakeImageCache()..failure = const FormatException('disk');
    final container = ProviderContainer(
      overrides: [
        orbitImageCacheProvider.overrideWithValue(cache),
        safetyRepositoryProvider.overrideWithValue(_AcceptingSafety()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(blockedProvider.notifier).block('p1', name: 'Alex');

    expect(container.read(blockedProvider), {'p1'});
    expect(cache.calls, ['evictOwner:p1']);
  });

  test('a failing eviction does not make a report with block fail', () async {
    final cache = FakeImageCache()..failure = const FormatException('disk');
    final container = ProviderContainer(
      overrides: [
        orbitImageCacheProvider.overrideWithValue(cache),
        safetyRepositoryProvider.overrideWithValue(_AcceptingSafety()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(blockedProvider.notifier)
        .report('p1', ReportReason.fake, name: 'A', alsoBlock: true);

    expect(container.read(blockedProvider), {'p1'});
  });
}

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/widgets/media_image.dart';
import 'package:orbit/features/discovery/data/fake_profile_repository.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/features/safety/data/safety_repository.dart';
import 'package:orbit/features/status/data/status_repository.dart';
import 'package:orbit/features/status/presentation/status_providers.dart';
import 'package:orbit/features/status/presentation/status_viewer.dart';
import 'package:orbit/l10n/app_localizations.dart';

import '../helpers/fake_api.dart';

/// Serves no image bytes: URLs containing `gone` fail at once (an expired
/// status), every other image stays loading, so only the viewer's own
/// failure handling can move it along.
class _Images extends CacheManager {
  _Images() : super(Config('status-viewer-test'));

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => url.contains('gone')
      ? Stream.error(Exception('410'))
      : StreamController<FileResponse>().stream;
}

/// The shared image cache: status photos must never be read from or
/// written to it, so any request fails the test.
class _SharedImages extends CacheManager {
  _SharedImages() : super(Config('status-viewer-shared-test'));

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => throw StateError('Status photo $key went to the shared cache');
}

class _RecordingSafety implements SafetyRepository {
  final List<String?> reportedStatusIds = [];

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
  }) async => reportedStatusIds.add(statusId);

  @override
  Future<Map<String, String>> blocked() async => {};
}

final _now = DateTime(2026, 11, 9, 12);

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

Map<String, Object?> _item(int n, {String host = 'ok'}) => {
  'id': 's$n',
  'url': 'https://img.test/$host/s$n.jpg',
  'caption': 'Caption $n',
  'createdAt': _now.subtract(Duration(hours: 4 - n)).toUtc().toIso8601String(),
  'seen': false,
};

Map<String, Object?> _mine(int n, {List<Map<String, Object?>>? viewers}) => {
  'id': 'm$n',
  'url': 'https://img.test/ok/m$n.jpg',
  'caption': 'Mine $n',
  'createdAt': _now.subtract(Duration(hours: 4 - n)).toUtc().toIso8601String(),
  'expiresAt': _now.add(const Duration(hours: 20)).toUtc().toIso8601String(),
  'viewCount': viewers?.length ?? 0,
  'viewers': viewers ?? const [],
};

Map<String, Object?> _viewer(String name, int minutesAgo) => {
  'id': 'v-$name',
  'name': name,
  'viewedAt': _now.subtract(Duration(minutes: minutesAgo)).toIso8601String(),
};

class _Harness {
  _Harness(this.adapter, this.safety);

  final FakeAdapter adapter;
  final _RecordingSafety safety;

  List<RequestOptions> requests(String method) =>
      adapter.requests.where((r) => r.method == method).toList();
}

Future<_Harness> _open(
  WidgetTester tester, {
  String profileId = 'p1',
  List<Map<String, Object?>> theirs = const [],
  List<Map<String, Object?>> Function()? mine,
  BaseCacheManager? statusImages,
}) async {
  final statuses = statusImages ?? _Images();
  final adapter = FakeAdapter(
    {
      'PUT /statuses/s1/view': (204, null),
      'PUT /statuses/s2/view': (204, null),
      'PUT /statuses/s3/view': (204, null),
    },
    handlers: {
      'GET /profiles/p1/statuses': (_) => (200, theirs),
      'GET /me/statuses': (_) => (200, mine?.call() ?? const []),
      'DELETE /me/statuses/m1': (_) => (204, null),
    },
  );
  final safety = _RecordingSafety();
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        clockProvider.overrideWithValue(() => _now),
        statusRepositoryProvider.overrideWithValue(
          ApiStatusRepository(dioWith(adapter)),
        ),
        safetyRepositoryProvider.overrideWithValue(safety),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(profiles: [_sam], latency: Duration.zero),
        ),
        orbitImageCacheProvider.overrideWithValue(
          OrbitImageCache(manager: _SharedImages(), statusManager: statuses),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => StatusViewerScreen(profileId: profileId),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // Load the data and finish the route transition without letting a whole
  // segment elapse.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return _Harness(adapter, safety);
}

Future<void> _tapRight(WidgetTester tester) async {
  await tester.tapAt(const Offset(380, 400));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _tapLeft(WidgetTester tester) async {
  await tester.tapAt(const Offset(20, 400));
  await tester.pump(const Duration(milliseconds: 50));
}

/// Runs the screen-reader action [label] on the status photo.
void _semanticAction(WidgetTester tester, String label) =>
    tester.semantics.customAction(
      find.semantics.byLabel('Status photo'),
      CustomSemanticsAction(label: label),
    );

final List<Map<String, Object?>> _threeStatuses = [
  _item(1),
  _item(2),
  _item(3),
];

void main() {
  // Images are shared between tests by cache key (status id and variant).
  setUp(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  testWidgets('advances after 5 seconds and closes after the last', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _open(tester, theirs: _threeStatuses);
    expect(find.text('Caption 1'), findsOneWidget);
    expect(find.bySemanticsLabel('Status 1 of 3'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('3h ago'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Caption 1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Caption 2'), findsOneWidget);

    // The next segment's clock starts on the first frame after the switch.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Caption 3'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(StatusViewerScreen), findsNothing);
    semantics.dispose();
  });

  testWidgets('tap right goes next, tap left goes back', (tester) async {
    await _open(tester, theirs: _threeStatuses);

    await _tapRight(tester);
    expect(find.text('Caption 2'), findsOneWidget);
    await _tapRight(tester);
    expect(find.text('Caption 3'), findsOneWidget);
    await _tapLeft(tester);
    expect(find.text('Caption 2'), findsOneWidget);
    await _tapLeft(tester);
    expect(find.text('Caption 1'), findsOneWidget);
  });

  testWidgets('screen-reader actions go back, go next, pause and resume', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _open(tester, theirs: _threeStatuses);

    _semanticAction(tester, 'Next status');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Caption 2'), findsOneWidget);
    _semanticAction(tester, 'Previous status');
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Caption 1'), findsOneWidget);

    _semanticAction(tester, 'Pause');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Caption 1'), findsOneWidget);

    // Paused at its start, the segment needs its full 5 seconds from the
    // first frame after resuming.
    _semanticAction(tester, 'Resume');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Caption 2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    semantics.dispose();
  });

  testWidgets('a screen reader stops statuses advancing on their own', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final semantics = tester.ensureSemantics();
    await _open(tester, theirs: _threeStatuses);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Caption 1'), findsOneWidget);

    // Paused at its start, the segment needs its full 5 seconds from the
    // first frame after resuming.
    _semanticAction(tester, 'Resume');
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Caption 2'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    semantics.dispose();
  });

  testWidgets('holding pauses progress', (tester) async {
    await _open(tester, theirs: _threeStatuses);

    final hold = await tester.startGesture(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Caption 1'), findsOneWidget);

    await hold.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Caption 1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Caption 2'), findsOneWidget);
    // Let the view request for the new status finish.
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('marks each status viewed once', (tester) async {
    final harness = await _open(tester, theirs: _threeStatuses);

    await _tapRight(tester);
    await _tapLeft(tester);
    await _tapRight(tester);
    await _tapRight(tester);
    await tester.pump(const Duration(milliseconds: 50));

    expect(harness.requests('PUT').map((r) => r.path), [
      '/statuses/s1/view',
      '/statuses/s2/view',
      '/statuses/s3/view',
    ]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StatusViewerScreen)),
    );
    expect(container.read(seenStatusOwnersProvider), {'p1'});
  });

  testWidgets('viewing one of three statuses keeps the ring unseen', (
    tester,
  ) async {
    await _open(tester, theirs: _threeStatuses);
    await tester.pump(const Duration(milliseconds: 50));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(StatusViewerScreen)),
    );
    expect(container.read(seenStatusOwnersProvider), isEmpty);

    await _tapRight(tester);
    await _tapRight(tester);
    expect(container.read(seenStatusOwnersProvider), {'p1'});
  });

  testWidgets('statuses seen before count towards the ring', (tester) async {
    await _open(
      tester,
      theirs: [
        {..._item(1), 'seen': true},
        {..._item(2), 'seen': true},
        _item(3),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(StatusViewerScreen)),
    );

    await _tapRight(tester);
    expect(container.read(seenStatusOwnersProvider), isEmpty);
    await _tapRight(tester);
    expect(container.read(seenStatusOwnersProvider), {'p1'});
  });

  testWidgets('own status shows view count and opens Viewed by', (
    tester,
  ) async {
    final harness = await _open(
      tester,
      profileId: 'me',
      mine: () => [
        _mine(2),
        _mine(1, viewers: [_viewer('Ann', 90), _viewer('Bo', 10)]),
      ],
    );

    expect(find.text('Mine 1'), findsOneWidget);
    expect(find.text('👁 2'), findsOneWidget);
    await tester.tap(find.text('👁 2'));
    await tester.pumpAndSettle();

    expect(find.text('Viewed by'), findsOneWidget);
    expect(find.text('10m ago'), findsOneWidget);
    expect(find.text('1h ago'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Bo')).dy,
      lessThan(tester.getTopLeft(find.text('Ann')).dy),
    );
    expect(harness.requests('PUT'), isEmpty);
  });

  testWidgets('reopening my statuses shows viewers added since', (
    tester,
  ) async {
    var viewers = [_viewer('Ann', 90)];
    await _open(
      tester,
      profileId: 'me',
      mine: () => [_mine(1, viewers: viewers)],
    );
    expect(find.text('👁 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    viewers = [_viewer('Ann', 90), _viewer('Sam', 1)];
    await tester.tap(find.text('open'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('👁 2'), findsOneWidget);
    await tester.tap(find.text('👁 2'));
    await tester.pumpAndSettle();
    expect(find.text('Sam'), findsOneWidget);
  });

  testWidgets('my expired statuses are skipped', (tester) async {
    final semantics = tester.ensureSemantics();
    await _open(
      tester,
      profileId: 'me',
      mine: () => [
        _mine(2),
        {
          ..._mine(1),
          'expiresAt': _now
              .subtract(const Duration(minutes: 1))
              .toUtc()
              .toIso8601String(),
        },
      ],
    );

    expect(find.text('Mine 2'), findsOneWidget);
    expect(find.text('Mine 1'), findsNothing);
    expect(find.bySemanticsLabel('Status 1 of 1'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('delete own status asks first, then removes it', (tester) async {
    var statuses = [_mine(2), _mine(1)];
    final harness = await _open(
      tester,
      profileId: 'me',
      mine: () => statuses,
    );

    await tester.tap(find.byTooltip('Delete status'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Delete this status?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(harness.requests('DELETE'), isEmpty);
    expect(find.text('Mine 1'), findsOneWidget);

    statuses = [_mine(2)];
    await tester.tap(find.byTooltip('Delete status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(harness.requests('DELETE').map((r) => r.path), [
      '/me/statuses/m1',
    ]);
    expect(find.text('Mine 2'), findsOneWidget);
    expect(find.text('Mine 1'), findsNothing);
  });

  testWidgets('report passes the status id', (tester) async {
    final harness = await _open(tester, theirs: _threeStatuses);

    await _tapRight(tester);
    await tester.tap(find.byTooltip('Report status'));
    await tester.pumpAndSettle();
    final reason = find.text('Fake profile or spam');
    await tester.ensureVisible(reason);
    await tester.pump();
    await tester.tap(reason);
    await tester.pump();
    final submit = find.text('Submit report');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(harness.safety.reportedStatusIds, ['s2']);
  });

  testWidgets('skips a status whose image fails to load', (tester) async {
    await _open(
      tester,
      theirs: [
        _item(1, host: 'gone'),
        _item(2),
        _item(3),
      ],
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Caption 2'), findsOneWidget);
    expect(find.text('Caption 1'), findsNothing);
  });

  testWidgets('status photos use the short-lived status cache', (
    tester,
  ) async {
    final statuses = _Images();
    await _open(tester, theirs: _threeStatuses, statusImages: statuses);
    await _tapRight(tester);

    final images = tester.widgetList<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(images, isNotEmpty);
    for (final image in images) {
      expect(image.cacheManager, same(statuses));
    }
  });

  testWidgets('closes when the member has no statuses', (tester) async {
    await _open(tester);
    await tester.pumpAndSettle();

    expect(find.byType(StatusViewerScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping down closes the viewer', (tester) async {
    await _open(tester, theirs: _threeStatuses);

    await tester.dragFrom(const Offset(200, 300), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.byType(StatusViewerScreen), findsNothing);
  });
}

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/widgets/status_ring.dart';
import 'package:orbit/features/discovery/data/fake_profile_repository.dart';
import 'package:orbit/features/discovery/domain/discovery_filters.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/media/domain/media.dart';
import 'package:orbit/features/profile/presentation/me_screen.dart';
import 'package:orbit/features/status/data/status_repository.dart';
import 'package:orbit/features/status/domain/status.dart';
import 'package:orbit/features/status/presentation/status_providers.dart';
import 'package:orbit/features/status/presentation/status_viewer.dart';

import '../helpers/fake_api.dart';
import '../helpers/photo_bytes.dart';
import '../helpers/pump_app.dart';

class _Picker implements MediaPicker {
  @override
  Future<PickedMedia?> pickPhoto({required bool camera}) async =>
      PickedMedia(bytes: plainJpeg(), contentType: 'image/jpeg');

  @override
  Future<PickedMedia?> pickVideo({required Duration maxDuration}) async => null;
}

/// An upload that finishes when the test says so.
class _PendingUpload implements MediaRepository {
  final Completer<UploadedMedia> result = Completer();

  @override
  Future<UploadedMedia> upload(
    MediaPurpose purpose,
    Uint8List bytes,
    String contentType, {
    int? durationMs,
  }) => result.future;
}

class _CountingProfiles extends FakeProfileRepository {
  _CountingProfiles(List<Profile> profiles)
    : super(profiles: profiles, latency: Duration.zero);

  int nearbyCalls = 0;

  @override
  Future<List<Profile>> nearby(DiscoveryFilters filters) {
    nearbyCalls++;
    return super.nearby(filters);
  }
}

Profile _member(
  String id,
  String name, {
  StatusRing status = StatusRing.none,
  bool isNew = false,
}) => Profile(
  id: id,
  name: name,
  age: 30,
  distanceKm: 2,
  online: false,
  bio: '',
  lookingFor: const {},
  tags: const [],
  photoCount: 0,
  isNew: isNew,
  status: status,
);

const Map<String, Object?> _created = {
  'id': 'st1',
  'url': 'https://img.test/st1.jpg',
  'caption': 'Sunset',
  'createdAt': '2026-11-09T11:00:00Z',
  'expiresAt': '2026-11-10T11:00:00Z',
  'viewCount': 0,
  'viewers': <Object?>[],
};

class _Api {
  _Api({bool limit = false, this.upload}) {
    var posted = false;
    api = FakeAdapter(
      {
        'POST /media/uploads': (
          201,
          {
            'id': 'm1',
            'uploadUrl': 'https://storage.test/m/m1',
            'headers': {'Content-Type': 'image/jpeg'},
            'expiresAt': '2026-11-09T12:05:00Z',
          },
        ),
        'POST /media/uploads/m1/complete': (
          200,
          {
            'id': 'm1',
            'kind': 'PHOTO',
            'privateOnly': false,
            'links': {
              'kind': 'PHOTO',
              'url': 'https://storage.test/full',
              'thumbUrl': 'https://storage.test/thumb',
              'width': 100,
              'height': 100,
              'expiresAt': '2026-11-09T12:10:00Z',
            },
          },
        ),
        'GET /profiles/p1/statuses': (200, <Object?>[]),
      },
      handlers: {
        'POST /me/statuses': (_) {
          if (limit) return (409, problem('status-limit', 409));
          posted = true;
          return (201, _created);
        },
        'GET /me/statuses': (_) => (200, posted ? [_created] : <Object?>[]),
      },
    );
    storage = FakeAdapter({'PUT https://storage.test/m/m1': (200, null)});
  }

  /// Replaces the HTTP upload when set.
  final MediaRepository? upload;

  late final FakeAdapter api;
  late final FakeAdapter storage;

  List<Override> get overrides => [
    mediaPickerProvider.overrideWithValue(_Picker()),
    mediaRepositoryProvider.overrideWithValue(
      upload ??
          ApiMediaRepository(
            dioWith(api),
            Dio()..httpClientAdapter = storage,
          ),
    ),
    statusRepositoryProvider.overrideWithValue(
      ApiStatusRepository(dioWith(api)),
    ),
  ];

  List<String> get calls => [
    for (final r in api.requests) '${r.method} ${r.path}',
  ];
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

Future<void> _openComposer(WidgetTester tester, _Api api) async {
  await pumpOrbit(tester, overrides: api.overrides);
  await onboard(tester);
  await tapText(tester, 'Me');
  await tester.tap(find.byTooltip('Add a status'));
  await tester.pumpAndSettle();
}

StatusRing _ringIn(WidgetTester tester, Finder within) => tester
    .widget<StatusRingFrame>(
      find
          .descendant(
            of: within,
            matching: find.byType(StatusRingFrame, skipOffstage: false),
            skipOffstage: false,
          )
          .first,
    )
    .ring;

Finder _tile(String id) => find.byKey(ValueKey(id));

void main() {
  testWidgets('posting a status uploads, posts and shows my ring', (
    tester,
  ) async {
    final api = _Api();
    await _openComposer(tester, api);
    expect(
      _ringIn(tester, find.byType(MeAvatar, skipOffstage: false)),
      StatusRing.none,
    );

    await tester.enterText(find.byType(TextField), 'Sunset');
    await tester.tap(find.widgetWithText(FilledButton, 'Post'));
    await tester.pumpAndSettle();

    final upload = api.api.requests.firstWhere(
      (r) => r.path == '/media/uploads' && r.method == 'POST',
    );
    expect((upload.data as Map)['purpose'], 'STATUS_PHOTO');
    final post = api.api.requests.firstWhere(
      (r) => r.path == '/me/statuses' && r.method == 'POST',
    );
    expect(post.data, {'mediaId': 'm1', 'caption': 'Sunset'});
    expect(find.text('New status'), findsNothing);
    expect(_ringIn(tester, find.byType(MeAvatar)), StatusRing.unseen);
  });

  testWidgets('caption stops at 100 characters', (tester) async {
    await _openComposer(tester, _Api());

    await tester.enterText(find.byType(TextField), 'x' * 120);
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text.length, 100);
    expect(find.text('100/100'), findsOneWidget);
  });

  testWidgets('the eleventh status shows the limit message', (tester) async {
    await _openComposer(tester, _Api(limit: true));

    await tester.tap(find.widgetWithText(FilledButton, 'Post'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'You can have 10 statuses at once. Delete one to post another.',
      ),
      findsOneWidget,
    );
    expect(find.text('New status'), findsNothing);
    expect(find.byKey(const ValueKey('status-posting')), findsNothing);
    expect(find.byType(MeAvatar), findsOneWidget);
  });

  testWidgets('grid tile with UNSEEN status shows a gradient ring; tapping '
      'the ring opens the viewer; tapping elsewhere opens the profile', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final api = _Api();
    await pumpOrbit(
      tester,
      profiles: _CountingProfiles([
        _member('p1', 'Sam', status: StatusRing.unseen),
      ]),
      overrides: api.overrides,
    );
    await onboard(tester);

    expect(_ringIn(tester, _tile('p1')), StatusRing.unseen);
    final painter =
        tester
                .widget<CustomPaint>(
                  find
                      .descendant(
                        of: find.descendant(
                          of: _tile('p1'),
                          matching: find.byType(StatusRingFrame),
                        ),
                        matching: find.byType(CustomPaint),
                      )
                      .first,
                )
                .foregroundPainter!
            as StatusRingPainter;
    expect(painter.colors, hasLength(2));
    expect(painter.colors.last, const Color(0xFFFF9F0A));
    expect(find.bySemanticsLabel(RegExp('has a new status')), findsWidgets);

    final ring = find.byKey(const ValueKey('status-ring-p1'));
    final size = tester.getSize(ring);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));

    await tester.tap(ring);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(StatusViewerScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(api.calls, contains('GET /profiles/p1/statuses'));
    expect(find.text('Message'), findsNothing);

    await tester.tapAt(tester.getCenter(_tile('p1')));
    await tester.pumpAndSettle();
    expect(find.text('Message'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('ring turns grey after viewing without a refetch', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final profiles = _CountingProfiles([
      _member('p1', 'Sam', status: StatusRing.unseen, isNew: true),
    ]);
    await pumpOrbit(tester, profiles: profiles, overrides: _Api().overrides);
    await onboard(tester);
    final fresh = find.byKey(const ValueKey('fresh-p1'));
    expect(_ringIn(tester, _tile('p1')), StatusRing.unseen);
    expect(_ringIn(tester, fresh), StatusRing.unseen);
    final fetches = profiles.nearbyCalls;

    _container(tester).read(seenStatusOwnersProvider.notifier).markSeen('p1');
    await tester.pump();

    expect(_ringIn(tester, _tile('p1')), StatusRing.seen);
    expect(_ringIn(tester, fresh), StatusRing.seen);
    expect(profiles.nearbyCalls, fetches);
    expect(find.bySemanticsLabel(RegExp('has a status')), findsWidgets);
    semantics.dispose();
  });

  testWidgets('profile header shows the ring and tapping it opens the viewer', (
    tester,
  ) async {
    final api = _Api();
    await pumpOrbit(
      tester,
      profiles: _CountingProfiles([
        _member('p1', 'Sam', status: StatusRing.unseen),
      ]),
      overrides: api.overrides,
    );
    await onboard(tester);
    await tapText(tester, 'Sam 30');

    final ring = find.byKey(const ValueKey('status-ring'));
    expect(_ringIn(tester, ring), StatusRing.unseen);

    await tester.tap(ring);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(StatusViewerScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(api.calls, contains('GET /profiles/p1/statuses'));
  });

  testWidgets('the Me avatar shows progress while posting, then the ring', (
    tester,
  ) async {
    final upload = _PendingUpload();
    await _openComposer(tester, _Api(upload: upload));

    await tester.tap(find.widgetWithText(FilledButton, 'Post'));
    // The spinner animates for as long as the upload is pending.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('New status'), findsNothing);
    expect(find.byKey(const ValueKey('status-posting')), findsOneWidget);
    expect(_ringIn(tester, find.byType(MeAvatar)), StatusRing.none);

    upload.result.complete(
      UploadedMedia(
        id: 'm1',
        links: MediaLinks(url: 'u', expiresAt: DateTime.utc(2026, 11, 10)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('status-posting')), findsNothing);
    expect(_ringIn(tester, find.byType(MeAvatar)), StatusRing.unseen);
  });
}

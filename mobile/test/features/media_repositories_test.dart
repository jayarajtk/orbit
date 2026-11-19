import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/albums/data/album_repository.dart';
import 'package:orbit/features/albums/domain/album.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/media/domain/media.dart';

import '../helpers/fake_api.dart';
import '../helpers/photo_bytes.dart';
import '../helpers/video_bytes.dart';

const Map<String, Object> _links = {
  'kind': 'PHOTO',
  'url': 'https://storage.test/full',
  'thumbUrl': 'https://storage.test/thumb',
  'width': 2048,
  'height': 1536,
  'expiresAt': '2026-11-18T12:10:00Z',
};

void main() {
  group('uploads', () {
    late FakeAdapter api;
    late FakeAdapter storage;
    late ApiMediaRepository repository;

    setUp(() {
      api = FakeAdapter({
        'POST /media/uploads': (
          201,
          {
            'id': 'm1',
            'uploadUrl': 'https://storage.test/m/m1/original?X-Amz-Signature=x',
            'headers': {'Content-Type': 'image/jpeg'},
            'expiresAt': '2026-11-18T12:05:00Z',
          },
        ),
        'POST /media/uploads/m1/complete': (
          200,
          {'id': 'm1', 'kind': 'PHOTO', 'privateOnly': false, 'links': _links},
        ),
      });
      storage = FakeAdapter({
        'PUT https://storage.test/m/m1/original?X-Amz-Signature=x': (200, null),
      });
      final apiDio = dioWith(api)
        ..options.headers['Authorization'] = 'Bearer t';
      repository = ApiMediaRepository(
        apiDio,
        Dio()..httpClientAdapter = storage,
      );
    });

    test('starts, puts the bytes to storage, then completes', () async {
      final photo = plainJpeg();
      final uploaded = await repository.upload(
        MediaPurpose.profilePhoto,
        photo,
        'image/jpeg',
      );

      expect(api.requests.first.data, {
        'purpose': 'PROFILE_PHOTO',
        'contentType': 'image/jpeg',
        'sizeBytes': photo.length,
      });
      final put = storage.requests.single;
      expect(put.headers['Content-Type'], 'image/jpeg');
      expect(put.headers[Headers.contentLengthHeader], photo.length);
      expect(storage.streamedBodies.single, photo);
      expect(put.headers.containsKey('Authorization'), isFalse);
      expect(uploaded.id, 'm1');
      expect(uploaded.links.thumbUrl, 'https://storage.test/thumb');
      expect(uploaded.links.aspectRatio, closeTo(4 / 3, 0.001));
    });

    test('photos leave the phone without location or other metadata', () async {
      final photo = pickerJpeg(orientation: 6);

      await repository.upload(MediaPurpose.chatPhoto, photo, 'image/jpeg');

      final sent = storage.streamedBodies.single;
      expect(sent.length, lessThan(photo.length));
      expect(latin1.decode(sent), isNot(contains('GPS')));
      expect(api.requests.first.data, containsPair('sizeBytes', sent.length));
      expect(
        storage.requests.single.headers[Headers.contentLengthHeader],
        sent.length,
      );
    });

    test('a photo that cannot be read is never sent', () async {
      await expectLater(
        repository.upload(
          MediaPurpose.albumPhoto,
          Uint8List.fromList(List.filled(10, 7)),
          'image/jpeg',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.status, 'status', 422)
              .having((e) => e.type, 'type', 'invalid-upload'),
        ),
      );
      expect(api.requests, isEmpty);
      expect(storage.requests, isEmpty);
    });

    test('video and voice leave the phone without location', () async {
      for (final purpose in [MediaPurpose.chatVideo, MediaPurpose.voiceNote]) {
        final video = locatedVideo();

        await repository.upload(
          purpose,
          video,
          'video/quicktime',
          durationMs: 1000,
        );

        final sent = storage.streamedBodies.last;
        expect(sent.length, video.length);
        expect(latin1.decode(sent), isNot(contains(location)));
      }
    });

    test('a video that cannot be read is never sent', () async {
      await expectLater(
        repository.upload(
          MediaPurpose.chatVideo,
          Uint8List(10),
          'video/mp4',
          durationMs: 1000,
        ),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 422)),
      );
      expect(storage.requests, isEmpty);
    });

    test('sends the length of video and voice when completing', () async {
      await repository.upload(
        MediaPurpose.voiceNote,
        plainVideo(),
        'audio/mp4',
        durationMs: 2500,
      );

      expect(api.requests.last.data, {'durationMs': 2500});
    });

    test('a refused file surfaces as an ApiException', () async {
      api.routes['POST /media/uploads/m1/complete'] = (
        422,
        problem('media-rejected', 422),
      );

      await expectLater(
        repository.upload(MediaPurpose.chatPhoto, plainJpeg(), 'image/jpeg'),
        throwsA(
          isA<ApiException>().having((e) => e.type, 'type', 'media-rejected'),
        ),
      );
    });
  });

  group('albums', () {
    test('reads albums with their grants', () async {
      final api = FakeAdapter({
        'GET /albums': (
          200,
          [
            {
              'id': 'a1',
              'name': 'Summer',
              'photoCount': 3,
              'grants': [
                {
                  'albumId': 'a1',
                  'granteeId': 'bob',
                  'expiresAt': '2026-11-19T12:00:00Z',
                  'viewOnce': true,
                  'viewedAt': null,
                },
              ],
            },
          ],
        ),
      });

      final albums = await ApiAlbumRepository(dioWith(api)).mine();

      expect(albums.single.name, 'Summer');
      expect(albums.single.isPrivate, isTrue);
      final grant = albums.single.grants.single;
      expect(grant.profileId, 'bob');
      expect(grant.viewOnce, isTrue);
      expect(grant.expiresAt, DateTime.utc(2026, 11, 19, 12));
    });

    test('removes a photo from an album', () async {
      final api = FakeAdapter({'DELETE /albums/a1/photos/m1': (204, null)});

      await ApiAlbumRepository(dioWith(api)).removePhoto('a1', 'm1');

      expect(api.requests.single.method, 'DELETE');
      expect(api.requests.single.path, '/albums/a1/photos/m1');
    });

    test('shares with the access the server understands', () async {
      final api = FakeAdapter({'PUT /albums/a1/grants/bob': (204, null)});

      await ApiAlbumRepository(
        dioWith(api),
      ).share('a1', 'bob', AlbumAccess.untilRevoked, viewOnce: false);

      expect(api.requests.single.data, {
        'access': 'UNTIL_REVOKED',
        'viewOnce': false,
      });
    });

    test('opens an album with photo links', () async {
      final api = FakeAdapter({
        'GET /albums/a1': (
          200,
          {
            'id': 'a1',
            'ownerId': 'alice',
            'name': 'Summer',
            'viewOnce': true,
            'expiresAt': null,
            'photos': [
              {'id': 'p1', 'links': _links},
            ],
          },
        ),
        'GET /albums/a2': (410, problem('view-once-opened', 410)),
      });
      final repository = ApiAlbumRepository(dioWith(api));

      final album = await repository.open('a1');

      expect(album.ownerId, 'alice');
      expect(album.viewOnce, isTrue);
      expect(album.photos.single.links.url, 'https://storage.test/full');
      await expectLater(
        repository.open('a2'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 410)),
      );
    });
  });
}

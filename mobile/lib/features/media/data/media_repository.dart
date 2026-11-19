import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app/env.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/media/data/photo_metadata.dart';
import 'package:orbit/features/media/data/video_metadata.dart';
import 'package:orbit/features/media/domain/media.dart';

/// Uploads media (design doc §7.4): the bytes go straight to storage through
/// a short-lived link, never through the API.
// An interface rather than a function typedef so tests can swap in a fake
// and media can grow (listing, deleting) without changing call sites.
// ignore: one_member_abstracts
abstract interface class MediaRepository {
  /// Uploads [bytes] of [contentType] for [purpose]. [durationMs] is required
  /// for video and voice. Every file loses its metadata (location
  /// included) before it leaves the phone. Throws [ApiException] when
  /// refused, including `invalid-upload` (422) for a file that cannot be
  /// read.
  Future<UploadedMedia> upload(
    MediaPurpose purpose,
    Uint8List bytes,
    String contentType, {
    int? durationMs,
  });
}

/// A plain client for presigned storage links: no base URL and, above all,
/// no Authorization header (the link carries its own signature).
final storageDioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(seconds: 30),
    ),
  ),
);

/// The media repository, or null in demo mode (no server to upload to).
final mediaRepositoryProvider = Provider<MediaRepository?>(
  (ref) => AppEnv.usesApi
      ? ApiMediaRepository(
          ref.watch(dioProvider),
          ref.watch(storageDioProvider),
        )
      : null,
);

/// [MediaRepository] on the Orbit API.
class ApiMediaRepository implements MediaRepository {
  /// Creates the repository.
  ApiMediaRepository(this._api, this._storage);

  final Dio _api;
  final Dio _storage;

  @override
  Future<UploadedMedia> upload(
    MediaPurpose purpose,
    Uint8List bytes,
    String contentType, {
    int? durationMs,
  }) async {
    final body = _withoutMetadata(purpose, bytes);
    final ticket = await guardApi(
      () => _api.post<Map<String, dynamic>>(
        '/media/uploads',
        data: {
          'purpose': purpose.apiValue,
          'contentType': contentType,
          'sizeBytes': body.length,
        },
      ),
    );
    final upload = ticket.data!;
    final headers = (upload['headers'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as String),
    );
    await guardApi(
      () => _storage.put<void>(
        upload['uploadUrl'] as String,
        data: Stream.fromIterable([body]),
        options: Options(
          headers: {...headers, Headers.contentLengthHeader: body.length},
        ),
      ),
    );
    final done = await guardApi(
      () => _api.post<Map<String, dynamic>>(
        '/media/uploads/${upload['id']}/complete',
        data: {'durationMs': ?durationMs},
      ),
    );
    final media = done.data!;
    return UploadedMedia(
      id: media['id'] as String,
      links: MediaLinks.fromJson(media['links'] as Map<String, dynamic>),
    );
  }

  /// The file without metadata. A file that can't be cleaned is refused the
  /// way the server refuses an unreadable one, rather than sent as it is.
  static Uint8List _withoutMetadata(MediaPurpose purpose, Uint8List file) {
    try {
      return purpose.isPhoto
          ? stripPhotoMetadata(file)
          : stripVideoMetadata(file);
    } on FormatException catch (e) {
      throw ApiException(
        status: 422,
        type: 'invalid-upload',
        detail: e.message,
      );
    }
  }
}

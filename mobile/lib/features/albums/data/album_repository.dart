import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app/env.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/albums/domain/album.dart';
import 'package:orbit/features/media/domain/media.dart';

/// A photo in an opened album.
class AlbumPhoto {
  /// Creates a photo.
  const AlbumPhoto({required this.id, required this.links});

  /// Media id.
  final String id;

  /// Short-lived links.
  final MediaLinks links;
}

/// An album as opened by its owner or a grantee.
class OpenedAlbum {
  /// Creates an opened album.
  const OpenedAlbum({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.photos,
    required this.viewOnce,
    this.expiresAt,
  });

  /// Album id.
  final String id;

  /// Who owns it.
  final String ownerId;

  /// Album name.
  final String name;

  /// Photos with links.
  final List<AlbumPhoto> photos;

  /// The caller can't open it again.
  final bool viewOnce;

  /// When the caller's access ends; null for the owner or no expiry.
  final DateTime? expiresAt;
}

/// An album someone shared with the user.
class SharedAlbum {
  /// Creates a shared album.
  const SharedAlbum({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.photoCount,
    required this.viewOnce,
    this.expiresAt,
  });

  /// Album id.
  final String id;

  /// Who shared it.
  final String ownerId;

  /// Album name.
  final String name;

  /// Number of photos.
  final int photoCount;

  /// Opens only once.
  final bool viewOnce;

  /// When access ends; null until revoked.
  final DateTime? expiresAt;
}

/// Private albums on the server.
abstract interface class AlbumRepository {
  /// The user's albums with their grants.
  Future<List<Album>> mine();

  /// Creates an album and returns its id.
  Future<String> create(String name);

  /// Adds the user's uploaded photo [mediaId].
  Future<void> addPhoto(String albumId, String mediaId);

  /// Shares [albumId] with [profileId].
  Future<void> share(
    String albumId,
    String profileId,
    AlbumAccess access, {
    required bool viewOnce,
  });

  /// Ends [profileId]'s access.
  Future<void> revoke(String albumId, String profileId);

  /// Albums shared with the user that can still be opened.
  Future<List<SharedAlbum>> sharedWithMe();

  /// Opens an album. Throws [ApiException] (404 no access, 410 already
  /// opened once).
  Future<OpenedAlbum> open(String albumId);
}

/// The album repository, or null in demo mode (albums stay in memory).
final albumRepositoryProvider = Provider<AlbumRepository?>(
  (ref) => AppEnv.usesApi ? ApiAlbumRepository(ref.watch(dioProvider)) : null,
);

/// [AlbumRepository] on the Orbit API.
class ApiAlbumRepository implements AlbumRepository {
  /// Creates the repository.
  ApiAlbumRepository(this._dio);

  final Dio _dio;

  static DateTime? _time(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  @override
  Future<List<Album>> mine() => guardApi(() async {
    final response = await _dio.get<List<dynamic>>('/albums');
    return [
      for (final a in response.data!.cast<Map<String, dynamic>>())
        Album(
          id: a['id'] as String,
          name: a['name'] as String,
          photoCount: (a['photoCount'] as num).toInt(),
          isPrivate: true,
          grants: [
            for (final g
                in (a['grants'] as List<dynamic>).cast<Map<String, dynamic>>())
              AlbumGrant(
                profileId: g['granteeId'] as String,
                expiresAt: _time(g['expiresAt']),
                viewOnce: g['viewOnce'] as bool,
              ),
          ],
        ),
    ];
  });

  @override
  Future<String> create(String name) => guardApi(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/albums',
      data: {'name': name},
    );
    return response.data!['id'] as String;
  });

  @override
  Future<void> addPhoto(String albumId, String mediaId) => guardApi(
    () =>
        _dio.post<void>('/albums/$albumId/photos', data: {'mediaId': mediaId}),
  );

  @override
  Future<void> share(
    String albumId,
    String profileId,
    AlbumAccess access, {
    required bool viewOnce,
  }) => guardApi(
    () => _dio.put<void>(
      '/albums/$albumId/grants/$profileId',
      data: {
        'access': switch (access) {
          AlbumAccess.day => 'DAY',
          AlbumAccess.week => 'WEEK',
          AlbumAccess.untilRevoked => 'UNTIL_REVOKED',
        },
        'viewOnce': viewOnce,
      },
    ),
  );

  @override
  Future<void> revoke(String albumId, String profileId) =>
      guardApi(() => _dio.delete<void>('/albums/$albumId/grants/$profileId'));

  @override
  Future<List<SharedAlbum>> sharedWithMe() => guardApi(() async {
    final response = await _dio.get<List<dynamic>>('/albums/shared-with-me');
    return [
      for (final a in response.data!.cast<Map<String, dynamic>>())
        SharedAlbum(
          id: a['id'] as String,
          ownerId: a['ownerId'] as String,
          name: a['name'] as String,
          photoCount: (a['photoCount'] as num).toInt(),
          viewOnce: a['viewOnce'] as bool,
          expiresAt: _time(a['expiresAt']),
        ),
    ];
  });

  @override
  Future<OpenedAlbum> open(String albumId) => guardApi(() async {
    final response = await _dio.get<Map<String, dynamic>>('/albums/$albumId');
    final a = response.data!;
    return OpenedAlbum(
      id: a['id'] as String,
      ownerId: a['ownerId'] as String,
      name: a['name'] as String,
      viewOnce: a['viewOnce'] as bool,
      expiresAt: _time(a['expiresAt']),
      photos: [
        for (final p
            in (a['photos'] as List<dynamic>).cast<Map<String, dynamic>>())
          AlbumPhoto(
            id: p['id'] as String,
            links: MediaLinks.fromJson(p['links'] as Map<String, dynamic>),
          ),
      ],
    );
  });
}

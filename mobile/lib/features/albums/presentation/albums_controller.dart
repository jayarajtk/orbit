import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/albums/data/album_repository.dart';
import 'package:orbit/features/albums/domain/album.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/media/domain/media.dart';

/// The user's albums: on the server in API mode, in memory in demo mode.
final albumsProvider = NotifierProvider<AlbumsController, List<Album>>(
  AlbumsController.new,
);

/// A photo being added to an album: waiting its turn, uploading, or failed.
class AlbumUpload {
  /// Creates an upload tile state.
  const AlbumUpload({
    required this.localId,
    required this.preview,
    this.progress = 0,
    this.failed = false,
  });

  /// Identifies the tile on this phone; not a server id.
  final String localId;

  /// The picked photo, shown while it uploads.
  final Uint8List preview;

  /// 0 while waiting or uploading, 0.5 once uploaded and being attached, 1
  /// when attached.
  final double progress;

  /// Whether the photo is attached to the album and only waits for the
  /// album screen to show it.
  bool get done => progress >= 1;

  /// The upload or the attach was refused; the tile offers a retry.
  final bool failed;

  /// A copy with [progress] and [failed] replaced.
  AlbumUpload copyWith({double? progress, bool? failed}) => AlbumUpload(
    localId: localId,
    preview: preview,
    progress: progress ?? this.progress,
    failed: failed ?? this.failed,
  );
}

/// Photos on their way into each album, by album id, in picked order.
final albumUploadsProvider =
    NotifierProvider<AlbumUploadsController, Map<String, List<AlbumUpload>>>(
      AlbumUploadsController.new,
    );

/// Holds the upload tiles of albums being added to.
class AlbumUploadsController extends Notifier<Map<String, List<AlbumUpload>>> {
  @override
  Map<String, List<AlbumUpload>> build() => const {};

  /// The tiles of [albumId], oldest first.
  List<AlbumUpload> of(String albumId) => state[albumId] ?? const [];

  /// Appends [uploads] to [albumId].
  void add(String albumId, List<AlbumUpload> uploads) => state = {
    ...state,
    albumId: [...of(albumId), ...uploads],
  };

  /// Replaces the tile [localId] of [albumId] with [change] applied.
  void update(
    String albumId,
    String localId,
    AlbumUpload Function(AlbumUpload) change,
  ) => state = {
    ...state,
    albumId: [
      for (final u in of(albumId))
        if (u.localId == localId) change(u) else u,
    ],
  };

  /// Drops the tile [localId] of [albumId].
  void remove(String albumId, String localId) => state = {
    ...state,
    albumId: [
      for (final u in of(albumId))
        if (u.localId != localId) u,
    ],
  };
}

/// Holds albums and their sharing grants.
class AlbumsController extends Notifier<List<Album>> {
  final Map<String, PickedMedia> _picked = {};
  int _nextTile = 0;

  AlbumRepository? get _api => ref.read(albumRepositoryProvider);

  @override
  List<Album> build() {
    if (ref.watch(albumRepositoryProvider) != null) {
      unawaited(load());
      return const [];
    }
    return const [
      Album(id: 'a1', name: 'Travel', photoCount: 12, isPrivate: false),
      Album(id: 'a2', name: 'Private', photoCount: 5, isPrivate: true),
    ];
  }

  /// Reloads from the server (API mode only). Keeps the current list if it
  /// can't be reached.
  Future<void> load() async {
    final api = _api;
    if (api == null) return;
    try {
      final albums = await api.mine();
      if (ref.mounted) state = albums;
    } on ApiException {
      // Shown again from the current list; the next load retries.
    }
  }

  /// Creates an album (API mode). Throws [ApiException].
  Future<String> create(String name) async {
    final id = await _api!.create(name.trim());
    await load();
    return id;
  }

  /// Uploads [photos] to [albumId] one at a time in the order given (API
  /// mode), reporting each on [albumUploadsProvider]. A photo that fails
  /// stays as a failed tile and the rest carry on.
  Future<void> addPhotos(String albumId, List<PickedMedia> photos) async {
    final uploads = ref.read(albumUploadsProvider.notifier);
    final tiles = [
      for (final photo in photos)
        AlbumUpload(localId: 'upload-${_nextTile++}', preview: photo.bytes),
    ];
    for (final (i, tile) in tiles.indexed) {
      _picked[tile.localId] = photos[i];
    }
    uploads.add(albumId, tiles);
    for (final tile in tiles) {
      if (!ref.mounted) return;
      await _send(albumId, tile.localId);
    }
  }

  /// Tries a failed upload of [albumId] again.
  Future<void> retryUpload(String albumId, String localId) =>
      _send(albumId, localId);

  /// Drops the upload tile [localId] of [albumId] and its photo.
  void discardUpload(String albumId, String localId) {
    _picked.remove(localId);
    ref.read(albumUploadsProvider.notifier).remove(albumId, localId);
  }

  Future<void> _send(String albumId, String localId) async {
    final photo = _picked[localId];
    if (photo == null) return;
    final uploads = ref.read(albumUploadsProvider.notifier)
      ..update(
        albumId,
        localId,
        (u) => u.copyWith(progress: 0, failed: false),
      );
    try {
      final uploaded = await ref
          .read(mediaRepositoryProvider)!
          .upload(MediaPurpose.albumPhoto, photo.bytes, photo.contentType);
      if (!ref.mounted) return;
      uploads.update(albumId, localId, (u) => u.copyWith(progress: 0.5));
      await _api!.addPhoto(albumId, uploaded.id);
    } on ApiException {
      if (ref.mounted) {
        uploads.update(albumId, localId, (u) => u.copyWith(failed: true));
      }
      return;
    }
    if (!ref.mounted) return;
    _picked.remove(localId);
    // The tile stays, done, until the album screen shows the photo in its
    // place and drops it; see [AlbumUpload.done].
    uploads.update(albumId, localId, (u) => u.copyWith(progress: 1));
    await load();
  }

  /// Removes [mediaIds] from [albumId] one by one (API mode). Stops at the
  /// first refusal and throws it, after reloading what was removed. Throws
  /// [ApiException].
  Future<void> removePhotos(String albumId, List<String> mediaIds) async {
    try {
      for (final id in mediaIds) {
        await _api!.removePhoto(albumId, id);
      }
    } finally {
      if (ref.mounted) await load();
    }
  }

  /// Shares [albumId] with [profileId], replacing any earlier grant. Throws
  /// [ApiException] in API mode.
  Future<void> share({
    required String albumId,
    required String profileId,
    required AlbumAccess access,
    required bool viewOnce,
  }) async {
    final api = _api;
    if (api != null) {
      await api.share(albumId, profileId, access, viewOnce: viewOnce);
      await load();
      return;
    }
    final duration = access.duration;
    final expiresAt = duration == null
        ? null
        : ref.read(clockProvider)().add(duration);
    _update(albumId, (album) {
      return album.withGrants([
        for (final g in album.grants)
          if (g.profileId != profileId) g,
        AlbumGrant(
          profileId: profileId,
          expiresAt: expiresAt,
          viewOnce: viewOnce,
        ),
      ]);
    });
  }

  /// Revokes [profileId]'s access to [albumId]. Throws [ApiException] in API
  /// mode.
  Future<void> revoke({
    required String albumId,
    required String profileId,
  }) async {
    final api = _api;
    if (api != null) await api.revoke(albumId, profileId);
    _update(
      albumId,
      (album) => album.withGrants([
        for (final g in album.grants)
          if (g.profileId != profileId) g,
      ]),
    );
  }

  void _update(String albumId, Album Function(Album) change) {
    state = [
      for (final album in state)
        if (album.id == albumId) change(album) else album,
    ];
  }
}

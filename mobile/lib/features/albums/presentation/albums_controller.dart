import 'dart:async';

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

/// Holds albums and their sharing grants.
class AlbumsController extends Notifier<List<Album>> {
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

  /// Uploads [photo] and adds it to [albumId] (API mode). Throws
  /// [ApiException].
  Future<void> addPhoto(String albumId, PickedMedia photo) async {
    final uploaded = await ref
        .read(mediaRepositoryProvider)!
        .upload(MediaPurpose.albumPhoto, photo.bytes, photo.contentType);
    await _api!.addPhoto(albumId, uploaded.id);
    await load();
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

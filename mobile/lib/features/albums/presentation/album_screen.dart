import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/core/widgets/media_image.dart';
import 'package:orbit/core/widgets/photo_viewer.dart';
import 'package:orbit/features/albums/data/album_repository.dart';
import 'package:orbit/features/albums/presentation/albums_controller.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Albums shared with the user (API mode).
final FutureProvider<List<SharedAlbum>> sharedAlbumsProvider =
    FutureProvider.autoDispose<List<SharedAlbum>>(
      (ref) =>
          ref.watch(albumRepositoryProvider)?.sharedWithMe() ??
          Future.value([]),
    );

/// One album's photos. Opened once when the screen appears: for a view-once
/// share that single opening is all the viewer gets.
class AlbumScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [albumId].
  const AlbumScreen({required this.albumId, super.key});

  /// Album to open.
  final String albumId;

  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  OpenedAlbum? _album;
  bool _failed = false;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final album = await ref
          .read(albumRepositoryProvider)!
          .open(widget.albumId);
      if (mounted) setState(() => _album = album);
    } on ApiException {
      if (mounted) setState(() => _failed = true);
    }
  }

  bool get _mine =>
      ref.watch(albumsProvider).any((album) => album.id == widget.albumId);

  Future<void> _add() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final photo = await ref.read(mediaPickerProvider).pickPhoto(camera: false);
    if (photo == null || !mounted) return;
    setState(() => _adding = true);
    try {
      await ref.read(albumsProvider.notifier).addPhoto(widget.albumId, photo);
      await _open();
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.status == 422 ? l10n.uploadFailed : l10n.actionFailed,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final album = _album;
    return Scaffold(
      appBar: AppBar(title: Text(album?.name ?? '')),
      floatingActionButton: album != null && _mine
          ? FloatingActionButton.extended(
              onPressed: _adding ? null : _add,
              icon: _adding
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo_outlined),
              label: Text(l10n.addPhoto),
            )
          : null,
      body: _failed
          ? Center(child: Text(l10n.albumGone))
          : album == null
          ? const Center(child: CircularProgressIndicator())
          : album.photos.isEmpty
          ? Center(child: Text(l10n.albumEmpty))
          : GridView.count(
              crossAxisCount: 3,
              padding: const EdgeInsets.all(4),
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              children: [
                for (final (index, photo) in album.photos.indexed)
                  Semantics(
                    button: true,
                    label: l10n.photoMessage,
                    child: GestureDetector(
                      onTap: () => openPhotos(
                        context,
                        [
                          for (final p in album.photos)
                            PhotoViewerItem(
                              mediaId: p.id,
                              url: p.links.url,
                              thumbUrl: p.links.thumbUrl,
                              cache: !album.viewOnce,
                              ownerId: album.ownerId,
                            ),
                        ],
                        initialIndex: index,
                        heroTag: 'album-photo:${photo.id}',
                      ),
                      child: Hero(
                        tag: 'album-photo:${photo.id}',
                        child: MediaImage(
                          mediaId: photo.id,
                          url: photo.links.thumbUrl ?? photo.links.url,
                          variant: photo.links.thumbUrl == null
                              ? MediaVariant.full
                              : MediaVariant.thumb,
                          cache: !album.viewOnce,
                          ownerId: album.ownerId,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

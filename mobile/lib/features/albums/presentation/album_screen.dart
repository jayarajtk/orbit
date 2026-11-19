import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app/theme.dart';
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
  bool _deleting = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  /// Loads the album. Upload tiles whose photo was already attached when
  /// the request started are dropped in the same frame the album arrives, so
  /// each tile is replaced by its photo in place. A failed reload keeps the
  /// album on screen; only the first load can show "album gone".
  Future<void> _open() async {
    final shown = [
      for (final u
          in ref.read(albumUploadsProvider)[widget.albumId] ??
              const <AlbumUpload>[])
        if (u.done) u.localId,
    ];
    try {
      final album = await ref
          .read(albumRepositoryProvider)!
          .open(widget.albumId);
      if (!mounted) return;
      setState(() => _album = album);
      final controller = ref.read(albumsProvider.notifier);
      for (final id in shown) {
        controller.discardUpload(widget.albumId, id);
      }
    } on ApiException {
      if (mounted && _album == null) setState(() => _failed = true);
    }
  }

  bool get _mine =>
      ref.watch(albumsProvider).any((album) => album.id == widget.albumId);

  bool get _selecting => _selected.isNotEmpty;

  Future<void> _add() async {
    final photos = await ref.read(mediaPickerProvider).pickPhotos();
    if (photos.isEmpty || !mounted) return;
    unawaited(
      ref.read(albumsProvider.notifier).addPhotos(widget.albumId, photos),
    );
  }

  void _toggle(String mediaId) => setState(() {
    if (!_selected.remove(mediaId)) _selected.add(mediaId);
  });

  Future<void> _deleteSelected(OpenedAlbum album) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ids = [
      for (final p in album.photos)
        if (_selected.contains(p.id)) p.id,
    ];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deletePhotosTitle(ids.length)),
        content: Text(l10n.deletePhotosBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(albumsProvider.notifier).removePhotos(widget.albumId, ids);
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    }
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _deleting = false;
    });
    await _open();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final album = _album;
    final mine = _mine;
    final uploads = ref.watch(albumUploadsProvider)[widget.albumId] ?? const [];
    // A finished upload is now on the server: fetch it, then swap its tile.
    ref.listen(
      albumUploadsProvider.select(
        (all) => all[widget.albumId]?.where((u) => u.done).length ?? 0,
      ),
      (previous, next) {
        if (next > (previous ?? 0)) unawaited(_open());
      },
    );
    final busy = uploads.any((u) => !u.failed);
    final photos = album?.photos ?? const <AlbumPhoto>[];

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _selecting
              ? IconButton(
                  tooltip: l10n.clearSelection,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(_selected.clear),
                )
              : null,
          title: _selecting
              ? Semantics(
                  liveRegion: true,
                  child: Text(l10n.selectedCount(_selected.length)),
                )
              : Text(album?.name ?? ''),
          actions: [
            if (_selecting && album != null)
              IconButton(
                tooltip: l10n.deleteAction,
                icon: const Icon(Icons.delete_outline),
                onPressed: _deleting ? null : () => _deleteSelected(album),
              ),
          ],
        ),
        floatingActionButton: album != null && mine && !_selecting
            ? FloatingActionButton.extended(
                onPressed: busy ? null : _add,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(l10n.addPhotos),
              )
            : null,
        body: _failed
            ? Center(child: Text(l10n.albumGone))
            : album == null
            ? const Center(child: CircularProgressIndicator())
            : photos.isEmpty && uploads.isEmpty
            ? Center(child: Text(l10n.albumEmpty))
            : GridView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 1,
                  crossAxisSpacing: 1,
                ),
                itemCount: photos.length + uploads.length,
                itemBuilder: (context, i) {
                  if (i >= photos.length) {
                    final upload = uploads[i - photos.length];
                    return _UploadTile(
                      key: ValueKey('upload-tile-${upload.localId}'),
                      upload: upload,
                      onRetry: () => unawaited(
                        ref
                            .read(albumsProvider.notifier)
                            .retryUpload(widget.albumId, upload.localId),
                      ),
                      onDiscard: () => ref
                          .read(albumsProvider.notifier)
                          .discardUpload(widget.albumId, upload.localId),
                    );
                  }
                  final photo = photos[i];
                  return _PhotoTile(
                    key: ValueKey('album-tile-${photo.id}'),
                    album: album,
                    index: i,
                    selecting: _selecting,
                    selected: _selected.contains(photo.id),
                    onToggle: () => _toggle(photo.id),
                    onSelect: mine && !_deleting
                        ? () => _toggle(photo.id)
                        : null,
                  );
                },
              ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.album,
    required this.index,
    required this.selecting,
    required this.selected,
    required this.onToggle,
    required this.onSelect,
    super.key,
  });

  final OpenedAlbum album;
  final int index;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;

  /// Starts or extends a selection; null when the viewer may not select.
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final photo = album.photos[index];
    final heroTag = 'album-photo:${photo.id}';
    return Semantics(
      button: true,
      selected: selected,
      label: l10n.photoOf(index + 1, album.photos.length),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selecting
            ? onToggle
            : () => openPhotos(
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
                heroTag: heroTag,
              ),
        onLongPress: selecting ? null : onSelect,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: heroTag,
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
            if (selected)
              ColoredBox(color: tokens.accent.withValues(alpha: 0.3)),
            if (selecting)
              Positioned(
                top: 6,
                right: 6,
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? tokens.accent : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? tokens.accent
                            : Colors.white, // photo-overlay
                        width: 2,
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: 22,
                      child: selected
                          ? Icon(Icons.check, size: 16, color: tokens.ground)
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.upload,
    required this.onRetry,
    required this.onDiscard,
    super.key,
  });

  final AlbumUpload upload;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = context.tokens;
    final preview = ExcludeSemantics(
      child: Image.memory(
        upload.preview,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            ColoredBox(color: tokens.surfaceRaised),
      ),
    );
    const scrim = ColoredBox(
      color: Color(0x73000000), // photo-overlay
    );
    if (upload.failed) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            button: true,
            label: l10n.uploadFailedRetry,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  preview,
                  scrim,
                  const ExcludeSemantics(
                    child: Center(
                      child: Icon(
                        Icons.refresh,
                        color: Colors.white, // photo-overlay
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: l10n.discardUpload,
              color: Colors.white, // photo-overlay
              icon: const Icon(Icons.close),
              onPressed: onDiscard,
            ),
          ),
        ],
      );
    }
    return Semantics(
      label: l10n.uploadingPhoto,
      child: Stack(
        fit: StackFit.expand,
        children: [
          preview,
          scrim,
          ExcludeSemantics(
            child: Center(
              child: SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  value: upload.progress == 0 ? null : upload.progress,
                  color: Colors.white, // photo-overlay
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

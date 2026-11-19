import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/profile/presentation/my_photos_actions.dart';
import 'package:orbit/features/profile/presentation/my_profile_controller.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// The member's public photos: add from the library, remove, reorder (the
/// first is the main photo), tap to open. Changes are
/// saved at once (separately from the profile form). Shown only when there
/// is a server to upload to.
class PhotoEditor extends ConsumerStatefulWidget {
  /// Creates the editor.
  const PhotoEditor({super.key});

  /// Public photos per member (the server enforces the same limit).
  static const maxPhotos = 6;

  @override
  ConsumerState<PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends ConsumerState<PhotoEditor> {
  bool _busy = false;

  Future<void> _add() async {
    final picked = await ref.read(mediaPickerProvider).pickPhoto(camera: false);
    if (picked == null || !mounted) return;
    await _run(() => ref.read(myPhotosActionsProvider).add(picked));
  }

  Future<void> _remove(ProfilePhoto photo) =>
      _run(() => ref.read(myPhotosActionsProvider).delete(photo.id));

  Future<void> _reorder(int from, int to) =>
      _run(() => ref.read(myPhotosActionsProvider).reorder(from, to));

  void _open(int index) => context.push('${AppRoutes.myPhotos}?index=$index');

  /// Runs [change] with the buttons disabled; a refusal shows a snackbar.
  Future<void> _run(Future<void> Function() change) async {
    setState(() => _busy = true);
    try {
      await runPhotoAction(context, change);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final photos = ref.watch(myProfileProvider.select((p) => p?.photos ?? []));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.photosTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(l10n.photosHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final (index, photo) in photos.indexed)
              _PhotoTile(
                key: ValueKey(photo.id),
                photo: photo,
                index: index,
                total: photos.length,
                enabled: !_busy,
                onOpen: _open,
                onRemove: _remove,
                onMove: _reorder,
              ),
            if (photos.length < PhotoEditor.maxPhotos)
              _AddTile(busy: _busy, onAdd: _add),
          ],
        ),
      ],
    );
  }
}

/// A photo in the grid: tap opens it, press and hold then drag onto another
/// photo moves it there.
class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.index,
    required this.total,
    required this.enabled,
    required this.onOpen,
    required this.onRemove,
    required this.onMove,
    super.key,
  });

  final ProfilePhoto photo;
  final int index;
  final int total;
  final bool enabled;
  final void Function(int index) onOpen;
  final Future<void> Function(ProfilePhoto) onRemove;
  final Future<void> Function(int from, int to) onMove;

  bool get _isMain => index == 0;

  Widget _image() => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: Image.network(
      photo.thumbUrl ?? photo.url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const ColoredBox(color: Colors.black12), // photo-overlay
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = _isMain
        ? l10n.photoTileMain(index + 1, total)
        : l10n.photoOf(index + 1, total);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tile = SizedBox.fromSize(
          size: constraints.biggest,
          child: _image(),
        );
        return DragTarget<int>(
          onWillAcceptWithDetails: (details) =>
              enabled && details.data != index,
          onAcceptWithDetails: (details) => onMove(details.data, index),
          builder: (context, candidates, rejected) {
            final hovered = candidates.isNotEmpty;
            return Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  container: true,
                  button: true,
                  label: label,
                  hint: l10n.photoReorderHint,
                  onTap: () => onOpen(index),
                  child: LongPressDraggable<int>(
                    data: index,
                    maxSimultaneousDrags: enabled ? 1 : 0,
                    feedback: Opacity(opacity: 0.85, child: tile),
                    childWhenDragging: Opacity(opacity: 0.3, child: tile),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onOpen(index),
                      child: DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: hovered
                              ? Border.all(
                                  color: theme.colorScheme.primary,
                                  width: 3,
                                )
                              : null,
                        ),
                        child: _image(),
                      ),
                    ),
                  ),
                ),
                if (_isMain)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Text(
                            l10n.photoMain,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                    tooltip: l10n.removePhoto,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: enabled ? () => onRemove(photo) : null,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.busy, required this.onAdd});

  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : onAdd,
        child: Center(
          child: busy
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_a_photo_outlined),
                    const SizedBox(height: 4),
                    Text(l10n.photoAdd),
                  ],
                ),
        ),
      ),
    );
  }
}

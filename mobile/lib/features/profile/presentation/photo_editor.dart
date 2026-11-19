import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/media/data/media_repository.dart';
import 'package:orbit/features/media/domain/media.dart';
import 'package:orbit/features/profile/data/account_repository.dart';
import 'package:orbit/features/profile/presentation/my_profile_controller.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// The member's public photos: add from the library, remove. Changes are
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

  List<ProfilePhoto> get _photos => ref.read(myProfileProvider)?.photos ?? [];

  Future<void> _add() async {
    final picked = await ref.read(mediaPickerProvider).pickPhoto(camera: false);
    if (picked == null || !mounted) return;
    await _run(() async {
      final media = ref.read(mediaRepositoryProvider)!;
      final uploaded = await media.upload(
        MediaPurpose.profilePhoto,
        picked.bytes,
        picked.contentType,
      );
      return [for (final p in _photos) p.id, uploaded.id];
    });
  }

  Future<void> _remove(ProfilePhoto photo) => _run(
    () async => [
      for (final p in _photos)
        if (p.id != photo.id) p.id,
    ],
  );

  /// Runs [change] to get the new photo order, then saves it.
  Future<void> _run(Future<List<String>> Function() change) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final ids = await change();
      final saved = await ref.read(accountRepositoryProvider).setPhotos(ids);
      ref.read(myProfileProvider.notifier).save(saved);
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.status == 422 ? l10n.uploadFailed : l10n.actionFailed,
          ),
        ),
      );
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
            for (final photo in photos) _PhotoTile(photo, onRemove: _remove),
            if (photos.length < PhotoEditor.maxPhotos)
              _AddTile(busy: _busy, onAdd: _add),
          ],
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile(this.photo, {required this.onRemove});

  final ProfilePhoto photo;
  final Future<void> Function(ProfilePhoto) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            photo.thumbUrl ?? photo.url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const ColoredBox(color: Colors.black12),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton.filledTonal(
            tooltip: l10n.removePhoto,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => onRemove(photo),
          ),
        ),
      ],
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
                    Text(l10n.addPhoto),
                  ],
                ),
        ),
      ),
    );
  }
}

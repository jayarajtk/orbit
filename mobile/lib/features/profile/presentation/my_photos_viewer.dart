import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/core/widgets/glass_icon_button.dart';
import 'package:orbit/core/widgets/photo_viewer.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/media/data/media_capture.dart';
import 'package:orbit/features/profile/presentation/me_screen.dart';
import 'package:orbit/features/profile/presentation/my_photos_actions.dart';
import 'package:orbit/features/profile/presentation/my_profile_controller.dart';
import 'package:orbit/features/profile/presentation/photo_editor.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// The member's own photos full screen, with add, replace, make main and
/// delete under the photo. Changes are saved at once.
class MyPhotosViewer extends ConsumerStatefulWidget {
  /// Creates the viewer, opening on [initialIndex].
  const MyPhotosViewer({this.initialIndex = 0, super.key});

  /// Photo shown first.
  final int initialIndex;

  @override
  ConsumerState<MyPhotosViewer> createState() => _MyPhotosViewerState();
}

class _MyPhotosViewerState extends ConsumerState<MyPhotosViewer> {
  bool _busy = false;

  // The pager keeps its own page, so after a change the viewer is rebuilt
  // (a new generation) on the page that should show.
  int _generation = 0;
  late int _start = widget.initialIndex;

  void _showPage(int index) => setState(() {
    _generation++;
    _start = index;
  });

  /// Runs [change] with a progress overlay and, once it is saved, shows
  /// the page [pageAfter] picks from the new photo count. A refusal shows a
  /// snackbar and leaves the viewer as it was.
  Future<void> _run(
    Future<void> Function() change,
    int Function(int count) pageAfter,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await change();
    } on ApiException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.status == 422 ? l10n.uploadFailed : l10n.actionFailed,
          ),
        ),
      );
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    final count = ref.read(myProfileProvider)?.photos.length ?? 0;
    if (count == 0) {
      navigator.pop();
      return;
    }
    _showPage(pageAfter(count));
  }

  Future<void> _add() async {
    final picked = await ref.read(mediaPickerProvider).pickPhoto(camera: false);
    if (picked == null || !mounted) return;
    await _run(
      () => ref.read(myPhotosActionsProvider).add(picked),
      (count) => count - 1,
    );
  }

  Future<void> _replace(ProfilePhoto photo, int index) async {
    final picked = await ref.read(mediaPickerProvider).pickPhoto(camera: false);
    if (picked == null || !mounted) return;
    await _run(
      () => ref.read(myPhotosActionsProvider).replace(photo.id, picked),
      (_) => index,
    );
  }

  Future<void> _makeMain(ProfilePhoto photo) => _run(
    () => ref.read(myPhotosActionsProvider).makeMain(photo.id),
    (_) => 0,
  );

  Future<void> _delete(ProfilePhoto photo, int index, int total) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteDialog(isOnlyPhoto: total == 1),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      () => ref.read(myPhotosActionsProvider).delete(photo.id),
      (count) => index.clamp(0, count - 1),
    );
  }

  Widget _bottomBar(
    BuildContext context,
    int index,
    List<ProfilePhoto> photos,
  ) {
    final l10n = AppLocalizations.of(context);
    if (index >= photos.length) return const SizedBox.shrink();
    final photo = photos[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (photos.length < PhotoEditor.maxPhotos)
            GlassIconButton(
              icon: Icons.add_a_photo_outlined,
              tooltip: l10n.photoAdd,
              onPressed: _add,
            ),
          GlassIconButton(
            icon: Icons.swap_horiz,
            tooltip: l10n.photoReplace,
            onPressed: () => _replace(photo, index),
          ),
          if (index > 0)
            GlassIconButton(
              icon: Icons.star_outline,
              tooltip: l10n.photoMakeMain,
              onPressed: () => _makeMain(photo),
            ),
          GlassIconButton(
            icon: Icons.delete_outline,
            tooltip: l10n.photoDelete,
            onPressed: () => _delete(photo, index, photos.length),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(myProfileProvider.select((p) => p?.photos ?? []));
    if (photos.isEmpty) return const Scaffold(backgroundColor: Colors.black);
    return Stack(
      fit: StackFit.expand,
      children: [
        PhotoViewer(
          key: ValueKey(_generation),
          items: [
            for (final photo in photos)
              PhotoViewerItem(
                mediaId: photo.id,
                url: photo.url,
                thumbUrl: photo.thumbUrl,
              ),
          ],
          initialIndex: _start.clamp(0, photos.length - 1),
          heroTag: _generation == 0 && _start == 0 ? myMainPhotoHeroTag : null,
          bottomBar: (context, index) => _bottomBar(context, index, photos),
        ),
        if (_busy)
          const Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Colors.black38, // photo-overlay
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.isOnlyPhoto});

  final bool isOnlyPhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.photoDeleteConfirm),
      content: isOnlyPhoto ? Text(l10n.photoDeleteLastWarning) : null,
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
    );
  }
}

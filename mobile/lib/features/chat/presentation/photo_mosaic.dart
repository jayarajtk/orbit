import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/app/theme.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/core/widgets/media_image.dart';
import 'package:orbit/core/widgets/photo_viewer.dart';
import 'package:orbit/features/chat/domain/message.dart';
import 'package:orbit/features/chat/presentation/message_media.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Photos shown as tiles; any more are counted on the last tile.
const _visibleTiles = 4;

const _gap = 2.0;
const _width = 240.0;

/// Several photos sent together, as a grid of up to four tiles. When there
/// are more, the last tile says how many are hidden. Tapping a tile opens
/// every photo in the shared viewer at that one.
class PhotoMosaic extends ConsumerWidget {
  /// Creates a mosaic of [photos] (at least two) in the chat with
  /// [profileId].
  const PhotoMosaic({required this.profileId, required this.photos, super.key});

  /// The other member.
  final String profileId;

  /// The photos, oldest first.
  final List<Message> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = photos.take(_visibleTiles).toList();
    final hidden = photos.length - shown.length;

    Widget tile(int index, {required double height, required double width}) =>
        SizedBox(
          width: width,
          height: height,
          child: _Tile(
            profileId: profileId,
            message: shown[index],
            label: AppLocalizations.of(
              context,
            ).photoTileLabel(index + 1, photos.length),
            hiddenCount: index == _visibleTiles - 1 ? hidden : 0,
            onTap: () => _open(context, ref, index),
          ),
        );

    const half = (_width - _gap) / 2;
    return SizedBox(
      width: _width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shown.length == 3)
            tile(0, height: half, width: _width)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                tile(0, height: half, width: half),
                const SizedBox(width: _gap),
                tile(1, height: half, width: half),
              ],
            ),
          if (shown.length > 2) ...[
            const SizedBox(height: _gap),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                tile(shown.length - 2, height: half, width: half),
                const SizedBox(width: _gap),
                tile(shown.length - 1, height: half, width: half),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Fetches links for every photo, then opens the viewer at the photo at
  /// [index]. Photos whose links can't be fetched are left out.
  Future<void> _open(BuildContext context, WidgetRef ref, int index) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final holds = <ProviderSubscription<Object?>>[];
    final items = <PhotoViewerItem?>[];
    try {
      for (final photo in photos) {
        final mediaId = photo.mediaId;
        if (mediaId == null) {
          items.add(null);
          continue;
        }
        final provider = messageMediaProvider((profileId, photo.id));
        holds.add(ref.listenManual(provider, (_, _) {}));
        try {
          final links = await ref.read(provider.future);
          items.add(
            PhotoViewerItem(
              mediaId: mediaId,
              url: links.url,
              thumbUrl: links.thumbUrl,
              ownerId: profileId,
            ),
          );
        } on ApiException {
          items.add(null);
        }
      }
    } finally {
      for (final hold in holds) {
        hold.close();
      }
    }
    final available = items.whereType<PhotoViewerItem>().toList();
    if (!context.mounted) return;
    if (items[index] == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.mediaUnavailable)));
      return;
    }
    await openPhotos(
      context,
      available,
      initialIndex: items.take(index).whereType<PhotoViewerItem>().length,
      heroTag: 'chat-photo:${photos[index].id}',
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({
    required this.profileId,
    required this.message,
    required this.label,
    required this.hiddenCount,
    required this.onTap,
  });

  final String profileId;
  final Message message;
  final String label;
  final int hiddenCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final mediaId = message.mediaId;
    final links = mediaId == null
        ? null
        : ref.watch(messageMediaProvider((profileId, message.id)));
    final image = switch (links) {
      AsyncData(:final value) when mediaId != null => Hero(
        tag: 'chat-photo:${message.id}',
        child: MediaImage(
          mediaId: mediaId,
          url: value.thumbUrl ?? value.url,
          variant: value.thumbUrl == null
              ? MediaVariant.full
              : MediaVariant.thumb,
          ownerId: profileId,
        ),
      ),
      AsyncError() => Icon(
        Icons.broken_image_outlined,
        color: tokens.textMuted,
      ),
      _ => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    };
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: tokens.surfaceRaised,
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                if (hiddenCount > 0)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.5), // photo-overlay
                    child: Center(
                      child: Text(
                        '+$hiddenCount',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white, // photo-overlay
                            ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which rendition of a media object an image shows.
enum MediaVariant {
  /// The small image for lists and grids.
  thumb,

  /// The full-size image.
  full,
}

/// The disk-cache key for [mediaId] in [variant]. The server's signed URLs
/// change on every request, so the URL must never be part of the key.
String mediaCacheKey(String mediaId, MediaVariant variant) =>
    '$mediaId:${variant.name}';

/// The on-disk image cache. Remembers which cached keys belong to which
/// member (in memory only) so a blocked member's images can be removed.
class OrbitImageCache {
  /// Creates the cache over [manager], or the shared default one.
  OrbitImageCache({BaseCacheManager? manager})
    : manager = manager ?? DefaultCacheManager();

  /// The store that [CachedNetworkImage] reads and writes.
  final BaseCacheManager manager;

  final Map<String, Set<String>> _keysByOwner = {};

  /// Remembers that [ownerId]'s images are cached under [keys].
  void register(String ownerId, Iterable<String> keys) =>
      _keysByOwner.putIfAbsent(ownerId, () => {}).addAll(keys);

  /// Deletes every cached image, e.g. on sign-out.
  Future<void> clearAll() async {
    _keysByOwner.clear();
    PaintingBinding.instance.imageCache.clear();
    await manager.emptyCache();
  }

  /// Deletes the cached images registered for [ownerId], e.g. when blocked.
  Future<void> evictOwner(String ownerId) async {
    final keys = _keysByOwner.remove(ownerId);
    if (keys == null) return;
    PaintingBinding.instance.imageCache.clear();
    for (final key in keys) {
      await manager.removeFile(key);
    }
  }
}

/// The app's image cache. Tests override it with a fake.
final orbitImageCacheProvider = Provider<OrbitImageCache>(
  (ref) => OrbitImageCache(),
);

/// A network image cached on disk by media id and variant. With
/// `cache: false` (view-once media) nothing is written to disk.
class MediaImage extends ConsumerWidget {
  /// Creates an image for [mediaId] loaded from [url].
  const MediaImage({
    required this.mediaId,
    required this.url,
    this.thumbUrl,
    this.variant = MediaVariant.full,
    this.cache = true,
    this.fit = BoxFit.cover,
    this.ownerId,
    this.placeholder,
    super.key,
  });

  /// Stable id of the media; part of the cache key.
  final String mediaId;

  /// Short-lived link to the image in [variant].
  final String url;

  /// Link to the small image, shown first while a full image loads.
  final String? thumbUrl;

  /// Which rendition [url] points to.
  final MediaVariant variant;

  /// Whether the image may be kept on disk.
  final bool cache;

  /// How the image fills its box.
  final BoxFit fit;

  /// Member whose images are evicted if they are blocked. Both variants of
  /// [mediaId] are registered, so the full image opened later from a
  /// thumbnail is evicted too.
  final String? ownerId;

  /// Shown while loading and if the image fails; a broken-image icon when
  /// null.
  final Widget? placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!cache) {
      return Image.network(
        url,
        fit: fit,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
            frame == null && !wasSynchronouslyLoaded
            ? (placeholder ?? const SizedBox.shrink())
            : child,
        errorBuilder: (context, error, stackTrace) => _failed(),
      );
    }
    final imageCache = ref.watch(orbitImageCacheProvider);
    final owner = ownerId;
    if (owner != null) {
      imageCache.register(owner, [
        mediaCacheKey(mediaId, MediaVariant.thumb),
        mediaCacheKey(mediaId, MediaVariant.full),
      ]);
    }
    final fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 250);
    final thumb = thumbUrl;
    final showThumb = variant == MediaVariant.full && thumb != null;
    return Stack(
      fit: StackFit.expand,
      children: [
        ?placeholder,
        if (showThumb)
          _cached(imageCache.manager, thumb, MediaVariant.thumb, Duration.zero),
        _cached(imageCache.manager, url, variant, fade),
      ],
    );
  }

  Widget _cached(
    BaseCacheManager manager,
    String source,
    MediaVariant of,
    Duration fade,
  ) {
    final isMain = of == variant;
    return CachedNetworkImage(
      imageUrl: source,
      cacheKey: mediaCacheKey(mediaId, of),
      cacheManager: manager,
      fit: fit,
      fadeInDuration: fade,
      fadeOutDuration: Duration.zero,
      errorWidget: (context, url, error) =>
          isMain ? _failed() : const SizedBox.shrink(),
    );
  }

  Widget _failed() => placeholder ?? const Icon(Icons.broken_image_outlined);
}

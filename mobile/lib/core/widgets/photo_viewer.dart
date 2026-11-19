import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/widgets/media_image.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// One photo in the full-screen viewer.
class PhotoViewerItem {
  /// Creates an item. Pass `cache: false` for view-once photos.
  const PhotoViewerItem({
    required this.mediaId,
    required this.url,
    this.thumbUrl,
    this.cache = true,
    this.ownerId,
  });

  /// Stable media id; part of the cache key.
  final String mediaId;

  /// Short-lived link to the full image.
  final String url;

  /// Short-lived link to the small image, shown while the full one loads.
  final String? thumbUrl;

  /// Whether the image may be kept on disk.
  final bool cache;

  /// Member whose cached images are evicted if they are blocked.
  final String? ownerId;
}

// A downward drag closes the viewer past this distance or speed.
const _dismissDistance = 120.0;
const _dismissVelocity = 800.0;
const _maxZoom = 4.0;
const _doubleTapZoom = 2.5;
const _motion = Duration(milliseconds: 250);

/// Opens [items] full screen at [initialIndex]. A matching [heroTag] on the
/// source widget animates the first photo in; [bottomBar] builds a bar under
/// the photo for the page at `index`.
Future<void> openPhotos(
  BuildContext context,
  List<PhotoViewerItem> items, {
  int initialIndex = 0,
  String? heroTag,
  Widget Function(BuildContext, int index)? bottomBar,
}) {
  final still = MediaQuery.disableAnimationsOf(context);
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      fullscreenDialog: true,
      transitionDuration: still ? Duration.zero : _motion,
      reverseTransitionDuration: still ? Duration.zero : _motion,
      pageBuilder: (context, animation, secondaryAnimation) => PhotoViewer(
        items: items,
        initialIndex: initialIndex,
        heroTag: heroTag,
        bottomBar: bottomBar,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
            child: child,
          ),
    ),
  );
}

/// A full-screen pager of zoomable photos that closes with a downward drag.
class PhotoViewer extends ConsumerStatefulWidget {
  /// Creates the viewer.
  const PhotoViewer({
    required this.items,
    this.initialIndex = 0,
    this.heroTag,
    this.bottomBar,
    super.key,
  });

  /// Photos to page through.
  final List<PhotoViewerItem> items;

  /// Photo shown first.
  final int initialIndex;

  /// Hero tag for the first photo.
  final String? heroTag;

  /// Builds a bar under the photo at the given index.
  final Widget Function(BuildContext, int index)? bottomBar;

  @override
  ConsumerState<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<PhotoViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  final Map<int, Offset> _starts = {};
  final VelocityTracker _velocity = VelocityTracker.withKind(
    PointerDeviceKind.touch,
  );
  double _drag = 0;
  bool _dragging = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheAround(_index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  ImageProvider _providerFor(PhotoViewerItem item) {
    if (!item.cache) return NetworkImage(item.url);
    return CachedNetworkImageProvider(
      item.url,
      cacheKey: mediaCacheKey(item.mediaId, MediaVariant.full),
      cacheManager: ref.read(orbitImageCacheProvider).manager,
    );
  }

  void _precacheAround(int index) {
    final items = widget.items;
    for (final i in [index - 1, index + 1]) {
      if (i < 0 || i >= items.length) continue;
      final provider = _providerFor(items[i]);
      // Warming a neighbour is best effort: a failure shows as the
      // broken-image icon when that page is actually opened.
      unawaited(precacheImage(provider, context, onError: (_, _) {}));
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _starts[event.pointer] = event.position;
    if (_starts.length > 1) _endDrag(dismissAllowed: false);
    _velocity.addPosition(event.timeStamp, event.position);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_starts.length != 1 || _zoomed) return;
    _velocity.addPosition(event.timeStamp, event.position);
    if (!_dragging) {
      final moved = event.position - _starts[event.pointer]!;
      final vertical = moved.dy > kTouchSlop && moved.dy > moved.dx.abs() * 1.5;
      if (!vertical) return;
      _dragging = true;
    }
    setState(() => _drag = (_drag + event.delta.dy).clamp(0, double.infinity));
  }

  void _onPointerEnd(PointerEvent event) {
    _starts.remove(event.pointer);
    _endDrag(dismissAllowed: event is PointerUpEvent);
  }

  void _endDrag({required bool dismissAllowed}) {
    if (!_dragging) return;
    _dragging = false;
    final speed = _velocity.getVelocity().pixelsPerSecond.dy;
    final far = _drag > _dismissDistance || speed > _dismissVelocity;
    if (dismissAllowed && far) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _drag = 0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final height = MediaQuery.sizeOf(context).height;
    final still = MediaQuery.disableAnimationsOf(context);
    final backdrop = (1 - _drag / (height * 0.5)).clamp(0.0, 1.0);
    final showChrome = _drag == 0;
    final bottomBar = widget.bottomBar;
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: backdrop),
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: _drag),
              duration: _dragging || still ? Duration.zero : _motion,
              curve: Curves.easeOut,
              builder: (context, offset, child) =>
                  Transform.translate(offset: Offset(0, offset), child: child),
              child: IconTheme(
                data: const IconThemeData(color: Colors.white),
                child: PageView.builder(
                  controller: _pages,
                  itemCount: widget.items.length,
                  physics: _zoomed
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  onPageChanged: (page) {
                    setState(() {
                      _index = page;
                      _zoomed = false;
                    });
                    _precacheAround(page);
                  },
                  itemBuilder: (context, i) => _ZoomablePage(
                    key: ValueKey(i),
                    item: widget.items[i],
                    heroTag: i == widget.initialIndex ? widget.heroTag : null,
                    onZoomChanged: (zoomed) {
                      if (i == _index && zoomed != _zoomed) {
                        setState(() => _zoomed = zoomed);
                      }
                    },
                  ),
                ),
              ),
            ),
            if (showChrome)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l10n.closeTooltip,
                        color: Colors.white,
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          '${_index + 1} / ${widget.items.length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            if (showChrome && bottomBar != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(child: bottomBar(context, _index)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ZoomablePage extends StatefulWidget {
  const _ZoomablePage({
    required this.item,
    required this.heroTag,
    required this.onZoomChanged,
    super.key,
  });

  final PhotoViewerItem item;
  final String? heroTag;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePage> createState() => _ZoomablePageState();
}

class _ZoomablePageState extends State<_ZoomablePage> {
  final _controller = TransformationController();
  Offset _tap = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_reportZoom);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_reportZoom)
      ..dispose();
    super.dispose();
  }

  bool get _isZoomed => _controller.value.getMaxScaleOnAxis() > 1.01;

  void _reportZoom() => widget.onZoomChanged(_isZoomed);

  void _toggleZoom() {
    if (_isZoomed) {
      _controller.value = Matrix4.identity();
      return;
    }
    const s = _doubleTapZoom;
    _controller.value = Matrix4.identity()
      ..translateByDouble(-_tap.dx * (s - 1), -_tap.dy * (s - 1), 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    Widget image = MediaImage(
      mediaId: item.mediaId,
      url: item.url,
      thumbUrl: item.thumbUrl,
      cache: item.cache,
      ownerId: item.ownerId,
      fit: BoxFit.contain,
    );
    final tag = widget.heroTag;
    if (tag != null) image = Hero(tag: tag, child: image);
    return GestureDetector(
      onDoubleTapDown: (details) => _tap = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _controller,
        maxScale: _maxZoom,
        child: SizedBox.expand(child: image),
      ),
    );
  }
}

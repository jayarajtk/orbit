import 'dart:async';
import 'dart:developer' as developer;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/core/widgets/glass_icon_button.dart';
import 'package:orbit/core/widgets/media_image.dart';
import 'package:orbit/core/widgets/profile_avatar.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/features/safety/presentation/safety_sheet.dart';
import 'package:orbit/features/status/data/status_repository.dart';
import 'package:orbit/features/status/domain/status.dart';
import 'package:orbit/features/status/presentation/status_ago.dart';
import 'package:orbit/features/status/presentation/status_providers.dart';
import 'package:orbit/features/status/presentation/viewers_sheet.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// The profile id that stands for the signed-in user's own statuses.
const _ownStatuses = 'me';

/// How long each status shows.
const _perStatus = Duration(seconds: 5);

// A downward drag closes the viewer past this distance or speed.
const _dismissDistance = 120.0;
const _dismissVelocity = 800.0;
const _motion = Duration(milliseconds: 250);

/// What the viewer needs of one status, whoever owns it.
class _Slide {
  const _Slide({
    required this.id,
    required this.url,
    required this.createdAt,
    this.thumbUrl,
    this.caption,
    this.seen = false,
    this.viewers = const [],
    this.viewCount = 0,
  });

  factory _Slide.fromItem(StatusItem item) => _Slide(
    id: item.id,
    url: item.url,
    thumbUrl: item.thumbUrl,
    caption: item.caption,
    createdAt: item.createdAt,
    seen: item.seen,
  );

  factory _Slide.fromMine(MyStatus status) => _Slide(
    id: status.id,
    url: status.url,
    thumbUrl: status.thumbUrl,
    caption: status.caption,
    createdAt: status.createdAt,
    viewers: status.viewers,
    viewCount: status.viewCount,
  );

  final String id;
  final String url;
  final String? thumbUrl;
  final String? caption;
  final DateTime createdAt;

  /// Whether the server says the user viewed it before this visit.
  final bool seen;
  final List<StatusSeenBy> viewers;
  final int viewCount;
}

/// Full-screen statuses, one after another, like a story. [profileId] is
/// `me` for the user's own.
class StatusViewerScreen extends ConsumerStatefulWidget {
  /// Creates the viewer for [profileId].
  const StatusViewerScreen({required this.profileId, super.key});

  /// Member whose statuses play, or `me`.
  final String profileId;

  @override
  ConsumerState<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends ConsumerState<StatusViewerScreen> {
  String get profileId => widget.profileId;

  bool get _isMine => profileId == _ownStatuses;

  @override
  void initState() {
    super.initState();
    // The user's own list is kept between visits; fetch it again so views
    // since the last visit show. Providers can't change during a build.
    if (_isMine) {
      unawaited(
        Future.microtask(() async {
          if (mounted) {
            await ref.read(myStatusesProvider.notifier).refresh();
          }
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final slides = _isMine
        ? ref
              .watch(liveMyStatusesProvider)
              // Newest first from the server; story order is oldest first.
              .whenData(
                (list) => [for (final s in list.reversed) _Slide.fromMine(s)],
              )
        : ref
              .watch(profileStatusesProvider(profileId))
              .whenData((list) => [for (final s in list) _Slide.fromItem(s)]);
    final profile = _isMine
        ? null
        : ref.watch(profileByIdProvider(profileId)).value;
    return slides.when(
      data: (list) => list.isEmpty
          ? const _CloseOnce()
          : _StatusPlayer(
              profileId: profileId,
              profile: profile,
              slides: list,
            ),
      loading: () => const _Backdrop(child: CircularProgressIndicator()),
      error: (_, _) => _Backdrop(
        child: Text(
          AppLocalizations.of(context).actionFailed,
          style: const TextStyle(color: Colors.white), // photo-overlay
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// A black screen with [child] in the middle and a way out.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // photo-overlay
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: child),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: GlassIconButton(
                icon: Icons.close,
                tooltip: AppLocalizations.of(context).closeTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Leaves the route once, right after it first builds (nothing to show).
class _CloseOnce extends StatefulWidget {
  const _CloseOnce();

  @override
  State<_CloseOnce> createState() => _CloseOnceState();
}

class _CloseOnceState extends State<_CloseOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(Navigator.of(context).maybePop());
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: Colors.black); // photo-overlay
}

class _StatusPlayer extends ConsumerStatefulWidget {
  const _StatusPlayer({
    required this.profileId,
    required this.profile,
    required this.slides,
  });

  final String profileId;
  final Profile? profile;
  final List<_Slide> slides;

  @override
  ConsumerState<_StatusPlayer> createState() => _StatusPlayerState();
}

class _StatusPlayerState extends ConsumerState<_StatusPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress =
      AnimationController(vsync: this, duration: _perStatus)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _next();
        });

  int _index = 0;
  final Set<String> _viewed = {};

  bool _holding = false;
  bool _dragging = false;
  int _sheetsOpen = 0;

  /// Set by the Pause and Resume screen-reader actions; null follows
  /// [_screenReader].
  bool? _pausedByUser;

  /// A screen reader is on: statuses wait for the member instead of moving
  /// on every 5 seconds, which is too quick to hear a status out.
  bool _screenReader = false;

  final Map<int, Offset> _starts = {};
  final VelocityTracker _velocity = VelocityTracker.withKind(
    PointerDeviceKind.touch,
  );
  double _drag = 0;

  ImageStream? _watched;
  ImageStreamListener? _watcher;

  bool get _isMine => widget.profileId == _ownStatuses;
  _Slide get _slide => widget.slides[_index];
  bool get _heldByUser => _pausedByUser ?? _screenReader;
  bool get _paused => _holding || _dragging || _sheetsOpen > 0 || _heldByUser;

  @override
  void initState() {
    super.initState();
    // Marking a status viewed changes providers, which a build must not.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enter();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenReader = MediaQuery.accessibleNavigationOf(context);
    if (screenReader == _screenReader) return;
    _screenReader = screenReader;
    _syncPlayback();
  }

  @override
  void didUpdateWidget(_StatusPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.slides, widget.slides)) return;
    // The list changed (a status was deleted): keep showing the same status,
    // or the one that took its place.
    final shown = oldWidget.slides[_index].id;
    final moved = widget.slides.indexWhere((s) => s.id == shown);
    if (moved >= 0) {
      _index = moved;
      return;
    }
    _index = _index.clamp(0, widget.slides.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enter();
    });
  }

  @override
  void dispose() {
    _unwatch();
    _progress.dispose();
    super.dispose();
  }

  ImageProvider _providerFor(_Slide slide) => CachedNetworkImageProvider(
    slide.url,
    cacheKey: mediaCacheKey(slide.id, MediaVariant.full),
    cacheManager: ref.read(orbitImageCacheProvider).manager,
  );

  /// Starts the current status: its timer, its view, its image check and
  /// a warm-up of the next photo.
  void _enter() {
    final slide = _slide;
    _progress.value = 0;
    _syncPlayback();
    _markViewed(slide);
    _watch(slide);
    _precacheNext();
  }

  void _syncPlayback() {
    if (_paused) {
      _progress.stop();
    } else if (!_progress.isAnimating && !_progress.isCompleted) {
      unawaited(_progress.forward());
    }
  }

  void _markViewed(_Slide slide) {
    if (_isMine || !_viewed.add(slide.id)) return;
    // The ring turns grey only once nothing of this member's is left unseen.
    if (widget.slides.every((s) => s.seen || _viewed.contains(s.id))) {
      ref.read(seenStatusOwnersProvider.notifier).markSeen(widget.profileId);
    }
    unawaited(_sendView(slide.id));
  }

  Future<void> _sendView(String id) async {
    final repository = ref.read(statusRepositoryProvider);
    try {
      await repository.markViewed(id);
    } on Exception catch (error, stack) {
      // Only the type: the exception text can carry a link.
      developer.log(
        'Could not record a status view (${error.runtimeType})',
        name: 'orbit.status',
        stackTrace: stack,
      );
    }
  }

  /// Moves on at once if this status's photo cannot be loaded, e.g. because
  /// it expired (404 or 410) between listing and viewing.
  void _watch(_Slide slide) {
    _unwatch();
    final stream = _providerFor(slide).resolve(
      createLocalImageConfiguration(context),
    );
    final listener = ImageStreamListener(
      (_, _) {},
      onError: (_, _) {
        if (mounted && _slide.id == slide.id) _next();
      },
    );
    stream.addListener(listener);
    _watched = stream;
    _watcher = listener;
  }

  void _unwatch() {
    final listener = _watcher;
    if (listener != null) _watched?.removeListener(listener);
    _watched = null;
    _watcher = null;
  }

  void _precacheNext() {
    final next = _index + 1;
    if (next >= widget.slides.length) return;
    final slide = widget.slides[next];
    if (!_isMine) {
      ref.read(orbitImageCacheProvider).register(widget.profileId, [
        mediaCacheKey(slide.id, MediaVariant.thumb),
        mediaCacheKey(slide.id, MediaVariant.full),
      ]);
    }
    // Warming is best effort: a failure is handled when it becomes current.
    unawaited(
      precacheImage(_providerFor(slide), context, onError: (_, _) {}),
    );
  }

  void _next() {
    if (_index + 1 >= widget.slides.length) {
      _close();
      return;
    }
    setState(() => _index++);
    _enter();
  }

  void _previous() {
    if (_index > 0) setState(() => _index--);
    _enter();
  }

  void _close() => unawaited(Navigator.of(context).maybePop());

  Future<T> _whilePaused<T>(Future<T> Function() open) async {
    _sheetsOpen++;
    _syncPlayback();
    try {
      return await open();
    } finally {
      _sheetsOpen--;
      if (mounted) _syncPlayback();
    }
  }

  void _onTapUp(TapUpDetails details) {
    final width = context.size?.width ?? 0;
    final fromStart = Directionality.of(context) == TextDirection.rtl
        ? width - details.localPosition.dx
        : details.localPosition.dx;
    fromStart < width / 3 ? _previous() : _next();
  }

  void _togglePause() {
    setState(() => _pausedByUser = !_heldByUser);
    _syncPlayback();
  }

  void _setHolding({required bool holding}) {
    _holding = holding;
    _syncPlayback();
  }

  void _onPointerDown(PointerDownEvent event) {
    _starts[event.pointer] = event.position;
    if (_starts.length > 1) _endDrag(dismissAllowed: false);
    _velocity.addPosition(event.timeStamp, event.position);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_starts.length != 1 || _sheetsOpen > 0) return;
    _velocity.addPosition(event.timeStamp, event.position);
    if (!_dragging) {
      final moved = event.position - _starts[event.pointer]!;
      final vertical = moved.dy > kTouchSlop && moved.dy > moved.dx.abs() * 1.5;
      if (!vertical) return;
      _dragging = true;
      _syncPlayback();
    }
    setState(() => _drag = (_drag + event.delta.dy).clamp(0, double.infinity));
  }

  void _onPointerEnd(PointerEvent event) {
    _starts.remove(event.pointer);
    _endDrag(dismissAllowed: event is PointerUpEvent);
  }

  void _endDrag({required bool dismissAllowed}) {
    if (!_dragging) return;
    final speed = _velocity.getVelocity().pixelsPerSecond.dy;
    if (dismissAllowed &&
        (_drag > _dismissDistance || speed > _dismissVelocity)) {
      _close();
      return;
    }
    setState(() {
      _dragging = false;
      _drag = 0;
    });
    _syncPlayback();
  }

  Future<void> _openViewers() async {
    final slide = _slide;
    final now = ref.read(clockProvider)();
    await _whilePaused(
      () => showViewersSheet(context, viewers: slide.viewers, now: now),
    );
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = _slide.id;
    final confirmed = await _whilePaused(
      () => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.statusDelete),
          content: Text(l10n.statusDeleteConfirm),
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
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(myStatusesProvider.notifier).delete(id);
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    }
  }

  Future<void> _report() async {
    final profile = widget.profile;
    if (profile == null) return;
    final id = _slide.id;
    final blocked = await _whilePaused(
      () => showSafetySheet(context, profile, statusId: id),
    );
    if (blocked && mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final height = MediaQuery.sizeOf(context).height;
    final backdrop = (1 - _drag / (height * 0.5)).clamp(0.0, 1.0);
    final slide = _slide;
    final caption = slide.caption;
    final profile = widget.profile;
    final now = ref.read(clockProvider)();
    const scrim = Colors.black; // photo-overlay
    return Scaffold(
      backgroundColor: scrim.withValues(alpha: backdrop),
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
              // A screen reader's tap lands in the middle, which can only go
              // forward, so it gets explicit actions instead of the taps.
              child: Semantics(
                label: l10n.statusPhoto,
                customSemanticsActions: {
                  CustomSemanticsAction(label: l10n.statusPrevious): _previous,
                  CustomSemanticsAction(label: l10n.statusNext): _next,
                  CustomSemanticsAction(
                    label: _heldByUser ? l10n.statusResume : l10n.statusPause,
                  ): _togglePause,
                },
                child: GestureDetector(
                  excludeFromSemantics: true,
                  behavior: HitTestBehavior.opaque,
                  onTapUp: _onTapUp,
                  onLongPressStart: (_) => _setHolding(holding: true),
                  onLongPressEnd: (_) => _setHolding(holding: false),
                  onLongPressCancel: () => _setHolding(holding: false),
                  child: MediaImage(
                    key: ValueKey(slide.id),
                    mediaId: slide.id,
                    url: slide.url,
                    thumbUrl: slide.thumbUrl,
                    ownerId: _isMine ? null : widget.profileId,
                    fit: BoxFit.contain,
                    placeholder: const ColoredBox(
                      color: Colors.black, // photo-overlay
                    ),
                  ),
                ),
              ),
            ),
            if (_drag == 0) ...[
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Segments(
                        count: widget.slides.length,
                        index: _index,
                        progress: _progress,
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 12),
                          if (profile != null) ...[
                            ProfileAvatar(
                              name: profile.name,
                              seed: profile.id,
                              size: 36,
                              photoUrl: profile.photos.firstOrNull?.thumbUrl,
                              mediaId: profile.photos.firstOrNull?.id,
                              ownerId: profile.id,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: _Title(
                              name: _isMine ? l10n.statusYours : profile?.name,
                              ago: statusAgoLabel(l10n, now, slide.createdAt),
                            ),
                          ),
                          if (_isMine)
                            GlassIconButton(
                              icon: Icons.delete_outline,
                              tooltip: l10n.statusDelete,
                              onPressed: _delete,
                            )
                          else
                            GlassIconButton(
                              icon: Icons.flag_outlined,
                              tooltip: l10n.statusReport,
                              onPressed: profile == null ? null : _report,
                            ),
                          GlassIconButton(
                            icon: Icons.close,
                            tooltip: l10n.closeTooltip,
                            onPressed: _close,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (caption != null && caption.isNotEmpty)
                        Container(
                          width: double.infinity,
                          // photo-overlay: 0.6 black keeps white text AA.
                          color: scrim.withValues(alpha: 0.6),
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            caption,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: Colors.white, // photo-overlay
                                ),
                          ),
                        ),
                      if (_isMine)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Tooltip(
                            message: l10n.statusViewedBy,
                            child: FilledButton.tonal(
                              onPressed: _openViewers,
                              child: Text(l10n.statusViews(slide.viewCount)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.name, required this.ago});

  final String? name;
  final String ago;

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(color: Colors.white); // photo-overlay
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name != null)
          Text(
            name!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.titleSmall?.merge(white),
          ),
        Text(ago, style: theme.bodySmall?.merge(white)),
      ],
    );
  }
}

/// One thin bar per status: full for past ones, filling for the current one.
class _Segments extends StatelessWidget {
  const _Segments({
    required this.count,
    required this.index,
    required this.progress,
  });

  final int count;
  final int index;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    const track = Colors.white; // photo-overlay
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                label: l10n.statusSegment(i + 1, count),
                selected: i == index,
                child: ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox(
                      height: 3,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: track.withValues(alpha: 0.4),
                          ),
                          if (i < index)
                            const ColoredBox(
                              color: Colors.white, // photo-overlay
                            )
                          else if (i == index)
                            AnimatedBuilder(
                              animation: progress,
                              builder: (context, _) => Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: FractionallySizedBox(
                                  widthFactor: progress.value,
                                  heightFactor: 1,
                                  child: const ColoredBox(
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
              ),
            ),
          ],
        ],
      ),
    );
  }
}

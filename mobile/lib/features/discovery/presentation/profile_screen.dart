import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/app/theme.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/labels.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/glass_icon_button.dart';
import 'package:orbit/core/widgets/media_image.dart';
import 'package:orbit/core/widgets/photo_viewer.dart';
import 'package:orbit/core/widgets/profile_avatar.dart';
import 'package:orbit/core/widgets/status_ring.dart';
import 'package:orbit/features/chat/presentation/chat_controller.dart';
import 'package:orbit/features/chat/presentation/wave_limit.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/features/safety/presentation/safety_providers.dart';
import 'package:orbit/features/safety/presentation/safety_sheet.dart';
import 'package:orbit/features/status/domain/status.dart';
import 'package:orbit/features/status/presentation/status_providers.dart';
import 'package:orbit/l10n/app_localizations.dart';

const _photoHeight = 420.0;

/// How far the details card slides up over the photo.
const _cardOverlap = 24.0;

/// Fraction of the photo's width at each edge where a tap changes photo.
const _stepZone = 0.3;

const _photoStep = Duration(milliseconds: 250);

/// The tag shared by the grid tile and the first photo, so it flies in.
String _heroTag(Profile profile) => 'profile-photo-${profile.id}';

/// W8: another member's full profile.
class ProfileScreen extends ConsumerWidget {
  /// Creates the profile screen for [profileId].
  const ProfileScreen({required this.profileId, super.key});

  /// The member to show.
  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final blocked = ref.watch(blockedProvider).contains(profileId);
    final unavailable = Scaffold(
      appBar: AppBar(),
      body: EmptyState(
        icon: Icons.person_off_outlined,
        message: l10n.profileUnavailable,
      ),
    );
    final cached = ref.watch(profilesByIdProvider)[profileId];
    // The grid's copy stands in while the fresh one loads, and if fetching
    // it fails (a weak connection is no reason to call the member gone).
    final fallback = cached != null && !blocked
        ? _ProfileView(profile: cached)
        : null;
    return ref
        .watch(profileByIdProvider(profileId))
        .when(
          loading: () =>
              fallback ??
              const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
          error: (_, _) => fallback ?? unavailable,
          data: (profile) => profile == null || blocked
              ? unavailable
              : _ProfileView(profile: profile),
        );
  }
}

class _ProfileView extends ConsumerStatefulWidget {
  const _ProfileView({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<_ProfileView> {
  final _pages = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    // Provider changes are not allowed while the tree is building.
    unawaited(
      Future.microtask(() async {
        if (!mounted) return;
        await ref.read(chatProvider.notifier).open(_profile.id);
        if (mounted) _syncWaveLimit();
      }),
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Profile get _profile => widget.profile;

  void _syncWaveLimit() {
    final messages = ref.read(chatProvider)[_profile.id]?.messages;
    if (messages == null) return;
    ref
        .read(waveLimitProvider(_profile.id).notifier)
        .fromHistory(messages, ref.read(clockProvider)());
  }

  void _showWaveRefusal(WaveRefusal refusal) {
    final l10n = AppLocalizations.of(context);
    final wait = refusal.retryAt.difference(ref.read(clockProvider)());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.waveLimitReached(waitLabel(wait)))),
    );
  }

  void _wave() {
    ref.read(chatProvider.notifier).wave(_profile.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).waveSent(_profile.name)),
      ),
    );
  }

  void _stepPhoto(int delta, int count) {
    final target = _page + delta;
    if (target < 0 || target >= count) return;
    unawaited(
      _pages.animateToPage(
        target,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : _photoStep,
        curve: Curves.easeOut,
      ),
    );
  }

  void _openPhotos() {
    final items = [
      for (final photo in _profile.photos)
        PhotoViewerItem(
          mediaId: photo.id,
          url: photo.url,
          thumbUrl: photo.thumbUrl,
          ownerId: _profile.id,
        ),
    ];
    if (items.isEmpty) return;
    final index = _page.clamp(0, items.length - 1);
    unawaited(
      openPhotos(
        context,
        items,
        initialIndex: index,
        heroTag: index == 0 ? _heroTag(_profile) : null,
      ),
    );
  }

  Future<void> _openSafety() async {
    final blocked = await showSafetySheet(context, _profile);
    if (blocked && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isFavorite = ref.watch(favoritesProvider).contains(_profile.id);
    ref
      ..listen(chatProvider.select((all) => all[_profile.id]?.messages), (
        _,
        _,
      ) {
        _syncWaveLimit();
      })
      ..listen(waveRefusalProvider, (_, refusal) {
        if (refusal != null && refusal.profileId == _profile.id) {
          _showWaveRefusal(refusal);
        }
      });
    final waveUnlocksAt = ref.watch(waveBlockedUntilProvider(_profile.id));
    final ring = ringFor(_profile, ref.watch(seenStatusOwnersProvider));
    final photos = _profile.photoCount == 0 ? 1 : _profile.photoCount;
    final details = [
      ?_profile.pronouns,
      if (_profile.heightCm case final cm?) l10n.heightCm(cm),
      if (_profile.relationship case final r?) l10n.relationship(r),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: GlassIconButton(
          icon: Icons.arrow_back,
          tooltip: l10n.backTooltip,
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          GlassIconButton(
            tooltip: isFavorite ? l10n.favoriteRemove : l10n.favoriteAdd,
            selected: isFavorite,
            icon: Icons.star_border,
            selectedIcon: Icons.star,
            onPressed: () =>
                ref.read(favoritesProvider.notifier).toggle(_profile.id),
          ),
          GlassIconButton(
            tooltip: l10n.moreActions,
            icon: Icons.more_horiz,
            onPressed: _openSafety,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _photoHeight,
                child: _PhotoPager(
                  profile: _profile,
                  count: photos,
                  controller: _pages,
                  page: _page,
                  ring: ring,
                  onPageChanged: (page) => setState(() => _page = page),
                  onStep: (delta) => _stepPhoto(delta, photos),
                  onOpen: _openPhotos,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: _photoHeight - _cardOverlap,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.tokens.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (_profile.online) ...[
                                const OnlineDot(),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  l10n.nameWithAge(_profile.name, _profile.age),
                                  style: theme.textTheme.headlineSmall,
                                ),
                              ),
                              Text(
                                l10n.distance(_profile.distanceKm),
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          if (details.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              details.join(' · '),
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(_profile.bio, style: theme.textTheme.bodyLarge),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final goal in _profile.lookingFor)
                                Chip(label: Text(l10n.lookingFor(goal))),
                              for (final tag in _profile.tags)
                                Chip(label: Text('#$tag')),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: waveUnlocksAt == null
                                      ? _wave
                                      : null,
                                  icon: const Icon(Icons.waving_hand_outlined),
                                  label: Text(
                                    waveUnlocksAt == null
                                        ? l10n.waveButton
                                        : l10n.waveAgainIn(
                                            waitLabel(
                                              waveUnlocksAt.difference(
                                                ref.read(clockProvider)(),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      context.push(AppRoutes.chat(_profile.id)),
                                  icon: const Icon(Icons.chat_bubble_outline),
                                  label: Text(l10n.messageButton),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoPager extends StatelessWidget {
  const _PhotoPager({
    required this.profile,
    required this.count,
    required this.controller,
    required this.page,
    required this.ring,
    required this.onPageChanged,
    required this.onStep,
    required this.onOpen,
  });

  final Profile profile;
  final int count;
  final PageController controller;
  final int page;
  final StatusRing ring;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onStep;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              // A screen reader focuses each labelled page, which carries
              // its own open action, so this tap is not offered a second time
              // on a node with no label.
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              // Edge taps step through the photos; the middle opens the viewer.
              onTapUp: (details) {
                final x = details.localPosition.dx / constraints.maxWidth;
                if (count > 1 && x < _stepZone) {
                  onStep(-1);
                } else if (count > 1 && x > 1 - _stepZone) {
                  onStep(1);
                } else {
                  onOpen();
                }
              },
              child: PageView.builder(
                controller: controller,
                itemCount: count,
                onPageChanged: onPageChanged,
                itemBuilder: (context, index) {
                  final photo = index < profile.photos.length
                      ? profile.photos[index]
                      : null;
                  final avatar = ProfileAvatar(
                    name: profile.name,
                    seed: '${profile.id}-$index',
                    photoUrl: photo?.url,
                    mediaId: photo?.id,
                    ownerId: profile.id,
                    variant: MediaVariant.full,
                    size: double.infinity,
                    square: true,
                  );
                  return Semantics(
                    button: true,
                    label: l10n.photoOf(index + 1, count),
                    onTap: onOpen,
                    child: index == 0 && !still
                        ? Hero(tag: _heroTag(profile), child: avatar)
                        : avatar,
                  );
                },
              ),
            ),
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x73000000), // photo-overlay
                    Color(0x00000000), // photo-overlay
                  ],
                ),
              ),
            ),
          ),
        ),
        if (count > 1)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            right: 12,
            child: _SegmentBar(count: count, page: page, onStep: onStep),
          ),
        if (ring != StatusRing.none)
          Positioned(
            left: 16,
            bottom: _cardOverlap + 12,
            child: Semantics(
              container: true,
              button: true,
              label: l10n.statusViewOf(profile.name),
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('status-ring'),
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push(AppRoutes.statuses(profile.id)),
                child: StatusRingFrame(
                  ring: ring,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ProfileAvatar(
                      name: profile.name,
                      seed: profile.id,
                      photoUrl: profile.thumbUrl,
                      mediaId: profile.thumbMediaId,
                      ownerId: profile.id,
                      size: 56,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One thin segment per photo, the current one bright. Screen readers get
/// one "2 of 5" control they can swipe up or down.
class _SegmentBar extends StatelessWidget {
  const _SegmentBar({
    required this.count,
    required this.page,
    required this.onStep,
  });

  final int count;
  final int page;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _photoStep;
    return Semantics(
      container: true,
      label: l10n.photoPagePosition(page + 1, count),
      value: '${page + 1}',
      increasedValue: '${page + 2}',
      decreasedValue: '$page',
      onIncrease: page < count - 1 ? () => onStep(1) : null,
      onDecrease: page > 0 ? () => onStep(-1) : null,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Row(
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: AnimatedContainer(
                      key: ValueKey('photo-segment-$i'),
                      duration: duration,
                      curve: Curves.easeOut,
                      height: 3,
                      decoration: BoxDecoration(
                        color: i == page
                            ? Colors
                                  .white // photo-overlay
                            : Colors.white38, // photo-overlay
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

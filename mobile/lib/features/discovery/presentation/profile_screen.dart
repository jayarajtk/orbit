import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/core/clock.dart';
import 'package:orbit/core/labels.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/glass_icon_button.dart';
import 'package:orbit/core/widgets/media_image.dart';
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
    return ref
        .watch(profileByIdProvider(profileId))
        .when(
          loading: () => cached != null && !blocked
              ? _ProfileView(profile: cached)
              : const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
          error: (_, _) => unavailable,
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
          SizedBox(
            height: 420,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pages,
                  itemCount: photos,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) => Semantics(
                    label: l10n.photoOf(index + 1, photos),
                    child: ProfileAvatar(
                      name: _profile.name,
                      seed: '${_profile.id}-$index',
                      hasPhoto: _profile.hasPhoto,
                      photoUrl: index < _profile.photos.length
                          ? _profile.photos[index].url
                          : null,
                      mediaId: index < _profile.photos.length
                          ? _profile.photos[index].id
                          : null,
                      ownerId: _profile.id,
                      variant: MediaVariant.full,
                      size: double.infinity,
                      square: true,
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
                if (ring != StatusRing.none)
                  Positioned(
                    left: 16,
                    bottom: 12,
                    child: Semantics(
                      container: true,
                      button: true,
                      label: l10n.statusViewOf(_profile.name),
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: const ValueKey('status-ring'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            context.push(AppRoutes.statuses(_profile.id)),
                        child: StatusRingFrame(
                          ring: ring,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: ProfileAvatar(
                              name: _profile.name,
                              seed: _profile.id,
                              hasPhoto: _profile.hasPhoto,
                              photoUrl: _profile.thumbUrl,
                              mediaId: _profile.thumbMediaId,
                              ownerId: _profile.id,
                              size: 56,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (photos > 1)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < photos; i++)
                            Container(
                              width: i == _page ? 18 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              decoration: BoxDecoration(
                                color: i == _page
                                    ? Colors.white
                                    : Colors.white54,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                    for (final tag in _profile.tags) Chip(label: Text('#$tag')),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: waveUnlocksAt == null ? _wave : null,
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
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/core/labels.dart';
import 'package:orbit/core/widgets/profile_avatar.dart';
import 'package:orbit/core/widgets/status_ring.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/status/domain/status.dart';
import 'package:orbit/features/status/presentation/status_providers.dart';
import 'package:orbit/l10n/app_localizations.dart';

const double _tileRadius = 12;
const double _ringInset = 2.5;

/// One member in the Nearby grid: a full-bleed photo with their name, age,
/// distance and online dot over a bottom scrim, and a status ring inset on
/// the tile.
class ProfileTile extends ConsumerWidget {
  /// Creates a tile. [onOpen] opens the profile, [onOpenStatus] their
  /// statuses (from the ring badge), and [onLongPress] the safety sheet.
  const ProfileTile({
    required this.profile,
    required this.onOpen,
    required this.onOpenStatus,
    this.onLongPress,
    super.key,
  });

  /// The member shown.
  final Profile profile;

  /// Called when the tile is tapped.
  final VoidCallback onOpen;

  /// Called when the status ring badge is tapped.
  final VoidCallback onOpenStatus;

  /// Called when the tile is long-pressed.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final ring = ringFor(profile, ref.watch(seenStatusOwnersProvider));
    final statusLabel = statusRingLabel(l10n, ring);
    return Semantics(
      button: true,
      label: [
        l10n.nameWithAge(profile.name, profile.age),
        l10n.distance(profile.distanceKm),
        if (profile.online) l10n.onlineNow,
        ?statusLabel,
      ].join(', '),
      child: Material(
        borderRadius: BorderRadius.circular(_tileRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          onLongPress: onLongPress,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'profile-photo-${profile.id}',
                child: ProfileAvatar(
                  name: profile.name,
                  seed: profile.id,
                  photoUrl: profile.thumbUrl,
                  mediaId: profile.thumbMediaId,
                  ownerId: profile.id,
                  size: double.infinity,
                  square: true,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ExcludeSemantics(child: _Caption(profile: profile)),
              ),
              Padding(
                padding: const EdgeInsets.all(_ringInset),
                child: IgnorePointer(
                  child: StatusRingFrame(
                    ring: ring,
                    radius: BorderRadius.circular(_tileRadius - _ringInset),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              if (ring != StatusRing.none)
                Positioned(
                  top: 0,
                  right: 0,
                  child: StatusRingTap(
                    profile: profile,
                    ring: ring,
                    onTap: onOpenStatus,
                    child: _RingBadge(ring: ring),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The name, age and distance over a transparent-to-black scrim.
class _Caption extends StatelessWidget {
  const _Caption({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0), // photo-overlay
            Colors.black.withValues(alpha: 0.7), // photo-overlay
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (profile.online) ...[
                  const OnlineDot(),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    [profile.name, ?profile.age].join(' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white, // photo-overlay
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              l10n.distance(profile.distanceKm),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8), // photo-overlay
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The text a screen reader adds for [ring], or null without a status.
String? statusRingLabel(AppLocalizations l10n, StatusRing ring) =>
    switch (ring) {
      StatusRing.none => null,
      StatusRing.unseen => l10n.statusRingNew,
      StatusRing.seen => l10n.statusRingSeen,
    };

/// Calls [onTap] when tapped and there is a status to see; at least 44 x 44
/// so it is easy to hit. Without a status it is just [child].
class StatusRingTap extends StatelessWidget {
  /// Creates the tap target for [profile]'s status [ring].
  const StatusRingTap({
    required this.profile,
    required this.ring,
    required this.onTap,
    required this.child,
    super.key,
  });

  /// Whose status this opens.
  final Profile profile;

  /// The member's status ring.
  final StatusRing ring;

  /// Called to open the statuses.
  final VoidCallback onTap;

  /// What is shown inside the target.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (ring == StatusRing.none) return child;
    return Semantics(
      container: true,
      button: true,
      label: AppLocalizations.of(context).statusViewOf(profile.name),
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('status-ring-${profile.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );
  }
}

/// A small ringed play button on a tile that marks the tappable status
/// target.
class _RingBadge extends StatelessWidget {
  const _RingBadge({required this.ring});

  final StatusRing ring;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 28,
      child: StatusRingFrame(
        ring: ring,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.45), // photo-overlay
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 16,
              color: Colors.white, // photo-overlay
            ),
          ),
        ),
      ),
    );
  }
}

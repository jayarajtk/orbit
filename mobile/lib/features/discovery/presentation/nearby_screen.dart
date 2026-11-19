import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/core/labels.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/glass_bar.dart';
import 'package:orbit/core/widgets/profile_avatar.dart';
import 'package:orbit/core/widgets/skeleton.dart';
import 'package:orbit/core/widgets/status_ring.dart';
import 'package:orbit/features/discovery/data/location_repository.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/features/discovery/presentation/filters_sheet.dart';
import 'package:orbit/features/discovery/presentation/profile_tile.dart';
import 'package:orbit/features/safety/presentation/safety_sheet.dart';
import 'package:orbit/features/status/presentation/status_providers.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// W6: grid of nearby members, nearest first.
class NearbyScreen extends ConsumerWidget {
  /// Creates the Nearby tab.
  const NearbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filters = ref.watch(filtersProvider);
    final grid = ref.watch(nearbyProfilesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: const FrostedBackground(edge: FrostedEdge.bottom),
        title: Text(l10n.appName),
        actions: [
          FilterChip(
            avatar: const OnlineDot(),
            label: Text(l10n.onlineFilter),
            selected: filters.onlineOnly,
            showCheckmark: false,
            onSelected: (value) => ref
                .read(filtersProvider.notifier)
                .update((f) => f.copyWith(onlineOnly: value)),
          ),
          IconButton(
            tooltip: l10n.filtersTooltip,
            isSelected: filters.isActive,
            icon: const Icon(Icons.tune),
            onPressed: () => showFiltersSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(allProfilesProvider.future),
        child: grid.when(
          loading: () => const _GridSkeleton(),
          error: (error, _) =>
              error is ApiException && error.isProblem('location-required')
              ? const _LocationNeeded()
              : _LoadError(onRetry: () => ref.invalidate(allProfilesProvider)),
          data: (profiles) => profiles.isEmpty
              ? ListView(
                  children: [
                    EmptyState(
                      icon: Icons.grid_view_outlined,
                      message: l10n.nearbyEmpty,
                    ),
                  ],
                )
              : _Grid(profiles: profiles),
        ),
      ),
    );
  }
}

const double _gutter = 2;

const _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  childAspectRatio: 0.8,
  mainAxisSpacing: _gutter,
  crossAxisSpacing: _gutter,
);

/// Shimmering tiles that stand in for the grid while it loads.
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: _gutter),
          sliver: SliverGrid.builder(
            itemCount: 12,
            gridDelegate: _gridDelegate,
            itemBuilder: (context, index) => const Skeleton(),
          ),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.profiles});

  final List<Profile> profiles;

  @override
  Widget build(BuildContext context) {
    final fresh = [
      for (final profile in profiles)
        if (profile.isNew) profile,
    ];
    return CustomScrollView(
      slivers: [
        // The frosted app bar floats over the page, so start below it.
        SliverPadding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        ),
        if (fresh.isNotEmpty)
          SliverToBoxAdapter(child: _FreshFaces(profiles: fresh)),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            0,
            _gutter,
            0,
            _gutter + MediaQuery.paddingOf(context).bottom,
          ),
          sliver: SliverGrid.builder(
            itemCount: profiles.length,
            gridDelegate: _gridDelegate,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return ProfileTile(
                key: ValueKey(profile.id),
                profile: profile,
                onOpen: () => context.push(AppRoutes.profile(profile.id)),
                onOpenStatus: () =>
                    context.push(AppRoutes.statuses(profile.id)),
                onLongPress: () => showSafetySheet(context, profile),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FreshFaces extends ConsumerWidget {
  const _FreshFaces({required this.profiles});

  final List<Profile> profiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final seen = ref.watch(seenStatusOwnersProvider);
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: profiles.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Center(
              child: Text(
                l10n.freshFaces,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            );
          }
          final profile = profiles[index - 1];
          final ring = ringFor(profile, seen);
          return Semantics(
            button: true,
            key: ValueKey('fresh-${profile.id}'),
            label: [
              l10n.nameWithAge(profile.name, profile.age),
              ?statusRingLabel(l10n, ring),
            ].join(', '),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push(AppRoutes.profile(profile.id)),
              child: Column(
                children: [
                  StatusRingTap(
                    profile: profile,
                    ring: ring,
                    onTap: () => context.push(AppRoutes.statuses(profile.id)),
                    child: StatusRingFrame(
                      ring: ring,
                      child: Padding(
                        padding: const EdgeInsets.all(3.5),
                        child: ProfileAvatar(
                          name: profile.name,
                          seed: profile.id,
                          photoUrl: profile.thumbUrl,
                          mediaId: profile.thumbMediaId,
                          ownerId: profile.id,
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ExcludeSemantics(
                    child: Text(
                      profile.name,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.loadFailed),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}

class _LocationNeeded extends ConsumerStatefulWidget {
  const _LocationNeeded();

  @override
  ConsumerState<_LocationNeeded> createState() => _LocationNeededState();
}

class _LocationNeededState extends ConsumerState<_LocationNeeded> {
  bool _busy = false;

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final shared = await ref
          .read(locationRepositoryProvider)
          .shareCurrentLocation();
      if (!shared) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.locationDenied)));
      }
      ref.invalidate(allProfilesProvider);
    } on ApiException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.actionFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A ListView so pull-to-refresh still works on this state.
    return ListView(
      children: [
        EmptyState(icon: Icons.place_outlined, message: l10n.locationNeeded),
        Center(
          child: FilledButton(
            onPressed: _busy ? null : _share,
            child: Text(l10n.shareLocation),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit/app/router.dart';
import 'package:orbit/core/labels.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/core/widgets/empty_state.dart';
import 'package:orbit/core/widgets/profile_avatar.dart';
import 'package:orbit/features/discovery/data/location_repository.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/presentation/discovery_providers.dart';
import 'package:orbit/features/discovery/presentation/filters_sheet.dart';
import 'package:orbit/features/safety/presentation/safety_sheet.dart';
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
      appBar: AppBar(
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
          loading: () => const Center(child: CircularProgressIndicator()),
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
        if (fresh.isNotEmpty)
          SliverToBoxAdapter(child: _FreshFaces(profiles: fresh)),
        SliverPadding(
          padding: const EdgeInsets.all(3),
          sliver: SliverGrid.builder(
            itemCount: profiles.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              childAspectRatio: 0.78,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
            ),
            itemBuilder: (context, index) => _ProfileTile(
              key: ValueKey(profiles[index].id),
              profile: profiles[index],
            ),
          ),
        ),
      ],
    );
  }
}

class _FreshFaces extends StatelessWidget {
  const _FreshFaces({required this.profiles});

  final List<Profile> profiles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 92,
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
          return Semantics(
            button: true,
            label: l10n.nameWithAge(profile.name, profile.age),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push(AppRoutes.profile(profile.id)),
              child: Column(
                children: [
                  ProfileAvatar(
                    name: profile.name,
                    seed: profile.id,
                    hasPhoto: profile.hasPhoto,
                    photoUrl: profile.thumbUrl,
                    size: 52,
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

class _ProfileTile extends ConsumerWidget {
  const _ProfileTile({required this.profile, super.key});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final distance = l10n.distance(profile.distanceKm);
    final online = profile.online ? ', ${l10n.onlineNow}' : '';
    return Semantics(
      button: true,
      label: '${l10n.nameWithAge(profile.name, profile.age)}, $distance$online',
      child: Material(
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.profile(profile.id)),
          onLongPress: () => showSafetySheet(context, profile),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ProfileAvatar(
                name: profile.name,
                seed: profile.id,
                hasPhoto: profile.hasPhoto,
                photoUrl: profile.thumbUrl,
                size: double.infinity,
                square: true,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
                    color: const Color(0xB80E0C1F),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (profile.online) ...[
                              const OnlineDot(size: 8),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                [profile.name, ?profile.age].join(' '),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          distance,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
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

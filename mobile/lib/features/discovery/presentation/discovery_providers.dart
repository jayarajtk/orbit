import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:orbit/app/env.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/discovery/data/api_profile_repository.dart';
import 'package:orbit/features/discovery/data/fake_profile_repository.dart';
import 'package:orbit/features/discovery/domain/discovery_filters.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/domain/profile_repository.dart';
import 'package:orbit/features/safety/presentation/safety_providers.dart';

/// Where profiles come from: the API when configured, else dummy data.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => AppEnv.usesApi
      ? ApiProfileRepository(ref.watch(dioProvider))
      : FakeProfileRepository(),
);

/// Current grid filters.
final filtersProvider = NotifierProvider<FiltersNotifier, DiscoveryFilters>(
  FiltersNotifier.new,
);

/// Holds the grid filters.
class FiltersNotifier extends Notifier<DiscoveryFilters> {
  @override
  DiscoveryFilters build() => const DiscoveryFilters();

  /// Applies [change] to the current filters.
  void update(DiscoveryFilters Function(DiscoveryFilters) change) =>
      state = change(state);

  /// Restores the defaults.
  void reset() => state = const DiscoveryFilters();
}

/// Nearby members for the current filters, as returned by the repository
/// (which filters on the server in API mode). Reloads when filters change and
/// on pull-to-refresh.
final allProfilesProvider = FutureProvider<List<Profile>>(
  (ref) =>
      ref.watch(profileRepositoryProvider).nearby(ref.watch(filtersProvider)),
);

/// Profiles by id from the current grid, for screens that only have an id.
final profilesByIdProvider = Provider<Map<String, Profile>>((ref) {
  final profiles = ref.watch(allProfilesProvider).value ?? const [];
  return {for (final profile in profiles) profile.id: profile};
});

/// One member: from the grid if loaded, otherwise fetched. Null when the
/// member doesn't exist or can't be shown (for example after a block).
final FutureProviderFamily<Profile?, String> profileByIdProvider =
    FutureProvider.family<Profile?, String>((
      ref,
      id,
    ) async {
      final cached = ref.watch(profilesByIdProvider)[id];
      if (cached != null) return cached;
      return ref.watch(profileRepositoryProvider).byId(id);
    });

/// The grid without blocked members (blocks hide people immediately, before
/// the next reload).
final nearbyProfilesProvider = Provider<AsyncValue<List<Profile>>>((ref) {
  final blocked = ref.watch(blockedProvider);
  return ref
      .watch(allProfilesProvider)
      .whenData(
        (profiles) => [
          for (final profile in profiles)
            if (!blocked.contains(profile.id)) profile,
        ],
      );
});

/// Favorite profile ids, synced with the server.
final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);

/// Holds favorites. Toggling updates the UI at once and reverts if the server
/// rejects the change.
class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Stars or un-stars [id].
  Future<void> toggle(String id) async {
    final previous = state;
    final favorite = !previous.contains(id);
    state = favorite ? {...previous, id} : ({...previous}..remove(id));
    try {
      await ref
          .read(profileRepositoryProvider)
          .setFavorite(id, favorite: favorite);
    } on Object {
      state = previous;
      rethrow;
    }
  }

  /// Loads favorites from the server (after sign-in).
  Future<void> load() async {
    state = await ref.read(profileRepositoryProvider).favoriteIds();
  }
}

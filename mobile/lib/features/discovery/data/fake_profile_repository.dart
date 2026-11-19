import 'package:orbit/features/discovery/data/dummy_profiles.dart';
import 'package:orbit/features/discovery/domain/discovery_filters.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/domain/profile_repository.dart';

/// Demo mode: serves [dummyProfiles] from memory, nearest first, filtered on
/// the device, with a short delay so loading states are visible.
class FakeProfileRepository implements ProfileRepository {
  /// Creates the repository over [profiles].
  FakeProfileRepository({
    List<Profile> profiles = dummyProfiles,
    this.latency = const Duration(milliseconds: 300),
  }) : _profiles = List<Profile>.unmodifiable(
         <Profile>[...profiles]..sort(
           (a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999),
         ),
       );

  final List<Profile> _profiles;
  final Set<String> _favorites = {};

  /// Simulated network delay.
  final Duration latency;

  @override
  Future<List<Profile>> nearby(DiscoveryFilters filters) async {
    await Future<void>.delayed(latency);
    return [
      for (final profile in _profiles)
        if (filters.matches(profile)) profile,
    ];
  }

  @override
  Future<Profile?> byId(String id) async {
    await Future<void>.delayed(latency);
    for (final profile in _profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  @override
  Future<Set<String>> favoriteIds() async => {..._favorites};

  @override
  Future<void> setFavorite(String id, {required bool favorite}) async {
    favorite ? _favorites.add(id) : _favorites.remove(id);
  }
}

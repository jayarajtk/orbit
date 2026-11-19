import 'package:orbit/features/discovery/domain/discovery_filters.dart';
import 'package:orbit/features/discovery/domain/profile.dart';

/// Other members' profiles and the member's favorites.
abstract interface class ProfileRepository {
  /// Members near the user who pass [filters], nearest first.
  Future<List<Profile>> nearby(DiscoveryFilters filters);

  /// One member, or null if they don't exist or can't be shown.
  Future<Profile?> byId(String id);

  /// Ids of the member's favorites.
  Future<Set<String>> favoriteIds();

  /// Stars or un-stars member [id].
  Future<void> setFavorite(String id, {required bool favorite});
}

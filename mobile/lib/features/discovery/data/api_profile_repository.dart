import 'package:dio/dio.dart';
import 'package:orbit/core/network/api_client.dart';
import 'package:orbit/features/discovery/domain/discovery_filters.dart';
import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/features/discovery/domain/profile_repository.dart';

/// Profiles from the Orbit API (`/discovery/grid`, `/profiles`, `/favorites`).
class ApiProfileRepository implements ProfileRepository {
  /// Creates the repository on [_dio].
  ApiProfileRepository(this._dio);

  /// Grid page size requested from the server (its maximum).
  static const pageSize = 60;

  final Dio _dio;

  @override
  Future<List<Profile>> nearby(DiscoveryFilters filters) {
    return guardApi(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/discovery/grid',
        queryParameters: gridQuery(filters),
      );
      final items = response.data!['items'] as List<dynamic>;
      return [
        for (final item in items)
          Profile.fromJson(item as Map<String, dynamic>),
      ];
    });
  }

  /// Query parameters for [filters]; defaults are left out.
  static Map<String, Object> gridQuery(DiscoveryFilters filters) => {
    'limit': pageSize,
    if (filters.minAge != DiscoveryFilters.minimumAge) 'minAge': filters.minAge,
    if (filters.maxAge != DiscoveryFilters.maximumAge) 'maxAge': filters.maxAge,
    if (filters.onlineOnly) 'onlineOnly': true,
    if (filters.lookingFor.isNotEmpty)
      'lookingFor': [for (final g in filters.lookingFor) g.apiValue],
    'maxDistanceKm': ?filters.maxDistanceKm,
  };

  @override
  Future<Profile?> byId(String id) async {
    try {
      return await guardApi(() async {
        final response = await _dio.get<Map<String, dynamic>>('/profiles/$id');
        return Profile.fromJson(response.data!);
      });
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Set<String>> favoriteIds() {
    return guardApi(() async {
      final response = await _dio.get<List<dynamic>>('/favorites');
      return {
        for (final item in response.data!)
          (item as Map<String, dynamic>)['id'] as String,
      };
    });
  }

  @override
  Future<void> setFavorite(String id, {required bool favorite}) {
    return guardApi(
      () => favorite
          ? _dio.post<void>('/favorites/$id')
          : _dio.delete<void>('/favorites/$id'),
    );
  }
}

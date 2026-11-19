import 'package:orbit/features/discovery/domain/profile.dart';

/// Grid filters. Empty [lookingFor] means "any".
class DiscoveryFilters {
  /// Creates filters; the defaults show everyone.
  const DiscoveryFilters({
    this.minAge = minimumAge,
    this.maxAge = maximumAge,
    this.onlineOnly = false,
    this.photoOnly = false,
    this.lookingFor = const {},
    this.maxDistanceKm,
  });

  /// Lowest selectable age.
  static const minimumAge = 18;

  /// Highest selectable age.
  static const maximumAge = 80;

  /// Lowest age shown.
  final int minAge;

  /// Highest age shown.
  final int maxAge;

  /// Only members online now.
  final bool onlineOnly;

  /// Only members with a photo.
  final bool photoOnly;

  /// Only members looking for at least one of these.
  final Set<LookingFor> lookingFor;

  /// Orbit+ only: hide members further than this. Null means no limit.
  /// Members who hide their distance are excluded when this is set.
  final int? maxDistanceKm;

  /// Whether any filter differs from the defaults.
  bool get isActive =>
      minAge != minimumAge ||
      maxAge != maximumAge ||
      onlineOnly ||
      photoOnly ||
      lookingFor.isNotEmpty ||
      maxDistanceKm != null;

  /// Whether [profile] passes every filter.
  bool matches(Profile profile) {
    final age = profile.age;
    // Hidden ages are filtered by the server, which knows the real age.
    if (age != null && (age < minAge || age > maxAge)) return false;
    if (onlineOnly && !profile.online) return false;
    if (photoOnly && !profile.hasPhoto) return false;
    if (lookingFor.isNotEmpty &&
        lookingFor.intersection(profile.lookingFor).isEmpty) {
      return false;
    }
    final limit = maxDistanceKm;
    if (limit != null) {
      final distance = profile.distanceKm;
      if (distance == null || distance > limit) return false;
    }
    return true;
  }

  /// Returns a copy with the given fields replaced. Pass
  /// [clearMaxDistance] to remove the distance limit.
  DiscoveryFilters copyWith({
    int? minAge,
    int? maxAge,
    bool? onlineOnly,
    bool? photoOnly,
    Set<LookingFor>? lookingFor,
    int? maxDistanceKm,
    bool clearMaxDistance = false,
  }) {
    return DiscoveryFilters(
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      onlineOnly: onlineOnly ?? this.onlineOnly,
      photoOnly: photoOnly ?? this.photoOnly,
      lookingFor: lookingFor ?? this.lookingFor,
      maxDistanceKm: clearMaxDistance
          ? null
          : maxDistanceKm ?? this.maxDistanceKm,
    );
  }
}

/// How long someone keeps access to a shared album.
enum AlbumAccess {
  /// 24 hours.
  day(Duration(hours: 24)),

  /// 7 days.
  week(Duration(days: 7)),

  /// Until the owner revokes it.
  untilRevoked(null)
  ;

  const AlbumAccess(this.duration);

  /// Access length; null means no expiry.
  final Duration? duration;
}

/// Access to one album granted to one member.
class AlbumGrant {
  /// Creates a grant.
  const AlbumGrant({
    required this.profileId,
    required this.expiresAt,
    required this.viewOnce,
  });

  /// Who can see the album.
  final String profileId;

  /// When access ends; null means until revoked.
  final DateTime? expiresAt;

  /// Whether photos disappear after one view.
  final bool viewOnce;
}

/// One of the user's private albums.
class Album {
  /// Creates an album.
  const Album({
    required this.id,
    required this.name,
    required this.photoCount,
    required this.isPrivate,
    this.grants = const [],
  });

  /// Stable id.
  final String id;

  /// Album name.
  final String name;

  /// Number of photos.
  final int photoCount;

  /// Whether the album may contain explicit photos (never public).
  final bool isPrivate;

  /// Members it is shared with.
  final List<AlbumGrant> grants;

  /// Grants still valid at [now].
  List<AlbumGrant> activeGrants(DateTime now) => [
    for (final grant in grants)
      if (grant.expiresAt == null || grant.expiresAt!.isAfter(now)) grant,
  ];

  /// Returns a copy with [grants] replaced.
  Album withGrants(List<AlbumGrant> grants) => Album(
    id: id,
    name: name,
    photoCount: photoCount,
    isPrivate: isPrivate,
    grants: List.unmodifiable(grants),
  );
}

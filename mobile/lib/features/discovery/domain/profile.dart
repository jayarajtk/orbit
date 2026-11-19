/// What a member is on Orbit for.
enum LookingFor {
  /// Just chatting.
  chat('CHAT'),

  /// Dating.
  dates('DATES'),

  /// Friendship.
  friends('FRIENDS'),

  /// Professional networking.
  networking('NETWORKING'),

  /// Meeting up soon.
  rightNow('RIGHT_NOW')
  ;

  const LookingFor(this.apiValue);

  /// Value used by the API.
  final String apiValue;

  /// Parses an API value; null for unknown values from a newer server.
  static LookingFor? fromApi(String value) {
    for (final goal in values) {
      if (goal.apiValue == value) return goal;
    }
    return null;
  }
}

/// Relationship status a member may choose to show.
enum RelationshipStatus {
  /// Single.
  single('SINGLE'),

  /// Seeing someone.
  dating('DATING'),

  /// In a partnership.
  partnered('PARTNERED'),

  /// In an open relationship.
  open('OPEN')
  ;

  const RelationshipStatus(this.apiValue);

  /// Value used by the API.
  final String apiValue;

  /// Parses an API value; null for unknown or missing values.
  static RelationshipStatus? fromApi(String? value) {
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    return null;
  }
}

/// A public profile photo with short-lived links.
class ProfilePhoto {
  /// Creates a photo.
  const ProfilePhoto({required this.id, required this.url, this.thumbUrl});

  /// Parses the API's photo object.
  factory ProfilePhoto.fromJson(Map<String, dynamic> json) => ProfilePhoto(
    id: json['id'] as String,
    url: json['url'] as String,
    thumbUrl: json['thumbUrl'] as String?,
  );

  /// Media id.
  final String id;

  /// Full-size image.
  final String url;

  /// Small image for lists.
  final String? thumbUrl;
}

/// Another member as seen in discovery. Distances are already bucketed by
/// the server (ADR-0003); the client never sees exact positions.
class Profile {
  /// Creates a profile.
  const Profile({
    required this.id,
    required this.name,
    required this.age,
    required this.distanceKm,
    required this.online,
    required this.bio,
    required this.lookingFor,
    required this.tags,
    required this.photoCount,
    required this.isNew,
    this.pronouns,
    this.heightCm,
    this.relationship,
    this.photos = const [],
  });

  /// Builds a profile from the API's `PersonView` JSON.
  factory Profile.fromJson(Map<String, dynamic> json) {
    String? nonEmpty(Object? value) =>
        value is String && value.isNotEmpty ? value : null;
    return Profile(
      id: json['id'] as String,
      name: json['displayName'] as String,
      age: json['age'] as int?,
      distanceKm: json['distanceKm'] as int?,
      online: json['online'] as bool? ?? false,
      bio: json['bio'] as String? ?? '',
      lookingFor: {
        for (final v in (json['lookingFor'] as List<dynamic>? ?? const []))
          ?LookingFor.fromApi(v as String),
      },
      tags: [
        for (final t in (json['tags'] as List<dynamic>? ?? const []))
          t as String,
      ],
      photoCount: json['photoCount'] as int? ?? 0,
      isNew: json['isNew'] as bool? ?? false,
      pronouns: nonEmpty(json['pronouns']),
      heightCm: json['heightCm'] as int?,
      relationship: RelationshipStatus.fromApi(json['relationship'] as String?),
      photos: [
        for (final p in (json['photos'] as List<dynamic>? ?? const []))
          ProfilePhoto.fromJson(p as Map<String, dynamic>),
      ],
    );
  }

  /// Distance bucket meaning "more than 10 km".
  static const tenPlusKm = 11;

  /// Stable id.
  final String id;

  /// Display name.
  final String name;

  /// Age in whole years; null when the member hides it.
  final int? age;

  /// Distance bucket in km: 0 means under 1 km, [tenPlusKm] means more than
  /// 10 km, null means hidden.
  final int? distanceKm;

  /// Whether the member is online now.
  final bool online;

  /// Short bio.
  final String bio;

  /// What they're looking for.
  final Set<LookingFor> lookingFor;

  /// Interest tags without the leading `#`.
  final List<String> tags;

  /// Number of public photos; 0 shows a placeholder.
  final int photoCount;

  /// Whether the member joined within the last week ("Fresh faces").
  final bool isNew;

  /// Optional pronouns.
  final String? pronouns;

  /// Optional height.
  final int? heightCm;

  /// Optional relationship status.
  final RelationshipStatus? relationship;

  /// Photos with links: the first one in lists, all of them on a profile.
  /// Empty in demo mode, where placeholders stand in.
  final List<ProfilePhoto> photos;

  /// Whether the member has at least one public photo.
  bool get hasPhoto => photoCount > 0;

  /// Small image for avatars and grid tiles, if any.
  String? get thumbUrl => photos.isEmpty ? null : photos.first.thumbUrl;
}

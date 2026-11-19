import 'package:orbit/features/discovery/domain/profile.dart';

/// The signed-in member's own profile. The birth date stays on the server;
/// only the age is known here.
class MyProfile {
  /// Creates a profile.
  const MyProfile({
    required this.displayName,
    required this.age,
    this.bio = '',
    this.pronouns = '',
    this.heightCm,
    this.relationship,
    this.lookingFor = const {},
    this.tags = const [],
    this.showAge = true,
    this.showDistance = true,
    this.photos = const [],
  });

  /// Builds a profile from the API's `MyProfile` JSON.
  factory MyProfile.fromJson(Map<String, dynamic> json) {
    return MyProfile(
      displayName: json['displayName'] as String,
      age: json['age'] as int,
      bio: json['bio'] as String? ?? '',
      pronouns: json['pronouns'] as String? ?? '',
      heightCm: json['heightCm'] as int?,
      relationship: RelationshipStatus.fromApi(json['relationship'] as String?),
      lookingFor: {
        for (final v in (json['lookingFor'] as List<dynamic>? ?? const []))
          ?LookingFor.fromApi(v as String),
      },
      tags: [
        for (final t in (json['tags'] as List<dynamic>? ?? const []))
          t as String,
      ],
      showAge: json['showAge'] as bool? ?? true,
      showDistance: json['showDistance'] as bool? ?? true,
      photos: [
        for (final p in (json['photos'] as List<dynamic>? ?? const []))
          ProfilePhoto.fromJson(p as Map<String, dynamic>),
      ],
    );
  }

  /// Display name.
  final String displayName;

  /// Age in whole years.
  final int age;

  /// About me.
  final String bio;

  /// Pronouns, or empty.
  final String pronouns;

  /// Height in cm, if given.
  final int? heightCm;

  /// Relationship status, if shown.
  final RelationshipStatus? relationship;

  /// What the member is looking for.
  final Set<LookingFor> lookingFor;

  /// Interest tags.
  final List<String> tags;

  /// Whether the age is shown on the profile.
  final bool showAge;

  /// Whether the distance is shown to others.
  final bool showDistance;

  /// Public photos in display order. Saved separately from the profile.
  final List<ProfilePhoto> photos;

  /// The `PUT /me/profile` body.
  Map<String, Object?> toJson() => {
    'displayName': displayName,
    'bio': bio,
    'pronouns': pronouns,
    'heightCm': heightCm,
    'relationship': relationship?.apiValue,
    'lookingFor': [for (final g in lookingFor) g.apiValue],
    'tags': tags,
    'showAge': showAge,
    'showDistance': showDistance,
  };

  /// Share of optional fields filled in, 0–100.
  int get completionPercent {
    const total = 6;
    var filled = 1; // display name is required
    if (photos.isNotEmpty) filled++;
    if (bio.isNotEmpty) filled++;
    if (pronouns.isNotEmpty) filled++;
    if (lookingFor.isNotEmpty) filled++;
    if (tags.isNotEmpty) filled++;
    return (filled * 100 / total).round();
  }

  /// Returns a copy with the given fields replaced. Pass [clearHeight] to
  /// remove the height.
  MyProfile copyWith({
    String? displayName,
    String? bio,
    String? pronouns,
    int? heightCm,
    bool clearHeight = false,
    Set<LookingFor>? lookingFor,
    List<String>? tags,
    bool? showAge,
    bool? showDistance,
    List<ProfilePhoto>? photos,
  }) {
    return MyProfile(
      displayName: displayName ?? this.displayName,
      age: age,
      bio: bio ?? this.bio,
      pronouns: pronouns ?? this.pronouns,
      heightCm: clearHeight ? null : heightCm ?? this.heightCm,
      relationship: relationship,
      lookingFor: lookingFor ?? this.lookingFor,
      tags: tags ?? this.tags,
      showAge: showAge ?? this.showAge,
      showDistance: showDistance ?? this.showDistance,
      photos: photos ?? this.photos,
    );
  }
}

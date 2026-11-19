import 'package:orbit/features/discovery/domain/profile.dart';
import 'package:orbit/l10n/app_localizations.dart';

/// Localized labels for domain values, so domain code stays UI-free.
extension DomainLabels on AppLocalizations {
  /// Label for a [LookingFor] value.
  String lookingFor(LookingFor value) => switch (value) {
    LookingFor.chat => lookingForChat,
    LookingFor.dates => lookingForDates,
    LookingFor.friends => lookingForFriends,
    LookingFor.networking => lookingForNetworking,
    LookingFor.rightNow => lookingForRightNow,
  };

  /// Label for a [RelationshipStatus].
  String relationship(RelationshipStatus value) => switch (value) {
    RelationshipStatus.single => relationshipSingle,
    RelationshipStatus.dating => relationshipDating,
    RelationshipStatus.partnered => relationshipPartnered,
    RelationshipStatus.open => relationshipOpen,
  };

  /// Distance bucket label: "<1 km", "3 km", "10+ km" or "Distance hidden".
  String distance(int? km) => switch (km) {
    null => distanceHidden,
    0 => distanceUnder1Km,
    >= Profile.tenPlusKm => distanceTenPlus,
    _ => distanceKm(km),
  };

  /// "Alex, 27", or just "Alex" when the member hides their age.
  String nameWithAge(String name, int? age) =>
      age == null ? name : nameAge(name, age);
}

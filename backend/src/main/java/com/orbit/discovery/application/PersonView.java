package com.orbit.discovery.application;

import com.orbit.discovery.domain.DistanceBucket;
import com.orbit.discovery.infrastructure.DiscoveryStore.PersonRow;
import com.orbit.media.MediaApi.Links;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.Period;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Another member as the caller sees them. Never includes a birth date or a raw distance.
 *
 * @param age null when the member hides it
 * @param distanceKm bucket from {@link DistanceBucket}, or null when hidden or unknown
 * @param photoCount public photos the member has
 * @param photos with short-lived links: the first one in the grid, all of them on a profile
 */
public record PersonView(
    UUID id,
    String displayName,
    Integer age,
    Integer distanceKm,
    boolean online,
    boolean isNew,
    boolean favorite,
    int photoCount,
    String bio,
    String pronouns,
    Integer heightCm,
    String relationship,
    List<String> lookingFor,
    List<String> tags,
    List<Photo> photos) {

  /** A public photo. */
  public record Photo(UUID id, String url, String thumbUrl) {}

  /** How recently a member must have been active to show as online. */
  public static final Duration ONLINE_WINDOW = Duration.ofMinutes(10);

  /** How long a member counts as new ("Fresh faces"). */
  public static final Duration NEW_WINDOW = Duration.ofDays(7);

  /**
   * Builds the view with up to {@code maxPhotos} photos, taking links from {@code links} (photos
   * without a link are skipped).
   */
  static PersonView of(
      PersonRow row, Instant now, LocalDate today, Map<UUID, Links> links, int maxPhotos) {
    Integer distance =
        row.showDistance() && row.meters() != null ? DistanceBucket.of(row.meters()) : null;
    return new PersonView(
        row.id(),
        row.displayName(),
        row.showAge() ? Period.between(row.birthDate(), today).getYears() : null,
        distance,
        row.lastActiveAt().isAfter(now.minus(ONLINE_WINDOW)),
        row.joinedAt().isAfter(now.minus(NEW_WINDOW)),
        row.favorite(),
        row.photoIds().size(),
        row.bio(),
        row.pronouns(),
        row.heightCm(),
        row.relationship(),
        row.lookingFor(),
        row.tags(),
        row.photoIds().stream()
            .limit(maxPhotos)
            .filter(links::containsKey)
            .map(id -> new Photo(id, links.get(id).url(), links.get(id).thumbUrl()))
            .toList());
  }
}

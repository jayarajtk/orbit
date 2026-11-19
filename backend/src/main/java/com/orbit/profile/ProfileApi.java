package com.orbit.profile;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/** What other modules may ask of profiles. */
public interface ProfileApi {

  /** Marks the member active now, which drives the "online" dot. */
  void touch(UUID accountId);

  /** Display names for the given members; members without a profile are absent. */
  Map<UUID, String> displayNames(Collection<UUID> accountIds);

  /** The member's profile as moderators review it, if they have one. */
  Optional<Card> card(UUID accountId);

  /**
   * Members whose display name starts with {@code prefix}, ignoring case, at most {@code limit}.
   */
  List<UUID> findByNamePrefix(String prefix, int limit);

  /**
   * Takes {@code mediaId} off {@code accountId}'s public photos, keeping the others in order.
   * Returns whether it was one of them.
   */
  boolean removePhoto(UUID accountId, UUID mediaId);

  /**
   * A profile for review.
   *
   * @param photoIds public photos in display order
   */
  record Card(
      String displayName,
      String bio,
      String pronouns,
      List<String> tags,
      List<UUID> photoIds,
      Instant lastActiveAt) {}
}

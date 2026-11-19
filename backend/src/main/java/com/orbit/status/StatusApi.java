package com.orbit.status;

import java.time.Instant;
import java.util.Collection;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/** What other modules may ask of statuses. */
public interface StatusApi {

  /**
   * Whether each owner has live statuses and whether {@code viewerId} has seen all of them, in one
   * query. Every owner asked about is in the result. Visibility is not checked here: callers pass
   * only members the viewer may already see.
   */
  Map<UUID, StatusState> statesFor(UUID viewerId, Collection<UUID> ownerIds);

  /** {@code ownerId}'s status {@code statusId} if it is still live, for report evidence. */
  Optional<StatusEvidence> liveStatusOf(UUID ownerId, UUID statusId);

  /** A member's statuses as one viewer sees them. */
  enum StatusState {
    /** No live statuses. */
    NONE,
    /** At least one live status the viewer hasn't seen. */
    UNSEEN,
    /** The viewer has seen every live status. */
    SEEN
  }

  /** A live status as a report keeps it. */
  record StatusEvidence(UUID id, UUID mediaId, String caption, Instant createdAt) {}

  /**
   * Published when a status is gone (deleted early or expired) so its photo can be purged. It goes
   * through the event publication registry, so a failed purge is retried.
   */
  record StatusExpired(UUID statusId, UUID mediaId) {}
}

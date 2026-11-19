package com.orbit.status.application;

import com.orbit.identity.IdentityApi;
import com.orbit.media.MediaApi;
import com.orbit.media.MediaApi.Kind;
import com.orbit.media.MediaApi.Links;
import com.orbit.profile.ProfileApi;
import com.orbit.safety.SafetyApi;
import com.orbit.status.StatusApi;
import com.orbit.status.application.StatusViews.MyStatus;
import com.orbit.status.application.StatusViews.StatusItem;
import com.orbit.status.application.StatusViews.Viewer;
import com.orbit.status.infrastructure.StatusStore;
import com.orbit.status.infrastructure.StatusStore.StatusRow;
import com.orbit.status.infrastructure.StatusStore.ViewRow;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 24-hour photo statuses (spec §8.1). Others see a member's statuses under the same rules as their
 * profile; anything they may not see is reported as missing, so a block or restriction is never
 * revealed. Logs carry ids only, never captions or links.
 */
@Service
public class StatusService implements StatusApi {

  /** Live statuses per member. */
  public static final int MAX_LIVE = 10;

  /** Longest caption, in characters. */
  public static final int MAX_CAPTION = 100;

  /** How long a status lives. */
  public static final Duration LIFETIME = Duration.ofHours(24);

  /** The only media purpose a status accepts. */
  static final String STATUS_PHOTO = "STATUS_PHOTO";

  private static final Logger log = LoggerFactory.getLogger(StatusService.class);

  private final StatusStore store;
  private final IdentityApi identity;
  private final SafetyApi safety;
  private final ProfileApi profiles;
  private final MediaApi media;
  private final ApplicationEventPublisher events;
  private final Clock clock;
  private final Counter posted;
  private final Counter viewed;

  public StatusService(
      StatusStore store,
      IdentityApi identity,
      SafetyApi safety,
      ProfileApi profiles,
      MediaApi media,
      ApplicationEventPublisher events,
      Clock clock,
      MeterRegistry meters) {
    this.store = store;
    this.identity = identity;
    this.safety = safety;
    this.profiles = profiles;
    this.media = media;
    this.events = events;
    this.clock = clock;
    this.posted = meters.counter("orbit.status.posted");
    this.viewed = meters.counter("orbit.status.viewed");
  }

  /**
   * Posts a status from one of the caller's status photos.
   *
   * @param caption at most {@link #MAX_CAPTION} characters (checked at the API boundary); blank
   *     means none
   * @throws IdentityApi.AccountRestrictedException if the caller is suspended or banned
   * @throws MediaApi.MediaUnavailableException if the photo isn't the caller's ready status photo,
   *     or the scanner allows it only in private
   * @throws InvalidStatusException if the photo is already used by another status
   * @throws StatusLimitException if the caller already has {@link #MAX_LIVE} live statuses
   */
  @Transactional
  public MyStatus post(String callerSubject, UUID mediaId, String caption) {
    UUID me = identity.require(callerSubject).id();
    // A status reaches the same audience as the profile, so the public-photo rule applies.
    media.requireAttachable(me, mediaId, Kind.PHOTO, true);
    media.requirePurpose(me, mediaId, STATUS_PHOTO);
    Instant now = clock.instant();
    // Serializes this member's posts, so two concurrent posts can't both take the last slot.
    store.lockOwner(me);
    if (store.usesMedia(mediaId)) {
      // Deleting either status would purge the photo out from under the other.
      throw new InvalidStatusException();
    }
    if (store.countLive(me, now) >= MAX_LIVE) {
      throw new StatusLimitException();
    }
    String text = caption == null || caption.isBlank() ? null : caption.strip();
    StatusRow row = new StatusRow(UUID.randomUUID(), me, mediaId, text, now, now.plus(LIFETIME));
    store.insert(row, now);
    posted.increment();
    log.info("Status {} posted by account {}", row.id(), me);
    return mine(row, media.links(List.of(mediaId)), List.of());
  }

  /** The caller's live statuses, oldest first, each with who viewed it. */
  @Transactional(readOnly = true)
  public List<MyStatus> mine(String callerSubject) {
    UUID me = identity.require(callerSubject).id();
    List<StatusRow> rows = store.liveOf(me, clock.instant());
    if (rows.isEmpty()) {
      return List.of();
    }
    Set<UUID> blocked = safety.blockedEitherWay(me);
    List<ViewRow> views =
        store.views(rows.stream().map(StatusRow::id).toList()).stream()
            .filter(v -> !blocked.contains(v.viewerId()))
            .toList();
    Set<UUID> viewerIds = views.stream().map(ViewRow::viewerId).collect(Collectors.toSet());
    Map<UUID, String> names = profiles.displayNames(viewerIds);
    Map<UUID, UUID> photos = profiles.mainPhotoIds(viewerIds);
    Map<UUID, Links> links =
        media.links(
            Stream.concat(rows.stream().map(StatusRow::mediaId), photos.values().stream())
                .toList());
    Map<UUID, List<Viewer>> viewersByStatus = new HashMap<>();
    for (ViewRow view : views) {
      String name = names.get(view.viewerId());
      if (name == null) {
        // No profile any more: nothing to show.
        continue;
      }
      Links photo = links.get(photos.get(view.viewerId()));
      viewersByStatus
          .computeIfAbsent(view.statusId(), id -> new ArrayList<>())
          .add(
              new Viewer(
                  view.viewerId(), name, photo == null ? null : photo.thumbUrl(), view.viewedAt()));
    }
    return rows.stream()
        .map(row -> mine(row, links, viewersByStatus.getOrDefault(row.id(), List.of())))
        .toList();
  }

  /**
   * Deletes one of the caller's statuses early. Its photo is purged through {@link StatusExpired},
   * like an expired one.
   *
   * @throws StatusNotFoundException if the caller has no such status
   */
  @Transactional
  public void delete(String callerSubject, UUID statusId) {
    UUID me = identity.require(callerSubject).id();
    UUID mediaId = store.deleteOwned(me, statusId).orElseThrow(StatusNotFoundException::new);
    events.publishEvent(new StatusExpired(statusId, mediaId));
    log.info("Status {} deleted by account {}", statusId, me);
  }

  /**
   * Another member's live statuses, oldest first, with whether the caller has seen each.
   *
   * @throws StatusNotFoundException if the caller may not see that member's profile
   */
  @Transactional(readOnly = true)
  public List<StatusItem> statusesOf(String callerSubject, UUID ownerId) {
    UUID me = identity.require(callerSubject).id();
    requireVisible(me, ownerId);
    Instant now = clock.instant();
    List<StatusRow> rows = store.liveOf(ownerId, now);
    if (rows.isEmpty()) {
      return List.of();
    }
    Set<UUID> seen = new HashSet<>(store.seenBy(me, ownerId, now));
    Map<UUID, Links> links = media.links(rows.stream().map(StatusRow::mediaId).toList());
    // A photo moderation took down has no links; the status is then not shown to others.
    return rows.stream()
        .filter(row -> links.containsKey(row.mediaId()))
        .map(row -> {
          Links photo = links.get(row.mediaId());
          return new StatusItem(
              row.id(),
              photo.url(),
              photo.thumbUrl(),
              row.caption(),
              row.createdAt(),
              seen.contains(row.id()));
        })
        .toList();
  }

  /**
   * Marks a status seen by the caller. Idempotent; the owner's own views are not recorded.
   *
   * @throws StatusNotFoundException if there is no such live status the caller may see
   */
  @Transactional
  public void view(String callerSubject, UUID statusId) {
    UUID me = identity.require(callerSubject).id();
    Instant now = clock.instant();
    StatusRow row = store.findLive(statusId, now).orElseThrow(StatusNotFoundException::new);
    requireVisible(me, row.ownerId());
    if (me.equals(row.ownerId())) {
      return;
    }
    try {
      if (store.recordView(statusId, me, now)) {
        viewed.increment();
      }
    } catch (DataIntegrityViolationException e) {
      // The status was deleted (by the reaper or its owner) after the live check above.
      throw new StatusNotFoundException();
    }
  }

  // --- StatusApi -------------------------------------------------------------------------------

  @Override
  @Transactional(readOnly = true)
  public Map<UUID, StatusState> statesFor(UUID viewerId, Collection<UUID> ownerIds) {
    if (ownerIds.isEmpty()) {
      return Map.of();
    }
    Map<UUID, Boolean> allSeen = store.allSeen(viewerId, ownerIds, clock.instant());
    Map<UUID, StatusState> states = new LinkedHashMap<>();
    for (UUID owner : ownerIds) {
      Boolean seen = allSeen.get(owner);
      StatusState state;
      if (seen == null) {
        state = StatusState.NONE;
      } else {
        state = seen ? StatusState.SEEN : StatusState.UNSEEN;
      }
      states.put(owner, state);
    }
    return states;
  }

  @Override
  @Transactional(readOnly = true)
  public Optional<StatusEvidence> liveStatusOf(UUID ownerId, UUID statusId) {
    return store
        .findLive(statusId, clock.instant())
        .filter(row -> row.ownerId().equals(ownerId))
        .map(row -> new StatusEvidence(row.id(), row.mediaId(), row.caption(), row.createdAt()));
  }

  /**
   * The same rules as {@code GET /api/v1/profiles/{id}}: the viewer has a profile, neither has
   * blocked the other, and the owner is active, not restricted and has a profile. Owners always see
   * their own.
   */
  private void requireVisible(UUID viewerId, UUID ownerId) {
    if (viewerId.equals(ownerId)) {
      return;
    }
    boolean visible =
        profiles.card(viewerId).isPresent()
            && !safety.isBlockedEitherWay(viewerId, ownerId)
            && identity
                .findById(ownerId)
                .filter(owner -> owner.active() && !owner.restricted())
                .isPresent()
            && profiles.card(ownerId).isPresent();
    if (!visible) {
      throw new StatusNotFoundException();
    }
  }

  private static MyStatus mine(StatusRow row, Map<UUID, Links> links, List<Viewer> viewers) {
    Links photo = links.get(row.mediaId());
    return new MyStatus(
        row.id(),
        photo == null ? null : photo.url(),
        photo == null ? null : photo.thumbUrl(),
        row.caption(),
        row.createdAt(),
        row.expiresAt(),
        viewers.size(),
        List.copyOf(viewers));
  }

  /** The member already has {@link #MAX_LIVE} live statuses. */
  public static class StatusLimitException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public StatusLimitException() {
      super("Status limit reached");
    }
  }

  /** No such status, or one the caller may not see (the two are never told apart). */
  public static class StatusNotFoundException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public StatusNotFoundException() {
      super("Status not found");
    }
  }

  /** The status can't be posted as given. */
  public static class InvalidStatusException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public InvalidStatusException() {
      super("Invalid status");
    }
  }
}

package com.orbit.discovery.application;

import com.orbit.discovery.domain.GeoPoint;
import com.orbit.discovery.domain.LocationSnapper;
import com.orbit.discovery.domain.LocationSnapper.Snapped;
import com.orbit.discovery.infrastructure.DiscoveryStore;
import com.orbit.discovery.infrastructure.DiscoveryStore.GridFilter;
import com.orbit.discovery.infrastructure.DiscoveryStore.PersonRow;
import com.orbit.discovery.infrastructure.DiscoveryStore.StoredLocation;
import com.orbit.identity.IdentityApi;
import com.orbit.media.MediaApi;
import com.orbit.media.MediaApi.Links;
import com.orbit.profile.ProfileApi;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Location updates, the nearby grid, other members' profiles and favorites. */
@Service
public class DiscoveryService {

  /** At most one location update per member per minute (ADR-0003). */
  public static final Duration MIN_UPDATE_INTERVAL = Duration.ofSeconds(60);

  /** Faster than an airliner means a spoofed location (ADR-0003). */
  public static final double MAX_SPEED_METERS_PER_SECOND = 250;

  /** Grid page size limit. */
  public static final int MAX_PAGE_SIZE = 60;

  /** Photos per member in lists; a profile shows all of them. */
  static final int GRID_PHOTOS = 1;

  private static final Logger log = LoggerFactory.getLogger(DiscoveryService.class);

  private final DiscoveryStore store;
  private final LocationSnapper snapper;
  private final IdentityApi identity;
  private final ProfileApi profiles;
  private final MediaApi media;
  private final Clock clock;

  public DiscoveryService(
      DiscoveryStore store,
      IdentityApi identity,
      ProfileApi profiles,
      MediaApi media,
      Clock clock) {
    this.store = store;
    this.snapper = new LocationSnapper();
    this.identity = identity;
    this.profiles = profiles;
    this.media = media;
    this.clock = clock;
  }

  /**
   * Stores the caller's snapped location. The exact position is used only inside this call.
   *
   * @throws LocationRateLimitedException within a minute of the previous update
   * @throws ImplausibleMovementException when the jump implies an impossible speed
   */
  @Transactional
  public void updateLocation(String callerSubject, GeoPoint exact) {
    UUID me = identity.require(callerSubject).id();
    Instant now = clock.instant();
    Snapped snapped = snapper.snap(me, exact);
    Optional<StoredLocation> previous = store.location(me);
    if (previous.isPresent()) {
      Duration elapsed = Duration.between(previous.get().updatedAt(), now);
      if (elapsed.compareTo(MIN_UPDATE_INTERVAL) < 0) {
        throw new LocationRateLimitedException();
      }
      double meters = previous.get().point().metersTo(snapped.point());
      if (meters / Math.max(1, elapsed.toSeconds()) > MAX_SPEED_METERS_PER_SECOND) {
        log.warn("Implausible location jump rejected for account {}", me);
        throw new ImplausibleMovementException();
      }
    }
    store.saveLocation(me, snapped, now);
    profiles.touch(me);
  }

  /**
   * One page of the nearby grid, nearest first.
   *
   * @throws LocationRequiredException if the caller has never shared a location
   */
  @Transactional(readOnly = true)
  public GridPage grid(String callerSubject, GridQuery query) {
    UUID me = identity.require(callerSubject).id();
    if (store.location(me).isEmpty()) {
      throw new LocationRequiredException();
    }
    Instant now = clock.instant();
    LocalDate today = LocalDate.now(clock);
    int limit = Math.min(Math.max(query.limit(), 1), MAX_PAGE_SIZE);
    GridFilter filter =
        new GridFilter(
            today.minusYears(query.minAge()),
            today.minusYears(query.maxAge() + 1L),
            query.onlineOnly() ? now.minus(PersonView.ONLINE_WINDOW) : null,
            query.lookingFor(),
            query.maxDistanceKm() == null ? null : query.maxDistanceKm() * 1_000.0);
    // Fetch one extra row to know whether another page exists.
    List<PersonView> rows =
        views(store.nearby(me, filter, limit + 1, query.offset()), now, today, GRID_PHOTOS);
    boolean more = rows.size() > limit;
    return new GridPage(more ? rows.subList(0, limit) : rows, more ? query.offset() + limit : null);
  }

  /**
   * Another member's profile.
   *
   * @throws PersonNotFoundException if missing, inactive, the caller, or blocked either way
   */
  @Transactional(readOnly = true)
  public PersonView person(String callerSubject, UUID id) {
    UUID me = identity.require(callerSubject).id();
    PersonRow row = store.person(me, id).orElseThrow(PersonNotFoundException::new);
    return views(List.of(row), clock.instant(), LocalDate.now(clock), Integer.MAX_VALUE).getFirst();
  }

  @Transactional(readOnly = true)
  public List<PersonView> favorites(String callerSubject) {
    UUID me = identity.require(callerSubject).id();
    Instant now = clock.instant();
    LocalDate today = LocalDate.now(clock);
    return views(store.favorites(me), now, today, GRID_PHOTOS);
  }

  /**
   * Stars a member. Idempotent.
   *
   * @throws PersonNotFoundException if the member can't be seen by the caller
   */
  @Transactional
  public void addFavorite(String callerSubject, UUID id) {
    UUID me = identity.require(callerSubject).id();
    if (store.person(me, id).isEmpty()) {
      throw new PersonNotFoundException();
    }
    store.addFavorite(me, id, clock.instant());
  }

  @Transactional
  public void removeFavorite(String callerSubject, UUID id) {
    store.removeFavorite(identity.require(callerSubject).id(), id);
  }

  /** Views for {@code rows}, fetching links for all their photos in one query. */
  private List<PersonView> views(
      List<PersonRow> rows, Instant now, LocalDate today, int maxPhotos) {
    Map<UUID, Links> links =
        media.links(rows.stream().flatMap(r -> r.photoIds().stream().limit(maxPhotos)).toList());
    return rows.stream().map(r -> PersonView.of(r, now, today, links, maxPhotos)).toList();
  }

  /**
   * Grid request.
   *
   * @param offset rows to skip (from the previous page's cursor)
   * @param maxDistanceKm Orbit+ filter; null for no limit
   */
  public record GridQuery(
      int minAge,
      int maxAge,
      boolean onlineOnly,
      List<String> lookingFor,
      Integer maxDistanceKm,
      int offset,
      int limit) {}

  /**
   * A grid page.
   *
   * @param nextOffset offset for the next page, or null at the end
   */
  public record GridPage(List<PersonView> items, Integer nextOffset) {}

  /** Location updated less than a minute ago. */
  public static class LocationRateLimitedException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public LocationRateLimitedException() {
      super("Location updated too recently");
    }
  }

  /** The new location implies an impossible speed. */
  public static class ImplausibleMovementException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public ImplausibleMovementException() {
      super("Implausible movement");
    }
  }

  /** The caller has no location yet. */
  public static class LocationRequiredException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public LocationRequiredException() {
      super("Location required");
    }
  }

  /** The member can't be shown to the caller. */
  public static class PersonNotFoundException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public PersonNotFoundException() {
      super("Person not found");
    }
  }
}

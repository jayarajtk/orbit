package com.orbit.media.application;

import com.orbit.identity.IdentityApi;
import com.orbit.identity.IdentityApi.AccountSummary;
import com.orbit.media.MediaApi.Kind;
import com.orbit.media.MediaApi.Links;
import com.orbit.media.infrastructure.AlbumStore;
import com.orbit.media.infrastructure.AlbumStore.AlbumRow;
import com.orbit.media.infrastructure.AlbumStore.GrantRow;
import com.orbit.media.infrastructure.AlbumStore.SharedRow;
import com.orbit.safety.SafetyApi;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Private albums. Only the owner and members with a current grant can open one; a block either way
 * ends access at once, and a view-once grant works for a single opening.
 */
@Service
public class AlbumService {

  /** Albums per member. */
  public static final int MAX_ALBUMS = 20;

  /** Photos per album. */
  public static final int MAX_PHOTOS = 60;

  private final AlbumStore albums;
  private final MediaService media;
  private final IdentityApi identity;
  private final SafetyApi safety;
  private final Clock clock;

  public AlbumService(
      AlbumStore albums, MediaService media, IdentityApi identity, SafetyApi safety, Clock clock) {
    this.albums = albums;
    this.media = media;
    this.identity = identity;
    this.safety = safety;
    this.clock = clock;
  }

  /** The caller's albums with their current grants. */
  @Transactional(readOnly = true)
  public List<OwnAlbum> mine(String callerSubject) {
    UUID me = me(callerSubject);
    Instant now = clock.instant();
    return albums.owned(me).stream()
        .map(a -> new OwnAlbum(a.id(), a.name(), a.photoCount(), albums.grants(a.id(), now)))
        .toList();
  }

  /**
   * Creates an album.
   *
   * @throws AlbumLimitException at {@link #MAX_ALBUMS}
   */
  @Transactional
  public UUID create(String callerSubject, String name) {
    UUID me = me(callerSubject);
    if (albums.countOwned(me) >= MAX_ALBUMS) {
      throw new AlbumLimitException();
    }
    UUID id = UUID.randomUUID();
    albums.insert(id, me, name.strip(), clock.instant());
    return id;
  }

  @Transactional
  public void delete(String callerSubject, UUID albumId) {
    albums.delete(owned(me(callerSubject), albumId).id());
  }

  /**
   * Adds one of the caller's photos.
   *
   * @throws AlbumLimitException at {@link #MAX_PHOTOS}
   */
  @Transactional
  public void addPhoto(String callerSubject, UUID albumId, UUID mediaId) {
    UUID me = me(callerSubject);
    AlbumRow album = owned(me, albumId);
    media.requireAttachable(me, mediaId, Kind.PHOTO, false);
    if (album.photoCount() >= MAX_PHOTOS) {
      throw new AlbumLimitException();
    }
    albums.addItem(albumId, mediaId, clock.instant());
  }

  @Transactional
  public void removePhoto(String callerSubject, UUID albumId, UUID mediaId) {
    albums.removeItem(owned(me(callerSubject), albumId).id(), mediaId);
  }

  /**
   * Shares the album with {@code granteeId}, replacing any earlier grant.
   *
   * @param access how long it lasts; null duration means until revoked
   * @throws AlbumNotFoundException if the grantee can't be shared with (self, blocked, inactive),
   *     reported like a missing album so blocks aren't revealed
   */
  @Transactional
  public void share(
      String callerSubject, UUID albumId, UUID granteeId, Access access, boolean viewOnce) {
    UUID me = me(callerSubject);
    owned(me, albumId);
    boolean reachable =
        !me.equals(granteeId)
            && !safety.isBlockedEitherWay(me, granteeId)
            && identity.findById(granteeId).map(AccountSummary::active).orElse(false);
    if (!reachable) {
      throw new AlbumNotFoundException();
    }
    Instant now = clock.instant();
    Instant expiresAt = access.duration() == null ? null : now.plus(access.duration());
    albums.grant(albumId, granteeId, expiresAt, viewOnce, now);
  }

  @Transactional
  public void revoke(String callerSubject, UUID albumId, UUID granteeId) {
    albums.revoke(owned(me(callerSubject), albumId).id(), granteeId);
  }

  /** Albums others shared with the caller that can still be opened. */
  @Transactional(readOnly = true)
  public List<SharedRow> sharedWithMe(String callerSubject) {
    return albums.sharedWith(me(callerSubject), clock.instant());
  }

  /**
   * Opens an album: the owner always; others with a current grant. Opening a view-once grant uses
   * it up, so the links returned are the only ones the grantee gets.
   *
   * @throws AlbumNotFoundException if the caller has no access (including after a block)
   * @throws AlbumViewedException if a view-once grant was already used
   */
  @Transactional
  public OpenedAlbum open(String callerSubject, UUID albumId) {
    UUID me = me(callerSubject);
    AlbumRow album = albums.find(albumId).orElseThrow(AlbumNotFoundException::new);
    if (album.ownerId().equals(me)) {
      return opened(album, null, false);
    }
    Instant now = clock.instant();
    GrantRow grant =
        albums
            .grant(albumId, me)
            .filter(g -> g.expiresAt() == null || g.expiresAt().isAfter(now))
            .filter(g -> !safety.isBlockedEitherWay(me, album.ownerId()))
            .filter(
                g -> identity.findById(album.ownerId()).map(AccountSummary::active).orElse(false))
            .orElseThrow(AlbumNotFoundException::new);
    if (grant.viewOnce() && !albums.markViewed(albumId, me, now)) {
      throw new AlbumViewedException();
    }
    return opened(album, grant.expiresAt(), grant.viewOnce());
  }

  private OpenedAlbum opened(AlbumRow album, Instant expiresAt, boolean viewOnce) {
    List<UUID> items = albums.items(album.id());
    Map<UUID, Links> links = media.links(items);
    List<Photo> photos =
        items.stream().filter(links::containsKey).map(id -> new Photo(id, links.get(id))).toList();
    return new OpenedAlbum(album.id(), album.ownerId(), album.name(), photos, expiresAt, viewOnce);
  }

  private AlbumRow owned(UUID me, UUID albumId) {
    return albums
        .find(albumId)
        .filter(a -> a.ownerId().equals(me))
        .orElseThrow(AlbumNotFoundException::new);
  }

  private UUID me(String callerSubject) {
    return identity.require(callerSubject).id();
  }

  /** How long a share lasts. */
  public enum Access {
    DAY(Duration.ofHours(24)),
    WEEK(Duration.ofDays(7)),
    UNTIL_REVOKED(null);

    private final Duration duration;

    Access(Duration duration) {
      this.duration = duration;
    }

    public Duration duration() {
      return duration;
    }
  }

  /** One of the caller's albums. */
  public record OwnAlbum(UUID id, String name, int photoCount, List<GrantRow> grants) {}

  /** A photo with its links. */
  public record Photo(UUID id, Links links) {}

  /**
   * An opened album.
   *
   * @param expiresAt when the caller's access ends (null for the owner or no expiry)
   * @param viewOnce the caller can't open it again
   */
  public record OpenedAlbum(
      UUID id,
      UUID ownerId,
      String name,
      List<Photo> photos,
      Instant expiresAt,
      boolean viewOnce) {}

  /** No such album, or no access to it. */
  public static class AlbumNotFoundException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public AlbumNotFoundException() {
      super("Album not found");
    }
  }

  /** A view-once share was already opened. */
  public static class AlbumViewedException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public AlbumViewedException() {
      super("Album already viewed");
    }
  }

  /** Too many albums or photos. */
  public static class AlbumLimitException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public AlbumLimitException() {
      super("Album limit reached");
    }
  }
}

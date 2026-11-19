package com.orbit.media.application;

import com.orbit.identity.IdentityApi;
import com.orbit.media.MediaApi;
import com.orbit.media.application.ImageProcessor.InvalidImageException;
import com.orbit.media.application.ImageProcessor.Processed;
import com.orbit.media.application.MediaScanner.Verdict;
import com.orbit.media.domain.MediaPurpose;
import com.orbit.media.infrastructure.AlbumStore;
import com.orbit.media.infrastructure.MediaProperties;
import com.orbit.media.infrastructure.MediaStore;
import com.orbit.media.infrastructure.MediaStore.MediaRow;
import com.orbit.media.infrastructure.MediaStore.Status;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Arrays;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.OptionalLong;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Uploads (design doc §7.4). The app asks for an upload link, PUTs the bytes straight to storage,
 * then calls {@link #complete}. Photos are then decoded, scanned and re-encoded without metadata;
 * video and audio are checked for an MP4 container. Processing runs in the completing request
 * because a photo takes well under a second; it can move to a worker without API changes.
 */
@Service
public class MediaService implements MediaApi {

  /** Open uploads allowed per member per hour (abandoned ones count until cleaned up). */
  static final int MAX_PENDING_PER_HOUR = 30;

  private static final Logger log = LoggerFactory.getLogger(MediaService.class);
  private static final byte[] MP4_BRAND_BOX = "ftyp".getBytes(StandardCharsets.US_ASCII);
  private static final int CONTAINER_HEADER_BYTES = 12;
  private static final String JPEG = "image/jpeg";

  private final MediaStore store;
  private final AlbumStore albums;
  private final ObjectStorage storage;
  private final ImageProcessor images;
  private final MediaScanner scanner;
  private final IdentityApi identity;
  private final MediaProperties properties;
  private final Clock clock;

  public MediaService(
      MediaStore store,
      AlbumStore albums,
      ObjectStorage storage,
      ImageProcessor images,
      MediaScanner scanner,
      IdentityApi identity,
      MediaProperties properties,
      Clock clock) {
    this.store = store;
    this.albums = albums;
    this.storage = storage;
    this.images = images;
    this.scanner = scanner;
    this.identity = identity;
    this.properties = properties;
    this.clock = clock;
  }

  /**
   * Starts an upload.
   *
   * @throws InvalidUploadException if the type or size isn't accepted for {@code purpose}
   * @throws UploadRateLimitedException after too many unfinished uploads
   */
  public UploadTicket startUpload(
      String callerSubject, MediaPurpose purpose, String contentType, long sizeBytes) {
    UUID me = identity.require(callerSubject).id();
    if (!purpose.accepts(contentType, sizeBytes)) {
      throw new InvalidUploadException();
    }
    Instant now = clock.instant();
    if (store.pendingSince(me, now.minus(Duration.ofHours(1))) >= MAX_PENDING_PER_HOUR) {
      throw new UploadRateLimitedException();
    }
    UUID id = UUID.randomUUID();
    String key = key(id, "original");
    store.insertPending(id, me, purpose, contentType, sizeBytes, key, now);
    Duration ttl = properties.uploadTtl();
    return new UploadTicket(
        id,
        storage.presignPut(key, contentType, sizeBytes, ttl),
        Map.of("Content-Type", contentType),
        now.plus(ttl));
  }

  /**
   * Finishes an upload: checks and processes what arrived. Calling it again returns the result.
   *
   * @param durationMs length reported by the app for video and voice (shown, never trusted for
   *     access decisions)
   * @throws MediaNotFoundException if there's no such upload of the caller's
   * @throws UploadIncompleteException if nothing has been uploaded yet
   * @throws MediaRejectedException if the content is invalid or refused
   */
  public MediaView complete(String callerSubject, UUID mediaId, Integer durationMs) {
    UUID me = identity.require(callerSubject).id();
    MediaRow row =
        store
            .find(mediaId)
            .filter(m -> m.ownerId().equals(me))
            .orElseThrow(MediaNotFoundException::new);
    switch (row.status()) {
      case READY -> {
        return view(row);
      }
      case REJECTED -> throw new MediaRejectedException();
      case PENDING -> {
        // Processed below.
      }
    }
    OptionalLong size = storage.size(row.storageKey());
    if (size.isEmpty()) {
      throw new UploadIncompleteException();
    }
    if (size.getAsLong() != row.sizeBytes() || !row.purpose().acceptsDuration(durationMs)) {
      reject(row, row.storageKey());
    }
    if (row.kind() == Kind.PHOTO) {
      processPhoto(row);
    } else {
      processContainer(row, durationMs);
    }
    return view(store.find(mediaId).orElseThrow());
  }

  /** The caller's own media with links (e.g. to preview right after uploading). */
  public MediaView mine(String callerSubject, UUID mediaId) {
    UUID me = identity.require(callerSubject).id();
    return store
        .find(mediaId)
        .filter(m -> m.ownerId().equals(me) && m.status() == Status.READY)
        .map(this::view)
        .orElseThrow(MediaNotFoundException::new);
  }

  private void processPhoto(MediaRow row) {
    Processed processed;
    try {
      processed = images.process(storage.read(row.storageKey()));
    } catch (InvalidImageException e) {
      reject(row, row.storageKey());
      return;
    }
    Verdict verdict = scanner.scan(Kind.PHOTO, processed.full());
    if (verdict == Verdict.REJECTED) {
      // Escalation (account freeze, report to authorities) arrives with the admin module.
      log.warn("Scanner rejected media {}", row.id());
      reject(row, row.storageKey());
    }
    String fullKey = key(row.id(), "full.jpg");
    String thumbKey = key(row.id(), "thumb.jpg");
    storage.write(fullKey, processed.full(), JPEG);
    storage.write(thumbKey, processed.thumb(), JPEG);
    storage.delete(row.storageKey());
    store.markReady(
        row.id(),
        fullKey,
        thumbKey,
        JPEG,
        processed.width(),
        processed.height(),
        null,
        verdict == Verdict.PRIVATE_ONLY,
        clock.instant());
  }

  /** Video and voice: accept only an MP4-family container; no transcoding yet. */
  private void processContainer(MediaRow row, Integer durationMs) {
    byte[] head = storage.readHead(row.storageKey(), CONTAINER_HEADER_BYTES);
    if (head.length < CONTAINER_HEADER_BYTES
        || !Arrays.equals(head, 4, 8, MP4_BRAND_BOX, 0, MP4_BRAND_BOX.length)) {
      reject(row, row.storageKey());
    }
    store.markReady(
        row.id(),
        row.storageKey(),
        null,
        row.contentType(),
        null,
        null,
        durationMs,
        false,
        clock.instant());
  }

  private void reject(MediaRow row, String key) {
    storage.delete(key);
    store.markRejected(row.id(), clock.instant());
    throw new MediaRejectedException();
  }

  private MediaView view(MediaRow row) {
    return new MediaView(
        row.id(),
        row.kind(),
        row.purpose(),
        row.privateOnly(),
        row.status() == Status.READY ? links(row) : null);
  }

  // --- MediaApi --------------------------------------------------------------------------------

  @Override
  public Attachment requireAttachable(UUID ownerId, UUID mediaId, Kind kind, boolean publicUse) {
    return store
        .find(mediaId)
        .filter(m ->
            m.ownerId().equals(ownerId)
                && m.status() == Status.READY
                && m.kind() == kind
                && !(publicUse && m.privateOnly()))
        .map(m -> new Attachment(m.id(), m.kind(), m.width(), m.height(), m.durationMs()))
        .orElseThrow(MediaUnavailableException::new);
  }

  @Override
  public Map<UUID, Links> links(Collection<UUID> mediaIds) {
    Map<UUID, Links> links = new LinkedHashMap<>();
    for (MediaRow row : store.findReady(mediaIds)) {
      links.put(row.id(), links(row));
    }
    return links;
  }

  @Override
  public boolean remove(UUID mediaId) {
    boolean removed = store.markRemoved(mediaId, clock.instant());
    if (removed) {
      log.info("Media {} removed by moderation", mediaId);
    }
    return removed;
  }

  @Override
  public boolean purge(UUID mediaId) {
    MediaRow row = store.find(mediaId).orElse(null);
    if (row == null || row.evidenceHold()) {
      return false;
    }
    // Objects first: if a delete fails the row stays, so a retry still finds what to delete.
    storage.delete(row.storageKey());
    if (row.thumbKey() != null) {
      storage.delete(row.thumbKey());
    }
    return store.deleteUnlessHeld(mediaId);
  }

  @Override
  public void holdAsEvidence(UUID mediaId) {
    store.markHeld(mediaId, clock.instant());
  }

  @Override
  public String requireOwnAlbum(UUID ownerId, UUID albumId) {
    return albums
        .find(albumId)
        .filter(a -> a.ownerId().equals(ownerId))
        .map(AlbumStore.AlbumRow::name)
        .orElseThrow(MediaUnavailableException::new);
  }

  private Links links(MediaRow row) {
    Duration ttl = properties.viewTtl();
    return new Links(
        row.kind(),
        storage.presignGet(row.storageKey(), ttl),
        row.thumbKey() == null ? null : storage.presignGet(row.thumbKey(), ttl),
        row.width(),
        row.height(),
        row.durationMs(),
        clock.instant().plus(ttl));
  }

  /** Keys are opaque: they never contain account ids or file names. */
  private static String key(UUID mediaId, String variant) {
    return "m/" + mediaId + "/" + variant;
  }

  /**
   * Where and how to upload.
   *
   * @param headers headers the PUT must carry exactly (they are part of the signature)
   */
  public record UploadTicket(
      UUID id, String uploadUrl, Map<String, String> headers, Instant expiresAt) {}

  /**
   * A media object of the caller's.
   *
   * @param privateOnly the scanner allows it only in private albums and chat
   * @param links null unless ready
   */
  public record MediaView(
      UUID id, Kind kind, MediaPurpose purpose, boolean privateOnly, Links links) {}

  /** The type or size isn't accepted. */
  public static class InvalidUploadException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public InvalidUploadException() {
      super("Invalid upload");
    }
  }

  /** Too many unfinished uploads. */
  public static class UploadRateLimitedException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public UploadRateLimitedException() {
      super("Upload rate limited");
    }
  }

  /** No such media of the caller's. */
  public static class MediaNotFoundException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public MediaNotFoundException() {
      super("Media not found");
    }
  }

  /** Completed before the bytes arrived. */
  public static class UploadIncompleteException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public UploadIncompleteException() {
      super("Upload incomplete");
    }
  }

  /** Invalid or refused content. */
  public static class MediaRejectedException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public MediaRejectedException() {
      super("Media rejected");
    }
  }
}

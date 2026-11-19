package com.orbit.media;

import java.time.Instant;
import java.util.Collection;
import java.util.Map;
import java.util.UUID;

/** What other modules may ask of media. */
public interface MediaApi {

  /**
   * Checks that {@code mediaId} can be attached by {@code ownerId}: it is theirs, processed, and of
   * {@code kind}. With {@code publicUse}, photos the scanner marked private-only are refused.
   *
   * @throws MediaUnavailableException otherwise (one error for every reason)
   */
  Attachment requireAttachable(UUID ownerId, UUID mediaId, Kind kind, boolean publicUse);

  /** Short-lived download links for ready media; ids that aren't ready are left out. */
  Map<UUID, Links> links(Collection<UUID> mediaIds);

  /**
   * Takes ready media down after moderation: its links stop working everywhere (profile, albums,
   * chat) and it can't be attached again. The stored object is kept as evidence. Returns whether it
   * was ready.
   */
  boolean remove(UUID mediaId);

  /**
   * Deletes media for real: the stored objects (original and thumbnail) first, then the row, so a
   * failed object delete leaves the row for a retry. Media held as evidence is kept. Returns
   * whether anything was deleted; calling it again is harmless.
   */
  boolean purge(UUID mediaId);

  /**
   * Keeps media from ever being purged, because it is evidence in a report. Safe to repeat. Returns
   * whether the media is now held and its stored objects still exist; false when there is no such
   * media or a purge already claimed it, so the caller knows the evidence is gone.
   */
  boolean holdAsEvidence(UUID mediaId);

  /**
   * The name of {@code ownerId}'s album {@code albumId}.
   *
   * @throws MediaUnavailableException if there is no such album of theirs
   */
  String requireOwnAlbum(UUID ownerId, UUID albumId);

  /** What a media object is. */
  enum Kind {
    PHOTO,
    VIDEO,
    AUDIO
  }

  /** A ready media object. Dimensions are set for photos, duration for video and audio. */
  record Attachment(UUID id, Kind kind, Integer width, Integer height, Integer durationMs) {}

  /**
   * Links that expire at {@code expiresAt}. {@code thumbUrl} is null when there is no thumbnail.
   */
  record Links(
      Kind kind,
      String url,
      String thumbUrl,
      Integer width,
      Integer height,
      Integer durationMs,
      Instant expiresAt) {}

  /** The media or album can't be used. */
  class MediaUnavailableException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public MediaUnavailableException() {
      super("Media unavailable");
    }
  }
}

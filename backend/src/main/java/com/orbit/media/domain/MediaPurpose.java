package com.orbit.media.domain;

import com.orbit.media.MediaApi.Kind;
import java.time.Duration;
import java.util.Set;

/** Why something is uploaded, which decides what is accepted. */
public enum MediaPurpose {
  PROFILE_PHOTO(Kind.PHOTO, Limits.PHOTO_BYTES, Limits.PHOTO_TYPES, null),
  ALBUM_PHOTO(Kind.PHOTO, Limits.PHOTO_BYTES, Limits.PHOTO_TYPES, null),
  CHAT_PHOTO(Kind.PHOTO, Limits.PHOTO_BYTES, Limits.PHOTO_TYPES, null),
  CHAT_VIDEO(
      Kind.VIDEO,
      50L * 1024 * 1024,
      Set.of("video/mp4", "video/quicktime"),
      Duration.ofSeconds(60)),
  VOICE_NOTE(
      Kind.AUDIO,
      5L * 1024 * 1024,
      Set.of("audio/mp4", "audio/aac", "audio/x-m4a"),
      Duration.ofMinutes(2));

  private final Kind kind;
  private final long maxBytes;
  private final Set<String> contentTypes;
  private final Duration maxDuration;

  MediaPurpose(Kind kind, long maxBytes, Set<String> contentTypes, Duration maxDuration) {
    this.kind = kind;
    this.maxBytes = maxBytes;
    this.contentTypes = contentTypes;
    this.maxDuration = maxDuration;
  }

  public Kind kind() {
    return kind;
  }

  /** Whether an upload of this type and size is acceptable. */
  public boolean accepts(String contentType, long sizeBytes) {
    return contentTypes.contains(contentType) && sizeBytes > 0 && sizeBytes <= maxBytes;
  }

  /** Whether a client-reported duration is acceptable (photos have none). */
  public boolean acceptsDuration(Integer durationMs) {
    if (maxDuration == null) {
      return true;
    }
    return durationMs != null && durationMs > 0 && durationMs <= maxDuration.toMillis();
  }

  private static final class Limits {
    // Phones send photos resized to at most 2048 px, which is well under this.
    static final long PHOTO_BYTES = 10L * 1024 * 1024;
    static final Set<String> PHOTO_TYPES = Set.of("image/jpeg", "image/png");
  }
}

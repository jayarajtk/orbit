package com.orbit.chat;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** What other modules may ask of chat. */
public interface ChatApi {

  /** Whether the member has a live chat connection right now (any server). */
  boolean isOnline(UUID accountId);

  /** Whether {@code accountId} muted the conversation. */
  boolean isMuted(UUID accountId, UUID conversationId);

  /**
   * The last {@code limit} messages between two members, oldest first, including ones either of
   * them deleted for themselves. For copying evidence into a report (ADR-0007).
   */
  List<EvidenceMessage> recentBetween(UUID a, UUID b, int limit);

  /**
   * A message as moderators see it.
   *
   * @param kind {@code TEXT}, {@code WAVE}, {@code LOCATION}, {@code ALBUM}, {@code PHOTO}, {@code
   *     VIDEO} or {@code VOICE}
   * @param text the text, or the album name for {@code ALBUM}; null when unsent or not text
   * @param mediaId the photo, video or voice note, if any
   * @param unsent whether the sender unsent it before the report
   */
  record EvidenceMessage(
      UUID id,
      UUID senderId,
      String kind,
      String text,
      UUID mediaId,
      Instant sentAt,
      boolean unsent) {}

  /**
   * Published after a new message is stored. Carries no message content: it is persisted in the
   * event log, and push notifications must not include text (ADR-0004).
   *
   * @param kind {@code TEXT}, {@code WAVE}, {@code LOCATION} or {@code ALBUM}
   */
  record MessageSent(
      UUID conversationId, UUID messageId, UUID senderId, UUID recipientId, String kind) {}
}

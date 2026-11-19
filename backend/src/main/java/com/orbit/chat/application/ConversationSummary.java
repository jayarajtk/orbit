package com.orbit.chat.application;

import com.orbit.chat.infrastructure.ChatStore.InboxRow;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;

/**
 * One inbox entry.
 *
 * @param otherId the other member (the conversation's key for clients)
 * @param online whether they were active in the last few minutes
 */
public record ConversationSummary(
    UUID otherId,
    String displayName,
    boolean online,
    boolean muted,
    long unread,
    MessageView last) {

  private static final Duration ONLINE_WINDOW = Duration.ofMinutes(10);

  static ConversationSummary of(InboxRow row, Instant now) {
    return new ConversationSummary(
        row.otherId(),
        row.displayName(),
        row.otherLastActive().isAfter(now.minus(ONLINE_WINDOW)),
        row.muted(),
        row.unread(),
        row.last());
  }
}

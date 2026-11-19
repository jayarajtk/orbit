package com.orbit.chat.application;

import java.util.UUID;

/** Chat-internal events, delivered to live connections after the transaction commits. */
public final class ChatEvents {

  private ChatEvents() {}

  /** A message was stored. */
  public record Stored(MessageView message, UUID senderId, UUID recipientId) {}

  /** A message was unsent; both members' clients replace it. */
  public record Unsent(MessageView message, UUID senderId, UUID otherId) {}

  /** The recipient opened a view-once photo; the sender's clients show it as opened. */
  public record Viewed(UUID messageId, UUID viewerId, UUID senderId) {}

  /** {@code readerId} read up to {@code seq} and shares read receipts. */
  public record ReadShared(UUID readerId, UUID otherId, long seq) {}
}

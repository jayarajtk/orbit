package com.orbit.chat.application;

import com.orbit.chat.domain.MessageKind;
import java.time.Instant;
import java.util.UUID;

/**
 * A message as clients see it. Unsent messages keep their place but lose their content.
 *
 * @param seq position in the conversation, used for paging, catch-up and read receipts
 * @param clientMsgId the sender's idempotency key, so clients can match acks to pending sends
 * @param mediaId the photo, video or voice note; fetch links via {@code /messages/{id}/media}
 * @param albumId the shared album, for {@code ALBUM}
 * @param viewOnce a photo the recipient can open once
 * @param viewed a view-once photo the recipient has opened
 */
public record MessageView(
    UUID id,
    UUID conversationId,
    long seq,
    UUID senderId,
    String clientMsgId,
    MessageKind kind,
    String text,
    Integer locationMinutes,
    String albumName,
    Instant createdAt,
    boolean unsent,
    UUID mediaId,
    UUID albumId,
    boolean viewOnce,
    boolean viewed) {}

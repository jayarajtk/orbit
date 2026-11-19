package com.orbit.chat.application;

import com.orbit.chat.ChatApi.MessageSent;
import com.orbit.chat.domain.MessageKind;
import com.orbit.chat.infrastructure.ChatStore;
import com.orbit.identity.IdentityApi;
import com.orbit.identity.IdentityApi.AccountSummary;
import com.orbit.media.MediaApi;
import com.orbit.media.MediaApi.Kind;
import com.orbit.media.MediaApi.Links;
import com.orbit.profile.ProfileApi;
import com.orbit.safety.SafetyApi;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 1:1 chat (ADR-0004). Every write checks blocks and account status. Live delivery happens after
 * commit ({@link ChatEvents}); offline members get a push via {@link MessageSent}.
 */
@Service
public class ChatService {

  /** How long after sending a message can be unsent. */
  public static final Duration UNSEND_WINDOW = Duration.ofMinutes(10);

  /** Longest text message. */
  public static final int MAX_TEXT = 2000;

  /** Allowed live-location share lengths. */
  public static final Set<Integer> LOCATION_MINUTES = Set.of(15, 30, 60);

  /** Messages per history page. */
  public static final int PAGE_SIZE = 50;

  private static final int INBOX_LIMIT = 100;

  private final ChatStore store;
  private final IdentityApi identity;
  private final SafetyApi safety;
  private final ProfileApi profiles;
  private final MediaApi media;
  private final ApplicationEventPublisher events;
  private final TransactionTemplate tx;
  private final TransactionTemplate readOnlyTx;
  private final Clock clock;

  public ChatService(
      ChatStore store,
      IdentityApi identity,
      SafetyApi safety,
      ProfileApi profiles,
      MediaApi media,
      ApplicationEventPublisher events,
      TransactionTemplate tx,
      Clock clock) {
    this.store = store;
    this.identity = identity;
    this.safety = safety;
    this.profiles = profiles;
    this.media = media;
    this.events = events;
    this.tx = tx;
    this.readOnlyTx = new TransactionTemplate(tx.getTransactionManager());
    this.readOnlyTx.setReadOnly(true);
    this.clock = clock;
  }

  /** The caller's account id. */
  public UUID me(String callerSubject) {
    return identity.require(callerSubject).id();
  }

  /**
   * Sends a message. Idempotent per {@code command.clientMsgId()}: a retry returns the original.
   *
   * @throws RecipientUnavailableException if the recipient is the caller, missing, inactive or
   *     blocked either way (one error for all, so a block is never revealed)
   * @throws InvalidMessageException if the content doesn't match its kind
   * @throws MediaApi.MediaUnavailableException if the media or album isn't the sender's or isn't
   *     ready
   */
  public SendResult send(UUID me, UUID to, SendCommand command) {
    command.validate();
    var existing = store.byClientId(me, command.clientMsgId());
    if (existing.isPresent()) {
      return new SendResult(existing.get(), false);
    }
    requireReachable(me, to);
    String albumName = attachments(me, command);
    try {
      MessageView stored = tx.execute(status -> store(me, to, command, albumName));
      profiles.touch(me);
      return new SendResult(stored, true);
    } catch (DuplicateKeyException e) {
      // A concurrent retry with the same client id won; return what it stored.
      return new SendResult(store.byClientId(me, command.clientMsgId()).orElseThrow(), false);
    }
  }

  /** Checks the media or album belongs to the sender; returns the album's name for ALBUM. */
  private String attachments(UUID me, SendCommand command) {
    switch (command.kind()) {
      case PHOTO -> media.requireAttachable(me, command.mediaId(), Kind.PHOTO, false);
      case VIDEO -> media.requireAttachable(me, command.mediaId(), Kind.VIDEO, false);
      case VOICE -> media.requireAttachable(me, command.mediaId(), Kind.AUDIO, false);
      case ALBUM -> {
        return media.requireOwnAlbum(me, command.albumId());
      }
      case TEXT, WAVE, LOCATION -> {
        // No attachment.
      }
    }
    return null;
  }

  private MessageView store(UUID me, UUID to, SendCommand command, String albumName) {
    Instant now = clock.instant();
    UUID conversationId = store.conversationFor(me, to, now);
    long seq = store.nextSeq(conversationId, now);
    MessageView message =
        new MessageView(
            UUID.randomUUID(),
            conversationId,
            seq,
            me,
            command.clientMsgId(),
            command.kind(),
            command.kind() == MessageKind.TEXT ? command.text().strip() : null,
            command.kind() == MessageKind.LOCATION ? command.locationMinutes() : null,
            albumName,
            now,
            false,
            command.kind().hasMedia() ? command.mediaId() : null,
            command.kind() == MessageKind.ALBUM ? command.albumId() : null,
            command.kind() == MessageKind.PHOTO && command.viewOnce(),
            false);
    store.insertMessage(message);
    // A sender has read everything up to their own message.
    store.markRead(conversationId, me, seq);
    events.publishEvent(new ChatEvents.Stored(message, me, to));
    events.publishEvent(
        new MessageSent(conversationId, message.id(), me, to, message.kind().name()));
    return message;
  }

  /** The caller's conversations, newest first. */
  public List<ConversationSummary> inbox(UUID me) {
    Instant now = clock.instant();
    return readOnlyTx.execute(status ->
        store.inbox(me, INBOX_LIMIT).stream()
            .map(row -> ConversationSummary.of(row, now))
            .toList());
  }

  /**
   * One page of history with {@code other}, plus how far they have read (for receipts).
   *
   * @throws RecipientUnavailableException if blocked either way or no such member
   */
  public MessagePage history(UUID me, UUID other, Long beforeSeq, Long afterSeq) {
    requireReachable(me, other);
    return readOnlyTx.execute(status ->
        store
            .conversationBetween(me, other)
            .map(c ->
                new MessagePage(
                    store.messages(c, me, beforeSeq, afterSeq, PAGE_SIZE),
                    store.lastReadSeq(c, other),
                    store.isMuted(me, c)))
            .orElse(new MessagePage(List.of(), 0, false)));
  }

  /** Marks messages up to {@code seq} as read; with {@code share} the other member is told. */
  public void markRead(UUID me, UUID other, long seq, boolean share) {
    tx.executeWithoutResult(status ->
        store
            .conversationBetween(me, other)
            .ifPresent(c -> {
              store.markRead(c, me, seq);
              if (share && !safety.isBlockedEitherWay(me, other)) {
                events.publishEvent(new ChatEvents.ReadShared(me, other, store.lastReadSeq(c, me)));
              }
            }));
  }

  public void setMuted(UUID me, UUID other, boolean muted) {
    tx.executeWithoutResult(status ->
        store.conversationBetween(me, other).ifPresent(c -> store.setMuted(c, me, muted)));
  }

  /** Deletes the conversation for the caller only. */
  public void delete(UUID me, UUID other) {
    tx.executeWithoutResult(
        status -> store.conversationBetween(me, other).ifPresent(c -> store.clear(c, me)));
  }

  /**
   * Unsends the caller's message.
   *
   * @throws MessageNotFoundException if it isn't theirs
   * @throws UnsendExpiredException after {@link #UNSEND_WINDOW}
   */
  public void unsend(UUID me, UUID messageId) {
    tx.executeWithoutResult(status -> {
      MessageView message =
          store
              .byId(messageId)
              .filter(m -> m.senderId().equals(me))
              .orElseThrow(MessageNotFoundException::new);
      if (message.unsent()) {
        return;
      }
      if (clock.instant().isAfter(message.createdAt().plus(UNSEND_WINDOW))) {
        throw new UnsendExpiredException();
      }
      store.unsend(messageId, clock.instant());
      UUID other = store.otherMember(message.conversationId(), me).orElseThrow();
      events.publishEvent(new ChatEvents.Unsent(store.byId(messageId).orElseThrow(), me, other));
    });
  }

  /**
   * Links to a message's photo, video or voice note. The recipient can open a view-once photo once;
   * the sender always can.
   *
   * @throws MessageNotFoundException if the caller can't see the message or it has no media
   * @throws ViewOnceOpenedException if the recipient already opened a view-once photo
   */
  public Links mediaLinks(UUID me, UUID messageId) {
    return tx.execute(status -> {
      MessageView message =
          store
              .byId(messageId)
              .filter(m -> m.mediaId() != null && !m.unsent())
              .orElseThrow(MessageNotFoundException::new);
      UUID other =
          store
              .otherMember(message.conversationId(), me)
              .orElseThrow(MessageNotFoundException::new);
      if (safety.isBlockedEitherWay(me, other)
          || store.clearedFor(message.conversationId(), me, message.seq())) {
        throw new MessageNotFoundException();
      }
      boolean recipient = !message.senderId().equals(me);
      if (recipient && message.viewOnce()) {
        if (!store.markViewed(messageId, clock.instant())) {
          throw new ViewOnceOpenedException();
        }
        events.publishEvent(new ChatEvents.Viewed(messageId, me, message.senderId()));
      }
      Links links = media.links(List.of(message.mediaId())).get(message.mediaId());
      if (links == null) {
        throw new MessageNotFoundException();
      }
      return links;
    });
  }

  /** Whether {@code me} may send typing signals to {@code other}. */
  public boolean canSignal(UUID me, UUID other) {
    return !me.equals(other) && !safety.isBlockedEitherWay(me, other);
  }

  private void requireReachable(UUID me, UUID other) {
    if (me.equals(other)
        || safety.isBlockedEitherWay(me, other)
        || !identity.findById(other).map(AccountSummary::active).orElse(false)) {
      throw new RecipientUnavailableException();
    }
  }

  /**
   * What to send.
   *
   * @param clientMsgId idempotency key chosen by the client (1–64 chars)
   * @param mediaId uploaded photo, video or voice note for those kinds
   * @param viewOnce for photos: the recipient can open it once
   * @param albumId the sender's album for {@code ALBUM}
   */
  public record SendCommand(
      String clientMsgId,
      MessageKind kind,
      String text,
      Integer locationMinutes,
      UUID mediaId,
      boolean viewOnce,
      UUID albumId) {

    /** A text message. */
    public static SendCommand text(String clientMsgId, String text) {
      return new SendCommand(clientMsgId, MessageKind.TEXT, text, null, null, false, null);
    }

    void validate() {
      if (clientMsgId == null || clientMsgId.isBlank() || clientMsgId.length() > 64) {
        throw new InvalidMessageException();
      }
      boolean valid =
          switch (kind) {
            case TEXT -> text != null && !text.isBlank() && text.length() <= MAX_TEXT;
            case WAVE -> true;
            case LOCATION -> locationMinutes != null && LOCATION_MINUTES.contains(locationMinutes);
            case ALBUM -> albumId != null;
            case PHOTO, VIDEO, VOICE -> mediaId != null;
          };
      if (viewOnce && kind != MessageKind.PHOTO) {
        valid = false;
      }
      if (!valid) {
        throw new InvalidMessageException();
      }
    }
  }

  /**
   * Result of a send.
   *
   * @param created false when this was a retry of an already stored message
   */
  public record SendResult(MessageView message, boolean created) {}

  /**
   * A page of history.
   *
   * @param otherReadSeq the other member has read up to here
   */
  public record MessagePage(List<MessageView> items, long otherReadSeq, boolean muted) {}

  /** The other member can't be messaged. */
  public static class RecipientUnavailableException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public RecipientUnavailableException() {
      super("Recipient unavailable");
    }
  }

  /** The message content is invalid for its kind. */
  public static class InvalidMessageException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public InvalidMessageException() {
      super("Invalid message");
    }
  }

  /** No such message of the caller's. */
  public static class MessageNotFoundException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public MessageNotFoundException() {
      super("Message not found");
    }
  }

  /** Too late to unsend. */
  public static class UnsendExpiredException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public UnsendExpiredException() {
      super("Unsend window expired");
    }
  }

  /** A view-once photo was already opened. */
  public static class ViewOnceOpenedException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public ViewOnceOpenedException() {
      super("View-once photo already opened");
    }
  }
}

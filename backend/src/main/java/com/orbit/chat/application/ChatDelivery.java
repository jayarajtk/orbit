package com.orbit.chat.application;

import com.orbit.chat.ChatApi;
import com.orbit.chat.domain.MessageKind;
import com.orbit.chat.infrastructure.ChatStore;
import com.orbit.chat.infrastructure.LiveSessions;
import com.orbit.identity.IdentityApi.AccountRestricted;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;
import tools.jackson.databind.json.JsonMapper;

/**
 * Turns committed chat changes into WebSocket frames (ADR-0004). Frames name the other member as
 * {@code with}, because clients key conversations by the person they're talking to.
 */
@Component
public class ChatDelivery implements ChatApi {

  private final LiveSessions live;
  private final ChatStore store;
  private final JsonMapper json;

  public ChatDelivery(LiveSessions live, ChatStore store, JsonMapper json) {
    this.live = live;
    this.store = store;
    this.json = json;
  }

  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  void onStored(ChatEvents.Stored event) {
    live.publish(
        event.recipientId(),
        frame("msg.new", Map.of("with", event.senderId(), "message", event.message())));
    live.publish(
        event.senderId(),
        frame(
            "msg.ack",
            Map.of(
                "with",
                event.recipientId(),
                "clientMsgId",
                event.message().clientMsgId(),
                "message",
                event.message())));
  }

  /** A suspended or banned member loses every live connection, on every server. */
  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  void onRestricted(AccountRestricted event) {
    live.disconnect(event.accountId());
  }

  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  void onUnsent(ChatEvents.Unsent event) {
    live.publish(
        event.otherId(),
        frame("msg.unsent", Map.of("with", event.senderId(), "message", event.message())));
    live.publish(
        event.senderId(),
        frame("msg.unsent", Map.of("with", event.otherId(), "message", event.message())));
  }

  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  void onViewed(ChatEvents.Viewed event) {
    live.publish(
        event.senderId(),
        frame("msg.viewed", Map.of("with", event.viewerId(), "messageId", event.messageId())));
  }

  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  void onRead(ChatEvents.ReadShared event) {
    live.publish(
        event.otherId(), frame("msg.read", Map.of("with", event.readerId(), "seq", event.seq())));
  }

  /** Relays a typing signal (never stored). */
  public void typing(UUID from, UUID to) {
    live.publish(to, frame("typing", Map.of("with", from)));
  }

  /** Serializes a frame: {@code {"type": ..., ...fields}}. */
  public String frame(String type, Map<String, Object> fields) {
    Map<String, Object> body = new LinkedHashMap<>();
    body.put("type", type);
    body.putAll(fields);
    return json.writeValueAsString(body);
  }

  @Override
  public boolean isOnline(UUID accountId) {
    return live.isOnline(accountId);
  }

  @Override
  @Transactional(readOnly = true)
  public List<EvidenceMessage> recentBetween(UUID a, UUID b, int limit) {
    return store
        .conversationBetween(a, b)
        .map(conversation -> store.latest(conversation, limit))
        .orElse(List.of())
        .stream()
        .map(m ->
            new EvidenceMessage(
                m.id(),
                m.senderId(),
                m.kind().name(),
                m.kind() == MessageKind.ALBUM ? m.albumName() : m.text(),
                m.mediaId(),
                m.createdAt(),
                m.unsent()))
        .toList();
  }

  @Override
  @Transactional(readOnly = true)
  public boolean isMuted(UUID accountId, UUID conversationId) {
    return store.isMuted(accountId, conversationId);
  }
}

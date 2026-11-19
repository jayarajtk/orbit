package com.orbit.chat.api;

import com.orbit.chat.application.ChatDelivery;
import com.orbit.chat.application.ChatService;
import com.orbit.chat.application.ChatService.InvalidMessageException;
import com.orbit.chat.application.ChatService.RecipientUnavailableException;
import com.orbit.chat.application.ChatService.SendCommand;
import com.orbit.chat.domain.MessageKind;
import com.orbit.chat.infrastructure.LiveSessions;
import com.orbit.identity.IdentityApi.AccountRequiredException;
import com.orbit.media.MediaApi.MediaUnavailableException;
import com.orbit.profile.ProfileApi;
import java.io.IOException;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.json.JsonMapper;

/**
 * The chat WebSocket ({@code /ws/v1}, ADR-0004). The upgrade request is authenticated by the normal
 * bearer-token filter chain; this handler maps the token to an account and speaks a small JSON
 * protocol: {@code msg.send}, {@code typing}, {@code read} and {@code ping} in; {@code msg.new},
 * {@code msg.ack}, {@code msg.unsent}, {@code msg.read}, {@code typing}, {@code pong} and {@code
 * error} out.
 */
@Component
class ChatWebSocketHandler extends TextWebSocketHandler {

  private static final String ACCOUNT = "orbit.account";
  private static final String LIVE = "orbit.live";
  private static final String TYPING = "orbit.typing";
  private static final Duration TYPING_THROTTLE = Duration.ofSeconds(2);
  private static final Logger log = LoggerFactory.getLogger(ChatWebSocketHandler.class);

  private final ChatService chat;
  private final ChatDelivery delivery;
  private final LiveSessions live;
  private final ProfileApi profiles;
  private final JsonMapper json;

  ChatWebSocketHandler(
      ChatService chat,
      ChatDelivery delivery,
      LiveSessions live,
      ProfileApi profiles,
      JsonMapper json) {
    this.chat = chat;
    this.delivery = delivery;
    this.live = live;
    this.profiles = profiles;
    this.json = json;
  }

  /**
   * A frame from the client; fields not used by its type are null.
   *
   * @param to recipient for {@code msg.send} and {@code typing}
   * @param with the other member for {@code read}
   */
  record ClientFrame(
      String type,
      UUID to,
      UUID with,
      String clientMsgId,
      MessageKind kind,
      String text,
      Integer locationMinutes,
      UUID mediaId,
      Boolean viewOnce,
      UUID albumId,
      Long seq,
      Boolean share) {}

  @Override
  public void afterConnectionEstablished(WebSocketSession session) throws IOException {
    if (!(session.getPrincipal() instanceof JwtAuthenticationToken token)) {
      session.close(CloseStatus.POLICY_VIOLATION);
      return;
    }
    UUID me;
    try {
      me = chat.me(token.getName());
    } catch (AccountRequiredException e) {
      session.close(CloseStatus.POLICY_VIOLATION.withReason("account-required"));
      return;
    }
    session.getAttributes().put(ACCOUNT, me);
    session.getAttributes().put(LIVE, live.register(me, session));
    session.getAttributes().put(TYPING, new HashMap<UUID, Instant>());
    profiles.touch(me);
  }

  @Override
  protected void handleTextMessage(WebSocketSession session, TextMessage message)
      throws IOException {
    UUID me = (UUID) session.getAttributes().get(ACCOUNT);
    WebSocketSession out = (WebSocketSession) session.getAttributes().get(LIVE);
    if (me == null || out == null) {
      return;
    }
    ClientFrame frame;
    try {
      frame = json.readValue(message.getPayload(), ClientFrame.class);
    } catch (JacksonException e) {
      send(out, error("bad-frame", null));
      return;
    }
    try {
      handle(me, out, session, frame);
    } catch (RecipientUnavailableException e) {
      send(out, error("recipient-unavailable", frame.clientMsgId()));
    } catch (InvalidMessageException e) {
      send(out, error("invalid-message", frame.clientMsgId()));
    } catch (MediaUnavailableException e) {
      send(out, error("media-unavailable", frame.clientMsgId()));
    }
  }

  private void handle(UUID me, WebSocketSession out, WebSocketSession raw, ClientFrame frame)
      throws IOException {
    switch (frame.type() == null ? "" : frame.type()) {
      case "msg.send" -> {
        if (frame.to() == null || frame.kind() == null) {
          throw new InvalidMessageException();
        }
        chat.send(
            me,
            frame.to(),
            new SendCommand(
                frame.clientMsgId(),
                frame.kind(),
                frame.text(),
                frame.locationMinutes(),
                frame.mediaId(),
                Boolean.TRUE.equals(frame.viewOnce()),
                frame.albumId()));
      }
      case "typing" -> {
        if (frame.to() != null
            && throttleTyping(raw, frame.to())
            && chat.canSignal(me, frame.to())) {
          delivery.typing(me, frame.to());
        }
      }
      case "read" -> {
        if (frame.with() == null || frame.seq() == null) {
          throw new InvalidMessageException();
        }
        chat.markRead(me, frame.with(), frame.seq(), Boolean.TRUE.equals(frame.share()));
      }
      case "ping" -> {
        live.touch(me);
        profiles.touch(me);
        send(out, delivery.frame("pong", Map.of()));
      }
      default -> send(out, error("unknown-type", null));
    }
  }

  @SuppressWarnings("unchecked")
  private static boolean throttleTyping(WebSocketSession raw, UUID to) {
    Map<UUID, Instant> last = (Map<UUID, Instant>) raw.getAttributes().get(TYPING);
    Instant now = Instant.now();
    Instant previous = last.get(to);
    if (previous != null && previous.plus(TYPING_THROTTLE).isAfter(now)) {
      return false;
    }
    last.put(to, now);
    return true;
  }

  private String error(String code, String clientMsgId) {
    Map<String, Object> fields = new HashMap<>();
    fields.put("code", code);
    if (clientMsgId != null) {
      fields.put("clientMsgId", clientMsgId);
    }
    return delivery.frame("error", fields);
  }

  private static void send(WebSocketSession session, String payload) throws IOException {
    if (session.isOpen()) {
      session.sendMessage(new TextMessage(payload));
    }
  }

  @Override
  public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
    UUID me = (UUID) session.getAttributes().get(ACCOUNT);
    WebSocketSession out = (WebSocketSession) session.getAttributes().get(LIVE);
    if (me != null && out != null) {
      live.unregister(me, out);
    }
  }

  @Override
  public void handleTransportError(WebSocketSession session, Throwable exception) {
    log.debug("Chat transport error: {}", exception.getClass().getSimpleName());
  }
}

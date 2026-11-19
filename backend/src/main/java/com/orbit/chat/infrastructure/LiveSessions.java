package com.orbit.chat.infrastructure;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.Message;
import org.springframework.data.redis.connection.MessageListener;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.listener.PatternTopic;
import org.springframework.data.redis.listener.RedisMessageListenerContainer;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.ConcurrentWebSocketSessionDecorator;

/**
 * Live WebSocket sessions on this server, plus cross-server fan-out and presence through Redis
 * (ADR-0004). Every frame goes through Redis, even when the recipient is on this server, so one
 * path is exercised in development and production.
 *
 * <p>Thread-safe: sessions are wrapped in {@link ConcurrentWebSocketSessionDecorator}.
 */
@Component
public class LiveSessions implements MessageListener {

  /** Presence lasts this long unless refreshed by a ping (clients ping every 25 s). */
  public static final Duration PRESENCE_TTL = Duration.ofSeconds(90);

  static final String CHANNEL_PREFIX = "orbit:user:";

  /** Control messages for a member's sessions, e.g. "close them all" after a ban. */
  static final String CONTROL_PREFIX = "orbit:control:";

  static final String CLOSE = "close";

  /** Close reason the app reads as "account restricted" (it stops reconnecting on 1008). */
  public static final CloseStatus RESTRICTED =
      CloseStatus.POLICY_VIOLATION.withReason("account-restricted");

  private static final String PRESENCE_PREFIX = "orbit:online:";
  private static final int SEND_TIME_LIMIT_MS = 5_000;
  private static final int BUFFER_LIMIT_BYTES = 512 * 1024;
  private static final Logger log = LoggerFactory.getLogger(LiveSessions.class);

  private final StringRedisTemplate redis;
  private final Map<UUID, Set<WebSocketSession>> sessions = new ConcurrentHashMap<>();

  public LiveSessions(StringRedisTemplate redis) {
    this.redis = redis;
  }

  /** Registers a session for {@code accountId} and marks them online. */
  public WebSocketSession register(UUID accountId, WebSocketSession raw) {
    WebSocketSession session =
        new ConcurrentWebSocketSessionDecorator(raw, SEND_TIME_LIMIT_MS, BUFFER_LIMIT_BYTES);
    sessions.computeIfAbsent(accountId, id -> ConcurrentHashMap.newKeySet()).add(session);
    touch(accountId);
    return session;
  }

  /** Removes a session; the member goes offline when their last session on this server closes. */
  public void unregister(UUID accountId, WebSocketSession session) {
    sessions.computeIfPresent(
        accountId,
        (id, set) -> {
          set.removeIf(s -> s.getId().equals(session.getId()));
          return set.isEmpty() ? null : set;
        });
    if (!sessions.containsKey(accountId)) {
      redis.delete(PRESENCE_PREFIX + accountId);
    }
  }

  /** Refreshes presence (on connect and on every ping). */
  public void touch(UUID accountId) {
    redis.opsForValue().set(PRESENCE_PREFIX + accountId, "1", PRESENCE_TTL);
  }

  /** Whether the member has a live session on any server. */
  public boolean isOnline(UUID accountId) {
    return Boolean.TRUE.equals(redis.hasKey(PRESENCE_PREFIX + accountId));
  }

  /** Closes every live session of {@code accountId}, on any server. */
  public void disconnect(UUID accountId) {
    redis.convertAndSend(CONTROL_PREFIX + accountId, CLOSE);
  }

  /** Sends {@code json} to every live session of {@code accountId}, on any server. */
  public void publish(UUID accountId, String json) {
    redis.convertAndSend(CHANNEL_PREFIX + accountId, json);
  }

  @Override
  public void onMessage(Message message, byte[] pattern) {
    String channel = new String(message.getChannel(), StandardCharsets.UTF_8);
    boolean control = channel.startsWith(CONTROL_PREFIX);
    UUID accountId;
    try {
      accountId =
          UUID.fromString(
              channel.substring(control ? CONTROL_PREFIX.length() : CHANNEL_PREFIX.length()));
    } catch (IllegalArgumentException e) {
      log.warn("Ignoring frame on unexpected channel");
      return;
    }
    Set<WebSocketSession> targets = sessions.get(accountId);
    if (targets == null) {
      return;
    }
    if (control) {
      closeAll(accountId, targets);
      return;
    }
    TextMessage frame = new TextMessage(new String(message.getBody(), StandardCharsets.UTF_8));
    for (WebSocketSession session : targets) {
      try {
        if (session.isOpen()) {
          session.sendMessage(frame);
        }
      } catch (IOException | IllegalStateException e) {
        // A slow or broken connection; the client reconnects and catches up over REST.
        log.debug("Dropping frame for a failed session of account {}", accountId);
      }
    }
  }

  private void closeAll(UUID accountId, Set<WebSocketSession> targets) {
    for (WebSocketSession session : targets) {
      try {
        session.close(RESTRICTED);
      } catch (IOException e) {
        // Already broken; unregister runs from the handler's close callback either way.
        log.debug("Session of account {} was already closing", accountId);
      }
    }
  }

  /** Subscribes this server to every member channel and control channel. */
  @Configuration(proxyBeanMethods = false)
  static class RedisRelayConfig {

    @Bean
    RedisMessageListenerContainer chatRelayContainer(
        RedisConnectionFactory connections, LiveSessions liveSessions) {
      RedisMessageListenerContainer container = new RedisMessageListenerContainer();
      container.setConnectionFactory(connections);
      container.addMessageListener(liveSessions, new PatternTopic(CHANNEL_PREFIX + "*"));
      container.addMessageListener(liveSessions, new PatternTopic(CONTROL_PREFIX + "*"));
      return container;
    }
  }
}

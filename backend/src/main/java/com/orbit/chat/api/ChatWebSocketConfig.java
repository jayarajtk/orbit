package com.orbit.chat.api;

import java.time.Duration;
import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;
import org.springframework.web.socket.server.standard.ServletServerContainerFactoryBean;

/** Registers {@code /ws/v1}. Native apps send no Origin header; browsers must be allow-listed. */
@Configuration(proxyBeanMethods = false)
@EnableWebSocket
@EnableConfigurationProperties(ChatWebSocketConfig.ChatProperties.class)
class ChatWebSocketConfig implements WebSocketConfigurer {

  /** Clients ping every 25 s; a silent connection is dropped after this. */
  static final Duration IDLE_TIMEOUT = Duration.ofSeconds(70);

  private static final int MAX_FRAME_BYTES = 16 * 1024;

  private final ChatWebSocketHandler handler;
  private final ChatProperties properties;

  ChatWebSocketConfig(ChatWebSocketHandler handler, ChatProperties properties) {
    this.handler = handler;
    this.properties = properties;
  }

  /**
   * Chat settings.
   *
   * @param allowedOrigins browser origins allowed to open the socket (web client); empty means
   *     same-origin only
   */
  @ConfigurationProperties(prefix = "orbit.chat")
  record ChatProperties(List<String> allowedOrigins) {
    ChatProperties {
      allowedOrigins = allowedOrigins == null ? List.of() : List.copyOf(allowedOrigins);
    }
  }

  @Override
  public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
    registry
        .addHandler(handler, "/ws/v1")
        .setAllowedOriginPatterns(properties.allowedOrigins().toArray(String[]::new));
  }

  @Bean
  ServletServerContainerFactoryBean webSocketContainer() {
    ServletServerContainerFactoryBean container = new ServletServerContainerFactoryBean();
    container.setMaxTextMessageBufferSize(MAX_FRAME_BYTES);
    container.setMaxSessionIdleTimeout(IDLE_TIMEOUT.toMillis());
    return container;
  }
}

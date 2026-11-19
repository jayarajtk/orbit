package com.orbit.notification.infrastructure;

import com.orbit.notification.application.PushSender;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Default {@link PushSender} until FCM credentials are configured: records that a push would have
 * gone out, without the token. Replaced by a real sender bean in deployed environments.
 */
@Configuration(proxyBeanMethods = false)
class LoggingPushSender {

  private static final Logger log = LoggerFactory.getLogger(LoggingPushSender.class);

  @Bean
  @ConditionalOnMissingBean(PushSender.class)
  PushSender pushSender() {
    return push ->
        log.info(
            "Push for account {} ({}) not sent: no push provider configured",
            push.accountId(),
            push.platform());
  }
}

package com.orbit.chat.api;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;

/** Chat settings are validated when the application starts. */
class ChatPropertiesTests {

  private final ApplicationContextRunner runner =
      new ApplicationContextRunner().withUserConfiguration(Enable.class);

  @Configuration(proxyBeanMethods = false)
  @EnableConfigurationProperties(ChatWebSocketConfig.ChatProperties.class)
  static class Enable {}

  @Test
  void usesTwoWavesPerDayWhenUnset() {
    runner.run(context -> {
      var properties = context.getBean(ChatWebSocketConfig.ChatProperties.class);
      assertThat(properties.waveLimit()).isEqualTo(2);
      assertThat(properties.waveWindow()).isEqualTo(Duration.ofHours(24));
    });
  }

  @Test
  void bindsConfiguredValues() {
    runner
        .withPropertyValues("orbit.chat.wave-limit=3", "orbit.chat.wave-window=PT1H")
        .run(context -> {
          var properties = context.getBean(ChatWebSocketConfig.ChatProperties.class);
          assertThat(properties.waveLimit()).isEqualTo(3);
          assertThat(properties.waveWindow()).isEqualTo(Duration.ofHours(1));
        });
  }

  @Test
  void rejectsAZeroWaveLimit() {
    runner
        .withPropertyValues("orbit.chat.wave-limit=0")
        .run(context -> assertThat(context).hasFailed());
  }

  @Test
  void rejectsANegativeWaveLimit() {
    runner
        .withPropertyValues("orbit.chat.wave-limit=-1")
        .run(context -> assertThat(context).hasFailed());
  }

  @Test
  void rejectsAnInvalidWaveWindow() {
    runner
        .withPropertyValues("orbit.chat.wave-window=tomorrow")
        .run(context -> assertThat(context).hasFailed());
  }
}

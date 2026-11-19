package com.orbit.shared.config;

import java.time.Clock;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** One UTC clock for the whole app, injected so time-based rules can be tested. */
@Configuration(proxyBeanMethods = false)
public class TimeConfig {

  @Bean
  Clock clock() {
    return Clock.systemUTC();
  }
}

package com.orbit;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

/** A UTC clock tests can move forward, so time rules are deterministic. */
public class MutableClock extends Clock {

  private Instant now;

  public MutableClock(Instant start) {
    this.now = start;
  }

  public void advance(Duration duration) {
    now = now.plus(duration);
  }

  public void set(Instant instant) {
    now = instant;
  }

  @Override
  public ZoneId getZone() {
    return ZoneOffset.UTC;
  }

  @Override
  public Clock withZone(ZoneId zone) {
    return this;
  }

  @Override
  public Instant instant() {
    return now;
  }

  /** Replaces the application clock in integration tests. */
  @TestConfiguration(proxyBeanMethods = false)
  public static class Config {

    @Bean
    @Primary
    MutableClock mutableClock() {
      return new MutableClock(Instant.parse("2026-11-17T12:00:00Z"));
    }
  }
}

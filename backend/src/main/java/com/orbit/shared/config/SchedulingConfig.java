package com.orbit.shared.config;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * Enables {@code @Scheduled} jobs. Each job is idempotent and safe to run on every server at once,
 * so no distributed lock is needed. Tests set {@code orbit.scheduling.enabled=false} and call the
 * jobs directly, so a scheduled run never races a test's clock.
 */
@Configuration(proxyBeanMethods = false)
@ConditionalOnProperty(
    name = "orbit.scheduling.enabled",
    havingValue = "true",
    matchIfMissing = true)
@EnableScheduling
public class SchedulingConfig {}

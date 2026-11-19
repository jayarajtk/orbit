package com.orbit.shared.config;

import java.time.Duration;
import org.hibernate.validator.constraints.time.DurationMin;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * How often unfinished event publications are retried ({@code orbit.events.resubmission.*}).
 *
 * @param interval time between runs of the job
 * @param minAge how old a publication must be before it is retried, so one still being handled is
 *     left alone
 */
@Validated
@ConfigurationProperties("orbit.events.resubmission")
public record EventResubmissionProperties(
    @DurationMin(nanos = 1) Duration interval, @DurationMin(nanos = 1) Duration minAge) {

  /** Default for {@code interval}, also used by the job's schedule. */
  static final String DEFAULT_INTERVAL = "PT5M";

  public EventResubmissionProperties {
    interval = interval == null ? Duration.parse(DEFAULT_INTERVAL) : interval;
    minAge = minAge == null ? Duration.ofMinutes(5) : minAge;
  }
}

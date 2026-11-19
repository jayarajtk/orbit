package com.orbit.shared.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.modulith.events.IncompleteEventPublications;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Retries event publications whose listener failed or was interrupted, such as an expired status's
 * photo purge that hit a storage error. Listeners are idempotent, so running this on several
 * servers at once only repeats harmless work.
 */
@Component
@EnableConfigurationProperties(EventResubmissionProperties.class)
public class EventResubmissionJob {

  private static final Logger log = LoggerFactory.getLogger(EventResubmissionJob.class);

  private final IncompleteEventPublications incomplete;
  private final EventResubmissionProperties properties;

  EventResubmissionJob(
      IncompleteEventPublications incomplete, EventResubmissionProperties properties) {
    this.incomplete = incomplete;
    this.properties = properties;
  }

  /** Resubmits incomplete publications older than the configured age. */
  @Scheduled(
      fixedDelayString = "${orbit.events.resubmission.interval:PT5M}",
      initialDelayString = "${orbit.events.resubmission.interval:PT5M}")
  public void run() {
    log.debug("Resubmitting event publications older than {}", properties.minAge());
    incomplete.resubmitIncompletePublicationsOlderThan(properties.minAge());
  }
}

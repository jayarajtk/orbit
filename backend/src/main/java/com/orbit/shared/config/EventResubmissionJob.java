package com.orbit.shared.config;

import com.orbit.status.StatusApi.StatusExpired;
import java.time.Clock;
import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.modulith.events.EventPublication;
import org.springframework.modulith.events.IncompleteEventPublications;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Retries {@link StatusExpired} publications whose listener failed or was interrupted, so an
 * expired status's photo purge that hit a storage error runs again. The purge is idempotent, so
 * running this on several servers at once only repeats harmless work.
 *
 * <p>No other event is resubmitted. Listeners such as push notifications and chat delivery are not
 * idempotent: replaying them would send the same push every run, without limit, and would replay
 * every old unfinished event after a deploy.
 */
@Component
@EnableConfigurationProperties(EventResubmissionProperties.class)
public class EventResubmissionJob {

  private static final Logger log = LoggerFactory.getLogger(EventResubmissionJob.class);

  private final IncompleteEventPublications incomplete;
  private final EventResubmissionProperties properties;
  private final Clock clock;

  EventResubmissionJob(
      IncompleteEventPublications incomplete, EventResubmissionProperties properties, Clock clock) {
    this.incomplete = incomplete;
    this.properties = properties;
    this.clock = clock;
  }

  /**
   * Resubmits incomplete status-expiry publications older than the configured age, leaving one
   * still being handled alone.
   */
  @Scheduled(
      fixedDelayString = "${orbit.events.resubmission.interval:PT5M}",
      initialDelayString = "${orbit.events.resubmission.interval:PT5M}")
  public void run() {
    Instant cutoff = clock.instant().minus(properties.minAge());
    log.debug("Resubmitting status expiry publications from before {}", cutoff);
    incomplete.resubmitIncompletePublications(publication -> isRetriable(publication, cutoff));
  }

  private static boolean isRetriable(EventPublication publication, Instant cutoff) {
    return publication.getEvent() instanceof StatusExpired
        && publication.getPublicationDate().isBefore(cutoff);
  }
}

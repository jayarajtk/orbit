package com.orbit.status.application;

import com.orbit.status.StatusApi.StatusExpired;
import com.orbit.status.infrastructure.StatusStore;
import com.orbit.status.infrastructure.StatusStore.Expired;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import java.time.Clock;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * Deletes statuses once they expire (spec §8.1). Each one is removed outright, and a {@link
 * StatusExpired} event, stored with the delete, makes the photo get purged; the event resubmission
 * job retries it if that fails. Logs carry counts only.
 */
@Component
public class StatusReaper {

  /** Rows deleted per transaction. */
  static final int BATCH_SIZE = 500;

  private static final Logger log = LoggerFactory.getLogger(StatusReaper.class);

  private final StatusStore store;
  private final ApplicationEventPublisher events;
  private final TransactionTemplate transaction;
  private final Clock clock;
  private final Counter expired;

  public StatusReaper(
      StatusStore store,
      ApplicationEventPublisher events,
      TransactionTemplate transaction,
      Clock clock,
      MeterRegistry meters) {
    this.store = store;
    this.events = events;
    this.transaction = transaction;
    this.clock = clock;
    this.expired = meters.counter("orbit.status.expired");
  }

  /**
   * Deletes every expired status, a batch at a time, until a batch comes back short. Returns how
   * many were deleted.
   */
  @Scheduled(fixedDelayString = "PT1M", initialDelayString = "PT1M")
  public int reap() {
    int total = 0;
    int batch;
    do {
      batch = reapBatch();
      total += batch;
    } while (batch == BATCH_SIZE);
    if (total > 0) {
      log.info("Reaped {} expired statuses", total);
    }
    return total;
  }

  /** One batch: the delete and its events commit together, so no photo is forgotten. */
  private int reapBatch() {
    Integer count =
        transaction.execute(status -> {
          List<Expired> gone = store.deleteExpired(clock.instant(), BATCH_SIZE);
          gone.forEach(
              row -> events.publishEvent(new StatusExpired(row.statusId(), row.mediaId())));
          expired.increment(gone.size());
          return gone.size();
        });
    return count == null ? 0 : count;
  }
}

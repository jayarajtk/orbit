package com.orbit.identity.application;

import com.orbit.identity.infrastructure.AccountRepository;
import java.time.Clock;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Lifts suspensions whose end has passed, so members reappear in the grid. Until it runs, those
 * accounts already count as active everywhere else ({@code Account#isActiveAt}). One UPDATE, so
 * running it on several servers at once is harmless.
 */
@Component
public class SuspensionLifter {

  private static final Logger log = LoggerFactory.getLogger(SuspensionLifter.class);

  private final AccountRepository accounts;
  private final Clock clock;

  SuspensionLifter(AccountRepository accounts, Clock clock) {
    this.accounts = accounts;
    this.clock = clock;
  }

  /** Lifts every ended suspension. Returns how many. */
  @Scheduled(fixedDelayString = "PT1M", initialDelayString = "PT1M")
  @Transactional
  public int liftEnded() {
    int lifted = accounts.liftSuspensionsEndedBy(clock.instant());
    if (lifted > 0) {
      log.info("Lifted {} ended suspensions", lifted);
    }
    return lifted;
  }
}

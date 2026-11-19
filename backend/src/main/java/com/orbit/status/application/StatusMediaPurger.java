package com.orbit.status.application;

import com.orbit.media.MediaApi;
import com.orbit.status.StatusApi.StatusExpired;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Purges a status's photo once the status is gone. It lives in the status module so media never
 * depends on status. Modulith keeps the publication until this returns, so a failed purge is
 * retried.
 */
@Component
class StatusMediaPurger {

  private static final Logger log = LoggerFactory.getLogger(StatusMediaPurger.class);

  private final MediaApi media;

  StatusMediaPurger(MediaApi media) {
    this.media = media;
  }

  /**
   * Same as {@code @ApplicationModuleListener} but with NOT_SUPPORTED instead of REQUIRES_NEW:
   * {@link MediaApi#purge} must not run in a transaction, or a rollback after the object deletes
   * would undo its claim on the row.
   */
  @Async
  @Transactional(propagation = Propagation.NOT_SUPPORTED)
  @TransactionalEventListener
  void on(StatusExpired event) {
    boolean purged = media.purge(event.mediaId());
    log.info("Status {} gone; media {} purged: {}", event.statusId(), event.mediaId(), purged);
  }
}

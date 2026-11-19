package com.orbit.safety.application;

import com.orbit.identity.IdentityApi;
import com.orbit.safety.SafetyApi;
import com.orbit.safety.domain.ReportReason;
import com.orbit.safety.infrastructure.SafetyStore;
import java.time.Clock;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Blocks and reports. Callers are identified by their token subject only. */
@Service
public class SafetyService implements SafetyApi {

  private static final Logger log = LoggerFactory.getLogger(SafetyService.class);

  private final SafetyStore store;
  private final IdentityApi identity;
  private final ApplicationEventPublisher events;
  private final Clock clock;

  public SafetyService(
      SafetyStore store, IdentityApi identity, ApplicationEventPublisher events, Clock clock) {
    this.store = store;
    this.identity = identity;
    this.events = events;
    this.clock = clock;
  }

  /**
   * Blocks {@code targetId}. Idempotent.
   *
   * @throws InvalidTargetException if the target is the caller or does not exist
   */
  @Transactional
  public void block(String callerSubject, UUID targetId) {
    UUID me = identity.require(callerSubject).id();
    requireOtherMember(me, targetId);
    if (store.block(me, targetId, clock.instant())) {
      log.info("Account {} blocked account {}", me, targetId);
      events.publishEvent(new MemberBlocked(me, targetId));
    }
  }

  @Transactional
  public void unblock(String callerSubject, UUID targetId) {
    store.unblock(identity.require(callerSubject).id(), targetId);
  }

  /**
   * Files a report, optionally also blocking. Returns the report id.
   *
   * @throws InvalidTargetException if the target is the caller or does not exist
   */
  @Transactional
  public UUID report(
      String callerSubject, UUID targetId, ReportReason reason, String details, boolean block) {
    UUID me = identity.require(callerSubject).id();
    requireOtherMember(me, targetId);
    UUID reportId = store.fileReport(me, targetId, reason, details.strip(), clock.instant());
    log.info("Report {} filed against account {} for {}", reportId, targetId, reason);
    events.publishEvent(new ReportFiled(reportId, me, targetId, reason.name()));
    if (block && store.block(me, targetId, clock.instant())) {
      events.publishEvent(new MemberBlocked(me, targetId));
    }
    return reportId;
  }

  @Override
  @Transactional(readOnly = true)
  public boolean isBlockedEitherWay(UUID a, UUID b) {
    return store.isBlockedEitherWay(a, b);
  }

  @Override
  @Transactional(readOnly = true)
  public Set<UUID> blockedEitherWay(UUID accountId) {
    return store.blockedEitherWay(accountId);
  }

  @Override
  @Transactional(readOnly = true)
  public Set<UUID> blockedBy(UUID accountId) {
    return store.blockedBy(accountId);
  }

  @Override
  @Transactional(readOnly = true)
  public List<OpenCase> openCases(int limit) {
    return store.openCases(urgentReasons(), limit);
  }

  @Override
  @Transactional(readOnly = true)
  public List<ReportRecord> reportsAgainst(UUID subjectId) {
    return store.reportsAgainst(subjectId);
  }

  @Override
  @Transactional
  public void startReview(UUID subjectId, String reviewer) {
    store.startReview(subjectId, reviewer, clock.instant());
  }

  @Override
  @Transactional
  public int resolveReports(UUID subjectId, boolean actioned, UUID actionId) {
    return store.resolve(subjectId, actioned ? "ACTIONED" : "DISMISSED", actionId, clock.instant());
  }

  private static List<String> urgentReasons() {
    return Arrays.stream(ReportReason.values())
        .filter(ReportReason::urgent)
        .map(Enum::name)
        .toList();
  }

  private void requireOtherMember(UUID me, UUID targetId) {
    if (me.equals(targetId) || identity.findById(targetId).isEmpty()) {
      throw new InvalidTargetException();
    }
  }

  /** The target is the caller or not a member. */
  public static class InvalidTargetException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public InvalidTargetException() {
      super("Target member is invalid");
    }
  }
}

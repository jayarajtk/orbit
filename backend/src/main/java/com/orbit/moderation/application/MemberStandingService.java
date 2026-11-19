package com.orbit.moderation.application;

import com.orbit.identity.IdentityApi;
import com.orbit.identity.IdentityApi.AccountSummary;
import com.orbit.moderation.application.ModerationExceptions.AppealExistsException;
import com.orbit.moderation.application.ModerationExceptions.MemberNotFoundException;
import com.orbit.moderation.application.ModerationExceptions.NotRestrictedException;
import com.orbit.moderation.application.Views.MemberAppeal;
import com.orbit.moderation.application.Views.Restriction;
import com.orbit.moderation.application.Views.Standing;
import com.orbit.moderation.application.Views.Warning;
import com.orbit.moderation.infrastructure.ModerationStore;
import com.orbit.moderation.infrastructure.ModerationStore.ActionRow;
import com.orbit.moderation.infrastructure.ModerationStore.AppealRow;
import java.time.Clock;
import java.util.Optional;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * What a member may see and do about moderation of their own account (ADR-0007). Unlike the rest of
 * the member API, this works while they are suspended or banned: it is how they learn why and
 * appeal. Members never see internal notes or who moderated them.
 */
@Service
public class MemberStandingService {

  /** Longest appeal text. */
  public static final int MAX_APPEAL = 1000;

  private static final Logger log = LoggerFactory.getLogger(MemberStandingService.class);

  private final IdentityApi identity;
  private final ModerationStore store;
  private final Clock clock;

  public MemberStandingService(IdentityApi identity, ModerationStore store, Clock clock) {
    this.identity = identity;
    this.store = store;
    this.clock = clock;
  }

  /**
   * The caller's standing.
   *
   * @throws MemberNotFoundException if they have no account
   */
  @Transactional(readOnly = true)
  public Standing standing(String callerSubject) {
    AccountSummary account = account(callerSubject);
    IdentityApi.Standing standing = identity.standing(account.id()).orElseThrow();
    Restriction restriction =
        account.restricted()
            ? store.currentRestriction(account.id()).map(this::restriction).orElse(null)
            : null;
    String status =
        account.restricted() || !"SUSPENDED".equals(standing.status())
            ? standing.status()
            : "ACTIVE";
    return new Standing(
        status,
        account.restricted() ? standing.suspendedUntil() : null,
        restriction,
        store.unacknowledgedWarnings(account.id()).stream()
            .map(w -> new Warning(w.id(), w.policy(), w.memberMessage(), w.createdAt()))
            .toList());
  }

  /**
   * Appeals the caller's current suspension or ban. One appeal per action.
   *
   * @throws NotRestrictedException if they aren't suspended or banned
   * @throws AppealExistsException if they already appealed this action
   */
  @Transactional
  public MemberAppeal appeal(String callerSubject, String text) {
    AccountSummary account = account(callerSubject);
    ActionRow restriction =
        Optional.of(account)
            .filter(AccountSummary::restricted)
            .flatMap(a -> store.currentRestriction(a.id()))
            .orElseThrow(NotRestrictedException::new);
    if (store.appealFor(restriction.id()).isPresent()) {
      throw new AppealExistsException();
    }
    UUID id = UUID.randomUUID();
    try {
      store.insertAppeal(id, restriction.id(), account.id(), text.strip(), clock.instant());
    } catch (DuplicateKeyException e) {
      // A concurrent second submit lost the race on the one-appeal-per-action constraint.
      throw new AppealExistsException();
    }
    log.info("Account {} appealed action {}", account.id(), restriction.id());
    return memberAppeal(store.appealFor(restriction.id()).orElseThrow());
  }

  /** Marks one of the caller's warnings as seen. Unknown ids and repeats are no-ops. */
  @Transactional
  public void acknowledgeWarning(String callerSubject, UUID warningId) {
    store.acknowledgeWarning(account(callerSubject).id(), warningId, clock.instant());
  }

  private AccountSummary account(String callerSubject) {
    return identity.findBySubject(callerSubject).orElseThrow(MemberNotFoundException::new);
  }

  private Restriction restriction(ActionRow action) {
    Optional<AppealRow> appeal = store.appealFor(action.id());
    return new Restriction(
        action.id(),
        action.kind(),
        action.policy(),
        action.memberMessage(),
        action.suspendedUntil(),
        action.createdAt(),
        appeal.map(MemberStandingService::memberAppeal).orElse(null),
        appeal.isEmpty());
  }

  private static MemberAppeal memberAppeal(AppealRow appeal) {
    return new MemberAppeal(
        appeal.id(),
        appeal.status(),
        appeal.decisionMessage(),
        appeal.createdAt(),
        appeal.decidedAt());
  }
}

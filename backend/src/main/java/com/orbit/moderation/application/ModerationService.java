package com.orbit.moderation.application;

import com.orbit.identity.IdentityApi;
import com.orbit.identity.IdentityApi.Standing;
import com.orbit.media.MediaApi;
import com.orbit.media.MediaApi.Links;
import com.orbit.moderation.application.ModerationExceptions.AppealDecidedException;
import com.orbit.moderation.application.ModerationExceptions.AppealNotFoundException;
import com.orbit.moderation.application.ModerationExceptions.InvalidActionException;
import com.orbit.moderation.application.ModerationExceptions.MemberNotFoundException;
import com.orbit.moderation.application.Views.ActionView;
import com.orbit.moderation.application.Views.AppealView;
import com.orbit.moderation.application.Views.AuditEntry;
import com.orbit.moderation.application.Views.CaseSummary;
import com.orbit.moderation.application.Views.EvidenceView;
import com.orbit.moderation.application.Views.MediaView;
import com.orbit.moderation.application.Views.MemberHit;
import com.orbit.moderation.application.Views.MemberRecord;
import com.orbit.moderation.application.Views.PhotoView;
import com.orbit.moderation.application.Views.ProfileView;
import com.orbit.moderation.application.Views.ReportView;
import com.orbit.moderation.domain.ActionKind;
import com.orbit.moderation.domain.AppealStatus;
import com.orbit.moderation.domain.Policy;
import com.orbit.moderation.infrastructure.AuditStore;
import com.orbit.moderation.infrastructure.ModerationStore;
import com.orbit.moderation.infrastructure.ModerationStore.ActionRow;
import com.orbit.moderation.infrastructure.ModerationStore.AppealRow;
import com.orbit.moderation.infrastructure.ModerationStore.EvidenceRow;
import com.orbit.profile.ProfileApi;
import com.orbit.profile.ProfileApi.Card;
import com.orbit.safety.SafetyApi;
import com.orbit.safety.SafetyApi.OpenCase;
import com.orbit.safety.SafetyApi.ReportRecord;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The moderation API behind the admin console (ADR-0007). Every method is called by a moderator the
 * security layer has already checked; every change and every read of a member's record is written
 * to the audit log in the same transaction.
 */
@Service
public class ModerationService {

  /** Longest suspension: a year. Longer than that is a ban. */
  public static final int MAX_SUSPEND_HOURS = 24 * 365;

  /** Search results returned at most. */
  static final int SEARCH_LIMIT = 20;

  private static final Logger log = LoggerFactory.getLogger(ModerationService.class);
  private static final int AUDIT_DETAIL_MAX = 500;

  private final SafetyApi safety;
  private final IdentityApi identity;
  private final ProfileApi profiles;
  private final MediaApi media;
  private final ModerationStore store;
  private final AuditStore audit;
  private final Clock clock;

  public ModerationService(
      SafetyApi safety,
      IdentityApi identity,
      ProfileApi profiles,
      MediaApi media,
      ModerationStore store,
      AuditStore audit,
      Clock clock) {
    this.safety = safety;
    this.identity = identity;
    this.profiles = profiles;
    this.media = media;
    this.store = store;
    this.audit = audit;
    this.clock = clock;
  }

  /** Members with unresolved reports, urgent first, then the longest-waiting. */
  @Transactional(readOnly = true)
  public List<CaseSummary> queue(int limit) {
    List<OpenCase> cases = safety.openCases(limit);
    Map<UUID, String> names =
        profiles.displayNames(cases.stream().map(OpenCase::subjectId).toList());
    return cases.stream()
        .map(c ->
            new CaseSummary(
                c.subjectId(),
                names.get(c.subjectId()),
                c.openReports(),
                c.urgent(),
                c.reasons(),
                c.oldestReportAt(),
                c.reviewer()))
        .toList();
  }

  /** Finds members by account id (exact) or by the start of their display name. */
  @Transactional
  public List<MemberHit> search(Moderator moderator, String query) {
    String trimmed = query.strip();
    List<UUID> ids =
        parseId(trimmed)
            .map(List::of)
            .orElseGet(() -> profiles.findByNamePrefix(trimmed, SEARCH_LIMIT));
    Map<UUID, String> names = profiles.displayNames(ids);
    List<MemberHit> hits = new ArrayList<>();
    for (UUID id : ids) {
      identity
          .standing(id)
          .ifPresent(standing -> hits.add(new MemberHit(id, names.get(id), standing.status())));
    }
    record(moderator, "MEMBER_SEARCHED", null, trimmed);
    return hits;
  }

  /** Marks the member's open reports as being reviewed by {@code moderator}. */
  @Transactional
  public void claim(Moderator moderator, UUID subjectId) {
    requireMember(subjectId);
    safety.startReview(subjectId, moderator.name());
    record(moderator, "CASE_CLAIMED", subjectId, "");
  }

  /**
   * The member's account, profile, reports with evidence, actions and appeals.
   *
   * @throws MemberNotFoundException if there is no such account
   */
  @Transactional
  public MemberRecord member(Moderator moderator, UUID accountId) {
    Standing standing = requireMember(accountId);
    List<ReportRecord> reports = safety.reportsAgainst(accountId);
    Map<UUID, List<EvidenceRow>> evidence =
        store.evidenceFor(reports.stream().map(ReportRecord::id).toList());
    Card card = profiles.card(accountId).orElse(null);
    Map<UUID, Links> links = media.links(mediaIds(card, evidence.values()));
    Map<UUID, String> reporterNames =
        profiles.displayNames(reports.stream().map(ReportRecord::reporterId).toList());

    record(moderator, "MEMBER_VIEWED", accountId, "");
    return new MemberRecord(
        accountId,
        standing.status(),
        standing.suspendedUntil(),
        standing.createdAt(),
        card == null ? null : profileView(card, links),
        reports.stream()
            .map(r -> reportView(r, accountId, reporterNames, evidence, links))
            .toList(),
        store.actionsFor(accountId).stream().map(ModerationService::actionView).toList(),
        appealViews(store.appealsBy(accountId)));
  }

  /**
   * Takes an action on a member and resolves their open reports.
   *
   * @throws MemberNotFoundException if there is no such account
   * @throws InvalidActionException if the action doesn't fit the member's current state
   */
  @Transactional
  public ActionView act(Moderator moderator, UUID subjectId, ActionCommand command) {
    Standing standing = requireMember(subjectId);
    validate(subjectId, standing, command);
    ActionRow action = apply(moderator, subjectId, command);
    log.info(
        "Moderator {} took {} ({}) on account {}",
        moderator.name(),
        action.kind(),
        action.policy(),
        subjectId);
    return actionView(action);
  }

  /** Appeals with {@code status}, oldest first. */
  @Transactional(readOnly = true)
  public List<AppealView> appeals(AppealStatus status, int limit) {
    return appealViews(store.appealsWithStatus(status, limit));
  }

  /**
   * Upholds or reverses an appeal. Reversing reinstates the account if it is still suspended or
   * banned, recorded as a reinstate action with policy {@code APPEAL_GRANTED}.
   *
   * @throws AppealNotFoundException if there is no such appeal
   * @throws AppealDecidedException if it was already decided
   */
  @Transactional
  public AppealView decide(Moderator moderator, UUID appealId, AppealDecision decision) {
    AppealRow appeal = store.findAppeal(appealId).orElseThrow(AppealNotFoundException::new);
    if (appeal.status() != AppealStatus.OPEN) {
      throw new AppealDecidedException();
    }
    AppealStatus outcome = decision.reverse() ? AppealStatus.REVERSED : AppealStatus.UPHELD;
    if (!store.decideAppeal(
        appealId, outcome, moderator.name(), decision.memberMessage(), clock.instant())) {
      throw new AppealDecidedException();
    }
    UUID accountId = appeal.accountId();
    if (decision.reverse() && isRestricted(requireMember(accountId))) {
      apply(
          moderator,
          accountId,
          new ActionCommand(
              ActionKind.REINSTATE,
              Policy.APPEAL_GRANTED,
              decision.memberMessage(),
              "Appeal " + appealId + " granted",
              null,
              null));
    }
    record(moderator, "APPEAL_DECIDED", accountId, outcome.name());
    log.info("Moderator {} decided appeal {}: {}", moderator.name(), appealId, outcome);
    return appealViews(List.of(store.findAppeal(appealId).orElseThrow())).getFirst();
  }

  /** Audit entries, newest first, optionally only about one member. */
  @Transactional(readOnly = true)
  public List<AuditEntry> auditLog(UUID accountId, Instant before, int limit) {
    return audit.entries(accountId, before, limit).stream()
        .map(e ->
            new AuditEntry(e.id(), e.actor(), e.action(), e.accountId(), e.detail(), e.createdAt()))
        .toList();
  }

  private void validate(UUID subjectId, Standing standing, ActionCommand command) {
    ActionKind kind = command.kind();
    if (command.policy() == Policy.APPEAL_GRANTED) {
      throw new InvalidActionException("APPEAL_GRANTED is set by appeal decisions only.");
    }
    if ((kind == ActionKind.DISMISS) != (command.policy() == Policy.NO_VIOLATION)) {
      throw new InvalidActionException("Dismissals, and only dismissals, use NO_VIOLATION.");
    }
    if ((kind == ActionKind.SUSPEND) != (command.suspendHours() != null)) {
      throw new InvalidActionException("Suspensions, and only suspensions, need a length.");
    }
    if (kind == ActionKind.SUSPEND
        && (command.suspendHours() < 1 || command.suspendHours() > MAX_SUSPEND_HOURS)) {
      throw new InvalidActionException("Suspend for 1 to " + MAX_SUSPEND_HOURS + " hours.");
    }
    if ((kind == ActionKind.REMOVE_PHOTO) != (command.mediaId() != null)) {
      throw new InvalidActionException("Photo removals, and only photo removals, name a photo.");
    }
    boolean banned = "BANNED".equals(standing.status());
    if ((kind == ActionKind.SUSPEND || kind == ActionKind.BAN) && banned) {
      throw new InvalidActionException("The member is already banned.");
    }
    if (kind == ActionKind.REINSTATE && !isRestricted(standing)) {
      throw new InvalidActionException("The member isn't suspended or banned.");
    }
    if (kind == ActionKind.REMOVE_PHOTO
        && profiles
            .card(subjectId)
            .map(card -> !card.photoIds().contains(command.mediaId()))
            .orElse(true)) {
      throw new InvalidActionException("That isn't one of the member's profile photos.");
    }
  }

  /** Records and carries out an action that has passed validation. */
  private ActionRow apply(Moderator moderator, UUID subjectId, ActionCommand command) {
    Instant now = clock.instant();
    Instant until =
        command.kind() == ActionKind.SUSPEND
            ? now.plus(Duration.ofHours(command.suspendHours()))
            : null;
    ActionRow action =
        new ActionRow(
            UUID.randomUUID(),
            subjectId,
            command.kind(),
            command.policy(),
            nullToEmpty(command.memberMessage()),
            nullToEmpty(command.internalNote()),
            until,
            command.mediaId(),
            moderator.name(),
            null,
            null,
            now);
    store.insertAction(action);
    switch (command.kind()) {
      case SUSPEND -> identity.suspend(subjectId, until);
      case BAN -> identity.ban(subjectId);
      case REMOVE_PHOTO -> {
        profiles.removePhoto(subjectId, command.mediaId());
        media.remove(command.mediaId());
      }
      case REINSTATE -> {
        identity.reinstate(subjectId);
        store.markRestrictionsReversed(subjectId, action.id(), now);
      }
      case WARN, DISMISS -> {
        // Nothing else changes: a warning is shown to the member, a dismissal only closes reports.
      }
    }
    if (command.kind().actionsReports()) {
      safety.resolveReports(subjectId, true, action.id());
    } else if (command.kind() == ActionKind.DISMISS) {
      safety.resolveReports(subjectId, false, action.id());
    }
    record(
        moderator,
        "ACTION_TAKEN",
        subjectId,
        command.kind() + " " + command.policy() + (until == null ? "" : " until " + until));
    return action;
  }

  private Standing requireMember(UUID accountId) {
    return identity.standing(accountId).orElseThrow(MemberNotFoundException::new);
  }

  private boolean isRestricted(Standing standing) {
    return "BANNED".equals(standing.status())
        || ("SUSPENDED".equals(standing.status())
            && standing.suspendedUntil().isAfter(clock.instant()));
  }

  private void record(Moderator moderator, String action, UUID accountId, String detail) {
    String bounded =
        detail.length() > AUDIT_DETAIL_MAX ? detail.substring(0, AUDIT_DETAIL_MAX) : detail;
    audit.append(moderator.name(), action, accountId, bounded, clock.instant());
  }

  private List<AppealView> appealViews(List<AppealRow> appeals) {
    Map<UUID, String> names =
        profiles.displayNames(appeals.stream().map(AppealRow::accountId).toList());
    Map<UUID, ActionRow> actions =
        store.findActions(appeals.stream().map(AppealRow::actionId).toList());
    return appeals.stream()
        .map(a -> {
          ActionRow action = actions.get(a.actionId());
          return new AppealView(
              a.id(),
              a.actionId(),
              a.accountId(),
              names.get(a.accountId()),
              action.kind(),
              action.policy(),
              a.text(),
              a.status(),
              a.decidedBy(),
              a.decisionMessage(),
              a.createdAt(),
              a.decidedAt());
        })
        .toList();
  }

  private static Set<UUID> mediaIds(Card card, Collection<List<EvidenceRow>> evidence) {
    Set<UUID> ids = new HashSet<>();
    if (card != null) {
      ids.addAll(card.photoIds());
    }
    evidence.forEach(messages ->
        messages.stream().map(EvidenceRow::mediaId).filter(Objects::nonNull).forEach(ids::add));
    return ids;
  }

  private static ProfileView profileView(Card card, Map<UUID, Links> links) {
    List<PhotoView> photos =
        card.photoIds().stream()
            .filter(links::containsKey)
            .map(id -> new PhotoView(id, links.get(id).url(), links.get(id).thumbUrl()))
            .toList();
    return new ProfileView(
        card.displayName(), card.bio(), card.pronouns(), card.tags(), card.lastActiveAt(), photos);
  }

  private static ReportView reportView(
      ReportRecord report,
      UUID subjectId,
      Map<UUID, String> reporterNames,
      Map<UUID, List<EvidenceRow>> evidence,
      Map<UUID, Links> links) {
    List<EvidenceView> messages =
        evidence.getOrDefault(report.id(), List.of()).stream()
            .map(m -> {
              Links link = m.mediaId() == null ? null : links.get(m.mediaId());
              return new EvidenceView(
                  m.messageId(),
                  m.senderId().equals(subjectId),
                  m.kind(),
                  m.text(),
                  m.sentAt(),
                  link == null
                      ? null
                      : new MediaView(link.kind().name(), link.url(), link.thumbUrl()));
            })
            .toList();
    return new ReportView(
        report.id(),
        report.reporterId(),
        reporterNames.get(report.reporterId()),
        report.reason(),
        report.details(),
        report.status(),
        report.reviewer(),
        report.createdAt(),
        messages);
  }

  private static ActionView actionView(ActionRow a) {
    return new ActionView(
        a.id(),
        a.kind(),
        a.policy(),
        a.memberMessage(),
        a.internalNote(),
        a.suspendedUntil(),
        a.mediaId(),
        a.moderator(),
        a.acknowledgedAt(),
        a.reversedBy(),
        a.createdAt());
  }

  private static Optional<UUID> parseId(String text) {
    try {
      return Optional.of(UUID.fromString(text));
    } catch (IllegalArgumentException e) {
      return Optional.empty();
    }
  }

  private static String nullToEmpty(String text) {
    return text == null ? "" : text.strip();
  }
}

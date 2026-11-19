package com.orbit.moderation.application;

import com.orbit.moderation.domain.ActionKind;
import com.orbit.moderation.domain.AppealStatus;
import com.orbit.moderation.domain.Policy;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/** What the moderation API returns. Grouped here because they only make sense together. */
public final class Views {

  private Views() {}

  /** A member waiting in the queue. */
  public record CaseSummary(
      UUID subjectId,
      String displayName,
      int openReports,
      boolean urgent,
      Set<String> reasons,
      Instant oldestReportAt,
      String reviewer) {}

  /** A search result. */
  public record MemberHit(UUID accountId, String displayName, String status) {}

  /** Everything a moderator needs to decide about a member. */
  public record MemberRecord(
      UUID accountId,
      String status,
      Instant suspendedUntil,
      Instant createdAt,
      ProfileView profile,
      List<ReportView> reports,
      List<ActionView> actions,
      List<AppealView> appeals) {}

  /** The member's profile; null on {@link MemberRecord} if they never created one. */
  public record ProfileView(
      String displayName,
      String bio,
      String pronouns,
      List<String> tags,
      Instant lastActiveAt,
      List<PhotoView> photos) {}

  /** A public photo with short-lived links. */
  public record PhotoView(UUID mediaId, String url, String thumbUrl) {}

  /** A report with the messages copied when it was filed. */
  public record ReportView(
      UUID id,
      UUID reporterId,
      String reporterName,
      String reason,
      String details,
      String status,
      String reviewer,
      Instant createdAt,
      List<EvidenceView> evidence) {}

  /**
   * A copied message.
   *
   * @param fromSubject whether the reported member sent it (otherwise the reporter did)
   * @param kind the message kind, or {@code UNSENT}
   * @param media links to its photo, video or voice note; null if none or no longer available
   */
  public record EvidenceView(
      UUID messageId,
      boolean fromSubject,
      String kind,
      String text,
      Instant sentAt,
      MediaView media) {}

  /** Short-lived links to a piece of evidence. */
  public record MediaView(String kind, String url, String thumbUrl) {}

  /** A moderation action. */
  public record ActionView(
      UUID id,
      ActionKind kind,
      Policy policy,
      String memberMessage,
      String internalNote,
      Instant suspendedUntil,
      UUID mediaId,
      String moderator,
      Instant acknowledgedAt,
      UUID reversedBy,
      Instant createdAt) {}

  /** An appeal, with the action it is against. */
  public record AppealView(
      UUID id,
      UUID actionId,
      UUID accountId,
      String displayName,
      ActionKind actionKind,
      Policy policy,
      String text,
      AppealStatus status,
      String decidedBy,
      String decisionMessage,
      Instant createdAt,
      Instant decidedAt) {}

  /** One audit log entry. */
  public record AuditEntry(
      UUID id, String actor, String action, UUID accountId, String detail, Instant createdAt) {}

  /**
   * Where a member stands, as the app shows it.
   *
   * @param status the account status as of now
   * @param restriction the suspension or ban in force; null if none
   * @param warnings warnings the member hasn't seen yet, oldest first
   */
  public record Standing(
      String status, Instant suspendedUntil, Restriction restriction, List<Warning> warnings) {}

  /**
   * A suspension or ban as the member sees it (never the internal note).
   *
   * @param appeal their appeal, if they made one
   * @param canAppeal whether they may appeal it now
   */
  public record Restriction(
      UUID actionId,
      ActionKind kind,
      Policy policy,
      String message,
      Instant suspendedUntil,
      Instant createdAt,
      MemberAppeal appeal,
      boolean canAppeal) {}

  /** A member's own appeal. */
  public record MemberAppeal(
      UUID id, AppealStatus status, String decisionMessage, Instant createdAt, Instant decidedAt) {}

  /** A warning as the member sees it. */
  public record Warning(UUID id, Policy policy, String message, Instant createdAt) {}
}

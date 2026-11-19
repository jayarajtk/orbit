package com.orbit.safety;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Block checks for every module that shows one member to another, and the report queue for
 * moderation (ADR-0007).
 */
public interface SafetyApi {

  /** Whether either member has blocked the other. */
  boolean isBlockedEitherWay(UUID a, UUID b);

  /** Everyone {@code accountId} has blocked or been blocked by; hidden from them everywhere. */
  Set<UUID> blockedEitherWay(UUID accountId);

  /** Only the members {@code accountId} chose to block, for the "Blocked users" screen. */
  Set<UUID> blockedBy(UUID accountId);

  /**
   * Members with unresolved reports, urgent ones first, then the longest-waiting. At most {@code
   * limit}.
   */
  List<OpenCase> openCases(int limit);

  /** Every report against {@code subjectId}, newest first. */
  List<ReportRecord> reportsAgainst(UUID subjectId);

  /** Marks {@code subjectId}'s open reports as being reviewed by {@code reviewer}. */
  void startReview(UUID subjectId, String reviewer);

  /**
   * Resolves every unresolved report against {@code subjectId} as actioned or dismissed, linked to
   * {@code actionId}. Returns how many.
   */
  int resolveReports(UUID subjectId, boolean actioned, UUID actionId);

  /**
   * A member with unresolved reports.
   *
   * @param urgent whether any report is for a minor or a threat
   * @param reasons the distinct reasons given
   * @param reviewer the moderator reviewing it, if someone is
   */
  record OpenCase(
      UUID subjectId,
      int openReports,
      boolean urgent,
      Set<String> reasons,
      Instant oldestReportAt,
      String reviewer) {}

  /**
   * A report.
   *
   * @param status {@code OPEN}, {@code IN_REVIEW}, {@code ACTIONED} or {@code DISMISSED}
   * @param resolvedByAction the moderation action that resolved it, if any
   */
  record ReportRecord(
      UUID id,
      UUID reporterId,
      UUID subjectId,
      String reason,
      String details,
      String status,
      String reviewer,
      UUID resolvedByAction,
      Instant createdAt) {}

  /**
   * Published inside the transaction that files a report, so evidence is copied before anything can
   * be unsent.
   */
  record ReportFiled(UUID reportId, UUID reporterId, UUID subjectId, String reason) {}

  /**
   * Published when one member blocks another, so chat can close the conversation and end calls.
   *
   * @param blockerId who blocked
   * @param blockedId who was blocked
   */
  record MemberBlocked(UUID blockerId, UUID blockedId) {}
}

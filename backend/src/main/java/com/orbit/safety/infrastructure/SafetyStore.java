package com.orbit.safety.infrastructure;

import com.orbit.safety.SafetyApi.OpenCase;
import com.orbit.safety.SafetyApi.ReportRecord;
import com.orbit.safety.domain.ReportReason;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/**
 * Blocks and reports. Plain SQL: both tables are simple, and blocks are queried by set membership
 * rather than loaded as entities.
 */
@Repository
public class SafetyStore {

  private final JdbcClient jdbc;

  public SafetyStore(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  /** Records a block; repeating it is a no-op. Returns whether a new block was created. */
  public boolean block(UUID blockerId, UUID blockedId, Instant now) {
    return jdbc.sql(
                """
                INSERT INTO block (blocker_id, blocked_id, created_at)
                VALUES (:blocker, :blocked, :now)
                ON CONFLICT DO NOTHING
                """)
            .param("blocker", blockerId)
            .param("blocked", blockedId)
            .param("now", utc(now))
            .update()
        == 1;
  }

  public void unblock(UUID blockerId, UUID blockedId) {
    jdbc.sql("DELETE FROM block WHERE blocker_id = :blocker AND blocked_id = :blocked")
        .param("blocker", blockerId)
        .param("blocked", blockedId)
        .update();
  }

  public boolean isBlockedEitherWay(UUID a, UUID b) {
    return jdbc.sql(
            """
            SELECT EXISTS (
              SELECT 1 FROM block
              WHERE (blocker_id = :a AND blocked_id = :b) OR (blocker_id = :b AND blocked_id = :a))
            """)
        .param("a", a)
        .param("b", b)
        .query(Boolean.class)
        .single();
  }

  public Set<UUID> blockedEitherWay(UUID accountId) {
    return new HashSet<>(
        jdbc.sql(
                """
                SELECT blocked_id FROM block WHERE blocker_id = :id
                UNION
                SELECT blocker_id FROM block WHERE blocked_id = :id
                """)
            .param("id", accountId)
            .query(UUID.class)
            .list());
  }

  public Set<UUID> blockedBy(UUID accountId) {
    return new HashSet<>(
        jdbc.sql("SELECT blocked_id FROM block WHERE blocker_id = :id")
            .param("id", accountId)
            .query(UUID.class)
            .list());
  }

  public UUID fileReport(
      UUID reporterId, UUID subjectId, ReportReason reason, String details, Instant now) {
    UUID id = UUID.randomUUID();
    jdbc.sql(
            """
            INSERT INTO report (id, reporter_id, subject_id, reason, details, created_at, updated_at)
            VALUES (:id, :reporter, :subject, :reason, :details, :now, :now)
            """)
        .param("id", id)
        .param("reporter", reporterId)
        .param("subject", subjectId)
        .param("reason", reason.name())
        .param("details", details)
        .param("now", utc(now))
        .update();
    return id;
  }

  /**
   * Members with unresolved reports: urgent first (any report for a reason in {@code
   * urgentReasons}), then the longest-waiting. Uses {@code report_queue_idx}.
   */
  public List<OpenCase> openCases(List<String> urgentReasons, int limit) {
    return jdbc.sql(
            """
            SELECT subject_id,
                   count(*) AS open_reports,
                   bool_or(reason IN (:urgent)) AS urgent,
                   array_agg(DISTINCT reason) AS reasons,
                   min(created_at) AS oldest,
                   max(reviewer) AS reviewer
            FROM report
            WHERE status IN ('OPEN', 'IN_REVIEW')
            GROUP BY subject_id
            ORDER BY urgent DESC, oldest
            LIMIT :limit
            """)
        .param("urgent", urgentReasons)
        .param("limit", limit)
        .query((rs, row) ->
            new OpenCase(
                rs.getObject("subject_id", UUID.class),
                rs.getInt("open_reports"),
                rs.getBoolean("urgent"),
                new TreeSet<>(Arrays.asList((String[]) rs.getArray("reasons").getArray())),
                rs.getObject("oldest", OffsetDateTime.class).toInstant(),
                rs.getString("reviewer")))
        .list();
  }

  public List<ReportRecord> reportsAgainst(UUID subjectId) {
    return jdbc.sql(
            """
            SELECT id, reporter_id, subject_id, reason, details, status, reviewer,
                   resolved_by_action, created_at
            FROM report WHERE subject_id = :subject
            ORDER BY created_at DESC
            """)
        .param("subject", subjectId)
        .query((rs, row) ->
            new ReportRecord(
                rs.getObject("id", UUID.class),
                rs.getObject("reporter_id", UUID.class),
                rs.getObject("subject_id", UUID.class),
                rs.getString("reason"),
                rs.getString("details"),
                rs.getString("status"),
                rs.getString("reviewer"),
                rs.getObject("resolved_by_action", UUID.class),
                rs.getObject("created_at", OffsetDateTime.class).toInstant()))
        .list();
  }

  public void startReview(UUID subjectId, String reviewer, Instant now) {
    jdbc.sql(
            """
            UPDATE report SET status = 'IN_REVIEW', reviewer = :reviewer, updated_at = :now
            WHERE subject_id = :subject AND status IN ('OPEN', 'IN_REVIEW')
            """)
        .param("subject", subjectId)
        .param("reviewer", reviewer)
        .param("now", utc(now))
        .update();
  }

  public int resolve(UUID subjectId, String status, UUID actionId, Instant now) {
    return jdbc.sql(
            """
            UPDATE report SET status = :status, resolved_by_action = :action, updated_at = :now
            WHERE subject_id = :subject AND status IN ('OPEN', 'IN_REVIEW')
            """)
        .param("subject", subjectId)
        .param("status", status)
        .param("action", actionId)
        .param("now", utc(now))
        .update();
  }

  private static OffsetDateTime utc(Instant instant) {
    return instant.atOffset(ZoneOffset.UTC);
  }
}

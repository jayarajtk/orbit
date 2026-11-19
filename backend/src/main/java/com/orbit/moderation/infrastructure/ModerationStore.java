package com.orbit.moderation.infrastructure;

import com.orbit.moderation.domain.ActionKind;
import com.orbit.moderation.domain.AppealStatus;
import com.orbit.moderation.domain.Policy;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** Moderation actions, appeals and report evidence. Plain SQL over simple, append-mostly tables. */
@Repository
public class ModerationStore {

  private static final String ACTION_COLUMNS =
      "id, subject_id, kind, policy, member_message, internal_note, suspended_until, media_id,"
          + " moderator, acknowledged_at, reversed_by, created_at";

  private static final String APPEAL_COLUMNS =
      "a.id, a.action_id, a.account_id, a.text, a.status, a.decided_by, a.decision_message,"
          + " a.decided_at, a.created_at";

  /** Evidence kind for a message that had been unsent before the report. */
  private static final String UNSENT = "UNSENT";

  private final JdbcClient jdbc;

  public ModerationStore(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  // Actions

  public void insertAction(ActionRow action) {
    jdbc.sql(
            """
            INSERT INTO moderation_action (id, subject_id, kind, policy, member_message,
                internal_note, suspended_until, media_id, moderator, created_at, updated_at)
            VALUES (:id, :subject, :kind, :policy, :message, :note, :until, :media, :moderator,
                :now, :now)
            """)
        .param("id", action.id())
        .param("subject", action.subjectId())
        .param("kind", action.kind().name())
        .param("policy", action.policy().name())
        .param("message", action.memberMessage())
        .param("note", action.internalNote())
        .param("until", utc(action.suspendedUntil()))
        .param("media", action.mediaId())
        .param("moderator", action.moderator())
        .param("now", utc(action.createdAt()))
        .update();
  }

  /** Every action on {@code subjectId}, newest first. */
  public List<ActionRow> actionsFor(UUID subjectId) {
    return jdbc.sql(
            "SELECT "
                + ACTION_COLUMNS
                + " FROM moderation_action WHERE subject_id = :subject"
                + " ORDER BY created_at DESC, id")
        .param("subject", subjectId)
        .query(ModerationStore::mapAction)
        .list();
  }

  /** Actions by id; ids that don't exist are absent. */
  public Map<UUID, ActionRow> findActions(Collection<UUID> actionIds) {
    if (actionIds.isEmpty()) {
      return Map.of();
    }
    Map<UUID, ActionRow> byId = new LinkedHashMap<>();
    jdbc.sql("SELECT " + ACTION_COLUMNS + " FROM moderation_action WHERE id IN (:ids)")
        .param("ids", actionIds)
        .query(ModerationStore::mapAction)
        .list()
        .forEach(action -> byId.put(action.id(), action));
    return byId;
  }

  /** The latest suspension or ban on {@code subjectId} that hasn't been reversed. */
  public Optional<ActionRow> currentRestriction(UUID subjectId) {
    return jdbc.sql(
            "SELECT "
                + ACTION_COLUMNS
                + """
                 FROM moderation_action
                WHERE subject_id = :subject AND kind IN ('SUSPEND', 'BAN') AND reversed_by IS NULL
                ORDER BY created_at DESC, id
                LIMIT 1
                """)
        .param("subject", subjectId)
        .query(ModerationStore::mapAction)
        .optional();
  }

  /** Records that {@code reinstateId} undid every unreversed suspension and ban on the member. */
  public void markRestrictionsReversed(UUID subjectId, UUID reinstateId, Instant now) {
    jdbc.sql(
            """
            UPDATE moderation_action SET reversed_by = :reinstate, updated_at = :now
            WHERE subject_id = :subject AND kind IN ('SUSPEND', 'BAN') AND reversed_by IS NULL
            """)
        .param("subject", subjectId)
        .param("reinstate", reinstateId)
        .param("now", utc(now))
        .update();
  }

  /** Warnings the member hasn't seen yet, oldest first. */
  public List<ActionRow> unacknowledgedWarnings(UUID subjectId) {
    return jdbc.sql(
            "SELECT "
                + ACTION_COLUMNS
                + """
                 FROM moderation_action
                WHERE subject_id = :subject AND kind = 'WARN' AND acknowledged_at IS NULL
                ORDER BY created_at, id
                """)
        .param("subject", subjectId)
        .query(ModerationStore::mapAction)
        .list();
  }

  /** Marks one of {@code subjectId}'s own warnings as seen. Repeating it is a no-op. */
  public void acknowledgeWarning(UUID subjectId, UUID warningId, Instant now) {
    jdbc.sql(
            """
            UPDATE moderation_action SET acknowledged_at = :now, updated_at = :now
            WHERE id = :id AND subject_id = :subject AND kind = 'WARN'
              AND acknowledged_at IS NULL
            """)
        .param("id", warningId)
        .param("subject", subjectId)
        .param("now", utc(now))
        .update();
  }

  // Appeals

  public void insertAppeal(UUID id, UUID actionId, UUID accountId, String text, Instant now) {
    jdbc.sql(
            """
            INSERT INTO appeal (id, action_id, account_id, text, status, created_at, updated_at)
            VALUES (:id, :action, :account, :text, 'OPEN', :now, :now)
            """)
        .param("id", id)
        .param("action", actionId)
        .param("account", accountId)
        .param("text", text)
        .param("now", utc(now))
        .update();
  }

  public Optional<AppealRow> findAppeal(UUID appealId) {
    return jdbc.sql("SELECT " + APPEAL_COLUMNS + " FROM appeal a WHERE a.id = :id")
        .param("id", appealId)
        .query(ModerationStore::mapAppeal)
        .optional();
  }

  public Optional<AppealRow> appealFor(UUID actionId) {
    return jdbc.sql("SELECT " + APPEAL_COLUMNS + " FROM appeal a WHERE a.action_id = :action")
        .param("action", actionId)
        .query(ModerationStore::mapAppeal)
        .optional();
  }

  /** Every appeal by {@code accountId}, newest first. */
  public List<AppealRow> appealsBy(UUID accountId) {
    return jdbc.sql(
            "SELECT "
                + APPEAL_COLUMNS
                + " FROM appeal a WHERE a.account_id = :account ORDER BY a.created_at DESC, a.id")
        .param("account", accountId)
        .query(ModerationStore::mapAppeal)
        .list();
  }

  /** Appeals with {@code status}, oldest first. Uses {@code appeal_queue_idx}. */
  public List<AppealRow> appealsWithStatus(AppealStatus status, int limit) {
    return jdbc.sql(
            "SELECT "
                + APPEAL_COLUMNS
                + " FROM appeal a WHERE a.status = :status ORDER BY a.created_at, a.id"
                + " LIMIT :limit")
        .param("status", status.name())
        .param("limit", limit)
        .query(ModerationStore::mapAppeal)
        .list();
  }

  /** Decides an open appeal; returns false if it was already decided. */
  public boolean decideAppeal(
      UUID appealId, AppealStatus status, String decidedBy, String message, Instant now) {
    return jdbc.sql(
                """
                UPDATE appeal SET status = :status, decided_by = :by, decision_message = :message,
                                  decided_at = :now, updated_at = :now
                WHERE id = :id AND status = 'OPEN'
                """)
            .param("id", appealId)
            .param("status", status.name())
            .param("by", decidedBy)
            .param("message", message)
            .param("now", utc(now))
            .update()
        == 1;
  }

  // Evidence

  public void insertEvidence(UUID reportId, List<EvidenceRow> messages, Instant now) {
    for (int position = 0; position < messages.size(); position++) {
      EvidenceRow m = messages.get(position);
      jdbc.sql(
              """
              INSERT INTO report_evidence (report_id, position, message_id, sender_id, kind, text,
                  media_id, sent_at, created_at, updated_at)
              VALUES (:report, :position, :message, :sender, :kind, :text, :media, :sent, :now,
                  :now)
              """)
          .param("report", reportId)
          .param("position", position)
          .param("message", m.messageId())
          .param("sender", m.senderId())
          .param("kind", m.unsent() ? UNSENT : m.kind())
          .param("text", m.text())
          .param("media", m.mediaId())
          .param("sent", utc(m.sentAt()))
          .param("now", utc(now))
          .update();
    }
  }

  /** Evidence for each report, in conversation order. Reports without evidence are absent. */
  public Map<UUID, List<EvidenceRow>> evidenceFor(Collection<UUID> reportIds) {
    if (reportIds.isEmpty()) {
      return Map.of();
    }
    Map<UUID, List<EvidenceRow>> byReport = new LinkedHashMap<>();
    jdbc.sql(
            """
            SELECT report_id, message_id, sender_id, kind, text, media_id, sent_at
            FROM report_evidence WHERE report_id IN (:reports)
            ORDER BY report_id, position
            """)
        .param("reports", reportIds)
        .query((ResultSet rs) -> {
          String kind = rs.getString("kind");
          byReport
              .computeIfAbsent(rs.getObject("report_id", UUID.class), id -> new ArrayList<>())
              .add(
                  new EvidenceRow(
                      rs.getObject("message_id", UUID.class),
                      rs.getObject("sender_id", UUID.class),
                      kind,
                      rs.getString("text"),
                      rs.getObject("media_id", UUID.class),
                      instant(rs, "sent_at"),
                      UNSENT.equals(kind)));
        });
    return byReport;
  }

  private static ActionRow mapAction(ResultSet rs, int row) throws SQLException {
    return new ActionRow(
        rs.getObject("id", UUID.class),
        rs.getObject("subject_id", UUID.class),
        ActionKind.valueOf(rs.getString("kind")),
        Policy.valueOf(rs.getString("policy")),
        rs.getString("member_message"),
        rs.getString("internal_note"),
        instant(rs, "suspended_until"),
        rs.getObject("media_id", UUID.class),
        rs.getString("moderator"),
        instant(rs, "acknowledged_at"),
        rs.getObject("reversed_by", UUID.class),
        instant(rs, "created_at"));
  }

  private static AppealRow mapAppeal(ResultSet rs, int row) throws SQLException {
    return new AppealRow(
        rs.getObject("id", UUID.class),
        rs.getObject("action_id", UUID.class),
        rs.getObject("account_id", UUID.class),
        rs.getString("text"),
        AppealStatus.valueOf(rs.getString("status")),
        rs.getString("decided_by"),
        rs.getString("decision_message"),
        instant(rs, "decided_at"),
        instant(rs, "created_at"));
  }

  private static Instant instant(ResultSet rs, String column) throws SQLException {
    OffsetDateTime value = rs.getObject(column, OffsetDateTime.class);
    return value == null ? null : value.toInstant();
  }

  private static OffsetDateTime utc(Instant instant) {
    return instant == null ? null : instant.atOffset(ZoneOffset.UTC);
  }

  /**
   * A moderation action.
   *
   * @param suspendedUntil set for {@code SUSPEND} only
   * @param mediaId set for {@code REMOVE_PHOTO} only
   * @param acknowledgedAt for {@code WARN}: when the member saw it
   * @param reversedBy for {@code SUSPEND} and {@code BAN}: the reinstatement that undid it
   */
  public record ActionRow(
      UUID id,
      UUID subjectId,
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

  /** An appeal against a suspension or ban. */
  public record AppealRow(
      UUID id,
      UUID actionId,
      UUID accountId,
      String text,
      AppealStatus status,
      String decidedBy,
      String decisionMessage,
      Instant decidedAt,
      Instant createdAt) {}

  /**
   * A message copied into a report.
   *
   * @param kind the message kind, or {@code UNSENT} if it had been unsent before the report
   */
  public record EvidenceRow(
      UUID messageId,
      UUID senderId,
      String kind,
      String text,
      UUID mediaId,
      Instant sentAt,
      boolean unsent) {}
}

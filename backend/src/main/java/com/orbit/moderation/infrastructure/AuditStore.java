package com.orbit.moderation.infrastructure;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** The append-only admin audit log (ADR-0007). There is deliberately no update or delete. */
@Repository
public class AuditStore {

  private final JdbcClient jdbc;

  public AuditStore(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  public void append(String actor, String action, UUID accountId, String detail, Instant now) {
    jdbc.sql(
            """
            INSERT INTO admin_audit (id, actor, action, account_id, detail, created_at, updated_at)
            VALUES (:id, :actor, :action, :account, :detail, :now, :now)
            """)
        .param("id", UUID.randomUUID())
        .param("actor", actor)
        .param("action", action)
        .param("account", accountId)
        .param("detail", detail)
        .param("now", now.atOffset(ZoneOffset.UTC))
        .update();
  }

  /**
   * Entries newest first, optionally only about {@code accountId}, and only older than {@code
   * before} (for paging).
   */
  public List<AuditRow> entries(UUID accountId, Instant before, int limit) {
    return jdbc.sql(
            """
            SELECT id, actor, action, account_id, detail, created_at FROM admin_audit
            WHERE (CAST(:account AS UUID) IS NULL OR account_id = :account)
              AND (CAST(:before AS TIMESTAMPTZ) IS NULL OR created_at < :before)
            ORDER BY created_at DESC, id
            LIMIT :limit
            """)
        .param("account", accountId)
        .param("before", before == null ? null : before.atOffset(ZoneOffset.UTC))
        .param("limit", limit)
        .query((rs, row) ->
            new AuditRow(
                rs.getObject("id", UUID.class),
                rs.getString("actor"),
                rs.getString("action"),
                rs.getObject("account_id", UUID.class),
                rs.getString("detail"),
                rs.getObject("created_at", OffsetDateTime.class).toInstant()))
        .list();
  }

  /** One audit entry. */
  public record AuditRow(
      UUID id, String actor, String action, UUID accountId, String detail, Instant createdAt) {}
}

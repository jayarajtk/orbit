package com.orbit.status.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/**
 * Status SQL. Writes only its own tables ({@code status}, {@code status_view}). Every read takes
 * {@code now} and keeps to {@code expires_at > now}, so an expired status is never served before
 * the reaper deletes it.
 */
@Repository
public class StatusStore {

  private static final String COLUMNS = "id, owner_id, media_id, caption, created_at, expires_at";

  private final JdbcClient jdbc;

  public StatusStore(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  /**
   * Locks the owner's account row until the transaction ends, so concurrent posts by one member
   * count and insert one at a time. Must run inside a transaction.
   */
  public void lockOwner(UUID ownerId) {
    jdbc.sql("SELECT id FROM account WHERE id = :owner FOR UPDATE")
        .param("owner", ownerId)
        .query(UUID.class)
        .optional();
  }

  public long countLive(UUID ownerId, Instant now) {
    return jdbc.sql("SELECT count(*) FROM status WHERE owner_id = :owner AND expires_at > :now")
        .param("owner", ownerId)
        .param("now", utc(now))
        .query(Long.class)
        .single();
  }

  /** Whether any status, live or not yet reaped, uses {@code mediaId}. */
  public boolean usesMedia(UUID mediaId) {
    return jdbc.sql("SELECT EXISTS (SELECT 1 FROM status WHERE media_id = :media)")
        .param("media", mediaId)
        .query(Boolean.class)
        .single();
  }

  public void insert(StatusRow row, Instant now) {
    jdbc.sql(
            """
            INSERT INTO status (id, owner_id, media_id, caption, created_at, expires_at, updated_at)
            VALUES (:id, :owner, :media, :caption, :created, :expires, :now)
            """)
        .param("id", row.id())
        .param("owner", row.ownerId())
        .param("media", row.mediaId())
        .param("caption", row.caption())
        .param("created", utc(row.createdAt()))
        .param("expires", utc(row.expiresAt()))
        .param("now", utc(now))
        .update();
  }

  /** A live status. */
  public Optional<StatusRow> findLive(UUID id, Instant now) {
    return jdbc.sql("SELECT " + COLUMNS + " FROM status WHERE id = :id AND expires_at > :now")
        .param("id", id)
        .param("now", utc(now))
        .query(StatusStore::map)
        .optional();
  }

  /** The owner's live statuses, oldest first. */
  public List<StatusRow> liveOf(UUID ownerId, Instant now) {
    return jdbc.sql(
            "SELECT "
                + COLUMNS
                + " FROM status WHERE owner_id = :owner AND expires_at > :now"
                + " ORDER BY created_at, id")
        .param("owner", ownerId)
        .param("now", utc(now))
        .query(StatusStore::map)
        .list();
  }

  /** The ids of the owner's live statuses that {@code viewerId} has seen. */
  public List<UUID> seenBy(UUID viewerId, UUID ownerId, Instant now) {
    return jdbc.sql(
            """
            SELECT s.id FROM status s
            JOIN status_view v ON v.status_id = s.id AND v.viewer_id = :viewer
            WHERE s.owner_id = :owner AND s.expires_at > :now
            """)
        .param("viewer", viewerId)
        .param("owner", ownerId)
        .param("now", utc(now))
        .query(UUID.class)
        .list();
  }

  /** Views of the given statuses, newest first. */
  public List<ViewRow> views(Collection<UUID> statusIds) {
    if (statusIds.isEmpty()) {
      return List.of();
    }
    return jdbc.sql(
            """
            SELECT status_id, viewer_id, viewed_at FROM status_view
            WHERE status_id IN (:ids)
            ORDER BY viewed_at DESC, viewer_id
            """)
        .param("ids", statusIds)
        .query((rs, rowNum) ->
            new ViewRow(
                rs.getObject("status_id", UUID.class),
                rs.getObject("viewer_id", UUID.class),
                instant(rs, "viewed_at")))
        .list();
  }

  /** Records a view once. Returns whether it is new. */
  public boolean recordView(UUID statusId, UUID viewerId, Instant now) {
    return jdbc.sql(
                """
                INSERT INTO status_view (status_id, viewer_id, viewed_at, created_at, updated_at)
                VALUES (:status, :viewer, :now, :now, :now)
                ON CONFLICT (status_id, viewer_id) DO NOTHING
                """)
            .param("status", statusId)
            .param("viewer", viewerId)
            .param("now", utc(now))
            .update()
        == 1;
  }

  /** Deletes the owner's status (views cascade). Returns its media id, or empty if none. */
  public Optional<UUID> deleteOwned(UUID ownerId, UUID statusId) {
    return jdbc.sql("DELETE FROM status WHERE id = :id AND owner_id = :owner RETURNING media_id")
        .param("id", statusId)
        .param("owner", ownerId)
        .query(UUID.class)
        .optional();
  }

  /**
   * For each owner with live statuses, whether {@code viewerId} has seen all of them. One query;
   * owners without live statuses are absent.
   */
  public Map<UUID, Boolean> allSeen(UUID viewerId, Collection<UUID> ownerIds, Instant now) {
    Map<UUID, Boolean> result = new HashMap<>();
    jdbc.sql(
            """
            SELECT s.owner_id, bool_and(v.viewer_id IS NOT NULL) AS all_seen
            FROM status s
            LEFT JOIN status_view v ON v.status_id = s.id AND v.viewer_id = :viewer
            WHERE s.owner_id IN (:owners) AND s.expires_at > :now
            GROUP BY s.owner_id
            """)
        .param("viewer", viewerId)
        .param("owners", ownerIds)
        .param("now", utc(now))
        .query(rs -> {
          result.put(rs.getObject("owner_id", UUID.class), rs.getBoolean("all_seen"));
        });
    return result;
  }

  private static OffsetDateTime utc(Instant instant) {
    return instant.atOffset(ZoneOffset.UTC);
  }

  private static Instant instant(ResultSet rs, String column) throws SQLException {
    return rs.getObject(column, OffsetDateTime.class).toInstant();
  }

  private static StatusRow map(ResultSet rs, int rowNum) throws SQLException {
    return new StatusRow(
        rs.getObject("id", UUID.class),
        rs.getObject("owner_id", UUID.class),
        rs.getObject("media_id", UUID.class),
        rs.getString("caption"),
        instant(rs, "created_at"),
        instant(rs, "expires_at"));
  }

  /** A status. {@code caption} may be null. */
  public record StatusRow(
      UUID id, UUID ownerId, UUID mediaId, String caption, Instant createdAt, Instant expiresAt) {}

  /** One member's view of a status. */
  public record ViewRow(UUID statusId, UUID viewerId, Instant viewedAt) {}
}

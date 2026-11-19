package com.orbit.media.infrastructure;

import com.orbit.media.MediaApi.Kind;
import com.orbit.media.domain.MediaPurpose;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** Media rows. */
@Repository
public class MediaStore {

  private static final String COLUMNS =
      "id, owner_id, purpose, kind, status, content_type, size_bytes, storage_key, thumb_key,"
          + " width, height, duration_ms, private_only, evidence_hold, created_at";

  private final JdbcClient jdbc;

  public MediaStore(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  public void insertPending(
      UUID id,
      UUID ownerId,
      MediaPurpose purpose,
      String contentType,
      long sizeBytes,
      String storageKey,
      Instant now) {
    jdbc.sql(
            """
            INSERT INTO media (id, owner_id, purpose, kind, status, content_type, size_bytes,
                               storage_key, created_at, updated_at)
            VALUES (:id, :owner, :purpose, :kind, 'PENDING', :type, :size, :key, :now, :now)
            """)
        .param("id", id)
        .param("owner", ownerId)
        .param("purpose", purpose.name())
        .param("kind", purpose.kind().name())
        .param("type", contentType)
        .param("size", sizeBytes)
        .param("key", storageKey)
        .param("now", utc(now))
        .update();
  }

  /** Uploads {@code ownerId} started since {@code since} and hasn't completed. */
  public long pendingSince(UUID ownerId, Instant since) {
    return jdbc.sql(
            """
            SELECT count(*) FROM media
            WHERE owner_id = :owner AND status = 'PENDING' AND created_at > :since
            """)
        .param("owner", ownerId)
        .param("since", utc(since))
        .query(Long.class)
        .single();
  }

  public Optional<MediaRow> find(UUID id) {
    return jdbc.sql("SELECT " + COLUMNS + " FROM media WHERE id = :id")
        .param("id", id)
        .query(MediaStore::map)
        .optional();
  }

  public List<MediaRow> findReady(Collection<UUID> ids) {
    if (ids.isEmpty()) {
      return List.of();
    }
    return jdbc.sql("SELECT " + COLUMNS + " FROM media WHERE id IN (:ids) AND status = 'READY'")
        .param("ids", ids)
        .query(MediaStore::map)
        .list();
  }

  /** Marks a pending upload ready. Returns false if it was no longer pending (a racing call). */
  public boolean markReady(
      UUID id,
      String storageKey,
      String thumbKey,
      String contentType,
      Integer width,
      Integer height,
      Integer durationMs,
      boolean privateOnly,
      Instant now) {
    return jdbc.sql(
                """
                UPDATE media
                SET status = 'READY', storage_key = :key, thumb_key = :thumb,
                    content_type = :type, width = :width, height = :height,
                    duration_ms = :duration, private_only = :private, updated_at = :now
                WHERE id = :id AND status = 'PENDING'
                """)
            .param("id", id)
            .param("key", storageKey)
            .param("thumb", thumbKey)
            .param("type", contentType)
            .param("width", width)
            .param("height", height)
            .param("duration", durationMs)
            .param("private", privateOnly)
            .param("now", utc(now))
            .update()
        == 1;
  }

  public void markRejected(UUID id, Instant now) {
    jdbc.sql(
            "UPDATE media SET status = 'REJECTED', updated_at = :now"
                + " WHERE id = :id AND status = 'PENDING'")
        .param("id", id)
        .param("now", utc(now))
        .update();
  }

  /** Marks ready media as removed by a moderator; returns whether it was ready. */
  public boolean markRemoved(UUID id, Instant now) {
    return jdbc.sql(
                "UPDATE media SET status = 'REMOVED', updated_at = :now"
                    + " WHERE id = :id AND status = 'READY'")
            .param("id", id)
            .param("now", utc(now))
            .update()
        == 1;
  }

  /** Keeps the row from being deleted by {@link #deleteUnlessHeld}. Safe to repeat. */
  public void markHeld(UUID id, Instant now) {
    jdbc.sql(
            "UPDATE media SET evidence_hold = TRUE, updated_at = :now"
                + " WHERE id = :id AND NOT evidence_hold")
        .param("id", id)
        .param("now", utc(now))
        .update();
  }

  /** Deletes the row unless it is held as evidence; returns whether it was deleted. */
  public boolean deleteUnlessHeld(UUID id) {
    return jdbc.sql("DELETE FROM media WHERE id = :id AND NOT evidence_hold")
            .param("id", id)
            .update()
        == 1;
  }

  private static OffsetDateTime utc(Instant instant) {
    return instant.atOffset(ZoneOffset.UTC);
  }

  private static MediaRow map(ResultSet rs, int row) throws SQLException {
    return new MediaRow(
        rs.getObject("id", UUID.class),
        rs.getObject("owner_id", UUID.class),
        MediaPurpose.valueOf(rs.getString("purpose")),
        Kind.valueOf(rs.getString("kind")),
        Status.valueOf(rs.getString("status")),
        rs.getString("content_type"),
        rs.getLong("size_bytes"),
        rs.getString("storage_key"),
        rs.getString("thumb_key"),
        rs.getObject("width", Integer.class),
        rs.getObject("height", Integer.class),
        rs.getObject("duration_ms", Integer.class),
        rs.getBoolean("private_only"),
        rs.getBoolean("evidence_hold"),
        rs.getObject("created_at", OffsetDateTime.class).toInstant());
  }

  /** Processing state. */
  public enum Status {
    PENDING,
    READY,
    REJECTED,
    /** Taken down by a moderator (ADR-0007). */
    REMOVED
  }

  /** A media row. */
  public record MediaRow(
      UUID id,
      UUID ownerId,
      MediaPurpose purpose,
      Kind kind,
      Status status,
      String contentType,
      long sizeBytes,
      String storageKey,
      String thumbKey,
      Integer width,
      Integer height,
      Integer durationMs,
      boolean privateOnly,
      boolean evidenceHold,
      Instant createdAt) {}
}

package com.orbit.media.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** Albums, their photos and who they're shared with. */
@Repository
public class AlbumStore {

  private final JdbcClient jdbc;

  public AlbumStore(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  public void insert(UUID id, UUID ownerId, String name, Instant now) {
    jdbc.sql(
            """
            INSERT INTO album (id, owner_id, name, created_at, updated_at)
            VALUES (:id, :owner, :name, :now, :now)
            """)
        .param("id", id)
        .param("owner", ownerId)
        .param("name", name)
        .param("now", utc(now))
        .update();
  }

  public int countOwned(UUID ownerId) {
    return jdbc.sql("SELECT count(*) FROM album WHERE owner_id = :owner")
        .param("owner", ownerId)
        .query(Integer.class)
        .single();
  }

  public Optional<AlbumRow> find(UUID id) {
    return jdbc.sql(
            """
            SELECT a.id, a.owner_id, a.name,
                   (SELECT count(*) FROM album_item i WHERE i.album_id = a.id) AS photos
            FROM album a WHERE a.id = :id
            """)
        .param("id", id)
        .query(AlbumStore::mapAlbum)
        .optional();
  }

  /** {@code ownerId}'s albums, newest first. */
  public List<AlbumRow> owned(UUID ownerId) {
    return jdbc.sql(
            """
            SELECT a.id, a.owner_id, a.name,
                   (SELECT count(*) FROM album_item i WHERE i.album_id = a.id) AS photos
            FROM album a WHERE a.owner_id = :owner
            ORDER BY a.created_at DESC
            """)
        .param("owner", ownerId)
        .query(AlbumStore::mapAlbum)
        .list();
  }

  public void delete(UUID id) {
    jdbc.sql("DELETE FROM album WHERE id = :id").param("id", id).update();
  }

  /** Photo ids, oldest first. */
  public List<UUID> items(UUID albumId) {
    return jdbc.sql(
            "SELECT media_id FROM album_item WHERE album_id = :album ORDER BY created_at, media_id")
        .param("album", albumId)
        .query(UUID.class)
        .list();
  }

  public void addItem(UUID albumId, UUID mediaId, Instant now) {
    jdbc.sql(
            """
            INSERT INTO album_item (album_id, media_id, created_at) VALUES (:album, :media, :now)
            ON CONFLICT DO NOTHING
            """)
        .param("album", albumId)
        .param("media", mediaId)
        .param("now", utc(now))
        .update();
  }

  public void removeItem(UUID albumId, UUID mediaId) {
    jdbc.sql("DELETE FROM album_item WHERE album_id = :album AND media_id = :media")
        .param("album", albumId)
        .param("media", mediaId)
        .update();
  }

  /** Grants or replaces {@code granteeId}'s access; a new grant can be opened again. */
  public void grant(
      UUID albumId, UUID granteeId, Instant expiresAt, boolean viewOnce, Instant now) {
    jdbc.sql(
            """
            INSERT INTO album_grant (album_id, grantee_id, expires_at, view_once, created_at)
            VALUES (:album, :grantee, :expires, :once, :now)
            ON CONFLICT (album_id, grantee_id) DO UPDATE
              SET expires_at = EXCLUDED.expires_at, view_once = EXCLUDED.view_once,
                  viewed_at = NULL, created_at = EXCLUDED.created_at
            """)
        .param("album", albumId)
        .param("grantee", granteeId)
        .param("expires", expiresAt == null ? null : utc(expiresAt))
        .param("once", viewOnce)
        .param("now", utc(now))
        .update();
  }

  public void revoke(UUID albumId, UUID granteeId) {
    jdbc.sql("DELETE FROM album_grant WHERE album_id = :album AND grantee_id = :grantee")
        .param("album", albumId)
        .param("grantee", granteeId)
        .update();
  }

  /** Grants on {@code albumId} still in force at {@code now}. */
  public List<GrantRow> grants(UUID albumId, Instant now) {
    return jdbc.sql(
            """
            SELECT album_id, grantee_id, expires_at, view_once, viewed_at FROM album_grant
            WHERE album_id = :album AND (expires_at IS NULL OR expires_at > :now)
            ORDER BY created_at
            """)
        .param("album", albumId)
        .param("now", utc(now))
        .query(AlbumStore::mapGrant)
        .list();
  }

  public Optional<GrantRow> grant(UUID albumId, UUID granteeId) {
    return jdbc.sql(
            """
            SELECT album_id, grantee_id, expires_at, view_once, viewed_at FROM album_grant
            WHERE album_id = :album AND grantee_id = :grantee
            """)
        .param("album", albumId)
        .param("grantee", granteeId)
        .query(AlbumStore::mapGrant)
        .optional();
  }

  /** Records the one allowed opening. False if someone already used it (a racing request). */
  public boolean markViewed(UUID albumId, UUID granteeId, Instant now) {
    return jdbc.sql(
                """
                UPDATE album_grant SET viewed_at = :now
                WHERE album_id = :album AND grantee_id = :grantee AND viewed_at IS NULL
                """)
            .param("album", albumId)
            .param("grantee", granteeId)
            .param("now", utc(now))
            .update()
        == 1;
  }

  /**
   * Albums shared with {@code granteeId} that can still be opened, without owners in a block with
   * them or owners who are no longer active.
   */
  public List<SharedRow> sharedWith(UUID granteeId, Instant now) {
    return jdbc.sql(
            """
            SELECT a.id, a.owner_id, a.name, g.expires_at, g.view_once,
                   (SELECT count(*) FROM album_item i WHERE i.album_id = a.id) AS photos
            FROM album_grant g
            JOIN album a ON a.id = g.album_id
            JOIN account owner ON owner.id = a.owner_id AND owner.status = 'ACTIVE'
            WHERE g.grantee_id = :grantee
              AND (g.expires_at IS NULL OR g.expires_at > :now)
              AND NOT (g.view_once AND g.viewed_at IS NOT NULL)
              AND NOT EXISTS (SELECT 1 FROM block b
                              WHERE (b.blocker_id = a.owner_id AND b.blocked_id = :grantee)
                                 OR (b.blocker_id = :grantee AND b.blocked_id = a.owner_id))
            ORDER BY g.created_at DESC
            """)
        .param("grantee", granteeId)
        .param("now", utc(now))
        .query((rs, row) ->
            new SharedRow(
                rs.getObject("id", UUID.class),
                rs.getObject("owner_id", UUID.class),
                rs.getString("name"),
                rs.getInt("photos"),
                instant(rs, "expires_at"),
                rs.getBoolean("view_once")))
        .list();
  }

  private static OffsetDateTime utc(Instant instant) {
    return instant.atOffset(ZoneOffset.UTC);
  }

  private static Instant instant(ResultSet rs, String column) throws SQLException {
    OffsetDateTime value = rs.getObject(column, OffsetDateTime.class);
    return value == null ? null : value.toInstant();
  }

  private static AlbumRow mapAlbum(ResultSet rs, int row) throws SQLException {
    return new AlbumRow(
        rs.getObject("id", UUID.class),
        rs.getObject("owner_id", UUID.class),
        rs.getString("name"),
        rs.getInt("photos"));
  }

  private static GrantRow mapGrant(ResultSet rs, int row) throws SQLException {
    return new GrantRow(
        rs.getObject("album_id", UUID.class),
        rs.getObject("grantee_id", UUID.class),
        instant(rs, "expires_at"),
        rs.getBoolean("view_once"),
        instant(rs, "viewed_at"));
  }

  /** An album. */
  public record AlbumRow(UUID id, UUID ownerId, String name, int photoCount) {}

  /** A grant. */
  public record GrantRow(
      UUID albumId, UUID granteeId, Instant expiresAt, boolean viewOnce, Instant viewedAt) {

    public boolean activeAt(Instant now) {
      return (expiresAt == null || expiresAt.isAfter(now)) && !(viewOnce && viewedAt != null);
    }
  }

  /** An album shared with the caller. */
  public record SharedRow(
      UUID id, UUID ownerId, String name, int photoCount, Instant expiresAt, boolean viewOnce) {}
}

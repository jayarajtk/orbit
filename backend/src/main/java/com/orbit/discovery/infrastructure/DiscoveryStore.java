package com.orbit.discovery.infrastructure;

import com.orbit.discovery.domain.GeoPoint;
import com.orbit.discovery.domain.LocationSnapper.Snapped;
import java.sql.Array;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/**
 * Discovery's SQL. Writes only its own tables ({@code user_location}, {@code favorite}).
 *
 * <p>The people queries are a deliberate read model: they also read {@code profile}, {@code
 * account} and {@code block}, so the grid is one indexed query instead of N+1 calls across modules.
 * Blocks are excluded with {@code NOT EXISTS} in both directions (design doc §5).
 */
@Repository
public class DiscoveryStore {

  private static final String PEOPLE_SELECT =
      """
      WITH me AS (SELECT point FROM user_location WHERE account_id = :me)
      SELECT p.account_id, p.display_name, p.show_age, p.show_distance, a.birth_date,
             a.created_at AS joined_at, p.last_active_at, p.bio, p.pronouns, p.height_cm,
             p.relationship, p.looking_for, p.tags,
             ST_Distance(l.point, (SELECT point FROM me)) AS meters,
             EXISTS (SELECT 1 FROM favorite f
                     WHERE f.owner_id = :me AND f.target_id = p.account_id) AS favorite,
             ARRAY(SELECT pp.media_id FROM profile_photo pp
                   JOIN media m ON m.id = pp.media_id
                               AND m.status = 'READY' AND NOT m.private_only
                   WHERE pp.account_id = p.account_id
                   ORDER BY pp.position) AS photo_ids
      FROM profile p
      JOIN account a ON a.id = p.account_id
      %s user_location l ON l.account_id = p.account_id
      %s
      WHERE a.status = 'ACTIVE'
        AND p.account_id <> :me
        AND NOT EXISTS (SELECT 1 FROM block b
                        WHERE (b.blocker_id = :me AND b.blocked_id = p.account_id)
                           OR (b.blocker_id = p.account_id AND b.blocked_id = :me))
      """;

  private final JdbcClient jdbc;

  public DiscoveryStore(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  /** The member's last stored (snapped) location and when it was stored. */
  public Optional<StoredLocation> location(UUID accountId) {
    return jdbc.sql(
            """
            SELECT ST_Y(point::geometry) AS lat, ST_X(point::geometry) AS lng, updated_at
            FROM user_location WHERE account_id = :id
            """)
        .param("id", accountId)
        .query((rs, row) ->
            new StoredLocation(
                new GeoPoint(rs.getDouble("lat"), rs.getDouble("lng")),
                rs.getObject("updated_at", OffsetDateTime.class).toInstant()))
        .optional();
  }

  public void saveLocation(UUID accountId, Snapped snapped, Instant now) {
    jdbc.sql(
            """
            INSERT INTO user_location (account_id, point, h3_cell, updated_at)
            VALUES (:id, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography, :cell, :now)
            ON CONFLICT (account_id) DO UPDATE
              SET point = EXCLUDED.point, h3_cell = EXCLUDED.h3_cell,
                  updated_at = EXCLUDED.updated_at
            """)
        .param("id", accountId)
        .param("lat", snapped.point().lat())
        .param("lng", snapped.point().lng())
        .param("cell", snapped.cell())
        .param("now", utc(now))
        .update();
  }

  /** Nearest members first, filtered; requires the caller to have a location. */
  public List<PersonRow> nearby(UUID me, GridFilter filter, int limit, int offset) {
    List<String> conditions = new ArrayList<>();
    JdbcClient.StatementSpec spec;
    conditions.add("a.birth_date <= :youngestBirth");
    conditions.add("a.birth_date > :oldestBirth");
    if (filter.onlineSince() != null) {
      conditions.add("p.last_active_at > :onlineSince");
    }
    if (!filter.lookingFor().isEmpty()) {
      conditions.add("p.looking_for && ARRAY[:lookingFor]::text[]");
    }
    if (filter.maxMeters() != null) {
      conditions.add("ST_DWithin(l.point, (SELECT point FROM me), :maxMeters)");
      conditions.add("p.show_distance");
    }
    String sql =
        PEOPLE_SELECT.formatted("JOIN", "")
            + conditions.stream().map(c -> "  AND " + c).reduce("", (a, b) -> a + "\n" + b)
            + "\nORDER BY l.point <-> (SELECT point FROM me), p.account_id"
            + "\nLIMIT :limit OFFSET :offset";
    spec =
        jdbc.sql(sql)
            .param("me", me)
            .param("youngestBirth", filter.youngestBirth())
            .param("oldestBirth", filter.oldestBirth())
            .param("limit", limit)
            .param("offset", offset);
    if (filter.onlineSince() != null) {
      spec = spec.param("onlineSince", utc(filter.onlineSince()));
    }
    if (!filter.lookingFor().isEmpty()) {
      spec = spec.param("lookingFor", filter.lookingFor());
    }
    if (filter.maxMeters() != null) {
      spec = spec.param("maxMeters", filter.maxMeters());
    }
    return spec.query(DiscoveryStore::mapPerson).list();
  }

  /** One member as seen by {@code me}; empty if missing, inactive or blocked either way. */
  public Optional<PersonRow> person(UUID me, UUID id) {
    return jdbc.sql(PEOPLE_SELECT.formatted("LEFT JOIN", "") + "  AND p.account_id = :id")
        .param("me", me)
        .param("id", id)
        .query(DiscoveryStore::mapPerson)
        .optional();
  }

  /** The caller's favorites, most recent first. */
  public List<PersonRow> favorites(UUID me) {
    return jdbc.sql(
            PEOPLE_SELECT.formatted(
                    "LEFT JOIN",
                    "JOIN favorite fav ON fav.owner_id = :me AND fav.target_id = p.account_id")
                + "ORDER BY fav.created_at DESC")
        .param("me", me)
        .query(DiscoveryStore::mapPerson)
        .list();
  }

  public void addFavorite(UUID owner, UUID target, Instant now) {
    jdbc.sql(
            """
            INSERT INTO favorite (owner_id, target_id, created_at)
            VALUES (:owner, :target, :now) ON CONFLICT DO NOTHING
            """)
        .param("owner", owner)
        .param("target", target)
        .param("now", utc(now))
        .update();
  }

  public void removeFavorite(UUID owner, UUID target) {
    jdbc.sql("DELETE FROM favorite WHERE owner_id = :owner AND target_id = :target")
        .param("owner", owner)
        .param("target", target)
        .update();
  }

  private static PersonRow mapPerson(ResultSet rs, int row) throws SQLException {
    double rawMeters = rs.getDouble("meters");
    Double meters = rs.wasNull() ? null : rawMeters;
    Integer height = rs.getObject("height_cm", Integer.class);
    return new PersonRow(
        rs.getObject("account_id", UUID.class),
        rs.getString("display_name"),
        rs.getBoolean("show_age"),
        rs.getBoolean("show_distance"),
        rs.getObject("birth_date", LocalDate.class),
        rs.getObject("joined_at", OffsetDateTime.class).toInstant(),
        rs.getObject("last_active_at", OffsetDateTime.class).toInstant(),
        meters,
        rs.getBoolean("favorite"),
        rs.getString("bio"),
        rs.getString("pronouns"),
        height,
        rs.getString("relationship"),
        strings(rs.getArray("looking_for")),
        strings(rs.getArray("tags")),
        uuids(rs.getArray("photo_ids")));
  }

  private static List<UUID> uuids(Array array) throws SQLException {
    if (array == null) {
      return List.of();
    }
    List<UUID> ids = new ArrayList<>();
    for (Object id : (Object[]) array.getArray()) {
      ids.add((UUID) id);
    }
    return List.copyOf(ids);
  }

  private static List<String> strings(Array array) throws SQLException {
    return array == null ? List.of() : List.of((String[]) array.getArray());
  }

  private static OffsetDateTime utc(Instant instant) {
    return instant.atOffset(ZoneOffset.UTC);
  }

  /**
   * A stored location.
   *
   * @param point snapped point
   * @param updatedAt when it was stored
   */
  public record StoredLocation(GeoPoint point, Instant updatedAt) {}

  /**
   * Grid filter in SQL terms.
   *
   * @param youngestBirth latest birth date allowed (minimum age)
   * @param oldestBirth birth dates must be after this (maximum age)
   * @param onlineSince only members active after this, or null
   * @param lookingFor overlap with any of these, or empty for any
   * @param maxMeters only members within this distance, or null
   */
  public record GridFilter(
      LocalDate youngestBirth,
      LocalDate oldestBirth,
      Instant onlineSince,
      List<String> lookingFor,
      Double maxMeters) {}

  /** One member row; {@code meters} is null when either side has no location. */
  public record PersonRow(
      UUID id,
      String displayName,
      boolean showAge,
      boolean showDistance,
      LocalDate birthDate,
      Instant joinedAt,
      Instant lastActiveAt,
      Double meters,
      boolean favorite,
      String bio,
      String pronouns,
      Integer heightCm,
      String relationship,
      List<String> lookingFor,
      List<String> tags,
      List<UUID> photoIds) {}
}

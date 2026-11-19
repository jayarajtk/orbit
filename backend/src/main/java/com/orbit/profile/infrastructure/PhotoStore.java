package com.orbit.profile.infrastructure;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** A member's public photos, in display order. */
@Repository
public class PhotoStore {

  private final JdbcClient jdbc;

  public PhotoStore(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  public List<UUID> photoIds(UUID accountId) {
    return jdbc.sql(
            "SELECT media_id FROM profile_photo WHERE account_id = :account ORDER BY position")
        .param("account", accountId)
        .query(UUID.class)
        .list();
  }

  /** Each member's photo at position 0 ({@link #replace} always numbers from 0). */
  public Map<UUID, UUID> mainPhotoIds(Collection<UUID> accountIds) {
    if (accountIds.isEmpty()) {
      return Map.of();
    }
    Map<UUID, UUID> photos = new HashMap<>();
    jdbc.sql(
            "SELECT account_id, media_id FROM profile_photo"
                + " WHERE account_id IN (:accounts) AND position = 0")
        .param("accounts", accountIds)
        .query(rs -> {
          photos.put(rs.getObject("account_id", UUID.class), rs.getObject("media_id", UUID.class));
        });
    return photos;
  }

  /** Replaces all of {@code accountId}'s photos with {@code mediaIds}, in that order. */
  public void replace(UUID accountId, List<UUID> mediaIds, Instant now) {
    jdbc.sql("DELETE FROM profile_photo WHERE account_id = :account")
        .param("account", accountId)
        .update();
    for (int position = 0; position < mediaIds.size(); position++) {
      jdbc.sql(
              """
              INSERT INTO profile_photo (account_id, position, media_id, created_at)
              VALUES (:account, :position, :media, :now)
              """)
          .param("account", accountId)
          .param("position", position)
          .param("media", mediaIds.get(position))
          .param("now", now.atOffset(ZoneOffset.UTC))
          .update();
    }
  }
}

package com.orbit.profile.infrastructure;

import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** Profile lookups by name, for moderators finding a member. */
@Repository
public class ProfileSearch {

  private final JdbcClient jdbc;

  public ProfileSearch(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  /**
   * Accounts whose display name starts with {@code prefix}, ignoring case, by name. LIKE wildcards
   * in the prefix match literally. Uses {@code profile_display_name_idx}.
   */
  public List<UUID> idsByNamePrefix(String prefix, int limit) {
    String escaped = prefix.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    return jdbc.sql(
            """
            SELECT account_id FROM profile
            WHERE lower(display_name) LIKE lower(:prefix) || '%' ESCAPE '\\'
            ORDER BY lower(display_name), account_id
            LIMIT :limit
            """)
        .param("prefix", escaped)
        .param("limit", limit)
        .query(UUID.class)
        .list();
  }
}

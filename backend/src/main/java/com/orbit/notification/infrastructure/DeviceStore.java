package com.orbit.notification.infrastructure;

import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/** Registered push targets. */
@Repository
public class DeviceStore {

  private final JdbcClient jdbc;

  public DeviceStore(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  /** Registers {@code token} for {@code accountId}, moving it from any previous account. */
  public void register(UUID accountId, String platform, String token, Instant now) {
    jdbc.sql(
            """
            INSERT INTO device (id, account_id, platform, push_token, created_at, last_seen_at)
            VALUES (:id, :account, :platform, :token, :now, :now)
            ON CONFLICT (push_token) DO UPDATE
              SET account_id = EXCLUDED.account_id, platform = EXCLUDED.platform,
                  last_seen_at = EXCLUDED.last_seen_at
            """)
        .param("id", UUID.randomUUID())
        .param("account", accountId)
        .param("platform", platform)
        .param("token", token)
        .param("now", now.atOffset(ZoneOffset.UTC))
        .update();
  }

  /** Forgets {@code token} if it belongs to {@code accountId} (sign-out). */
  public void unregister(UUID accountId, String token) {
    jdbc.sql("DELETE FROM device WHERE account_id = :account AND push_token = :token")
        .param("account", accountId)
        .param("token", token)
        .update();
  }

  public List<Device> devices(UUID accountId) {
    return jdbc.sql("SELECT platform, push_token FROM device WHERE account_id = :account")
        .param("account", accountId)
        .query((rs, row) -> new Device(rs.getString("platform"), rs.getString("push_token")))
        .list();
  }

  /** A push target. */
  public record Device(String platform, String token) {}
}

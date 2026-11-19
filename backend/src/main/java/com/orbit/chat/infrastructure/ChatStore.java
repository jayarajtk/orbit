package com.orbit.chat.infrastructure;

import com.orbit.chat.application.MessageView;
import com.orbit.chat.domain.MessageKind;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

/**
 * Chat SQL. Writes only chat tables. The inbox query is a read model that also reads {@code
 * profile}, {@code account} and {@code block}, like the discovery grid (design doc §5).
 */
@Repository
public class ChatStore {

  private static final String MESSAGE_COLUMNS =
      "m.id, m.conversation_id, m.seq, m.sender_id, m.client_msg_id, m.kind, m.text, "
          + "m.location_minutes, m.album_name, m.created_at, m.unsent_at, m.media_id, m.album_id,"
          + " m.view_once, m.viewed_at";

  private final JdbcClient jdbc;

  public ChatStore(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  /** Pair order used by the {@code conversation_order_ck} constraint (byte-wise UUID order). */
  public static boolean sortsFirst(UUID a, UUID b) {
    return a.toString().compareTo(b.toString()) < 0;
  }

  /** The conversation between two members, if one exists. */
  public Optional<UUID> conversationBetween(UUID a, UUID b) {
    UUID first = sortsFirst(a, b) ? a : b;
    UUID second = first.equals(a) ? b : a;
    return jdbc.sql("SELECT id FROM conversation WHERE member_a = :a AND member_b = :b")
        .param("a", first)
        .param("b", second)
        .query(UUID.class)
        .optional();
  }

  /** The conversation between two members, created (with both member rows) if needed. */
  public UUID conversationFor(UUID a, UUID b, Instant now) {
    UUID first = sortsFirst(a, b) ? a : b;
    UUID second = first.equals(a) ? b : a;
    jdbc.sql(
            """
            INSERT INTO conversation (id, member_a, member_b, created_at)
            VALUES (:id, :a, :b, :now) ON CONFLICT (member_a, member_b) DO NOTHING
            """)
        .param("id", UUID.randomUUID())
        .param("a", first)
        .param("b", second)
        .param("now", utc(now))
        .update();
    UUID id = conversationBetween(a, b).orElseThrow();
    for (UUID member : List.of(a, b)) {
      jdbc.sql(
              """
              INSERT INTO conversation_member (conversation_id, account_id)
              VALUES (:c, :m) ON CONFLICT DO NOTHING
              """)
          .param("c", id)
          .param("m", member)
          .update();
    }
    return id;
  }

  /** Reserves the next sequence number; the row lock serializes concurrent senders. */
  public long nextSeq(UUID conversationId, Instant now) {
    return jdbc.sql(
            """
            UPDATE conversation SET last_seq = last_seq + 1, last_message_at = :now
            WHERE id = :id RETURNING last_seq
            """)
        .param("id", conversationId)
        .param("now", utc(now))
        .query(Long.class)
        .single();
  }

  /** When {@code senderId} waved in the conversation since {@code since}, oldest first. */
  public List<Instant> wavesSince(UUID conversationId, UUID senderId, Instant since) {
    return jdbc.sql(
            """
            SELECT created_at FROM message
            WHERE conversation_id = :c AND sender_id = :s AND kind = 'WAVE'
              AND created_at > :since
            ORDER BY created_at
            """)
        .param("c", conversationId)
        .param("s", senderId)
        .param("since", utc(since))
        .query((rs, row) -> rs.getObject("created_at", OffsetDateTime.class).toInstant())
        .list();
  }

  public void insertMessage(MessageView m) {
    jdbc.sql(
            """
            INSERT INTO message (id, conversation_id, seq, sender_id, client_msg_id, kind, text,
                                 location_minutes, album_name, created_at, media_id, album_id,
                                 view_once)
            VALUES (:id, :c, :seq, :sender, :client, :kind, :text, :minutes, :album, :at,
                    :media, :albumId, :once)
            """)
        .param("id", m.id())
        .param("c", m.conversationId())
        .param("seq", m.seq())
        .param("sender", m.senderId())
        .param("client", m.clientMsgId())
        .param("kind", m.kind().name())
        .param("text", m.text())
        .param("minutes", m.locationMinutes())
        .param("album", m.albumName())
        .param("at", utc(m.createdAt()))
        .param("media", m.mediaId())
        .param("albumId", m.albumId())
        .param("once", m.viewOnce())
        .update();
  }

  /** Records the recipient's one opening of a view-once photo; false if already opened. */
  public boolean markViewed(UUID messageId, Instant now) {
    return jdbc.sql("UPDATE message SET viewed_at = :now WHERE id = :id AND viewed_at IS NULL")
            .param("id", messageId)
            .param("now", utc(now))
            .update()
        == 1;
  }

  /** Whether {@code accountId} deleted the conversation after {@code seq} (hiding it). */
  public boolean clearedFor(UUID conversationId, UUID accountId, long seq) {
    return jdbc.sql(
            """
            SELECT cleared_seq >= :seq FROM conversation_member
            WHERE conversation_id = :c AND account_id = :a
            """)
        .param("c", conversationId)
        .param("a", accountId)
        .param("seq", seq)
        .query(Boolean.class)
        .optional()
        .orElse(true);
  }

  public Optional<MessageView> byClientId(UUID senderId, String clientMsgId) {
    return jdbc.sql(
            "SELECT "
                + MESSAGE_COLUMNS
                + " FROM message m WHERE m.sender_id = :s AND m.client_msg_id = :c")
        .param("s", senderId)
        .param("c", clientMsgId)
        .query(ChatStore::mapMessage)
        .optional();
  }

  public Optional<MessageView> byId(UUID id) {
    return jdbc.sql("SELECT " + MESSAGE_COLUMNS + " FROM message m WHERE m.id = :id")
        .param("id", id)
        .query(ChatStore::mapMessage)
        .optional();
  }

  /**
   * Messages visible to {@code me}, oldest first: before {@code beforeSeq} (older pages) or after
   * {@code afterSeq} (catch-up), never including what {@code me} deleted.
   */
  public List<MessageView> messages(
      UUID conversationId, UUID me, Long beforeSeq, Long afterSeq, int limit) {
    String range =
        beforeSeq != null ? "AND m.seq < :before" : afterSeq != null ? "AND m.seq > :after" : "";
    String order = afterSeq != null ? "ASC" : "DESC";
    JdbcClient.StatementSpec spec =
        jdbc.sql(
                "SELECT "
                    + MESSAGE_COLUMNS
                    + """
                     FROM message m
                    JOIN conversation_member me ON me.conversation_id = m.conversation_id
                                               AND me.account_id = :me
                    WHERE m.conversation_id = :c AND m.seq > me.cleared_seq
                    """
                    + range
                    + " ORDER BY m.seq "
                    + order
                    + " LIMIT :limit")
            .param("c", conversationId)
            .param("me", me)
            .param("limit", limit);
    if (beforeSeq != null) {
      spec = spec.param("before", beforeSeq);
    }
    if (afterSeq != null) {
      spec = spec.param("after", afterSeq);
    }
    List<MessageView> rows = new ArrayList<>(spec.query(ChatStore::mapMessage).list());
    if (afterSeq == null) {
      Collections.reverse(rows);
    }
    return rows;
  }

  /**
   * The last {@code limit} messages of a conversation, oldest first, ignoring what either member
   * deleted for themselves.
   */
  public List<MessageView> latest(UUID conversationId, int limit) {
    List<MessageView> rows =
        new ArrayList<>(
            jdbc.sql(
                    "SELECT "
                        + MESSAGE_COLUMNS
                        + " FROM message m WHERE m.conversation_id = :c"
                        + " ORDER BY m.seq DESC LIMIT :limit")
                .param("c", conversationId)
                .param("limit", limit)
                .query(ChatStore::mapMessage)
                .list());
    Collections.reverse(rows);
    return rows;
  }

  /** How far {@code accountId} has read. */
  public long lastReadSeq(UUID conversationId, UUID accountId) {
    return jdbc.sql(
            """
            SELECT last_read_seq FROM conversation_member
            WHERE conversation_id = :c AND account_id = :a
            """)
        .param("c", conversationId)
        .param("a", accountId)
        .query(Long.class)
        .optional()
        .orElse(0L);
  }

  /** Moves the read marker forward (never back, never past the last message). */
  public void markRead(UUID conversationId, UUID accountId, long seq) {
    jdbc.sql(
            """
            UPDATE conversation_member cm
            SET last_read_seq = GREATEST(cm.last_read_seq,
                LEAST(:seq, (SELECT last_seq FROM conversation WHERE id = :c)))
            WHERE cm.conversation_id = :c AND cm.account_id = :a
            """)
        .param("c", conversationId)
        .param("a", accountId)
        .param("seq", seq)
        .update();
  }

  public boolean isMuted(UUID accountId, UUID conversationId) {
    return jdbc.sql(
            """
            SELECT muted FROM conversation_member WHERE conversation_id = :c AND account_id = :a
            """)
        .param("c", conversationId)
        .param("a", accountId)
        .query(Boolean.class)
        .optional()
        .orElse(false);
  }

  public void setMuted(UUID conversationId, UUID accountId, boolean muted) {
    jdbc.sql(
            """
            UPDATE conversation_member SET muted = :muted
            WHERE conversation_id = :c AND account_id = :a
            """)
        .param("c", conversationId)
        .param("a", accountId)
        .param("muted", muted)
        .update();
  }

  /** Deletes the conversation for {@code accountId} only: hides everything up to now. */
  public void clear(UUID conversationId, UUID accountId) {
    jdbc.sql(
            """
            UPDATE conversation_member
            SET cleared_seq = (SELECT last_seq FROM conversation WHERE id = :c),
                last_read_seq = (SELECT last_seq FROM conversation WHERE id = :c)
            WHERE conversation_id = :c AND account_id = :a
            """)
        .param("c", conversationId)
        .param("a", accountId)
        .update();
  }

  /** Removes a message's content; returns whether it was unsent now. */
  public boolean unsend(UUID messageId, Instant now) {
    return jdbc.sql(
                """
                UPDATE message SET unsent_at = :now, text = NULL, location_minutes = NULL,
                                   album_name = NULL, media_id = NULL, album_id = NULL
                WHERE id = :id AND unsent_at IS NULL
                """)
            .param("id", messageId)
            .param("now", utc(now))
            .update()
        == 1;
  }

  /** The other member of a conversation; empty unless {@code me} is a member. */
  public Optional<UUID> otherMember(UUID conversationId, UUID me) {
    return jdbc.sql(
            """
            SELECT other.account_id
            FROM conversation_member mine
            JOIN conversation_member other ON other.conversation_id = mine.conversation_id
                                          AND other.account_id <> mine.account_id
            WHERE mine.conversation_id = :c AND mine.account_id = :me
            """)
        .param("c", conversationId)
        .param("me", me)
        .query(UUID.class)
        .optional();
  }

  /** The inbox of {@code me}: newest first, without blocked or inactive members. */
  public List<InboxRow> inbox(UUID me, int limit) {
    return jdbc.sql(
            """
            SELECT c.id AS conversation_id, other.account_id AS other_id, p.display_name,
                   p.last_active_at, mine.muted,
                   (SELECT count(*) FROM message u
                    WHERE u.conversation_id = c.id AND u.sender_id <> :me
                      AND u.seq > GREATEST(mine.last_read_seq, mine.cleared_seq)) AS unread,
            """
                + MESSAGE_COLUMNS
                + """

                FROM conversation_member mine
                JOIN conversation c ON c.id = mine.conversation_id
                JOIN conversation_member other ON other.conversation_id = c.id
                                              AND other.account_id <> :me
                JOIN account a ON a.id = other.account_id AND a.status = 'ACTIVE'
                JOIN profile p ON p.account_id = other.account_id
                JOIN LATERAL (SELECT * FROM message lm WHERE lm.conversation_id = c.id
                              ORDER BY lm.seq DESC LIMIT 1) m ON TRUE
                WHERE mine.account_id = :me
                  AND c.last_seq > mine.cleared_seq
                  AND NOT EXISTS (SELECT 1 FROM block b
                                  WHERE (b.blocker_id = :me AND b.blocked_id = other.account_id)
                                     OR (b.blocker_id = other.account_id AND b.blocked_id = :me))
                ORDER BY c.last_message_at DESC
                LIMIT :limit
                """)
        .param("me", me)
        .param("limit", limit)
        .query((rs, row) ->
            new InboxRow(
                rs.getObject("other_id", UUID.class),
                rs.getString("display_name"),
                rs.getObject("last_active_at", OffsetDateTime.class).toInstant(),
                rs.getBoolean("muted"),
                rs.getLong("unread"),
                mapMessage(rs, row)))
        .list();
  }

  private static MessageView mapMessage(ResultSet rs, int row) throws SQLException {
    OffsetDateTime unsentAt = rs.getObject("unsent_at", OffsetDateTime.class);
    return new MessageView(
        rs.getObject("id", UUID.class),
        rs.getObject("conversation_id", UUID.class),
        rs.getLong("seq"),
        rs.getObject("sender_id", UUID.class),
        rs.getString("client_msg_id"),
        MessageKind.valueOf(rs.getString("kind")),
        rs.getString("text"),
        rs.getObject("location_minutes", Integer.class),
        rs.getString("album_name"),
        rs.getObject("created_at", OffsetDateTime.class).toInstant(),
        unsentAt != null,
        rs.getObject("media_id", UUID.class),
        rs.getObject("album_id", UUID.class),
        rs.getBoolean("view_once"),
        rs.getObject("viewed_at", OffsetDateTime.class) != null);
  }

  private static OffsetDateTime utc(Instant instant) {
    return instant.atOffset(ZoneOffset.UTC);
  }

  /** One inbox row. */
  public record InboxRow(
      UUID otherId,
      String displayName,
      Instant otherLastActive,
      boolean muted,
      long unread,
      MessageView last) {}
}

package com.orbit.moderation;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;

import com.orbit.MutableClock;
import com.orbit.TestcontainersConfiguration;
import com.orbit.identity.application.SuspensionLifter;
import java.net.URI;
import java.time.Duration;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.client.RestTestClient;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketHttpHeaders;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.handler.TextWebSocketHandler;

/**
 * Moderation end to end against real PostGIS and Redis (ADR-0007): the role check, the queue,
 * evidence copied at report time, every action and its effect on the member, suspension expiry,
 * appeals, and the audit log.
 *
 * <p>Tokens are fake: the token value is the subject. Tokens starting with {@code mod-} carry the
 * {@code moderator} realm role and a username.
 */
@Import({TestcontainersConfiguration.class, MutableClock.Config.class})
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
class ModerationIntegrationTests {

  private static final Instant START = Instant.parse("2026-11-18T12:00:00Z");
  private static final String MOD = "mod-sam";

  @MockitoBean JwtDecoder jwtDecoder;

  @Autowired RestTestClient client;
  @Autowired JdbcClient jdbc;
  @Autowired MutableClock clock;
  @Autowired SuspensionLifter lifter;

  @LocalServerPort int port;

  private final Map<String, String> ids = new HashMap<>();

  @BeforeEach
  void setUp() {
    for (String table :
        List.of(
            "admin_audit",
            "event_publication",
            "message",
            "conversation_member",
            "conversation",
            "block",
            "report",
            "profile",
            "account")) {
      jdbc.sql("DELETE FROM " + table).update();
    }
    clock.set(START);
    given(jwtDecoder.decode(anyString())).willAnswer(call -> jwt(call.getArgument(0)));
    for (String who : List.of("alice", "bob", "carol")) {
      ids.put(who, onboard(who));
    }
  }

  // --- helpers -------------------------------------------------------------------------------

  private static Jwt jwt(String token) {
    Jwt.Builder jwt =
        Jwt.withTokenValue(token)
            .header("alg", "RS256")
            .subject(token)
            .issuedAt(START)
            .expiresAt(START.plus(Duration.ofDays(400)));
    if (token.startsWith("mod-")) {
      jwt.claim("preferred_username", token.substring(4))
          .claim("realm_access", Map.of("roles", List.of("moderator", "offline_access")));
    }
    return jwt.build();
  }

  private RestTestClient.ResponseSpec post(String who, String uri, String body) {
    return client
        .post()
        .uri(uri)
        .header("Authorization", "Bearer " + who)
        .contentType(MediaType.APPLICATION_JSON)
        .body(body)
        .exchange();
  }

  private RestTestClient.ResponseSpec get(String who, String uri) {
    return client.get().uri(uri).header("Authorization", "Bearer " + who).exchange();
  }

  @SuppressWarnings("unchecked")
  private <T> T body(RestTestClient.ResponseSpec response, Class<T> type) {
    return response
        .expectStatus()
        .is2xxSuccessful()
        .expectBody(type)
        .returnResult()
        .getResponseBody();
  }

  @SuppressWarnings("unchecked")
  private List<Map<String, Object>> list(RestTestClient.ResponseSpec response) {
    return body(response, List.class);
  }

  @SuppressWarnings("unchecked")
  private String onboard(String who) {
    Map<String, Object> account =
        body(post(who, "/api/v1/accounts", "{\"birthDate\":\"1990-05-01\"}"), Map.class);
    client
        .put()
        .uri("/api/v1/me/profile")
        .header("Authorization", "Bearer " + who)
        .contentType(MediaType.APPLICATION_JSON)
        .body("{\"displayName\":\"" + who + "\",\"lookingFor\":[\"CHAT\"]}")
        .exchange()
        .expectStatus()
        .isOk();
    return (String) account.get("id");
  }

  private void sendText(String from, String to, String clientId, String text) {
    post(
            from,
            "/api/v1/conversations/" + ids.get(to) + "/messages",
            "{\"clientMsgId\":\"%s\",\"kind\":\"TEXT\",\"text\":\"%s\"}".formatted(clientId, text))
        .expectStatus()
        .is2xxSuccessful();
  }

  private void report(String reporter, String subject, String reason) {
    post(
            reporter,
            "/api/v1/reports",
            "{\"accountId\":\"%s\",\"reason\":\"%s\",\"details\":\"see chat\"}"
                .formatted(ids.get(subject), reason))
        .expectStatus()
        .isAccepted();
  }

  private RestTestClient.ResponseSpec act(String subject, String json) {
    return post(MOD, "/api/v1/admin/members/" + ids.get(subject) + "/actions", json);
  }

  @SuppressWarnings("unchecked")
  private Map<String, Object> member(String subject) {
    return body(get(MOD, "/api/v1/admin/members/" + ids.get(subject)), Map.class);
  }

  @SuppressWarnings("unchecked")
  private Map<String, Object> standing(String who) {
    return body(get(who, "/api/v1/me/standing"), Map.class);
  }

  private String reportStatus(String subject) {
    return jdbc.sql("SELECT DISTINCT status FROM report WHERE subject_id = :s")
        .param("s", UUID.fromString(ids.get(subject)))
        .query(String.class)
        .single();
  }

  private void expectProblem(RestTestClient.ResponseSpec response, int status, String type) {
    response
        .expectStatus()
        .isEqualTo(status)
        .expectBody()
        .jsonPath("$.type")
        .isEqualTo("urn:orbit:problem:" + type);
  }

  // --- tests ---------------------------------------------------------------------------------

  @Nested
  class Access {

    @Test
    void theAdminApiNeedsTheModeratorRole() {
      client.get().uri("/api/v1/admin/cases").exchange().expectStatus().isUnauthorized();
      get("alice", "/api/v1/admin/cases").expectStatus().isForbidden();
      get(MOD, "/api/v1/admin/cases").expectStatus().isOk();
    }

    @Test
    void membersCanNotActOnEachOther() {
      post(
              "alice",
              "/api/v1/admin/members/" + ids.get("bob") + "/actions",
              "{\"kind\":\"BAN\",\"policy\":\"SPAM\"}")
          .expectStatus()
          .isForbidden();

      assertThat(standing("bob").get("status")).isEqualTo("ACTIVE");
    }

    @Test
    void moderatorsNeedNoMemberAccount() {
      get(MOD, "/api/v1/admin/members/" + ids.get("bob")).expectStatus().isOk();
    }
  }

  @Nested
  class Queue {

    @Test
    void urgentReportsComeFirstThenTheOldest() {
      report("alice", "bob", "FAKE");
      clock.advance(Duration.ofMinutes(5));
      report("alice", "carol", "UNDERAGE");
      clock.advance(Duration.ofMinutes(5));
      report("carol", "bob", "HARASSMENT");

      List<Map<String, Object>> cases = list(get(MOD, "/api/v1/admin/cases"));

      assertThat(cases).hasSize(2);
      assertThat(cases.get(0))
          .containsEntry("subjectId", ids.get("carol"))
          .containsEntry("urgent", true);
      assertThat(cases.get(1))
          .containsEntry("subjectId", ids.get("bob"))
          .containsEntry("displayName", "bob")
          .containsEntry("openReports", 2)
          .containsEntry("urgent", false)
          .containsEntry("reasons", List.of("FAKE", "HARASSMENT"));
    }

    @Test
    void claimingShowsWhoIsReviewing() {
      report("alice", "bob", "FAKE");

      post(MOD, "/api/v1/admin/cases/" + ids.get("bob") + "/claim", "")
          .expectStatus()
          .isNoContent();

      assertThat(list(get(MOD, "/api/v1/admin/cases")).getFirst()).containsEntry("reviewer", "sam");
      assertThat(reportStatus("bob")).isEqualTo("IN_REVIEW");
    }

    @Test
    void findsMembersByNameOrId() {
      List<?> byName = body(get(MOD, "/api/v1/admin/members?q=CA"), List.class);
      List<?> byId = body(get(MOD, "/api/v1/admin/members?q=" + ids.get("bob")), List.class);
      List<?> wildcard = body(get(MOD, "/api/v1/admin/members?q=%25"), List.class);

      assertThat(byName).singleElement().asString().contains(ids.get("carol"));
      assertThat(byId).singleElement().asString().contains("displayName=bob", "status=ACTIVE");
      assertThat(wildcard).isEmpty();
    }
  }

  @Nested
  class Evidence {

    @Test
    @SuppressWarnings("unchecked")
    void reportsKeepTheConversationEvenAfterAnUnsend() {
      sendText("bob", "alice", "b-1", "you again");
      sendText("alice", "bob", "a-1", "please stop");
      sendText("bob", "alice", "b-2", "threatening words");
      report("alice", "bob", "THREAT");
      String unsent =
          jdbc.sql("SELECT id FROM message WHERE client_msg_id = 'b-2'")
              .query(String.class)
              .single();
      post("bob", "/api/v1/messages/" + unsent + "/unsend", "").expectStatus().is2xxSuccessful();

      Map<String, Object> report =
          (Map<String, Object>) ((List<?>) member("bob").get("reports")).getFirst();

      assertThat(report).containsEntry("reason", "THREAT").containsEntry("reporterName", "alice");
      List<Map<String, Object>> evidence = (List<Map<String, Object>>) report.get("evidence");
      assertThat(evidence)
          .extracting(m -> m.get("text"))
          .containsExactly("you again", "please stop", "threatening words");
      assertThat(evidence).extracting(m -> m.get("fromSubject")).containsExactly(true, false, true);
    }

    @Test
    void readingAMemberRecordIsAudited() {
      member("bob");

      List<?> audit = body(get(MOD, "/api/v1/admin/audit?accountId=" + ids.get("bob")), List.class);
      assertThat(audit).singleElement().asString().contains("actor=sam", "MEMBER_VIEWED");
    }
  }

  @Nested
  class Actions {

    @Test
    @SuppressWarnings("unchecked")
    void aWarningIsShownOnceAndResolvesReports() {
      report("alice", "bob", "HARASSMENT");

      act("bob", "{\"kind\":\"WARN\",\"policy\":\"HARASSMENT\",\"memberMessage\":\"Be kind.\"}")
          .expectStatus()
          .isCreated();

      assertThat(reportStatus("bob")).isEqualTo("ACTIONED");
      Map<String, Object> standing = standing("bob");
      assertThat(standing).containsEntry("status", "ACTIVE").containsEntry("restriction", null);
      Map<String, Object> warning =
          (Map<String, Object>) ((List<?>) standing.get("warnings")).getFirst();
      assertThat(warning).containsEntry("message", "Be kind.").doesNotContainKey("internalNote");

      post("bob", "/api/v1/me/warnings/" + warning.get("id") + "/ack", "")
          .expectStatus()
          .isNoContent();
      assertThat((List<?>) standing("bob").get("warnings")).isEmpty();
      get("bob", "/api/v1/me/profile").expectStatus().isOk();
    }

    @Test
    void aSuspendedMemberIsRefusedUntilItEnds() {
      act("bob", "{\"kind\":\"SUSPEND\",\"policy\":\"SPAM\",\"suspendHours\":24}")
          .expectStatus()
          .isCreated();

      expectProblem(get("bob", "/api/v1/me/profile"), 403, "account-restricted");
      expectProblem(
          post(
              "alice",
              "/api/v1/conversations/" + ids.get("bob") + "/messages",
              "{\"clientMsgId\":\"x\",\"kind\":\"TEXT\",\"text\":\"hi\"}"),
          404,
          "recipient-unavailable");
      assertThat(standing("bob"))
          .containsEntry("status", "SUSPENDED")
          .containsEntry("suspendedUntil", "2026-11-19T12:00:00Z");

      clock.advance(Duration.ofHours(24));
      get("bob", "/api/v1/me/profile").expectStatus().isOk();
      assertThat(lifter.liftEnded()).isEqualTo(1);
      assertThat(standing("bob")).containsEntry("status", "ACTIVE");
    }

    @Test
    void aBanClosesLiveConnectionsOnTheSpot() throws Exception {
      CompletableFuture<CloseStatus> closed = new CompletableFuture<>();
      WebSocketHttpHeaders headers = new WebSocketHttpHeaders();
      headers.setBearerAuth("bob");
      CompletableFuture<Void> registered = new CompletableFuture<>();
      WebSocketSession socket =
          new StandardWebSocketClient()
              .execute(
                  new TextWebSocketHandler() {
                    @Override
                    protected void handleTextMessage(WebSocketSession s, TextMessage m) {
                      registered.complete(null);
                    }

                    @Override
                    public void afterConnectionClosed(WebSocketSession s, CloseStatus status) {
                      closed.complete(status);
                    }
                  },
                  headers,
                  URI.create("ws://localhost:" + port + "/ws/v1"))
              .get(5, TimeUnit.SECONDS);
      socket.sendMessage(new TextMessage("{\"type\":\"ping\"}"));
      registered.get(5, TimeUnit.SECONDS);

      act("bob", "{\"kind\":\"BAN\",\"policy\":\"THREAT\"}").expectStatus().isCreated();

      CloseStatus status = closed.get(5, TimeUnit.SECONDS);
      assertThat(status.getCode()).isEqualTo(CloseStatus.POLICY_VIOLATION.getCode());
      assertThat(status.getReason()).isEqualTo("account-restricted");
    }

    @Test
    void removingAPhotoTakesItDownEverywhere() {
      UUID photo = UUID.randomUUID();
      OffsetDateTime now = START.atOffset(ZoneOffset.UTC);
      jdbc.sql(
              """
              INSERT INTO media (id, owner_id, purpose, kind, status, content_type, size_bytes,
                  storage_key, created_at, updated_at)
              VALUES (:id, :owner, 'PROFILE_PHOTO', 'PHOTO', 'READY', 'image/jpeg', 10, 'k',
                  :now, :now)
              """)
          .param("id", photo)
          .param("owner", UUID.fromString(ids.get("bob")))
          .param("now", now)
          .update();
      jdbc.sql(
              "INSERT INTO profile_photo (account_id, position, media_id, created_at)"
                  + " VALUES (:owner, 0, :id, :now)")
          .param("id", photo)
          .param("owner", UUID.fromString(ids.get("bob")))
          .param("now", now)
          .update();

      act(
              "bob",
              "{\"kind\":\"REMOVE_PHOTO\",\"policy\":\"EXPLICIT_PHOTO\",\"mediaId\":\"%s\"}"
                  .formatted(photo))
          .expectStatus()
          .isCreated();

      assertThat(
              jdbc.sql("SELECT status FROM media WHERE id = :id")
                  .param("id", photo)
                  .query(String.class)
                  .single())
          .isEqualTo("REMOVED");
      assertThat(
              jdbc.sql("SELECT count(*) FROM profile_photo WHERE media_id = :id")
                  .param("id", photo)
                  .query(Integer.class)
                  .single())
          .isZero();
      expectProblem(
          act(
              "bob",
              "{\"kind\":\"REMOVE_PHOTO\",\"policy\":\"EXPLICIT_PHOTO\",\"mediaId\":\"%s\"}"
                  .formatted(photo)),
          422,
          "invalid-action");
    }

    @Test
    void dismissingClosesReportsWithoutTouchingTheAccount() {
      report("alice", "bob", "FAKE");

      act("bob", "{\"kind\":\"DISMISS\",\"policy\":\"NO_VIOLATION\",\"internalNote\":\"real\"}")
          .expectStatus()
          .isCreated();

      assertThat(reportStatus("bob")).isEqualTo("DISMISSED");
      assertThat(standing("bob")).containsEntry("status", "ACTIVE");
      assertThat((List<?>) body(get(MOD, "/api/v1/admin/cases"), List.class)).isEmpty();
    }

    @Test
    void refusesActionsThatDoNotFit() {
      expectProblem(
          act("bob", "{\"kind\":\"SUSPEND\",\"policy\":\"SPAM\"}"), 422, "invalid-action");
      expectProblem(
          act("bob", "{\"kind\":\"SUSPEND\",\"policy\":\"SPAM\",\"suspendHours\":9000}"),
          422,
          "invalid-action");
      expectProblem(
          act("bob", "{\"kind\":\"WARN\",\"policy\":\"APPEAL_GRANTED\"}"), 422, "invalid-action");
      expectProblem(
          act("bob", "{\"kind\":\"WARN\",\"policy\":\"NO_VIOLATION\"}"), 422, "invalid-action");
      expectProblem(
          act("bob", "{\"kind\":\"REINSTATE\",\"policy\":\"OTHER\"}"), 422, "invalid-action");
      act("bob", "{\"kind\":\"BAN\",\"policy\":\"SPAM\"}").expectStatus().isCreated();
      expectProblem(act("bob", "{\"kind\":\"BAN\",\"policy\":\"SPAM\"}"), 422, "invalid-action");
      expectProblem(
          post(
              MOD,
              "/api/v1/admin/members/" + UUID.randomUUID() + "/actions",
              "{\"kind\":\"BAN\",\"policy\":\"SPAM\"}"),
          404,
          "account-not-found");
    }

    @Test
    void moderatorsCanReinstate() {
      act("bob", "{\"kind\":\"BAN\",\"policy\":\"SPAM\"}").expectStatus().isCreated();

      act("bob", "{\"kind\":\"REINSTATE\",\"policy\":\"OTHER\",\"internalNote\":\"mistake\"}")
          .expectStatus()
          .isCreated();

      get("bob", "/api/v1/me/profile").expectStatus().isOk();
      assertThat(member("bob").get("actions"))
          .asString()
          .contains("kind=REINSTATE")
          .contains("reversedBy=");
    }
  }

  @Nested
  class Appeals {

    @BeforeEach
    void banBob() {
      act(
              "bob",
              "{\"kind\":\"BAN\",\"policy\":\"THREAT\",\"memberMessage\":\"Threats aren't allowed.\","
                  + "\"internalNote\":\"see report\"}")
          .expectStatus()
          .isCreated();
    }

    @Test
    @SuppressWarnings("unchecked")
    void aBannedMemberSeesWhyButNotTheInternalNote() {
      Map<String, Object> standing = standing("bob");

      assertThat(standing).containsEntry("status", "BANNED");
      Map<String, Object> restriction = (Map<String, Object>) standing.get("restriction");
      assertThat(restriction)
          .containsEntry("kind", "BAN")
          .containsEntry("policy", "THREAT")
          .containsEntry("message", "Threats aren't allowed.")
          .containsEntry("canAppeal", true)
          .containsEntry("appeal", null);
      assertThat(standing.toString()).doesNotContain("see report", "sam");
    }

    @Test
    void reversingAnAppealReinstatesTheAccount() {
      post("bob", "/api/v1/me/appeals", "{\"text\":\"It was a joke between friends.\"}")
          .expectStatus()
          .isCreated();
      expectProblem(
          post("bob", "/api/v1/me/appeals", "{\"text\":\"again\"}"), 409, "appeal-exists");

      List<Map<String, Object>> open = list(get(MOD, "/api/v1/admin/appeals"));
      assertThat(open)
          .singleElement()
          .satisfies(appeal ->
              assertThat(appeal)
                  .containsEntry("displayName", "bob")
                  .containsEntry("actionKind", "BAN"));
      String appealId = (String) open.getFirst().get("id");

      post(
              MOD,
              "/api/v1/admin/appeals/" + appealId + "/decision",
              "{\"reverse\":true,\"memberMessage\":\"Welcome back.\"}")
          .expectStatus()
          .isOk();

      get("bob", "/api/v1/me/profile").expectStatus().isOk();
      assertThat(standing("bob"))
          .containsEntry("status", "ACTIVE")
          .containsEntry("restriction", null);
      assertThat(member("bob").get("actions"))
          .asString()
          .contains("kind=REINSTATE, policy=APPEAL_GRANTED");
      expectProblem(
          post(MOD, "/api/v1/admin/appeals/" + appealId + "/decision", "{\"reverse\":false}"),
          409,
          "appeal-decided");
      assertThat((List<?>) body(get(MOD, "/api/v1/admin/appeals"), List.class)).isEmpty();
    }

    @Test
    @SuppressWarnings("unchecked")
    void anUpheldAppealKeepsTheBan() {
      post("bob", "/api/v1/me/appeals", "{\"text\":\"Please reconsider.\"}")
          .expectStatus()
          .isCreated();
      String appealId = (String) list(get(MOD, "/api/v1/admin/appeals")).getFirst().get("id");

      post(
              MOD,
              "/api/v1/admin/appeals/" + appealId + "/decision",
              "{\"reverse\":false,\"memberMessage\":\"The ban stays.\"}")
          .expectStatus()
          .isOk();

      Map<String, Object> restriction = (Map<String, Object>) standing("bob").get("restriction");
      assertThat(restriction).containsEntry("canAppeal", false);
      assertThat((Map<String, Object>) restriction.get("appeal"))
          .containsEntry("status", "UPHELD")
          .containsEntry("decisionMessage", "The ban stays.");
      expectProblem(get("bob", "/api/v1/me/profile"), 403, "account-restricted");
    }

    @Test
    void activeMembersHaveNothingToAppeal() {
      expectProblem(
          post("alice", "/api/v1/me/appeals", "{\"text\":\"why\"}"), 409, "not-restricted");
    }

    @Test
    void everyDecisionIsInTheAuditLog() {
      List<?> audit = body(get(MOD, "/api/v1/admin/audit"), List.class);

      assertThat(audit).singleElement().asString().contains("ACTION_TAKEN", "BAN THREAT");
    }
  }

  @Test
  void standingNeedsAnAccount() {
    expectProblem(get("nobody", "/api/v1/me/standing"), 404, "account-not-found");
  }

  @Test
  void reportsAreStillFiledWithoutAConversation() {
    report("carol", "bob", "FAKE");

    assertThat(member("bob").get("reports")).asString().contains("evidence=[]");
  }
}

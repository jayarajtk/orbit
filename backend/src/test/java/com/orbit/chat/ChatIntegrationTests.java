package com.orbit.chat;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;

import com.orbit.MutableClock;
import com.orbit.TestcontainersConfiguration;
import com.orbit.notification.application.PushSender;
import java.net.URI;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.client.RestTestClient;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketHttpHeaders;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/** Chat over REST and WebSocket, plus push rules, against real PostGIS and Redis. */
@Import({
  TestcontainersConfiguration.class,
  MutableClock.Config.class,
  ChatIntegrationTests.CapturingPush.class
})
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ChatIntegrationTests {

  private static final Instant START = Instant.parse("2026-11-17T12:00:00Z");
  private static final Duration FRAME_WAIT = Duration.ofSeconds(5);

  @MockitoBean JwtDecoder jwtDecoder;

  @Autowired JdbcClient jdbc;
  @Autowired MutableClock clock;
  @Autowired JsonMapper json;
  @Autowired List<PushSender.Push> pushes;

  @LocalServerPort int port;

  /** The JDK client ignores Retry-After; Apache's would sleep through a 429's 22-hour wait. */
  private RestTestClient client;

  private final Map<String, String> ids = new HashMap<>();
  private final List<WebSocketSession> sockets = new CopyOnWriteArrayList<>();

  /** Records pushes instead of sending them. */
  @TestConfiguration(proxyBeanMethods = false)
  static class CapturingPush {

    @Bean
    List<PushSender.Push> capturedPushes() {
      return new CopyOnWriteArrayList<>();
    }

    @Bean
    @Primary
    PushSender capturingPushSender(List<PushSender.Push> capturedPushes) {
      return capturedPushes::add;
    }
  }

  @BeforeEach
  void setUp() {
    client =
        RestTestClient.bindToServer(new JdkClientHttpRequestFactory())
            .baseUrl("http://localhost:" + port)
            .build();
    for (String table :
        List.of(
            "event_publication",
            "message",
            "conversation_member",
            "conversation",
            "device",
            "favorite",
            "block",
            "report",
            "user_location",
            "profile",
            "account")) {
      jdbc.sql("DELETE FROM " + table).update();
    }
    pushes.clear();
    clock.set(START);
    given(jwtDecoder.decode(anyString()))
        .willAnswer(call -> {
          String token = call.getArgument(0);
          return Jwt.withTokenValue(token)
              .header("alg", "RS256")
              .subject(token)
              .issuedAt(START)
              .expiresAt(START.plus(Duration.ofDays(1)))
              .build();
        });
    ids.put("alice", onboard("alice"));
    ids.put("bob", onboard("bob"));
  }

  @AfterEach
  void closeSockets() throws Exception {
    for (WebSocketSession socket : sockets) {
      socket.close();
    }
  }

  // --- helpers -------------------------------------------------------------------------------

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
  private String onboard(String who) {
    Map<String, Object> account =
        post(who, "/api/v1/accounts", "{\"birthDate\":\"1990-05-01\"}")
            .expectStatus()
            .isCreated()
            .expectBody(Map.class)
            .returnResult()
            .getResponseBody();
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

  private RestTestClient.ResponseSpec sendText(
      String from, String to, String clientId, String text) {
    return post(
        from,
        "/api/v1/conversations/" + ids.get(to) + "/messages",
        "{\"clientMsgId\":\"%s\",\"kind\":\"TEXT\",\"text\":\"%s\"}".formatted(clientId, text));
  }

  private RestTestClient.ResponseSpec sendWave(String from, String to, String clientId) {
    return post(
        from,
        "/api/v1/conversations/" + ids.get(to) + "/messages",
        "{\"clientMsgId\":\"%s\",\"kind\":\"WAVE\"}".formatted(clientId));
  }

  private long waveRows() {
    return jdbc.sql("SELECT count(*) FROM message WHERE kind = 'WAVE'").query(Long.class).single();
  }

  /** Opens a chat socket as {@code who}; frames land in the returned queue. */
  private BlockingQueue<JsonNode> connect(String who) throws Exception {
    BlockingQueue<JsonNode> frames = new LinkedBlockingQueue<>();
    WebSocketHttpHeaders headers = new WebSocketHttpHeaders();
    headers.setBearerAuth(who);
    WebSocketSession socket =
        new StandardWebSocketClient()
            .execute(
                new TextWebSocketHandler() {
                  @Override
                  protected void handleTextMessage(WebSocketSession s, TextMessage m) {
                    frames.add(json.readTree(m.getPayload()));
                  }
                },
                headers,
                URI.create("ws://localhost:" + port + "/ws/v1"))
            .get(5, TimeUnit.SECONDS);
    sockets.add(socket);
    // Wait until the server has registered the socket (presence is set on connect).
    socket.sendMessage(new TextMessage("{\"type\":\"ping\"}"));
    assertThat(nextOfType(frames, "pong")).isNotNull();
    return frames;
  }

  private static JsonNode nextOfType(BlockingQueue<JsonNode> frames, String type)
      throws InterruptedException {
    long deadline = System.nanoTime() + FRAME_WAIT.toNanos();
    while (System.nanoTime() < deadline) {
      JsonNode frame = frames.poll(100, TimeUnit.MILLISECONDS);
      if (frame != null && type.equals(frame.get("type").asString())) {
        return frame;
      }
    }
    throw new AssertionError("No '" + type + "' frame within " + FRAME_WAIT);
  }

  // --- REST ----------------------------------------------------------------------------------

  @Nested
  class Rest {

    @Test
    void sendsOnceEvenWhenRetried() {
      sendText("alice", "bob", "c-1", "Hi Bob").expectStatus().isCreated();
      sendText("alice", "bob", "c-1", "Hi Bob").expectStatus().isOk();

      assertThat(jdbc.sql("SELECT count(*) FROM message").query(Long.class).single()).isOne();
    }

    @Test
    void historyInboxUnreadAndReadReceipts() {
      sendText("alice", "bob", "c-1", "Hi Bob").expectStatus().isCreated();
      sendText("alice", "bob", "c-2", "Coffee?").expectStatus().isCreated();

      get("bob", "/api/v1/conversations")
          .expectStatus()
          .isOk()
          .expectBody()
          .jsonPath("$[0].otherId")
          .isEqualTo(ids.get("alice"))
          .jsonPath("$[0].unread")
          .isEqualTo(2)
          .jsonPath("$[0].last.text")
          .isEqualTo("Coffee?");

      post(
              "bob",
              "/api/v1/conversations/" + ids.get("alice") + "/read",
              "{\"seq\":2,\"share\":true}")
          .expectStatus()
          .isNoContent();

      get("bob", "/api/v1/conversations").expectBody().jsonPath("$[0].unread").isEqualTo(0);
      get("alice", "/api/v1/conversations/" + ids.get("bob") + "/messages")
          .expectStatus()
          .isOk()
          .expectBody()
          .jsonPath("$.items.length()")
          .isEqualTo(2)
          .jsonPath("$.items[0].seq")
          .isEqualTo(1)
          .jsonPath("$.otherReadSeq")
          .isEqualTo(2);
    }

    @Test
    void catchUpReturnsOnlyNewerMessages() {
      sendText("alice", "bob", "c-1", "one").expectStatus().isCreated();
      sendText("alice", "bob", "c-2", "two").expectStatus().isCreated();

      get("bob", "/api/v1/conversations/" + ids.get("alice") + "/messages?after=1")
          .expectBody()
          .jsonPath("$.items.length()")
          .isEqualTo(1)
          .jsonPath("$.items[0].text")
          .isEqualTo("two");
    }

    @Test
    void blockedMembersCannotMessageAndDisappearFromInbox() {
      sendText("alice", "bob", "c-1", "Hi").expectStatus().isCreated();
      post("bob", "/api/v1/blocks", "{\"accountId\":\"%s\"}".formatted(ids.get("alice")))
          .expectStatus()
          .isNoContent();

      sendText("alice", "bob", "c-2", "Hello?")
          .expectStatus()
          .isNotFound()
          .expectBody()
          .jsonPath("$.type")
          .isEqualTo("urn:orbit:problem:recipient-unavailable");
      get("bob", "/api/v1/conversations").expectBody().json("[]");
      get("alice", "/api/v1/conversations").expectBody().json("[]");
    }

    @Test
    void rejectsContentThatDoesNotMatchItsKind() {
      post(
              "alice",
              "/api/v1/conversations/" + ids.get("bob") + "/messages",
              "{\"clientMsgId\":\"c-1\",\"kind\":\"TEXT\",\"text\":\"  \"}")
          .expectStatus()
          .isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT);
      post(
              "alice",
              "/api/v1/conversations/" + ids.get("bob") + "/messages",
              "{\"clientMsgId\":\"c-2\",\"kind\":\"LOCATION\",\"locationMinutes\":20}")
          .expectStatus()
          .isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT);
      sendText("alice", "alice", "c-3", "me").expectStatus().isNotFound();
    }

    @Test
    @SuppressWarnings("unchecked")
    void unsendOnlyWithinTenMinutesAndOnlyOwnMessages() {
      Map<String, Object> first =
          sendText("alice", "bob", "c-1", "oops")
              .expectBody(Map.class)
              .returnResult()
              .getResponseBody();
      post("bob", "/api/v1/messages/" + first.get("id") + "/unsend", "")
          .expectStatus()
          .isNotFound();
      post("alice", "/api/v1/messages/" + first.get("id") + "/unsend", "")
          .expectStatus()
          .isNoContent();
      get("bob", "/api/v1/conversations/" + ids.get("alice") + "/messages")
          .expectBody()
          .jsonPath("$.items[0].unsent")
          .isEqualTo(true)
          .jsonPath("$.items[0].text")
          .doesNotExist();

      Map<String, Object> second =
          sendText("alice", "bob", "c-2", "keep")
              .expectBody(Map.class)
              .returnResult()
              .getResponseBody();
      clock.advance(Duration.ofMinutes(11));
      post("alice", "/api/v1/messages/" + second.get("id") + "/unsend", "")
          .expectStatus()
          .isEqualTo(HttpStatus.CONFLICT);
    }

    @Test
    void deleteHidesTheConversationForTheCallerOnly() {
      sendText("alice", "bob", "c-1", "old").expectStatus().isCreated();
      client
          .delete()
          .uri("/api/v1/conversations/" + ids.get("bob"))
          .header("Authorization", "Bearer alice")
          .exchange()
          .expectStatus()
          .isNoContent();

      get("alice", "/api/v1/conversations").expectBody().json("[]");
      get("bob", "/api/v1/conversations").expectBody().jsonPath("$.length()").isEqualTo(1);

      sendText("bob", "alice", "c-2", "new").expectStatus().isCreated();
      get("alice", "/api/v1/conversations/" + ids.get("bob") + "/messages")
          .expectBody()
          .jsonPath("$.items.length()")
          .isEqualTo(1)
          .jsonPath("$.items[0].text")
          .isEqualTo("new");
    }
  }

  // --- WebSocket -----------------------------------------------------------------------------

  @Nested
  class Live {

    @Test
    void deliversMessagesAcksTypingAndReceipts() throws Exception {
      BlockingQueue<JsonNode> alice = connect("alice");
      BlockingQueue<JsonNode> bob = connect("bob");

      sockets
          .get(0)
          .sendMessage(
              new TextMessage(
                  """
                  {"type":"msg.send","to":"%s","clientMsgId":"c-1","kind":"TEXT","text":"Hey!"}
                  """
                      .formatted(ids.get("bob"))));

      JsonNode received = nextOfType(bob, "msg.new");
      assertThat(received.get("with").asString()).isEqualTo(ids.get("alice"));
      assertThat(received.get("message").get("text").asString()).isEqualTo("Hey!");
      JsonNode ack = nextOfType(alice, "msg.ack");
      assertThat(ack.get("clientMsgId").asString()).isEqualTo("c-1");
      assertThat(ack.get("message").get("seq").asLong()).isOne();

      sockets
          .get(1)
          .sendMessage(
              new TextMessage("{\"type\":\"typing\",\"to\":\"%s\"}".formatted(ids.get("alice"))));
      assertThat(nextOfType(alice, "typing").get("with").asString()).isEqualTo(ids.get("bob"));

      sockets
          .get(1)
          .sendMessage(
              new TextMessage(
                  "{\"type\":\"read\",\"with\":\"%s\",\"seq\":1,\"share\":true}"
                      .formatted(ids.get("alice"))));
      assertThat(nextOfType(alice, "msg.read").get("seq").asLong()).isOne();
    }

    @Test
    void reportsBadFramesWithoutDisconnecting() throws Exception {
      BlockingQueue<JsonNode> alice = connect("alice");

      sockets.get(0).sendMessage(new TextMessage("not json"));
      assertThat(nextOfType(alice, "error").get("code").asString()).isEqualTo("bad-frame");

      sockets
          .get(0)
          .sendMessage(
              new TextMessage(
                  """
                  {"type":"msg.send","to":"%s","clientMsgId":"c-1","kind":"TEXT","text":" "}
                  """
                      .formatted(ids.get("bob"))));
      JsonNode error = nextOfType(alice, "error");
      assertThat(error.get("code").asString()).isEqualTo("invalid-message");
      assertThat(error.get("clientMsgId").asString()).isEqualTo("c-1");
      assertThat(sockets.get(0).isOpen()).isTrue();
    }

    @Test
    void rejectsSocketsWithoutAToken() {
      assertThatThrownBy(() ->
              new StandardWebSocketClient()
                  .execute(
                      new TextWebSocketHandler(),
                      new WebSocketHttpHeaders(),
                      URI.create("ws://localhost:" + port + "/ws/v1"))
                  .get(5, TimeUnit.SECONDS))
          .hasMessageContaining("401");
    }
  }

  // --- Push ----------------------------------------------------------------------------------

  @Nested
  class Push {

    private void registerDevice(String who, String token) {
      post(who, "/api/v1/devices", "{\"platform\":\"IOS\",\"token\":\"%s\"}".formatted(token))
          .expectStatus()
          .isNoContent();
    }

    @Test
    void pushesOfflineRecipientsWithoutContent() {
      registerDevice("bob", "bob-phone");

      sendText("alice", "bob", "c-1", "secret text").expectStatus().isCreated();

      await().atMost(FRAME_WAIT).until(() -> !pushes.isEmpty());
      PushSender.Push push = pushes.get(0);
      assertThat(push.token()).isEqualTo("bob-phone");
      assertThat(push.toString()).doesNotContain("secret text").doesNotContain("alice");
    }

    @Test
    void skipsOnlineRecipients() throws Exception {
      registerDevice("bob", "bob-phone");
      connect("bob");

      sendText("alice", "bob", "c-1", "hi").expectStatus().isCreated();
      sendText("alice", "bob", "c-2", "marker").expectStatus().isCreated();

      // Both events are processed in order of publication; wait until they are complete.
      await()
          .atMost(FRAME_WAIT)
          .until(() ->
              jdbc.sql("SELECT count(*) FROM event_publication WHERE completion_date IS NULL")
                      .query(Long.class)
                      .single()
                  == 0);
      assertThat(pushes).isEmpty();
    }

    @Test
    void skipsMutedConversations() {
      registerDevice("bob", "bob-phone");
      sendText("alice", "bob", "c-1", "first").expectStatus().isCreated();
      await().atMost(FRAME_WAIT).until(() -> pushes.size() == 1);

      client
          .put()
          .uri("/api/v1/conversations/" + ids.get("alice") + "/mute")
          .header("Authorization", "Bearer bob")
          .contentType(MediaType.APPLICATION_JSON)
          .body("{\"muted\":true}")
          .exchange()
          .expectStatus()
          .isNoContent();
      sendText("alice", "bob", "c-2", "second").expectStatus().isCreated();

      await()
          .atMost(FRAME_WAIT)
          .until(() ->
              jdbc.sql("SELECT count(*) FROM event_publication WHERE completion_date IS NULL")
                      .query(Long.class)
                      .single()
                  == 0);
      assertThat(pushes).hasSize(1);
    }
  }

  // --- wave limit ----------------------------------------------------------------------------

  @Nested
  class WaveLimit {

    private static final Duration WINDOW = Duration.ofHours(24);

    @Test
    void thirdWaveWithin24hIsRefused() {
      sendWave("alice", "bob", "w-1").expectStatus().isCreated();
      clock.advance(Duration.ofHours(1));
      sendWave("alice", "bob", "w-2").expectStatus().isCreated();
      clock.advance(Duration.ofHours(1));

      Instant retryAt = START.plus(WINDOW);
      long retryAfter = Duration.between(clock.instant(), retryAt).toSeconds();
      sendWave("alice", "bob", "w-3")
          .expectStatus()
          .isEqualTo(HttpStatus.TOO_MANY_REQUESTS)
          .expectHeader()
          .valueEquals("Retry-After", String.valueOf(retryAfter))
          .expectBody()
          .jsonPath("$.type")
          .isEqualTo("urn:orbit:problem:wave-limit")
          .jsonPath("$.retryAt")
          .isEqualTo(retryAt.toString());
      assertThat(waveRows()).isEqualTo(2);
    }

    @Test
    void waveToAnotherMemberIsAllowed() {
      ids.put("carol", onboard("carol"));
      sendWave("alice", "bob", "w-1").expectStatus().isCreated();
      sendWave("alice", "bob", "w-2").expectStatus().isCreated();

      sendWave("alice", "carol", "w-3").expectStatus().isCreated();
    }

    @Test
    void waveAllowedAfterWindow() {
      sendWave("alice", "bob", "w-1").expectStatus().isCreated();
      sendWave("alice", "bob", "w-2").expectStatus().isCreated();
      clock.advance(WINDOW.plusSeconds(1));

      sendWave("alice", "bob", "w-3").expectStatus().isCreated();
    }

    @Test
    void duplicateClientIdAfterLimitReturnsStoredWave() {
      sendWave("alice", "bob", "w-1").expectStatus().isCreated();
      String secondId = waveId(sendWave("alice", "bob", "w-2"));

      assertThat(waveId(sendWave("alice", "bob", "w-2"))).isEqualTo(secondId);
      assertThat(waveRows()).isEqualTo(2);
    }

    @Test
    void socketGetsWaveLimitError() throws Exception {
      sendWave("alice", "bob", "w-1").expectStatus().isCreated();
      sendWave("alice", "bob", "w-2").expectStatus().isCreated();
      BlockingQueue<JsonNode> alice = connect("alice");

      sockets
          .get(0)
          .sendMessage(
              new TextMessage(
                  "{\"type\":\"msg.send\",\"to\":\"%s\",\"clientMsgId\":\"w-3\",\"kind\":\"WAVE\"}"
                      .formatted(ids.get("bob"))));

      JsonNode error = nextOfType(alice, "error");
      assertThat(error.get("code").asString()).isEqualTo("wave-limit");
      assertThat(error.get("clientMsgId").asString()).isEqualTo("w-3");
      assertThat(Instant.parse(error.get("retryAt").asString())).isEqualTo(START.plus(WINDOW));
    }

    @Test
    void concurrentWavesStoreAtMostTwo() throws Exception {
      int attempts = 5;
      ExecutorService pool = Executors.newFixedThreadPool(attempts);
      CountDownLatch gate = new CountDownLatch(1);
      try {
        List<Future<?>> sends = new java.util.ArrayList<>();
        for (int i = 0; i < attempts; i++) {
          String clientId = "w-" + i;
          sends.add(
              pool.submit(() -> {
                gate.await();
                sendWave("alice", "bob", clientId);
                return null;
              }));
        }
        gate.countDown();
        for (Future<?> send : sends) {
          send.get(30, TimeUnit.SECONDS);
        }
      } finally {
        pool.shutdownNow();
      }

      assertThat(waveRows()).isEqualTo(2);
    }

    @Test
    void concurrentResendOfTheLimitingWaveIsNotRefused() throws Exception {
      sendWave("alice", "bob", "w-1").expectStatus().isCreated();
      ExecutorService pool = Executors.newFixedThreadPool(2);
      CountDownLatch gate = new CountDownLatch(1);
      try {
        List<Future<String>> sends = new java.util.ArrayList<>();
        for (int i = 0; i < 2; i++) {
          sends.add(
              pool.submit(() -> {
                gate.await();
                return waveId(sendWave("alice", "bob", "w-2"));
              }));
        }
        gate.countDown();
        assertThat(sends.get(0).get(30, TimeUnit.SECONDS))
            .isEqualTo(sends.get(1).get(30, TimeUnit.SECONDS));
      } finally {
        pool.shutdownNow();
      }

      assertThat(waveRows()).isEqualTo(2);
    }

    private String waveId(RestTestClient.ResponseSpec response) {
      return response
          .expectBody(JsonNode.class)
          .returnResult()
          .getResponseBody()
          .get("id")
          .asString();
    }
  }
}

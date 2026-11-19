package com.orbit.status;

import static org.assertj.core.api.Assertions.assertThat;
import static org.awaitility.Awaitility.await;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.clearInvocations;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.timeout;
import static org.mockito.Mockito.verify;

import com.orbit.MutableClock;
import com.orbit.TestcontainersConfiguration;
import com.orbit.identity.IdentityApi;
import com.orbit.media.MediaApi;
import com.orbit.media.application.MediaScanner;
import com.orbit.media.application.ObjectStorage;
import com.orbit.shared.CountingDataSource;
import com.orbit.shared.CountingDataSource.Counted;
import com.orbit.shared.config.EventResubmissionJob;
import com.orbit.status.StatusApi.StatusExpired;
import com.orbit.status.StatusApi.StatusState;
import com.orbit.status.application.StatusReaper;
import com.orbit.status.infrastructure.StatusStore;
import io.micrometer.core.instrument.MeterRegistry;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.client.RestTestClient;
import org.springframework.transaction.event.TransactionalEventListener;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * 24-hour photo statuses end to end against real PostGIS and S3-compatible storage: posting and its
 * limits, who may see them, views, viewers and early deletion.
 */
@Import({
  TestcontainersConfiguration.class,
  MutableClock.Config.class,
  CountingDataSource.Config.class,
  StatusIntegrationTests.ExpiryRecorder.class,
  StatusIntegrationTests.ScannerConfig.class
})
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
class StatusIntegrationTests {

  private static final Instant START = Instant.parse("2026-11-18T12:00:00Z");
  private static final Duration EVENT_WAIT = Duration.ofSeconds(5);
  private static final String PURGER = "StatusMediaPurger";

  @MockitoBean JwtDecoder jwtDecoder;
  @MockitoSpyBean StatusStore statusStore;

  @Autowired RestTestClient client;
  @Autowired JdbcClient jdbc;
  @Autowired JsonMapper json;
  @Autowired MutableClock clock;
  @Autowired IdentityApi identity;
  @Autowired StatusApi statusApi;
  @Autowired StatusReaper reaper;
  @Autowired MediaApi mediaApi;
  @MockitoSpyBean ObjectStorage storage;
  @Autowired EventResubmissionJob resubmission;
  @Autowired CountingDataSource dataSource;
  @Autowired MeterRegistry meters;
  @Autowired ExpiryRecorder expiries;
  @Autowired AtomicReference<MediaScanner.Verdict> verdict;

  private final HttpClient http = HttpClient.newHttpClient();
  private final Map<String, String> ids = new HashMap<>();

  /** A scanner whose verdict each test chooses. */
  @TestConfiguration(proxyBeanMethods = false)
  static class ScannerConfig {

    @Bean
    AtomicReference<MediaScanner.Verdict> scannerVerdict() {
      return new AtomicReference<>(MediaScanner.Verdict.CLEAN);
    }

    @Bean
    @Primary
    MediaScanner testScanner(AtomicReference<MediaScanner.Verdict> scannerVerdict) {
      return (kind, content) -> scannerVerdict.get();
    }
  }

  /**
   * Records {@link StatusExpired} after commit. Being a transactional listener, it also makes
   * Modulith store the publication in its registry, which the delete test checks.
   */
  @TestConfiguration(proxyBeanMethods = false)
  static class ExpiryRecorder {

    private final List<StatusExpired> events = new CopyOnWriteArrayList<>();

    @TransactionalEventListener
    void on(StatusExpired event) {
      events.add(event);
    }

    List<StatusExpired> events() {
      return events;
    }
  }

  @BeforeEach
  void setUp() {
    for (String table :
        List.of(
            "status_view",
            "status",
            "event_publication",
            "block",
            "report",
            "profile",
            "account")) {
      jdbc.sql("DELETE FROM " + table).update();
    }
    expiries.events().clear();
    verdict.set(MediaScanner.Verdict.CLEAN);
    clock.set(START);
    given(jwtDecoder.decode(anyString()))
        .willAnswer(call -> {
          String token = call.getArgument(0);
          return Jwt.withTokenValue(token)
              .header("alg", "RS256")
              .subject(token)
              .issuedAt(START)
              .expiresAt(START.plus(Duration.ofDays(2)))
              .build();
        });
    for (String who : List.of("alice", "bob", "carol")) {
      ids.put(who, onboard(who));
    }
  }

  // --- helpers -------------------------------------------------------------------------------

  private RestTestClient.ResponseSpec send(String method, String who, String uri, String body) {
    RestTestClient.RequestBodySpec request =
        client.method(HttpMethod.valueOf(method)).uri(uri).header("Authorization", "Bearer " + who);
    if (body != null) {
      request.contentType(MediaType.APPLICATION_JSON).body(body);
    }
    return request.exchange();
  }

  private RestTestClient.ResponseSpec post(String who, String uri, String body) {
    return send("POST", who, uri, body);
  }

  private RestTestClient.ResponseSpec put(String who, String uri, String body) {
    return send("PUT", who, uri, body);
  }

  private RestTestClient.ResponseSpec get(String who, String uri) {
    return send("GET", who, uri, null);
  }

  private RestTestClient.ResponseSpec delete(String who, String uri) {
    return send("DELETE", who, uri, null);
  }

  private JsonNode body(RestTestClient.ResponseSpec spec) {
    return json.readTree(spec.expectBody(String.class).returnResult().getResponseBody());
  }

  /** Creates an account and a profile; returns the account id. */
  private String onboard(String who) {
    JsonNode account =
        body(
            post(who, "/api/v1/accounts", "{\"birthDate\":\"1990-05-01\"}")
                .expectStatus()
                .isCreated());
    put(who, "/api/v1/me/profile", "{\"displayName\":\"" + who + "\",\"lookingFor\":[\"CHAT\"]}")
        .expectStatus()
        .isOk();
    return account.get("id").asString();
  }

  /** Uploads and completes a small photo for {@code purpose}; returns the media id. */
  private String photo(String who, String purpose) throws IOException, InterruptedException {
    byte[] bytes = jpeg();
    JsonNode ticket =
        body(
            post(
                    who,
                    "/api/v1/media/uploads",
                    "{\"purpose\":\"%s\",\"contentType\":\"image/jpeg\",\"sizeBytes\":%d}"
                        .formatted(purpose, bytes.length))
                .expectStatus()
                .isCreated());
    HttpResponse<String> stored =
        http.send(
            HttpRequest.newBuilder(URI.create(ticket.get("uploadUrl").asString()))
                .header("Content-Type", "image/jpeg")
                .PUT(HttpRequest.BodyPublishers.ofByteArray(bytes))
                .build(),
            HttpResponse.BodyHandlers.ofString());
    assertThat(stored.statusCode()).isEqualTo(200);
    String id = ticket.get("id").asString();
    post(who, "/api/v1/media/uploads/" + id + "/complete", "{}").expectStatus().isOk();
    return id;
  }

  private static byte[] jpeg() throws IOException {
    BufferedImage image = new BufferedImage(64, 48, BufferedImage.TYPE_INT_RGB);
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    ImageIO.write(image, "jpeg", out);
    return out.toByteArray();
  }

  private RestTestClient.ResponseSpec postStatus(String who, String mediaId, String caption) {
    String body =
        caption == null
            ? "{\"mediaId\":\"%s\"}".formatted(mediaId)
            : "{\"mediaId\":\"%s\",\"caption\":\"%s\"}".formatted(mediaId, caption);
    return post(who, "/api/v1/me/statuses", body);
  }

  /** Posts a status from a fresh status photo; returns the status id. */
  private String status(String who) throws IOException, InterruptedException {
    return body(postStatus(who, photo(who, "STATUS_PHOTO"), null).expectStatus().isCreated())
        .get("id")
        .asString();
  }

  private RestTestClient.ResponseSpec statusesOf(String viewer, String owner) {
    return get(viewer, "/api/v1/profiles/" + ids.get(owner) + "/statuses");
  }

  private RestTestClient.ResponseSpec view(String viewer, String statusId) {
    return put(viewer, "/api/v1/statuses/" + statusId + "/view", null);
  }

  private void expectProblem(RestTestClient.ResponseSpec spec, HttpStatus status, String type) {
    spec.expectStatus()
        .isEqualTo(status)
        .expectBody()
        .jsonPath("$.type")
        .isEqualTo("urn:orbit:problem:" + type);
  }

  private void block(String blocker, String blocked) {
    post(blocker, "/api/v1/blocks", "{\"accountId\":\"%s\"}".formatted(ids.get(blocked)))
        .expectStatus()
        .is2xxSuccessful();
  }

  private UUID id(String who) {
    return UUID.fromString(ids.get(who));
  }

  private double counter(String name) {
    var counter = meters.find(name).counter();
    return counter == null ? 0 : counter.count();
  }

  // --- posting -------------------------------------------------------------------------------

  @Nested
  class Posting {

    @Test
    void postAndListMyStatus() throws Exception {
      double postedBefore = counter("orbit.status.posted");
      String mediaId = photo("alice", "STATUS_PHOTO");

      JsonNode posted = body(postStatus("alice", mediaId, "Sunny day").expectStatus().isCreated());

      assertThat(posted.get("id").asString()).isNotBlank();
      assertThat(posted.get("url").asString()).isNotBlank();
      assertThat(posted.get("thumbUrl").asString()).isNotBlank();
      assertThat(posted.get("caption").asString()).isEqualTo("Sunny day");
      assertThat(Instant.parse(posted.get("createdAt").asString())).isEqualTo(START);
      assertThat(Instant.parse(posted.get("expiresAt").asString()))
          .isEqualTo(START.plus(Duration.ofHours(24)));
      assertThat(posted.get("viewCount").asLong()).isZero();
      assertThat(posted.get("viewers").size()).isZero();
      assertThat(counter("orbit.status.posted")).isEqualTo(postedBefore + 1);

      JsonNode mine = body(get("alice", "/api/v1/me/statuses").expectStatus().isOk());
      assertThat(mine.size()).isOne();
      assertThat(mine.get(0).get("id").asString()).isEqualTo(posted.get("id").asString());
      assertThat(mine.get(0).get("caption").asString()).isEqualTo("Sunny day");
      assertThat(mine.get(0).get("url").asString()).isNotBlank();
    }

    @Test
    void eleventhLiveStatusIsRefused() throws Exception {
      for (int i = 0; i < 10; i++) {
        status("alice");
      }
      String eleventh = photo("alice", "STATUS_PHOTO");

      expectProblem(postStatus("alice", eleventh, null), HttpStatus.CONFLICT, "status-limit");
      assertThat(jdbc.sql("SELECT count(*) FROM status").query(Long.class).single()).isEqualTo(10);

      // Expired statuses no longer count, even before the reaper deletes them.
      clock.advance(Duration.ofHours(24).plusSeconds(1));
      postStatus("alice", eleventh, null).expectStatus().isCreated();
    }

    @Test
    void concurrentPostsCannotBothTakeTheLastSlot() throws Exception {
      for (int i = 0; i < 9; i++) {
        status("alice");
      }
      String first = photo("alice", "STATUS_PHOTO");
      String second = photo("alice", "STATUS_PHOTO");
      CountDownLatch go = new CountDownLatch(1);
      ExecutorService pool = Executors.newFixedThreadPool(2);
      try {
        List<Callable<Integer>> posts =
            List.of(
                () -> {
                  go.await();
                  return postStatus("alice", first, null)
                      .returnResult(String.class)
                      .getStatus()
                      .value();
                },
                () -> {
                  go.await();
                  return postStatus("alice", second, null)
                      .returnResult(String.class)
                      .getStatus()
                      .value();
                });
        List<Future<Integer>> results = posts.stream().map(pool::submit).toList();
        go.countDown();
        List<Integer> statuses = new ArrayList<>();
        for (Future<Integer> result : results) {
          statuses.add(result.get(10, TimeUnit.SECONDS));
        }

        assertThat(statuses).containsExactlyInAnyOrder(201, 409);
        assertThat(jdbc.sql("SELECT count(*) FROM status").query(Long.class).single())
            .isEqualTo(10);
      } finally {
        pool.shutdownNow();
      }
    }

    @Test
    void captionOver100Refused() throws Exception {
      String mediaId = photo("alice", "STATUS_PHOTO");

      expectProblem(
          postStatus("alice", mediaId, "x".repeat(101)),
          HttpStatus.UNPROCESSABLE_CONTENT,
          "invalid-status");
      postStatus("alice", mediaId, "x".repeat(100)).expectStatus().isCreated();
    }

    @Test
    void otherMembersMediaRefused() throws Exception {
      String bobs = photo("bob", "STATUS_PHOTO");

      expectProblem(
          postStatus("alice", bobs, null), HttpStatus.UNPROCESSABLE_CONTENT, "invalid-status");
      assertThat(jdbc.sql("SELECT count(*) FROM status").query(Long.class).single()).isZero();
    }

    @Test
    void privateOnlyPhotoRefused() throws Exception {
      verdict.set(MediaScanner.Verdict.PRIVATE_ONLY);
      String privateOnly = photo("alice", "STATUS_PHOTO");

      // A status reaches the same audience as the profile, so the public-photo rule applies.
      expectProblem(
          postStatus("alice", privateOnly, null),
          HttpStatus.UNPROCESSABLE_CONTENT,
          "invalid-status");
      assertThat(jdbc.sql("SELECT count(*) FROM status").query(Long.class).single()).isZero();
    }

    @Test
    void profilePhotoPurposeRefused() throws Exception {
      String profilePhoto = photo("alice", "PROFILE_PHOTO");

      expectProblem(
          postStatus("alice", profilePhoto, null),
          HttpStatus.UNPROCESSABLE_CONTENT,
          "invalid-status");
    }

    @Test
    void samePhotoCannotBePostedTwice() throws Exception {
      String mediaId = photo("alice", "STATUS_PHOTO");
      postStatus("alice", mediaId, null).expectStatus().isCreated();

      // Deleting either status purges the photo, which would break the other one.
      expectProblem(
          postStatus("alice", mediaId, null), HttpStatus.UNPROCESSABLE_CONTENT, "invalid-status");
    }

    @Test
    void restrictedMemberCannotPost() throws Exception {
      String mediaId = photo("alice", "STATUS_PHOTO");
      identity.ban(id("alice"));

      expectProblem(postStatus("alice", mediaId, null), HttpStatus.FORBIDDEN, "account-restricted");
      assertThat(jdbc.sql("SELECT count(*) FROM status").query(Long.class).single()).isZero();
    }
  }

  // --- visibility ----------------------------------------------------------------------------

  @Nested
  class Visibility {

    @Test
    void visibleMemberSeesStatusOldestFirst() throws Exception {
      String older = status("alice");
      clock.advance(Duration.ofMinutes(5));
      String newer = status("alice");

      JsonNode items = body(statusesOf("bob", "alice").expectStatus().isOk());

      assertThat(items.size()).isEqualTo(2);
      assertThat(items.get(0).get("id").asString()).isEqualTo(older);
      assertThat(items.get(1).get("id").asString()).isEqualTo(newer);
      assertThat(items.get(0).get("url").asString()).isNotBlank();
      assertThat(items.get(0).get("thumbUrl").asString()).isNotBlank();
      assertThat(Instant.parse(items.get(0).get("createdAt").asString())).isEqualTo(START);
      assertThat(items.get(0).get("seen").asBoolean()).isFalse();

      view("bob", older).expectStatus().isNoContent();

      JsonNode after = body(statusesOf("bob", "alice").expectStatus().isOk());
      assertThat(after.get(0).get("seen").asBoolean()).isTrue();
      assertThat(after.get(1).get("seen").asBoolean()).isFalse();
    }

    @Test
    void blockedViewerGets404() throws Exception {
      String statusId = status("alice");

      block("bob", "alice");
      expectProblem(statusesOf("bob", "alice"), HttpStatus.NOT_FOUND, "status-not-found");
      expectProblem(view("bob", statusId), HttpStatus.NOT_FOUND, "status-not-found");

      delete("bob", "/api/v1/blocks/" + ids.get("alice")).expectStatus().isNoContent();
      statusesOf("bob", "alice").expectStatus().isOk();

      block("alice", "bob");
      expectProblem(statusesOf("bob", "alice"), HttpStatus.NOT_FOUND, "status-not-found");
      expectProblem(view("bob", statusId), HttpStatus.NOT_FOUND, "status-not-found");

      statusesOf("carol", "alice").expectStatus().isOk();
      assertThat(jdbc.sql("SELECT count(*) FROM status_view").query(Long.class).single()).isZero();
    }

    @Test
    void restrictedOwnerHidden() throws Exception {
      String statusId = status("alice");

      identity.suspend(id("alice"), START.plus(Duration.ofDays(1)));

      expectProblem(statusesOf("bob", "alice"), HttpStatus.NOT_FOUND, "status-not-found");
      expectProblem(view("bob", statusId), HttpStatus.NOT_FOUND, "status-not-found");
    }

    @Test
    void viewerWithoutProfileGets404() throws Exception {
      String statusId = status("alice");
      post("dave", "/api/v1/accounts", "{\"birthDate\":\"1990-05-01\"}").expectStatus().isCreated();

      expectProblem(statusesOf("dave", "alice"), HttpStatus.NOT_FOUND, "status-not-found");
      expectProblem(view("dave", statusId), HttpStatus.NOT_FOUND, "status-not-found");
    }

    @Test
    void unknownMemberAndUnknownStatusGet404() {
      expectProblem(
          get("bob", "/api/v1/profiles/" + UUID.randomUUID() + "/statuses"),
          HttpStatus.NOT_FOUND,
          "status-not-found");
      expectProblem(
          view("bob", UUID.randomUUID().toString()), HttpStatus.NOT_FOUND, "status-not-found");
    }

    @Test
    void expiredStatusNotServedBeforeReaper() throws Exception {
      String statusId = status("alice");

      clock.advance(Duration.ofHours(24).plusSeconds(1));

      assertThat(body(statusesOf("bob", "alice").expectStatus().isOk()).size()).isZero();
      expectProblem(view("bob", statusId), HttpStatus.NOT_FOUND, "status-not-found");
      assertThat(body(get("alice", "/api/v1/me/statuses").expectStatus().isOk()).size()).isZero();
      assertThat(statusApi.liveStatusOf(id("alice"), UUID.fromString(statusId))).isEmpty();
      // Still stored: only the reaper deletes it.
      assertThat(jdbc.sql("SELECT count(*) FROM status").query(Long.class).single()).isOne();
    }
  }

  // --- views and viewers ---------------------------------------------------------------------

  @Nested
  class Views {

    @Test
    void viewRecordedOnceAndOwnViewIgnored() throws Exception {
      String statusId = status("alice");
      double viewedBefore = counter("orbit.status.viewed");

      view("bob", statusId).expectStatus().isNoContent();
      view("bob", statusId).expectStatus().isNoContent();
      view("alice", statusId).expectStatus().isNoContent();

      JsonNode mine = body(get("alice", "/api/v1/me/statuses").expectStatus().isOk());
      assertThat(mine.get(0).get("viewCount").asLong()).isOne();
      assertThat(mine.get(0).get("viewers").size()).isOne();
      assertThat(mine.get(0).get("viewers").get(0).get("id").asString()).isEqualTo(ids.get("bob"));
      assertThat(jdbc.sql("SELECT count(*) FROM status_view").query(Long.class).single()).isOne();
      assertThat(counter("orbit.status.viewed")).isEqualTo(viewedBefore + 1);
    }

    @Test
    void viewOfStatusDeletedMidRequestGets404() throws Exception {
      String statusId = status("alice");
      // The status disappears after the live check and before the view is written.
      doAnswer(
              call -> {
                Object live = call.callRealMethod();
                jdbc.sql("DELETE FROM status WHERE id = :id")
                    .param("id", UUID.fromString(statusId))
                    .update();
                return live;
              })
          .when(statusStore)
          .findLive(any(), any());

      expectProblem(view("bob", statusId), HttpStatus.NOT_FOUND, "status-not-found");
    }

    @Test
    void viewersNewestFirstWithNames() throws Exception {
      String carolsPhoto = photo("carol", "PROFILE_PHOTO");
      put("carol", "/api/v1/me/photos", "{\"mediaIds\":[\"%s\"]}".formatted(carolsPhoto))
          .expectStatus()
          .isOk();
      String statusId = status("alice");

      clock.advance(Duration.ofMinutes(1));
      view("bob", statusId).expectStatus().isNoContent();
      clock.advance(Duration.ofMinutes(1));
      view("carol", statusId).expectStatus().isNoContent();

      JsonNode viewers =
          body(get("alice", "/api/v1/me/statuses").expectStatus().isOk()).get(0).get("viewers");

      assertThat(viewers.size()).isEqualTo(2);
      assertThat(viewers.get(0).get("id").asString()).isEqualTo(ids.get("carol"));
      assertThat(viewers.get(0).get("name").asString()).isEqualTo("carol");
      assertThat(viewers.get(0).get("thumbUrl").asString()).isNotBlank();
      assertThat(Instant.parse(viewers.get(0).get("viewedAt").asString()))
          .isEqualTo(START.plus(Duration.ofMinutes(2)));
      assertThat(viewers.get(1).get("id").asString()).isEqualTo(ids.get("bob"));
      assertThat(viewers.get(1).get("name").asString()).isEqualTo("bob");
      assertThat(viewers.get(1).get("thumbUrl").isNull()).isTrue();
      assertThat(Instant.parse(viewers.get(1).get("viewedAt").asString()))
          .isEqualTo(START.plus(Duration.ofMinutes(1)));
    }

    @Test
    void statesForUsesOneQuery() throws Exception {
      String dave = onboard("dave");
      status("alice");
      String carols = status("carol");
      view("bob", carols).expectStatus().isNoContent();
      List<UUID> owners = List.of(id("alice"), id("carol"), UUID.fromString(dave));

      Counted<Map<UUID, StatusState>> counted =
          dataSource.count(() -> statusApi.statesFor(id("bob"), owners));

      assertThat(counted.result())
          .containsExactlyInAnyOrderEntriesOf(
              Map.of(
                  id("alice"), StatusState.UNSEEN,
                  id("carol"), StatusState.SEEN,
                  UUID.fromString(dave), StatusState.NONE));
      assertThat(counted.statements()).isOne();
    }
  }

  // --- deleting ------------------------------------------------------------------------------

  @Nested
  class Deleting {

    @Test
    void deleteRemovesAndPublishesStatusExpired() throws Exception {
      String mediaId = photo("alice", "STATUS_PHOTO");
      String statusId =
          body(postStatus("alice", mediaId, null).expectStatus().isCreated()).get("id").asString();
      view("bob", statusId).expectStatus().isNoContent();

      expectProblem(
          delete("bob", "/api/v1/me/statuses/" + statusId),
          HttpStatus.NOT_FOUND,
          "status-not-found");
      delete("alice", "/api/v1/me/statuses/" + statusId).expectStatus().isNoContent();

      assertThat(body(get("alice", "/api/v1/me/statuses").expectStatus().isOk()).size()).isZero();
      assertThat(jdbc.sql("SELECT count(*) FROM status_view").query(Long.class).single()).isZero();
      await()
          .atMost(EVENT_WAIT)
          .untilAsserted(() ->
              assertThat(expiries.events())
                  .containsExactly(
                      new StatusExpired(UUID.fromString(statusId), UUID.fromString(mediaId))));
      // One publication per listener: the test recorder and the media purger.
      assertThat(
              jdbc.sql("SELECT count(*) FROM event_publication WHERE event_type = :type")
                  .param("type", StatusExpired.class.getName())
                  .query(Long.class)
                  .single())
          .isEqualTo(2);
      expectProblem(
          delete("alice", "/api/v1/me/statuses/" + statusId),
          HttpStatus.NOT_FOUND,
          "status-not-found");
    }
  }

  // --- reaping -------------------------------------------------------------------------------

  /** The stored object key of a media row. */
  private String storageKey(String mediaId) {
    return jdbc.sql("SELECT storage_key FROM media WHERE id = :id")
        .param("id", UUID.fromString(mediaId))
        .query(String.class)
        .single();
  }

  private long mediaRows(String mediaId) {
    return jdbc.sql("SELECT count(*) FROM media WHERE id = :id")
        .param("id", UUID.fromString(mediaId))
        .query(Long.class)
        .single();
  }

  /** Event publications not yet completed for the listener whose id contains {@code listener}. */
  private long incompletePublications(String listener) {
    return jdbc.sql(
            "SELECT count(*) FROM event_publication WHERE completion_date IS NULL"
                + " AND listener_id LIKE :listener")
        .param("listener", "%" + listener + "%")
        .query(Long.class)
        .single();
  }

  /** Waits until every event publication has been handled. */
  private void awaitPublicationsCompleted() {
    await()
        .atMost(EVENT_WAIT)
        .untilAsserted(() ->
            assertThat(
                    jdbc.sql("SELECT count(*) FROM event_publication WHERE completion_date IS NULL")
                        .query(Long.class)
                        .single())
                .isZero());
  }

  @Nested
  class Reaping {

    @Test
    void reaperDeletesExpiredAndPurgesMedia() throws Exception {
      double expiredBefore = counter("orbit.status.expired");
      String mediaId = photo("alice", "STATUS_PHOTO");
      String statusId =
          body(postStatus("alice", mediaId, null).expectStatus().isCreated()).get("id").asString();
      view("bob", statusId).expectStatus().isNoContent();
      String key = storageKey(mediaId);
      clock.advance(Duration.ofHours(24).plusSeconds(1));

      assertThat(reaper.reap()).isOne();

      assertThat(jdbc.sql("SELECT count(*) FROM status").query(Long.class).single()).isZero();
      assertThat(jdbc.sql("SELECT count(*) FROM status_view").query(Long.class).single()).isZero();
      assertThat(counter("orbit.status.expired")).isEqualTo(expiredBefore + 1);
      await()
          .atMost(EVENT_WAIT)
          .untilAsserted(() -> {
            assertThat(storage.size(key)).isEmpty();
            assertThat(mediaRows(mediaId)).isZero();
          });
      assertThat(expiries.events())
          .contains(new StatusExpired(UUID.fromString(statusId), UUID.fromString(mediaId)));
      awaitPublicationsCompleted();
    }

    @Test
    void reaperKeepsLiveStatuses() throws Exception {
      String mediaId = photo("alice", "STATUS_PHOTO");
      postStatus("alice", mediaId, null).expectStatus().isCreated();
      clock.advance(Duration.ofHours(23));

      assertThat(reaper.reap()).isZero();

      assertThat(jdbc.sql("SELECT count(*) FROM status").query(Long.class).single()).isOne();
      assertThat(storage.size(storageKey(mediaId))).isPresent();
      assertThat(expiries.events()).isEmpty();
    }

    @Test
    void reaperIsIdempotent() throws Exception {
      status("alice");
      clock.advance(Duration.ofHours(24).plusSeconds(1));

      assertThat(reaper.reap()).isOne();
      assertThat(reaper.reap()).isZero();
    }

    @Test
    void reaperLoopsUntilABatchComesBackShort() throws Exception {
      status("alice");
      // 600 expired rows need a batch of 500 and one of 100. They share the one media row, which
      // the reaper itself never touches.
      jdbc.sql(
              """
              INSERT INTO status (id, owner_id, media_id, created_at, expires_at, updated_at)
              SELECT gen_random_uuid(), s.owner_id, s.media_id, s.created_at, s.expires_at,
                     s.updated_at
              FROM status s, generate_series(1, 599)
              """)
          .update();
      clock.advance(Duration.ofHours(24).plusSeconds(1));

      assertThat(reaper.reap()).isEqualTo(600);
      assertThat(jdbc.sql("SELECT count(*) FROM status").query(Long.class).single()).isZero();
    }

    @Test
    void failedPurgeIsRetriedByTheResubmissionJob() throws Exception {
      String mediaId = photo("alice", "STATUS_PHOTO");
      postStatus("alice", mediaId, null).expectStatus().isCreated();
      String key = storageKey(mediaId);
      doThrow(new IllegalStateException("storage down"))
          .doCallRealMethod()
          .when(storage)
          .delete(any());
      // Uploading the photo deleted its original; count only the purge's own deletes.
      clearInvocations(storage);
      clock.advance(Duration.ofHours(24).plusSeconds(1));

      assertThat(reaper.reap()).isOne();

      // The first purge attempt fails, so the photo stays and the publication stays incomplete.
      verify(storage, timeout(EVENT_WAIT.toMillis())).delete(any());
      assertThat(storage.size(key)).isPresent();
      assertThat(incompletePublications(PURGER)).isOne();

      clock.advance(Duration.ofMinutes(10));
      resubmission.run();

      await()
          .atMost(EVENT_WAIT)
          .untilAsserted(() -> {
            assertThat(incompletePublications(PURGER)).isZero();
            assertThat(storage.size(key)).isEmpty();
            assertThat(mediaRows(mediaId)).isZero();
          });
    }

    @Test
    void reaperKeepsHeldEvidenceMedia() throws Exception {
      String mediaId = photo("alice", "STATUS_PHOTO");
      postStatus("alice", mediaId, null).expectStatus().isCreated();
      String key = storageKey(mediaId);
      assertThat(mediaApi.holdAsEvidence(UUID.fromString(mediaId))).isTrue();
      clock.advance(Duration.ofHours(24).plusSeconds(1));

      assertThat(reaper.reap()).isOne();

      awaitPublicationsCompleted();
      assertThat(jdbc.sql("SELECT count(*) FROM status").query(Long.class).single()).isZero();
      assertThat(storage.size(key)).isPresent();
      assertThat(mediaRows(mediaId)).isOne();
    }
  }
}

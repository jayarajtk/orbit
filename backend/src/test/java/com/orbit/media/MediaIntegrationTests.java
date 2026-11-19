package com.orbit.media;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.doAnswer;

import com.orbit.MutableClock;
import com.orbit.TestcontainersConfiguration;
import com.orbit.media.application.MediaScanner;
import com.orbit.media.application.ObjectStorage;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
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
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.client.RestTestClient;

/**
 * Uploads, profile photos, albums and media messages against real PostGIS, Redis and MinIO. Bytes
 * go to MinIO through the presigned links exactly as the app sends them.
 */
@Import({
  TestcontainersConfiguration.class,
  MutableClock.Config.class,
  MediaIntegrationTests.ScannerConfig.class
})
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
class MediaIntegrationTests {

  private static final Instant START = Instant.parse("2026-11-18T12:00:00Z");

  @MockitoBean JwtDecoder jwtDecoder;

  @Autowired RestTestClient client;
  @Autowired JdbcClient jdbc;
  @Autowired MutableClock clock;
  @Autowired AtomicReference<MediaScanner.Verdict> verdict;
  @Autowired MediaApi mediaApi;
  @MockitoSpyBean ObjectStorage storage;

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

  @BeforeEach
  void setUp() {
    for (String table :
        List.of("event_publication", "message", "conversation_member", "conversation", "account")) {
      jdbc.sql("DELETE FROM " + table).update();
    }
    verdict.set(MediaScanner.Verdict.CLEAN);
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
    for (String who : List.of("alice", "bob", "carol")) {
      ids.put(who, onboard(who));
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

  private RestTestClient.ResponseSpec put(String who, String uri, String body) {
    return client
        .put()
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
  private <T> T json(RestTestClient.ResponseSpec spec, Class<T> type) {
    return spec.expectBody(type).returnResult().getResponseBody();
  }

  @SuppressWarnings("unchecked")
  private String onboard(String who) {
    Map<String, Object> account =
        json(
            post(who, "/api/v1/accounts", "{\"birthDate\":\"1990-05-01\"}")
                .expectStatus()
                .isCreated(),
            Map.class);
    put(who, "/api/v1/me/profile", "{\"displayName\":\"" + who + "\",\"lookingFor\":[\"CHAT\"]}")
        .expectStatus()
        .isOk();
    return (String) account.get("id");
  }

  /** Starts an upload and PUTs {@code bytes} to the presigned link; returns the media id. */
  @SuppressWarnings("unchecked")
  private String upload(String who, String purpose, String contentType, byte[] bytes)
      throws IOException, InterruptedException {
    Map<String, Object> ticket =
        json(
            post(
                    who,
                    "/api/v1/media/uploads",
                    "{\"purpose\":\"%s\",\"contentType\":\"%s\",\"sizeBytes\":%d}"
                        .formatted(purpose, contentType, bytes.length))
                .expectStatus()
                .isCreated(),
            Map.class);
    HttpResponse<String> stored =
        http.send(
            HttpRequest.newBuilder(URI.create((String) ticket.get("uploadUrl")))
                .header("Content-Type", contentType)
                .PUT(HttpRequest.BodyPublishers.ofByteArray(bytes))
                .build(),
            HttpResponse.BodyHandlers.ofString());
    assertThat(stored.statusCode()).isEqualTo(200);
    return (String) ticket.get("id");
  }

  private RestTestClient.ResponseSpec complete(String who, String mediaId, Integer durationMs) {
    return post(
        who,
        "/api/v1/media/uploads/" + mediaId + "/complete",
        durationMs == null ? "{}" : "{\"durationMs\":" + durationMs + "}");
  }

  /** Uploads and completes a photo. */
  private String photo(String who, String purpose) throws Exception {
    String id = upload(who, purpose, "image/jpeg", jpegWithExif(1200, 800));
    complete(who, id, null).expectStatus().isOk();
    return id;
  }

  private byte[] download(String url) throws IOException, InterruptedException {
    HttpResponse<byte[]> response =
        http.send(
            HttpRequest.newBuilder(URI.create(url)).build(),
            HttpResponse.BodyHandlers.ofByteArray());
    assertThat(response.statusCode()).isEqualTo(200);
    return response.body();
  }

  /** A JPEG with an EXIF segment carrying a fake GPS marker, as phones produce. */
  static byte[] jpegWithExif(int width, int height) throws IOException {
    BufferedImage image = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
    ByteArrayOutputStream plain = new ByteArrayOutputStream();
    ImageIO.write(image, "jpeg", plain);
    byte[] jpeg = plain.toByteArray();
    byte[] payload = "Exif\0\0GPSLatitude=37.7749".getBytes(StandardCharsets.US_ASCII);
    int length = payload.length + 2;
    ByteArrayOutputStream withExif = new ByteArrayOutputStream();
    withExif.write(jpeg, 0, 2); // SOI
    withExif.write(new byte[] {(byte) 0xFF, (byte) 0xE1, (byte) (length >> 8), (byte) length});
    withExif.write(payload);
    withExif.write(jpeg, 2, jpeg.length - 2);
    return withExif.toByteArray();
  }

  /** Bytes that start like an MP4 file. */
  static byte[] mp4Like(int size) {
    byte[] bytes = new byte[size];
    byte[] header = {0, 0, 0, 0x18, 'f', 't', 'y', 'p', 'i', 's', 'o', 'm'};
    System.arraycopy(header, 0, bytes, 0, header.length);
    return bytes;
  }

  private static boolean contains(byte[] haystack, String needle) {
    return new String(haystack, StandardCharsets.ISO_8859_1).contains(needle);
  }

  // --- status photos, purge and evidence hold ---------------------------------------------------

  @Nested
  class StatusMedia {

    private String key(String column, String mediaId) {
      return jdbc.sql("SELECT " + column + " FROM media WHERE id = :id")
          .param("id", UUID.fromString(mediaId))
          .query(String.class)
          .single();
    }

    private boolean stored(String key) {
      return storage.size(key).isPresent();
    }

    @Test
    void statusPhotoUploadIsAccepted() throws Exception {
      String id = photo("alice", "STATUS_PHOTO");

      get("alice", "/api/v1/media/" + id)
          .expectStatus()
          .isOk()
          .expectBody()
          .jsonPath("$.purpose")
          .isEqualTo("STATUS_PHOTO");
    }

    @Test
    void purgeDeletesObjectsAndRow() throws Exception {
      String id = photo("alice", "STATUS_PHOTO");
      UUID mediaId = UUID.fromString(id);
      String full = key("storage_key", id);
      String thumb = key("thumb_key", id);
      assertThat(stored(full)).isTrue();
      assertThat(stored(thumb)).isTrue();

      assertThat(mediaApi.purge(mediaId)).isTrue();

      assertThat(stored(full)).isFalse();
      assertThat(stored(thumb)).isFalse();
      assertThat(mediaApi.links(List.of(mediaId))).isEmpty();
      assertThat(
              jdbc.sql("SELECT count(*) FROM media WHERE id = :id")
                  .param("id", mediaId)
                  .query(Long.class)
                  .single())
          .isZero();
    }

    @Test
    void purgeSkipsHeldMedia() throws Exception {
      String id = photo("alice", "STATUS_PHOTO");
      UUID mediaId = UUID.fromString(id);
      String full = key("storage_key", id);

      assertThat(mediaApi.holdAsEvidence(mediaId)).isTrue();
      assertThat(mediaApi.holdAsEvidence(mediaId)).isTrue();

      assertThat(mediaApi.purge(mediaId)).isFalse();
      assertThat(stored(full)).isTrue();
      assertThat(mediaApi.links(List.of(mediaId))).containsKey(mediaId);
    }

    @Test
    void purgeIsIdempotent() throws Exception {
      String id = photo("alice", "STATUS_PHOTO");
      UUID mediaId = UUID.fromString(id);

      assertThat(mediaApi.purge(mediaId)).isTrue();
      assertThat(mediaApi.purge(mediaId)).isFalse();
    }

    @Test
    void aHoldThatLandsMidPurgeIsRefusedSoTheCallerKnows() throws Exception {
      String id = photo("alice", "STATUS_PHOTO");
      UUID mediaId = UUID.fromString(id);
      String full = key("storage_key", id);
      String thumb = key("thumb_key", id);
      AtomicReference<Boolean> heldMidPurge = new AtomicReference<>();
      doAnswer(
              call -> {
                heldMidPurge.compareAndSet(null, mediaApi.holdAsEvidence(mediaId));
                return call.callRealMethod();
              })
          .when(storage)
          .delete(anyString());

      assertThat(mediaApi.purge(mediaId)).isTrue();

      assertThat(heldMidPurge.get()).isFalse();
      assertThat(stored(full)).isFalse();
      assertThat(stored(thumb)).isFalse();
      assertThat(mediaApi.holdAsEvidence(mediaId)).isFalse();
    }

    @Test
    void holdingMissingMediaReportsFalse() {
      assertThat(mediaApi.holdAsEvidence(UUID.randomUUID())).isFalse();
    }

    @Test
    void purgeCompletesWhenAnObjectIsAlreadyGone() throws Exception {
      String id = photo("alice", "STATUS_PHOTO");
      UUID mediaId = UUID.fromString(id);
      String full = key("storage_key", id);
      storage.delete(key("thumb_key", id));

      assertThat(mediaApi.purge(mediaId)).isTrue();
      assertThat(stored(full)).isFalse();
    }
  }

  // --- uploads -------------------------------------------------------------------------------

  @Nested
  class Uploads {

    @Test
    @SuppressWarnings("unchecked")
    void photosAreResizedAndLoseTheirMetadata() throws Exception {
      byte[] original = jpegWithExif(4000, 3000);
      assertThat(contains(original, "GPSLatitude")).isTrue();
      String id = upload("alice", "CHAT_PHOTO", "image/jpeg", original);

      Map<String, Object> media =
          json(complete("alice", id, null).expectStatus().isOk(), Map.class);

      Map<String, Object> links = (Map<String, Object>) media.get("links");
      assertThat(links.get("width")).isEqualTo(2048);
      assertThat(links.get("height")).isEqualTo(1536);
      byte[] full = download((String) links.get("url"));
      byte[] thumb = download((String) links.get("thumbUrl"));
      assertThat(contains(full, "Exif")).isFalse();
      assertThat(contains(full, "GPSLatitude")).isFalse();
      assertThat(ImageIO.read(new java.io.ByteArrayInputStream(thumb)).getWidth()).isEqualTo(480);
      // Completing again returns the same result.
      complete("alice", id, null).expectStatus().isOk();
    }

    @Test
    void refusesTypesAndSizesThePurposeDoesNotAllow() {
      post(
              "alice",
              "/api/v1/media/uploads",
              "{\"purpose\":\"PROFILE_PHOTO\",\"contentType\":\"image/gif\",\"sizeBytes\":100}")
          .expectStatus()
          .isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT)
          .expectBody()
          .jsonPath("$.type")
          .isEqualTo("urn:orbit:problem:invalid-upload");
      post(
              "alice",
              "/api/v1/media/uploads",
              "{\"purpose\":\"CHAT_PHOTO\",\"contentType\":\"image/jpeg\",\"sizeBytes\":%d}"
                  .formatted(11L * 1024 * 1024))
          .expectStatus()
          .isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT);
    }

    @Test
    @SuppressWarnings("unchecked")
    void completingBeforeUploadingIsAConflict() {
      Map<String, Object> ticket =
          json(
              post(
                  "alice",
                  "/api/v1/media/uploads",
                  "{\"purpose\":\"CHAT_PHOTO\",\"contentType\":\"image/jpeg\",\"sizeBytes\":10}"),
              Map.class);

      complete("alice", (String) ticket.get("id"), null)
          .expectStatus()
          .isEqualTo(HttpStatus.CONFLICT);
      complete("bob", (String) ticket.get("id"), null).expectStatus().isNotFound();
    }

    @Test
    void rejectsContentThatIsNotWhatItClaims() throws Exception {
      String fakePhoto =
          upload(
              "alice", "CHAT_PHOTO", "image/jpeg", "not a jpeg".getBytes(StandardCharsets.UTF_8));
      complete("alice", fakePhoto, null)
          .expectStatus()
          .isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT)
          .expectBody()
          .jsonPath("$.type")
          .isEqualTo("urn:orbit:problem:media-rejected");

      String fakeVideo = upload("alice", "CHAT_VIDEO", "video/mp4", new byte[64]);
      complete("alice", fakeVideo, 5_000)
          .expectStatus()
          .isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT);
    }

    @Test
    void acceptsVideoAndVoiceWithinTheirLimits() throws Exception {
      String video = upload("alice", "CHAT_VIDEO", "video/mp4", mp4Like(2048));
      complete("alice", video, 12_000)
          .expectStatus()
          .isOk()
          .expectBody()
          .jsonPath("$.links.durationMs")
          .isEqualTo(12_000)
          .jsonPath("$.links.thumbUrl")
          .doesNotExist();

      String tooLong = upload("alice", "VOICE_NOTE", "audio/mp4", mp4Like(1024));
      complete("alice", tooLong, 121_000)
          .expectStatus()
          .isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT);
    }

    @Test
    void scannerRejectionsAreNeverStored() throws Exception {
      verdict.set(MediaScanner.Verdict.REJECTED);
      String id = upload("alice", "CHAT_PHOTO", "image/jpeg", jpegWithExif(100, 100));

      complete("alice", id, null).expectStatus().isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT);
      get("alice", "/api/v1/media/" + id).expectStatus().isNotFound();
    }
  }

  // --- profile photos ------------------------------------------------------------------------

  @Nested
  class ProfilePhotos {

    @Test
    void othersSeeThemOnTheProfile() throws Exception {
      String first = photo("alice", "PROFILE_PHOTO");
      String second = photo("alice", "PROFILE_PHOTO");

      put("alice", "/api/v1/me/photos", "{\"mediaIds\":[\"%s\",\"%s\"]}".formatted(second, first))
          .expectStatus()
          .isOk()
          .expectBody()
          .jsonPath("$.photos[0].id")
          .isEqualTo(second)
          .jsonPath("$.photos[1].id")
          .isEqualTo(first);

      get("bob", "/api/v1/profiles/" + ids.get("alice"))
          .expectStatus()
          .isOk()
          .expectBody()
          .jsonPath("$.photoCount")
          .isEqualTo(2)
          .jsonPath("$.photos.length()")
          .isEqualTo(2)
          .jsonPath("$.photos[0].thumbUrl")
          .exists();
    }

    @Test
    void onlyOwnPublicSafePhotosQualify() throws Exception {
      String bobs = photo("bob", "PROFILE_PHOTO");
      verdict.set(MediaScanner.Verdict.PRIVATE_ONLY);
      String explicit = photo("alice", "ALBUM_PHOTO");

      put("alice", "/api/v1/me/photos", "{\"mediaIds\":[\"%s\"]}".formatted(bobs))
          .expectStatus()
          .isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT)
          .expectBody()
          .jsonPath("$.type")
          .isEqualTo("urn:orbit:problem:media-unavailable");
      put("alice", "/api/v1/me/photos", "{\"mediaIds\":[\"%s\"]}".formatted(explicit))
          .expectStatus()
          .isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT);
    }
  }

  // --- albums --------------------------------------------------------------------------------

  @Nested
  class Albums {

    @SuppressWarnings("unchecked")
    private String album(String who, String name) throws Exception {
      Map<String, Object> created =
          json(
              post(who, "/api/v1/albums", "{\"name\":\"" + name + "\"}").expectStatus().isCreated(),
              Map.class);
      String id = (String) created.get("id");
      // Private albums may hold photos the scanner allows only in private.
      verdict.set(MediaScanner.Verdict.PRIVATE_ONLY);
      String photo = photo(who, "ALBUM_PHOTO");
      verdict.set(MediaScanner.Verdict.CLEAN);
      post(who, "/api/v1/albums/" + id + "/photos", "{\"mediaId\":\"" + photo + "\"}")
          .expectStatus()
          .isNoContent();
      return id;
    }

    private void share(String albumId, String with, String access, boolean viewOnce) {
      put(
              "alice",
              "/api/v1/albums/" + albumId + "/grants/" + ids.get(with),
              "{\"access\":\"%s\",\"viewOnce\":%s}".formatted(access, viewOnce))
          .expectStatus()
          .isNoContent();
    }

    @Test
    @SuppressWarnings("unchecked")
    void sharedAlbumsOpenForTheGranteeOnly() throws Exception {
      String id = album("alice", "Private");
      share(id, "bob", "UNTIL_REVOKED", false);

      get("bob", "/api/v1/albums/shared-with-me")
          .expectBody()
          .jsonPath("$[0].id")
          .isEqualTo(id)
          .jsonPath("$[0].photoCount")
          .isEqualTo(1);
      Map<String, Object> opened = json(get("bob", "/api/v1/albums/" + id), Map.class);
      List<Map<String, Object>> photos = (List<Map<String, Object>>) opened.get("photos");
      download((String) ((Map<String, Object>) photos.get(0).get("links")).get("url"));
      get("carol", "/api/v1/albums/" + id).expectStatus().isNotFound();
      get("alice", "/api/v1/albums")
          .expectBody()
          .jsonPath("$[0].grants[0].granteeId")
          .isEqualTo(ids.get("bob"));
    }

    @Test
    void viewOnceSharesOpenOnce() throws Exception {
      String id = album("alice", "Once");
      share(id, "bob", "WEEK", true);

      get("bob", "/api/v1/albums/" + id).expectStatus().isOk();
      get("bob", "/api/v1/albums/" + id)
          .expectStatus()
          .isEqualTo(HttpStatus.GONE)
          .expectBody()
          .jsonPath("$.type")
          .isEqualTo("urn:orbit:problem:view-once-opened");
      get("bob", "/api/v1/albums/shared-with-me").expectBody().json("[]");
    }

    @Test
    void accessEndsOnExpiryRevokeOrBlock() throws Exception {
      String id = album("alice", "Trip");
      share(id, "bob", "DAY", false);
      share(id, "carol", "UNTIL_REVOKED", false);

      clock.advance(Duration.ofHours(25));
      get("bob", "/api/v1/albums/" + id).expectStatus().isNotFound();

      client
          .delete()
          .uri("/api/v1/albums/" + id + "/grants/" + ids.get("carol"))
          .header("Authorization", "Bearer alice")
          .exchange()
          .expectStatus()
          .isNoContent();
      get("carol", "/api/v1/albums/" + id).expectStatus().isNotFound();

      share(id, "bob", "UNTIL_REVOKED", false);
      post("bob", "/api/v1/blocks", "{\"accountId\":\"%s\"}".formatted(ids.get("alice")))
          .expectStatus()
          .isNoContent();
      get("bob", "/api/v1/albums/" + id).expectStatus().isNotFound();
      get("bob", "/api/v1/albums/shared-with-me").expectBody().json("[]");
    }
  }

  // --- media messages ------------------------------------------------------------------------

  @Nested
  class Messages {

    @SuppressWarnings("unchecked")
    private String send(String from, String to, String body) {
      Map<String, Object> message =
          json(
              post(from, "/api/v1/conversations/" + ids.get(to) + "/messages", body)
                  .expectStatus()
                  .isCreated(),
              Map.class);
      return (String) message.get("id");
    }

    @Test
    @SuppressWarnings("unchecked")
    void recipientsGetLinksToPhotosVideosAndVoice() throws Exception {
      String photo = photo("alice", "CHAT_PHOTO");
      String voice = upload("alice", "VOICE_NOTE", "audio/mp4", mp4Like(512));
      complete("alice", voice, 4_000).expectStatus().isOk();

      String photoMessage =
          send(
              "alice",
              "bob",
              "{\"clientMsgId\":\"c-1\",\"kind\":\"PHOTO\",\"mediaId\":\"%s\"}".formatted(photo));
      String voiceMessage =
          send(
              "alice",
              "bob",
              "{\"clientMsgId\":\"c-2\",\"kind\":\"VOICE\",\"mediaId\":\"%s\"}".formatted(voice));

      Map<String, Object> links =
          json(
              get("bob", "/api/v1/messages/" + photoMessage + "/media").expectStatus().isOk(),
              Map.class);
      download((String) links.get("thumbUrl"));
      get("bob", "/api/v1/messages/" + voiceMessage + "/media")
          .expectBody()
          .jsonPath("$.kind")
          .isEqualTo("AUDIO")
          .jsonPath("$.durationMs")
          .isEqualTo(4_000);
      get("carol", "/api/v1/messages/" + photoMessage + "/media").expectStatus().isNotFound();
    }

    @Test
    void viewOncePhotosOpenOnceForTheRecipient() throws Exception {
      String photo = photo("alice", "CHAT_PHOTO");
      String message =
          send(
              "alice",
              "bob",
              "{\"clientMsgId\":\"c-1\",\"kind\":\"PHOTO\",\"mediaId\":\"%s\",\"viewOnce\":true}"
                  .formatted(photo));

      get("bob", "/api/v1/messages/" + message + "/media").expectStatus().isOk();
      get("bob", "/api/v1/messages/" + message + "/media")
          .expectStatus()
          .isEqualTo(HttpStatus.GONE);
      get("alice", "/api/v1/messages/" + message + "/media").expectStatus().isOk();
      get("bob", "/api/v1/conversations/" + ids.get("alice") + "/messages")
          .expectBody()
          .jsonPath("$.items[0].viewOnce")
          .isEqualTo(true)
          .jsonPath("$.items[0].viewed")
          .isEqualTo(true);
    }

    @Test
    void onlyTheSendersOwnMediaAndAlbumsCanBeSent() throws Exception {
      String bobsPhoto = photo("bob", "CHAT_PHOTO");
      post(
              "alice",
              "/api/v1/conversations/" + ids.get("bob") + "/messages",
              "{\"clientMsgId\":\"c-1\",\"kind\":\"PHOTO\",\"mediaId\":\"%s\"}"
                  .formatted(bobsPhoto))
          .expectStatus()
          .isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT)
          .expectBody()
          .jsonPath("$.type")
          .isEqualTo("urn:orbit:problem:media-unavailable");
      post(
              "alice",
              "/api/v1/conversations/" + ids.get("bob") + "/messages",
              "{\"clientMsgId\":\"c-2\",\"kind\":\"VIDEO\",\"mediaId\":\"%s\",\"viewOnce\":true}"
                  .formatted(bobsPhoto))
          .expectStatus()
          .isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT)
          .expectBody()
          .jsonPath("$.type")
          .isEqualTo("urn:orbit:problem:invalid-message");
    }

    @Test
    @SuppressWarnings("unchecked")
    void albumSharesCarryTheAlbumsName() {
      Map<String, Object> album =
          json(post("alice", "/api/v1/albums", "{\"name\":\"Summer\"}"), Map.class);

      post(
              "alice",
              "/api/v1/conversations/" + ids.get("bob") + "/messages",
              "{\"clientMsgId\":\"c-1\",\"kind\":\"ALBUM\",\"albumId\":\"%s\"}"
                  .formatted(album.get("id")))
          .expectStatus()
          .isCreated()
          .expectBody()
          .jsonPath("$.albumName")
          .isEqualTo("Summer")
          .jsonPath("$.albumId")
          .isEqualTo(album.get("id"));
    }
  }
}

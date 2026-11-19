package com.orbit.discovery;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;

import com.orbit.MutableClock;
import com.orbit.TestcontainersConfiguration;
import com.orbit.discovery.domain.GeoPoint;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.client.RestTestClient;

/** Profiles, location, grid, blocks, reports and favorites end to end against PostGIS. */
@Import({TestcontainersConfiguration.class, MutableClock.Config.class})
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
class PeopleIntegrationTests {

  private static final Instant START = Instant.parse("2026-11-17T12:00:00Z");
  private static final GeoPoint HOME = new GeoPoint(37.7749, -122.4194);

  @MockitoBean JwtDecoder jwtDecoder;

  @Autowired RestTestClient client;
  @Autowired JdbcClient jdbc;
  @Autowired MutableClock clock;

  private final Map<String, String> ids = new HashMap<>();

  @BeforeEach
  void setUp() {
    for (String table :
        List.of("favorite", "block", "report", "user_location", "profile", "account")) {
      jdbc.sql("DELETE FROM " + table).update();
    }
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
  }

  // --- helpers -------------------------------------------------------------------------------

  private RestTestClient.RequestHeadersSpec<?> as(
      String who, RestTestClient.RequestHeadersSpec<?> spec) {
    return spec.header("Authorization", "Bearer " + who);
  }

  private RestTestClient.ResponseSpec get(String who, String uri) {
    return as(who, client.get().uri(uri)).exchange();
  }

  private RestTestClient.ResponseSpec put(String who, String uri, String json) {
    return as(who, client.put().uri(uri).contentType(MediaType.APPLICATION_JSON).body(json))
        .exchange();
  }

  private RestTestClient.ResponseSpec post(String who, String uri, String json) {
    return as(who, client.post().uri(uri).contentType(MediaType.APPLICATION_JSON).body(json))
        .exchange();
  }

  private RestTestClient.ResponseSpec delete(String who, String uri) {
    return as(who, client.delete().uri(uri)).exchange();
  }

  /** Creates the account and profile; returns the account id. */
  @SuppressWarnings("unchecked")
  private String onboard(String who, String birthDate, String extraProfileJson) {
    Map<String, Object> account =
        post(who, "/api/v1/accounts", "{\"birthDate\":\"" + birthDate + "\"}")
            .expectStatus()
            .isCreated()
            .expectBody(Map.class)
            .returnResult()
            .getResponseBody();
    put(
            who,
            "/api/v1/me/profile",
            "{\"displayName\":\"%s\",\"lookingFor\":[\"CHAT\"]%s}"
                .formatted(capitalize(who), extraProfileJson))
        .expectStatus()
        .isOk();
    String id = (String) account.get("id");
    ids.put(who, id);
    return id;
  }

  private void locate(String who, GeoPoint point) {
    put(who, "/api/v1/me/location", "{\"lat\":%s,\"lng\":%s}".formatted(point.lat(), point.lng()))
        .expectStatus()
        .isNoContent();
  }

  @SuppressWarnings("unchecked")
  private List<Map<String, Object>> grid(String who, String query) {
    Map<String, Object> page =
        get(who, "/api/v1/discovery/grid" + query)
            .expectStatus()
            .isOk()
            .expectBody(Map.class)
            .returnResult()
            .getResponseBody();
    return (List<Map<String, Object>>) page.get("items");
  }

  private List<Object> gridIds(String who, String query) {
    return grid(who, query).stream().map(p -> p.get("id")).toList();
  }

  private static String capitalize(String s) {
    return Character.toUpperCase(s.charAt(0)) + s.substring(1);
  }

  /** alice at HOME, bob ~2 km away, carol ~6 km away (hides age, wants networking). */
  private void threeNeighbours() {
    onboard("alice", "1990-05-01", "");
    onboard("bob", "1997-03-03", "");
    onboard("carol", "1981-01-01", ",\"showAge\":false,\"lookingFor\":[\"NETWORKING\"]");
    locate("alice", HOME);
    locate("bob", HOME.offset(90, 2_000));
    locate("carol", HOME.offset(180, 6_000));
  }

  // --- tests ---------------------------------------------------------------------------------

  @Test
  void profileEndpointsRequireAnAccount() {
    put("ghost", "/api/v1/me/profile", "{\"displayName\":\"Ghost\",\"lookingFor\":[]}")
        .expectStatus()
        .isForbidden()
        .expectBody()
        .jsonPath("$.type")
        .isEqualTo("urn:orbit:problem:account-required");
  }

  @Test
  void savesAndReadsOwnProfileAndNormalizesTags() {
    onboard("alice", "1990-05-01", ",\"tags\":[\"#Hiking\",\"music\",\"hiking\"],\"heightCm\":180");

    get("alice", "/api/v1/me/profile")
        .expectStatus()
        .isOk()
        .expectBody()
        .jsonPath("$.displayName")
        .isEqualTo("Alice")
        .jsonPath("$.age")
        .isEqualTo(36)
        .jsonPath("$.heightCm")
        .isEqualTo(180)
        .jsonPath("$.tags.length()")
        .isEqualTo(2)
        .jsonPath("$.tags[0]")
        .isEqualTo("hiking");
  }

  @Test
  void rejectsInvalidProfileFields() {
    onboard("alice", "1990-05-01", "");
    put("alice", "/api/v1/me/profile", "{\"displayName\":\" \",\"lookingFor\":[]}")
        .expectStatus()
        .isBadRequest();
    put("alice", "/api/v1/me/profile", "{\"displayName\":\"A\",\"lookingFor\":[],\"heightCm\":999}")
        .expectStatus()
        .isBadRequest();
  }

  @Nested
  class Grid {

    @Test
    void showsOthersNearestFirstWithBucketedDistancesOnly() {
      threeNeighbours();

      List<Map<String, Object>> people = grid("alice", "");

      assertThat(people)
          .extracting(p -> p.get("id"))
          .containsExactly(ids.get("bob"), ids.get("carol"));
      assertThat((Integer) people.get(0).get("distanceKm")).isBetween(0, 3);
      assertThat((Integer) people.get(1).get("distanceKm")).isBetween(4, 8);
      assertThat(people.get(1).get("age")).isNull();
      assertThat(people.get(0)).doesNotContainKeys("birthDate", "meters", "lat", "lng");
      assertThat(people.get(0).get("online")).isEqualTo(true);
      assertThat(people.get(0).get("isNew")).isEqualTo(true);
    }

    @Test
    void requiresTheCallerToHaveALocation() {
      onboard("dan", "1990-01-01", "");
      get("dan", "/api/v1/discovery/grid")
          .expectStatus()
          .isEqualTo(HttpStatus.CONFLICT)
          .expectBody()
          .jsonPath("$.type")
          .isEqualTo("urn:orbit:problem:location-required");
    }

    @Test
    void filtersByAgeLookingForDistanceAndOnline() {
      threeNeighbours();

      assertThat(gridIds("alice", "?minAge=40")).containsExactly(ids.get("carol"));
      assertThat(gridIds("alice", "?maxAge=30")).containsExactly(ids.get("bob"));
      assertThat(gridIds("alice", "?lookingFor=networking")).containsExactly(ids.get("carol"));
      assertThat(gridIds("alice", "?maxDistanceKm=4")).containsExactly(ids.get("bob"));

      clock.advance(Duration.ofMinutes(11));
      locate("bob", HOME.offset(90, 2_100));
      assertThat(gridIds("alice", "?onlineOnly=true")).containsExactly(ids.get("bob"));
    }

    @Test
    @SuppressWarnings("unchecked")
    void pagesWithAnOpaqueCursor() {
      threeNeighbours();

      Map<String, Object> first =
          get("alice", "/api/v1/discovery/grid?limit=1")
              .expectStatus()
              .isOk()
              .expectBody(Map.class)
              .returnResult()
              .getResponseBody();
      assertThat((List<?>) first.get("items")).hasSize(1);
      String cursor = (String) first.get("nextCursor");
      assertThat(cursor).isNotBlank();

      Map<String, Object> second =
          get("alice", "/api/v1/discovery/grid?limit=1&cursor=" + cursor)
              .expectStatus()
              .isOk()
              .expectBody(Map.class)
              .returnResult()
              .getResponseBody();
      assertThat(((List<Map<String, Object>>) second.get("items")).get(0).get("id"))
          .isEqualTo(ids.get("carol"));
      assertThat(second.get("nextCursor")).isNull();

      get("alice", "/api/v1/discovery/grid?cursor=not-a-cursor").expectStatus().isBadRequest();
    }
  }

  @Nested
  class LocationRules {

    @Test
    void allowsOneUpdatePerMinute() {
      onboard("alice", "1990-05-01", "");
      locate("alice", HOME);

      put("alice", "/api/v1/me/location", "{\"lat\":37.7750,\"lng\":-122.4195}")
          .expectStatus()
          .isEqualTo(HttpStatus.TOO_MANY_REQUESTS);

      clock.advance(Duration.ofSeconds(61));
      locate("alice", HOME.offset(0, 50));
    }

    @Test
    void rejectsImpossibleJumps() {
      onboard("alice", "1990-05-01", "");
      locate("alice", HOME);
      clock.advance(Duration.ofMinutes(2));

      put("alice", "/api/v1/me/location", "{\"lat\":40.7128,\"lng\":-74.0060}")
          .expectStatus()
          .isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT)
          .expectBody()
          .jsonPath("$.type")
          .isEqualTo("urn:orbit:problem:implausible-movement");
    }

    @Test
    void rejectsOutOfRangeCoordinates() {
      onboard("alice", "1990-05-01", "");
      put("alice", "/api/v1/me/location", "{\"lat\":95,\"lng\":0}").expectStatus().isBadRequest();
    }
  }

  @Nested
  class Safety {

    @Test
    void blockingHidesMembersFromEachOtherEverywhere() {
      threeNeighbours();

      post("alice", "/api/v1/blocks", "{\"accountId\":\"%s\"}".formatted(ids.get("bob")))
          .expectStatus()
          .isNoContent();

      assertThat(gridIds("alice", "")).doesNotContain(ids.get("bob"));
      assertThat(gridIds("bob", "")).doesNotContain(ids.get("alice"));
      get("alice", "/api/v1/profiles/" + ids.get("bob")).expectStatus().isNotFound();
      get("bob", "/api/v1/profiles/" + ids.get("alice")).expectStatus().isNotFound();
      get("alice", "/api/v1/me/blocked")
          .expectStatus()
          .isOk()
          .expectBody()
          .jsonPath("$[0].displayName")
          .isEqualTo("Bob");

      delete("alice", "/api/v1/blocks/" + ids.get("bob")).expectStatus().isNoContent();
      assertThat(gridIds("alice", "")).contains(ids.get("bob"));
    }

    @Test
    void cannotBlockOrReportYourself() {
      onboard("alice", "1990-05-01", "");
      post("alice", "/api/v1/blocks", "{\"accountId\":\"%s\"}".formatted(ids.get("alice")))
          .expectStatus()
          .isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT);
    }

    @Test
    void reportingCanAlsoBlock() {
      threeNeighbours();

      post(
              "alice",
              "/api/v1/reports",
              "{\"accountId\":\"%s\",\"reason\":\"HARASSMENT\",\"alsoBlock\":true}"
                  .formatted(ids.get("carol")))
          .expectStatus()
          .isAccepted()
          .expectBody()
          .jsonPath("$.id")
          .exists();

      assertThat(jdbc.sql("SELECT count(*) FROM report").query(Long.class).single()).isOne();
      assertThat(gridIds("alice", "")).doesNotContain(ids.get("carol"));
    }
  }

  @Nested
  class Favorites {

    @Test
    void addListAndRemove() {
      threeNeighbours();
      String bob = ids.get("bob");

      post("alice", "/api/v1/favorites/" + bob, "").expectStatus().isNoContent();
      get("alice", "/api/v1/favorites")
          .expectStatus()
          .isOk()
          .expectBody()
          .jsonPath("$[0].id")
          .isEqualTo(bob)
          .jsonPath("$[0].favorite")
          .isEqualTo(true);
      assertThat(grid("alice", "").get(0).get("favorite")).isEqualTo(true);

      delete("alice", "/api/v1/favorites/" + bob).expectStatus().isNoContent();
      get("alice", "/api/v1/favorites").expectStatus().isOk().expectBody().json("[]");
    }

    @Test
    void cannotFavoriteSomeoneBlocked() {
      threeNeighbours();
      post("bob", "/api/v1/blocks", "{\"accountId\":\"%s\"}".formatted(ids.get("alice")))
          .expectStatus()
          .isNoContent();

      post("alice", "/api/v1/favorites/" + ids.get("bob"), "").expectStatus().isNotFound();
    }
  }
}

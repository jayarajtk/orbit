package com.orbit;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.client.RestTestClient;

/** Boots the full application against real PostGIS and Redis containers. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
class OrbitApiApplicationTests {

  // No identity provider in tests; token validation is covered by the web slice tests.
  @MockitoBean JwtDecoder jwtDecoder;

  @Autowired RestTestClient client;
  @Autowired JdbcTemplate jdbc;

  @Test
  void flywayMigrationEnablesPostgis() {
    String version = jdbc.queryForObject("SELECT postgis_lib_version()", String.class);

    assertThat(version).startsWith("3.");
  }

  @Test
  void healthProbesArePublicAndUp() {
    client
        .get()
        .uri("/actuator/health/liveness")
        .exchange()
        .expectStatus()
        .isOk()
        .expectBody()
        .jsonPath("$.status")
        .isEqualTo("UP");
    client.get().uri("/actuator/health/readiness").exchange().expectStatus().isOk();
  }

  @Test
  void apiRequiresAuthenticationByDefault() {
    client
        .get()
        .uri("/api/v1/me/profile")
        .exchange()
        .expectStatus()
        .isEqualTo(HttpStatus.UNAUTHORIZED);
  }

  @Test
  void nonPublicActuatorEndpointsAreNotOpen() {
    client.get().uri("/actuator/env").exchange().expectStatus().isEqualTo(HttpStatus.UNAUTHORIZED);
  }
}

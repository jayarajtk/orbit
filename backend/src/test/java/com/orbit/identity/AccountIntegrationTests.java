package com.orbit.identity;

import static org.mockito.BDDMockito.given;

import com.orbit.TestcontainersConfiguration;
import java.time.Instant;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureRestTestClient;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.client.RestTestClient;

/** Account onboarding end to end: HTTP, security, service, Flyway schema and PostgreSQL. */
@Import(TestcontainersConfiguration.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureRestTestClient
class AccountIntegrationTests {

  @MockitoBean JwtDecoder jwtDecoder;

  @Autowired RestTestClient client;
  @Autowired JdbcTemplate jdbc;

  @BeforeEach
  void setUp() {
    jdbc.update("DELETE FROM account");
    given(jwtDecoder.decode("alice-token")).willReturn(tokenFor("alice"));
    given(jwtDecoder.decode("bob-token")).willReturn(tokenFor("bob"));
  }

  private static Jwt tokenFor(String subject) {
    Instant now = Instant.now();
    return Jwt.withTokenValue(subject + "-token")
        .header("alg", "RS256")
        .subject(subject)
        .issuedAt(now)
        .expiresAt(now.plusSeconds(900))
        .build();
  }

  private RestTestClient.ResponseSpec createAccount(String token, String birthDate) {
    return client
        .post()
        .uri("/api/v1/accounts")
        .header("Authorization", "Bearer " + token)
        .contentType(MediaType.APPLICATION_JSON)
        .body("{\"birthDate\":\"" + birthDate + "\"}")
        .exchange();
  }

  private RestTestClient.ResponseSpec getMe(String token) {
    return client.get().uri("/api/v1/me").header("Authorization", "Bearer " + token).exchange();
  }

  @Test
  void onboardsANewMemberOnce() {
    getMe("alice-token").expectStatus().isNotFound();

    createAccount("alice-token", "1990-05-01")
        .expectStatus()
        .isCreated()
        .expectBody()
        .jsonPath("$.status")
        .isEqualTo("ONBOARDING");

    getMe("alice-token").expectStatus().isOk().expectBody().jsonPath("$.id").exists();
    createAccount("alice-token", "1990-05-01").expectStatus().isEqualTo(HttpStatus.CONFLICT);
  }

  @Test
  void neverCreatesAnAccountForAMinor() {
    createAccount("alice-token", "2015-01-01")
        .expectStatus()
        .isEqualTo(HttpStatus.UNPROCESSABLE_CONTENT);

    getMe("alice-token").expectStatus().isNotFound();
  }

  @Test
  void membersOnlySeeTheirOwnAccount() {
    createAccount("alice-token", "1990-05-01").expectStatus().isCreated();

    getMe("bob-token").expectStatus().isNotFound();
  }
}

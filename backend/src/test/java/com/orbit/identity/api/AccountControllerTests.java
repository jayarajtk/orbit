package com.orbit.identity.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.orbit.identity.application.AccountAlreadyExistsException;
import com.orbit.identity.application.AccountNotFoundException;
import com.orbit.identity.application.AccountService;
import com.orbit.identity.application.AccountView;
import com.orbit.identity.application.UnderageException;
import com.orbit.identity.domain.AccountStatus;
import com.orbit.shared.security.SecurityConfig;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;

@WebMvcTest(AccountController.class)
@Import(SecurityConfig.class)
class AccountControllerTests {

  private static final String SUBJECT = "idp-user-123";
  private static final UUID ACCOUNT_ID = UUID.fromString("7d1f6c3e-5a39-4b55-9a0e-6a8f0e4b2c11");
  private static final AccountView ACCOUNT =
      new AccountView(ACCOUNT_ID, AccountStatus.ONBOARDING, Instant.parse("2026-11-09T12:00:00Z"));

  @MockitoBean JwtDecoder jwtDecoder;
  @MockitoBean AccountService accountService;

  @Autowired MockMvcTester mvc;

  private MockMvcTester.MockMvcRequestBuilder createAccount(String json) {
    return mvc.post()
        .uri("/api/v1/accounts")
        .with(jwt().jwt(token -> token.subject(SUBJECT)))
        .contentType(MediaType.APPLICATION_JSON)
        .content(json);
  }

  @Nested
  class CreateAccount {

    @Test
    void requiresAuthentication() {
      assertThat(
              mvc.post()
                  .uri("/api/v1/accounts")
                  .contentType(MediaType.APPLICATION_JSON)
                  .content("{\"birthDate\":\"1990-05-01\"}"))
          .hasStatus(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void createsAccountForTheTokenSubject() {
      given(accountService.register(SUBJECT, LocalDate.of(1990, 5, 1))).willReturn(ACCOUNT);

      assertThat(createAccount("{\"birthDate\":\"1990-05-01\"}"))
          .hasStatus(HttpStatus.CREATED)
          .hasHeader("Location", "/api/v1/me")
          .bodyJson()
          .isLenientlyEqualTo(
              """
              {"id":"7d1f6c3e-5a39-4b55-9a0e-6a8f0e4b2c11","status":"ONBOARDING"}
              """);
      then(accountService).should().register(SUBJECT, LocalDate.of(1990, 5, 1));
    }

    @Test
    void rejectsMissingBirthDate() {
      assertThat(createAccount("{}"))
          .hasStatus(HttpStatus.BAD_REQUEST)
          .hasContentType(MediaType.APPLICATION_PROBLEM_JSON);
    }

    @Test
    void rejectsBirthDateInTheFuture() {
      assertThat(createAccount("{\"birthDate\":\"2999-01-01\"}")).hasStatus(HttpStatus.BAD_REQUEST);
    }

    @Test
    void rejectsUnderageUsersWithAgeRequirementProblem() {
      given(accountService.register(SUBJECT, LocalDate.of(2012, 1, 1)))
          .willThrow(new UnderageException());

      assertThat(createAccount("{\"birthDate\":\"2012-01-01\"}"))
          .hasStatus(HttpStatus.UNPROCESSABLE_CONTENT)
          .hasContentType(MediaType.APPLICATION_PROBLEM_JSON)
          .bodyJson()
          .extractingPath("$.type")
          .isEqualTo("urn:orbit:problem:age-requirement");
    }

    @Test
    void rejectsSecondAccountForSameSubjectWithConflict() {
      given(accountService.register(SUBJECT, LocalDate.of(1990, 5, 1)))
          .willThrow(new AccountAlreadyExistsException());

      assertThat(createAccount("{\"birthDate\":\"1990-05-01\"}"))
          .hasStatus(HttpStatus.CONFLICT)
          .bodyJson()
          .extractingPath("$.type")
          .isEqualTo("urn:orbit:problem:account-exists");
    }
  }

  @Nested
  class GetMyAccount {

    @Test
    void returnsTheCallersAccount() {
      given(accountService.findMine(SUBJECT)).willReturn(ACCOUNT);

      assertThat(mvc.get().uri("/api/v1/me").with(jwt().jwt(token -> token.subject(SUBJECT))))
          .hasStatusOk()
          .bodyJson()
          .extractingPath("$.status")
          .isEqualTo("ONBOARDING");
    }

    @Test
    void returnsNotFoundProblemBeforeOnboarding() {
      given(accountService.findMine(SUBJECT)).willThrow(new AccountNotFoundException());

      assertThat(mvc.get().uri("/api/v1/me").with(jwt().jwt(token -> token.subject(SUBJECT))))
          .hasStatus(HttpStatus.NOT_FOUND)
          .bodyJson()
          .extractingPath("$.type")
          .isEqualTo("urn:orbit:problem:account-not-found");
    }
  }
}

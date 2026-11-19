package com.orbit.shared;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;

import com.orbit.shared.security.SecurityConfig;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.assertj.MockMvcTester;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/** Verifies the security rules and RFC 9457 error contract every module's controllers inherit. */
@WebMvcTest(controllers = WebLayerContractTests.ProbeController.class)
@Import({SecurityConfig.class, WebLayerContractTests.ProbeController.class})
class WebLayerContractTests {

  private static final MediaType PROBLEM_JSON = MediaType.APPLICATION_PROBLEM_JSON;

  @MockitoBean JwtDecoder jwtDecoder;

  @Autowired MockMvcTester mvc;

  @Nested
  class Security {

    @Test
    void rejectsRequestsWithoutToken() {
      assertThat(mvc.get().uri("/api/v1/probe/ok")).hasStatus(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void unauthorizedResponseIsProblemJsonAndKeepsBearerChallenge() {
      var result = mvc.get().uri("/api/v1/probe/ok").exchange();

      assertThat(result)
          .hasStatus(HttpStatus.UNAUTHORIZED)
          .hasContentTypeCompatibleWith(PROBLEM_JSON);
      assertThat(result.getResponse().getHeader("WWW-Authenticate")).startsWith("Bearer");
      assertThat(result).bodyJson().extractingPath("$.status").isEqualTo(401);
    }

    @Test
    void acceptsRequestsWithValidToken() {
      assertThat(mvc.get().uri("/api/v1/probe/ok").with(jwt())).hasStatusOk();
    }

    @Test
    void returnsForbiddenProblemWhenMethodSecurityDenies() {
      assertThat(mvc.get().uri("/api/v1/probe/admin").with(jwt()))
          .hasStatus(HttpStatus.FORBIDDEN)
          .hasContentType(PROBLEM_JSON);
    }

    @Test
    void sendsSecurityHeaders() {
      assertThat(mvc.get().uri("/api/v1/probe/ok").with(jwt()))
          .headers()
          .containsHeader("Content-Security-Policy")
          .containsHeader("X-Content-Type-Options");
    }
  }

  @Nested
  class Errors {

    @Test
    void hidesInternalDetailsOfUnexpectedErrors() {
      assertThat(mvc.get().uri("/api/v1/probe/boom").with(jwt()))
          .hasStatus(HttpStatus.INTERNAL_SERVER_ERROR)
          .hasContentType(PROBLEM_JSON)
          .bodyText()
          .doesNotContain(ProbeController.SECRET_DETAIL)
          .contains("An unexpected error occurred.");
    }

    @Test
    void mapsValidationFailuresToBadRequestProblem() {
      assertThat(
              mvc.post()
                  .uri("/api/v1/probe/echo")
                  .with(jwt())
                  .contentType(MediaType.APPLICATION_JSON)
                  .content("{\"name\":\"\"}"))
          .hasStatus(HttpStatus.BAD_REQUEST)
          .hasContentType(PROBLEM_JSON);
    }
  }

  /** Minimal endpoints that exercise the shared web configuration. Test-only. */
  @RestController
  static class ProbeController {

    static final String SECRET_DETAIL = "db password is hunter2";

    record EchoRequest(@NotBlank String name) {}

    @GetMapping("/api/v1/probe/ok")
    String ok() {
      return "ok";
    }

    @GetMapping("/api/v1/probe/admin")
    @PreAuthorize("hasAuthority('SCOPE_admin')")
    String admin() {
      return "admin";
    }

    @GetMapping("/api/v1/probe/boom")
    String boom() {
      throw new IllegalStateException(SECRET_DETAIL);
    }

    @PostMapping("/api/v1/probe/echo")
    String echo(@Valid @RequestBody EchoRequest request) {
      return request.name();
    }
  }
}

package com.orbit.shared.security;

import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.oauth2.server.resource.web.BearerTokenAuthenticationEntryPoint;
import org.springframework.security.web.AuthenticationEntryPoint;

/**
 * Rejects unauthenticated requests with an RFC 9457 body. Spring's bearer entry point still sets
 * the status and the {@code WWW-Authenticate} challenge; this adds the body, which never includes
 * the exception message (it can describe why a token was invalid).
 */
final class ProblemDetailAuthenticationEntryPoint implements AuthenticationEntryPoint {

  private static final String BODY =
      """
      {"type":"about:blank","title":"Unauthorized","status":401,\
      "detail":"Sign in to continue."}\
      """;

  private final AuthenticationEntryPoint bearerEntryPoint =
      new BearerTokenAuthenticationEntryPoint();

  @Override
  public void commence(
      HttpServletRequest request,
      HttpServletResponse response,
      AuthenticationException authException)
      throws IOException, ServletException {
    bearerEntryPoint.commence(request, response, authException);
    response.setContentType(MediaType.APPLICATION_PROBLEM_JSON_VALUE);
    response.setCharacterEncoding(StandardCharsets.UTF_8.name());
    response.getWriter().write(BODY);
  }
}

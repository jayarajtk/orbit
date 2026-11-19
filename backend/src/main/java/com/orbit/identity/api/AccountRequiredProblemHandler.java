package com.orbit.identity.api;

import com.orbit.identity.IdentityApi.AccountRequiredException;
import com.orbit.identity.IdentityApi.AccountRestrictedException;
import java.net.URI;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Maps {@link AccountRequiredException} from any module's endpoint. The app treats {@code
 * account-required} as "go to onboarding" and {@code account-restricted} as "show why the account
 * is suspended or banned" (ADR-0007).
 */
@RestControllerAdvice
@Order(Ordered.HIGHEST_PRECEDENCE)
class AccountRequiredProblemHandler {

  @ExceptionHandler(AccountRequiredException.class)
  ProblemDetail accountRequired() {
    ProblemDetail problem =
        ProblemDetail.forStatusAndDetail(
            HttpStatus.FORBIDDEN, "Finish onboarding, or your account is not available.");
    problem.setType(URI.create("urn:orbit:problem:account-required"));
    problem.setTitle("Account required");
    return problem;
  }

  @ExceptionHandler(AccountRestrictedException.class)
  ProblemDetail accountRestricted() {
    ProblemDetail problem =
        ProblemDetail.forStatusAndDetail(
            HttpStatus.FORBIDDEN, "This account is suspended or banned.");
    problem.setType(URI.create("urn:orbit:problem:account-restricted"));
    problem.setTitle("Account restricted");
    return problem;
  }
}

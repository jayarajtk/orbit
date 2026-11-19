package com.orbit.identity.api;

import com.orbit.identity.application.AccountAlreadyExistsException;
import com.orbit.identity.application.AccountNotFoundException;
import com.orbit.identity.application.UnderageException;
import java.net.URI;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Maps identity errors to RFC 9457 problems with stable {@code type} URNs that the app can switch
 * on. Ordered before the global handler, whose catch-all would otherwise turn these into 500s.
 */
@RestControllerAdvice(assignableTypes = AccountController.class)
@Order(Ordered.HIGHEST_PRECEDENCE)
class IdentityProblemHandler {

  @ExceptionHandler(UnderageException.class)
  ProblemDetail underage() {
    return problem(
        HttpStatus.UNPROCESSABLE_CONTENT,
        "age-requirement",
        "Age requirement not met",
        "You must be 18 or older to use Orbit.");
  }

  @ExceptionHandler(AccountAlreadyExistsException.class)
  ProblemDetail alreadyExists() {
    return problem(
        HttpStatus.CONFLICT,
        "account-exists",
        "Account already exists",
        "This sign-in already has an Orbit account.");
  }

  @ExceptionHandler(AccountNotFoundException.class)
  ProblemDetail notFound() {
    return problem(
        HttpStatus.NOT_FOUND,
        "account-not-found",
        "Account not found",
        "Finish onboarding to create your account.");
  }

  private static ProblemDetail problem(
      HttpStatus status, String type, String title, String detail) {
    ProblemDetail problem = ProblemDetail.forStatusAndDetail(status, detail);
    problem.setType(URI.create("urn:orbit:problem:" + type));
    problem.setTitle(title);
    return problem;
  }
}

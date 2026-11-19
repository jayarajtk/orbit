package com.orbit.moderation.api;

import com.orbit.moderation.application.ModerationExceptions.AppealDecidedException;
import com.orbit.moderation.application.ModerationExceptions.AppealExistsException;
import com.orbit.moderation.application.ModerationExceptions.AppealNotFoundException;
import com.orbit.moderation.application.ModerationExceptions.InvalidActionException;
import com.orbit.moderation.application.ModerationExceptions.MemberNotFoundException;
import com.orbit.moderation.application.ModerationExceptions.NotRestrictedException;
import java.net.URI;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/** Problems for moderation errors (RFC 9457). */
@RestControllerAdvice(assignableTypes = {AdminController.class, StandingController.class})
class ModerationProblemHandler {

  @ExceptionHandler(MemberNotFoundException.class)
  ProblemDetail memberNotFound() {
    return problem(
        HttpStatus.NOT_FOUND, "account-not-found", "Account not found", "No such account.");
  }

  @ExceptionHandler(AppealNotFoundException.class)
  ProblemDetail appealNotFound() {
    return problem(HttpStatus.NOT_FOUND, "appeal-not-found", "Appeal not found", "No such appeal.");
  }

  /** The detail is meant for the moderator and names what to change; it holds no member data. */
  @ExceptionHandler(InvalidActionException.class)
  ProblemDetail invalidAction(InvalidActionException e) {
    return problem(
        HttpStatus.UNPROCESSABLE_CONTENT, "invalid-action", "Action not possible", e.getMessage());
  }

  @ExceptionHandler(AppealDecidedException.class)
  ProblemDetail appealDecided() {
    return problem(
        HttpStatus.CONFLICT,
        "appeal-decided",
        "Appeal already decided",
        "Another moderator decided this appeal. Reload to see the outcome.");
  }

  @ExceptionHandler(NotRestrictedException.class)
  ProblemDetail notRestricted() {
    return problem(
        HttpStatus.CONFLICT,
        "not-restricted",
        "Nothing to appeal",
        "Your account isn't suspended or banned.");
  }

  @ExceptionHandler(AppealExistsException.class)
  ProblemDetail appealExists() {
    return problem(
        HttpStatus.CONFLICT,
        "appeal-exists",
        "Already appealed",
        "You've already appealed this. We'll let you know the outcome.");
  }

  private static ProblemDetail problem(
      HttpStatus status, String type, String title, String detail) {
    ProblemDetail problem = ProblemDetail.forStatusAndDetail(status, detail);
    problem.setType(URI.create("urn:orbit:problem:" + type));
    problem.setTitle(title);
    return problem;
  }
}

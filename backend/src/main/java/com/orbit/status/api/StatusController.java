package com.orbit.status.api;

import com.orbit.media.MediaApi.MediaUnavailableException;
import com.orbit.status.application.StatusService;
import com.orbit.status.application.StatusService.InvalidStatusException;
import com.orbit.status.application.StatusService.StatusLimitException;
import com.orbit.status.application.StatusService.StatusNotFoundException;
import com.orbit.status.application.StatusViews.MyStatus;
import com.orbit.status.application.StatusViews.StatusItem;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.net.URI;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 24-hour photo statuses: the caller's own, and other members'. */
@RestController
@RequestMapping("/api/v1")
class StatusController {

  private final StatusService statuses;

  StatusController(StatusService statuses) {
    this.statuses = statuses;
  }

  record PostRequest(
      @NotNull UUID mediaId, @Size(max = StatusService.MAX_CAPTION) String caption) {}

  @PostMapping("/me/statuses")
  ResponseEntity<MyStatus> post(
      @AuthenticationPrincipal Jwt token, @Valid @RequestBody PostRequest request) {
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(statuses.post(token.getSubject(), request.mediaId(), request.caption()));
  }

  @GetMapping("/me/statuses")
  List<MyStatus> mine(@AuthenticationPrincipal Jwt token) {
    return statuses.mine(token.getSubject());
  }

  @DeleteMapping("/me/statuses/{id}")
  ResponseEntity<Void> delete(@AuthenticationPrincipal Jwt token, @PathVariable UUID id) {
    statuses.delete(token.getSubject(), id);
    return ResponseEntity.noContent().build();
  }

  @GetMapping("/profiles/{id}/statuses")
  List<StatusItem> statusesOf(@AuthenticationPrincipal Jwt token, @PathVariable UUID id) {
    return statuses.statusesOf(token.getSubject(), id);
  }

  @PutMapping("/statuses/{id}/view")
  ResponseEntity<Void> view(@AuthenticationPrincipal Jwt token, @PathVariable UUID id) {
    statuses.view(token.getSubject(), id);
    return ResponseEntity.noContent().build();
  }

  @ExceptionHandler(StatusLimitException.class)
  ProblemDetail limit() {
    return problem(
        HttpStatus.CONFLICT,
        "status-limit",
        "Status limit reached",
        "You can have up to " + StatusService.MAX_LIVE + " statuses at a time.");
  }

  @ExceptionHandler(StatusNotFoundException.class)
  ProblemDetail notFound() {
    return problem(
        HttpStatus.NOT_FOUND, "status-not-found", "Status not found", "It isn't available.");
  }

  /**
   * Bad media and an over-long caption are both {@code invalid-status}, so the app has one case to
   * handle. Handled here so they win over the shared media and validation mappings.
   */
  @ExceptionHandler({
    InvalidStatusException.class,
    MediaUnavailableException.class,
    MethodArgumentNotValidException.class
  })
  ProblemDetail invalid() {
    return problem(
        HttpStatus.UNPROCESSABLE_CONTENT,
        "invalid-status",
        "Status not accepted",
        "Choose one of your status photos and keep the caption to "
            + StatusService.MAX_CAPTION
            + " characters.");
  }

  private static ProblemDetail problem(
      HttpStatus status, String type, String title, String detail) {
    ProblemDetail problem = ProblemDetail.forStatusAndDetail(status, detail);
    problem.setType(URI.create("urn:orbit:problem:" + type));
    problem.setTitle(title);
    return problem;
  }
}

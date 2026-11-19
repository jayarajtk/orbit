package com.orbit.safety.api;

import com.orbit.safety.application.SafetyService;
import com.orbit.safety.application.SafetyService.InvalidTargetException;
import com.orbit.safety.domain.ReportReason;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.net.URI;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Blocking and reporting (W9). */
@RestController
@RequestMapping("/api/v1")
class SafetyController {

  private final SafetyService safety;

  SafetyController(SafetyService safety) {
    this.safety = safety;
  }

  record BlockRequest(@NotNull UUID accountId) {}

  /**
   * {@code alsoBlock} is optional (null means no); boxed because Jackson 3 rejects a missing
   * primitive.
   */
  record ReportRequest(
      @NotNull UUID accountId,
      @NotNull ReportReason reason,
      @Size(max = 500) String details,
      Boolean alsoBlock,
      UUID statusId) {}

  record ReportResponse(UUID id) {}

  @PostMapping("/blocks")
  ResponseEntity<Void> block(
      @AuthenticationPrincipal Jwt token, @Valid @RequestBody BlockRequest request) {
    safety.block(token.getSubject(), request.accountId());
    return ResponseEntity.noContent().build();
  }

  @DeleteMapping("/blocks/{accountId}")
  ResponseEntity<Void> unblock(@AuthenticationPrincipal Jwt token, @PathVariable UUID accountId) {
    safety.unblock(token.getSubject(), accountId);
    return ResponseEntity.noContent().build();
  }

  @PostMapping("/reports")
  ResponseEntity<ReportResponse> report(
      @AuthenticationPrincipal Jwt token, @Valid @RequestBody ReportRequest request) {
    UUID id =
        safety.report(
            token.getSubject(),
            request.accountId(),
            request.reason(),
            request.details() == null ? "" : request.details(),
            Boolean.TRUE.equals(request.alsoBlock()),
            request.statusId());
    return ResponseEntity.accepted().body(new ReportResponse(id));
  }

  @ExceptionHandler(InvalidTargetException.class)
  ProblemDetail invalidTarget() {
    ProblemDetail problem =
        ProblemDetail.forStatusAndDetail(
            HttpStatus.UNPROCESSABLE_CONTENT, "That member can't be blocked or reported.");
    problem.setType(URI.create("urn:orbit:problem:invalid-target"));
    problem.setTitle("Invalid member");
    return problem;
  }
}

package com.orbit.moderation.api;

import com.orbit.moderation.application.MemberStandingService;
import com.orbit.moderation.application.Views.MemberAppeal;
import com.orbit.moderation.application.Views.Standing;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * A member's own moderation standing: why they are suspended or banned, their appeal, and warnings.
 * These endpoints work while the account is restricted (ADR-0007).
 */
@RestController
@RequestMapping("/api/v1/me")
class StandingController {

  private final MemberStandingService standing;

  StandingController(MemberStandingService standing) {
    this.standing = standing;
  }

  record AppealRequest(@NotBlank @Size(max = MemberStandingService.MAX_APPEAL) String text) {}

  @GetMapping("/standing")
  Standing standing(@AuthenticationPrincipal Jwt token) {
    return standing.standing(token.getSubject());
  }

  @PostMapping("/appeals")
  ResponseEntity<MemberAppeal> appeal(
      @AuthenticationPrincipal Jwt token, @Valid @RequestBody AppealRequest request) {
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(standing.appeal(token.getSubject(), request.text()));
  }

  @PostMapping("/warnings/{warningId}/ack")
  ResponseEntity<Void> acknowledge(
      @AuthenticationPrincipal Jwt token, @PathVariable UUID warningId) {
    standing.acknowledgeWarning(token.getSubject(), warningId);
    return ResponseEntity.noContent().build();
  }
}

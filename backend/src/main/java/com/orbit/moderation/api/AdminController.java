package com.orbit.moderation.api;

import com.orbit.moderation.application.ActionCommand;
import com.orbit.moderation.application.AppealDecision;
import com.orbit.moderation.application.ModerationService;
import com.orbit.moderation.application.Moderator;
import com.orbit.moderation.application.Views.ActionView;
import com.orbit.moderation.application.Views.AppealView;
import com.orbit.moderation.application.Views.AuditEntry;
import com.orbit.moderation.application.Views.CaseSummary;
import com.orbit.moderation.application.Views.MemberHit;
import com.orbit.moderation.application.Views.MemberRecord;
import com.orbit.moderation.domain.ActionKind;
import com.orbit.moderation.domain.AppealStatus;
import com.orbit.moderation.domain.Policy;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * The moderation API for the admin console (ADR-0007). {@code SecurityConfig} requires the {@code
 * moderator} role for every path here. Actions aren't idempotent; the console never retries them.
 */
@RestController
@RequestMapping("/api/v1/admin")
@Validated
class AdminController {

  private static final String USERNAME_CLAIM = "preferred_username";

  private final ModerationService moderation;

  AdminController(ModerationService moderation) {
    this.moderation = moderation;
  }

  record ActionRequest(
      @NotNull ActionKind kind,
      @NotNull Policy policy,
      @Size(max = 500) String memberMessage,
      @Size(max = 1000) String internalNote,
      Integer suspendHours,
      UUID mediaId) {}

  record DecisionRequest(@NotNull Boolean reverse, @Size(max = 500) String memberMessage) {}

  @GetMapping("/cases")
  List<CaseSummary> cases(@RequestParam(defaultValue = "50") @Min(1) @Max(200) int limit) {
    return moderation.queue(limit);
  }

  @PostMapping("/cases/{subjectId}/claim")
  ResponseEntity<Void> claim(@AuthenticationPrincipal Jwt token, @PathVariable UUID subjectId) {
    moderation.claim(moderator(token), subjectId);
    return ResponseEntity.noContent().build();
  }

  @GetMapping("/members")
  List<MemberHit> search(
      @AuthenticationPrincipal Jwt token, @RequestParam @NotBlank @Size(max = 100) String q) {
    return moderation.search(moderator(token), q);
  }

  @GetMapping("/members/{accountId}")
  MemberRecord member(@AuthenticationPrincipal Jwt token, @PathVariable UUID accountId) {
    return moderation.member(moderator(token), accountId);
  }

  @PostMapping("/members/{accountId}/actions")
  ResponseEntity<ActionView> act(
      @AuthenticationPrincipal Jwt token,
      @PathVariable UUID accountId,
      @Valid @RequestBody ActionRequest request) {
    ActionView action =
        moderation.act(
            moderator(token),
            accountId,
            new ActionCommand(
                request.kind(),
                request.policy(),
                request.memberMessage(),
                request.internalNote(),
                request.suspendHours(),
                request.mediaId()));
    return ResponseEntity.status(HttpStatus.CREATED).body(action);
  }

  @GetMapping("/appeals")
  List<AppealView> appeals(
      @RequestParam(defaultValue = "OPEN") AppealStatus status,
      @RequestParam(defaultValue = "50") @Min(1) @Max(200) int limit) {
    return moderation.appeals(status, limit);
  }

  @PostMapping("/appeals/{appealId}/decision")
  AppealView decide(
      @AuthenticationPrincipal Jwt token,
      @PathVariable UUID appealId,
      @Valid @RequestBody DecisionRequest request) {
    return moderation.decide(
        moderator(token), appealId, new AppealDecision(request.reverse(), request.memberMessage()));
  }

  @GetMapping("/audit")
  List<AuditEntry> audit(
      @RequestParam(required = false) UUID accountId,
      @RequestParam(required = false) Instant before,
      @RequestParam(defaultValue = "100") @Min(1) @Max(500) int limit) {
    return moderation.auditLog(accountId, before, limit);
  }

  /** The moderator's username for the audit log, or their subject when the token has none. */
  private static Moderator moderator(Jwt token) {
    String username = token.getClaimAsString(USERNAME_CLAIM);
    String name = username == null || username.isBlank() ? token.getSubject() : username;
    return new Moderator(
        name.length() > Moderator.MAX_NAME ? name.substring(0, Moderator.MAX_NAME) : name);
  }
}

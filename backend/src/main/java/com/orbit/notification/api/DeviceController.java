package com.orbit.notification.api;

import com.orbit.notification.application.NotificationService;
import com.orbit.notification.application.NotificationService.Platform;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Push token registration. Tokens travel in request bodies, never in URLs (they're logged). */
@RestController
@RequestMapping("/api/v1/devices")
class DeviceController {

  private final NotificationService notifications;

  DeviceController(NotificationService notifications) {
    this.notifications = notifications;
  }

  record RegisterRequest(@NotNull Platform platform, @NotBlank @Size(max = 512) String token) {}

  record UnregisterRequest(@NotBlank @Size(max = 512) String token) {}

  @PostMapping
  ResponseEntity<Void> register(
      @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody RegisterRequest request) {
    notifications.register(jwt.getSubject(), request.platform(), request.token());
    return ResponseEntity.noContent().build();
  }

  @PostMapping("/unregister")
  ResponseEntity<Void> unregister(
      @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody UnregisterRequest request) {
    notifications.unregister(jwt.getSubject(), request.token());
    return ResponseEntity.noContent().build();
  }
}

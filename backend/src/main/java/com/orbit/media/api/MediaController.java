package com.orbit.media.api;

import com.orbit.media.application.MediaService;
import com.orbit.media.application.MediaService.MediaView;
import com.orbit.media.application.MediaService.UploadTicket;
import com.orbit.media.domain.MediaPurpose;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
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

/** Presigned uploads: start, PUT to storage, complete. */
@RestController
@RequestMapping("/api/v1/media")
class MediaController {

  private final MediaService media;

  MediaController(MediaService media) {
    this.media = media;
  }

  record StartRequest(
      @NotNull MediaPurpose purpose,
      @NotBlank @Size(max = 64) String contentType,
      @Positive long sizeBytes) {}

  record CompleteRequest(@Positive Integer durationMs) {}

  @PostMapping("/uploads")
  ResponseEntity<UploadTicket> start(
      @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody StartRequest request) {
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(
            media.startUpload(
                jwt.getSubject(), request.purpose(), request.contentType(), request.sizeBytes()));
  }

  @PostMapping("/uploads/{id}/complete")
  MediaView complete(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID id,
      @Valid @RequestBody(required = false) CompleteRequest request) {
    return media.complete(jwt.getSubject(), id, request == null ? null : request.durationMs());
  }

  @GetMapping("/{id}")
  MediaView mine(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
    return media.mine(jwt.getSubject(), id);
  }
}

package com.orbit.media.api;

import com.orbit.media.application.AlbumService;
import com.orbit.media.application.AlbumService.Access;
import com.orbit.media.application.AlbumService.OpenedAlbum;
import com.orbit.media.application.AlbumService.OwnAlbum;
import com.orbit.media.infrastructure.AlbumStore.SharedRow;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Private albums and sharing. */
@RestController
@RequestMapping("/api/v1/albums")
class AlbumController {

  private final AlbumService albums;

  AlbumController(AlbumService albums) {
    this.albums = albums;
  }

  record CreateRequest(@NotBlank @Size(max = 60) String name) {}

  record AddPhotoRequest(@NotNull UUID mediaId) {}

  record ShareRequest(@NotNull Access access, Boolean viewOnce) {}

  @GetMapping
  List<OwnAlbum> mine(@AuthenticationPrincipal Jwt jwt) {
    return albums.mine(jwt.getSubject());
  }

  @PostMapping
  ResponseEntity<Map<String, UUID>> create(
      @AuthenticationPrincipal Jwt jwt, @Valid @RequestBody CreateRequest request) {
    return ResponseEntity.status(HttpStatus.CREATED)
        .body(Map.of("id", albums.create(jwt.getSubject(), request.name())));
  }

  @GetMapping("/shared-with-me")
  List<SharedRow> sharedWithMe(@AuthenticationPrincipal Jwt jwt) {
    return albums.sharedWithMe(jwt.getSubject());
  }

  @GetMapping("/{id}")
  OpenedAlbum open(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
    return albums.open(jwt.getSubject(), id);
  }

  @DeleteMapping("/{id}")
  ResponseEntity<Void> delete(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
    albums.delete(jwt.getSubject(), id);
    return ResponseEntity.noContent().build();
  }

  @PostMapping("/{id}/photos")
  ResponseEntity<Void> addPhoto(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID id,
      @Valid @RequestBody AddPhotoRequest request) {
    albums.addPhoto(jwt.getSubject(), id, request.mediaId());
    return ResponseEntity.noContent().build();
  }

  @DeleteMapping("/{id}/photos/{mediaId}")
  ResponseEntity<Void> removePhoto(
      @AuthenticationPrincipal Jwt jwt, @PathVariable UUID id, @PathVariable UUID mediaId) {
    albums.removePhoto(jwt.getSubject(), id, mediaId);
    return ResponseEntity.noContent().build();
  }

  @PutMapping("/{id}/grants/{granteeId}")
  ResponseEntity<Void> share(
      @AuthenticationPrincipal Jwt jwt,
      @PathVariable UUID id,
      @PathVariable UUID granteeId,
      @Valid @RequestBody ShareRequest request) {
    albums.share(
        jwt.getSubject(), id, granteeId, request.access(), Boolean.TRUE.equals(request.viewOnce()));
    return ResponseEntity.noContent().build();
  }

  @DeleteMapping("/{id}/grants/{granteeId}")
  ResponseEntity<Void> revoke(
      @AuthenticationPrincipal Jwt jwt, @PathVariable UUID id, @PathVariable UUID granteeId) {
    albums.revoke(jwt.getSubject(), id, granteeId);
    return ResponseEntity.noContent().build();
  }
}

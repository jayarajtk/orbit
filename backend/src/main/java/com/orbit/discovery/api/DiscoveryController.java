package com.orbit.discovery.api;

import com.orbit.discovery.application.DiscoveryService;
import com.orbit.discovery.application.DiscoveryService.GridPage;
import com.orbit.discovery.application.DiscoveryService.GridQuery;
import com.orbit.discovery.application.DiscoveryService.ImplausibleMovementException;
import com.orbit.discovery.application.DiscoveryService.LocationRateLimitedException;
import com.orbit.discovery.application.DiscoveryService.LocationRequiredException;
import com.orbit.discovery.application.DiscoveryService.PersonNotFoundException;
import com.orbit.discovery.application.PersonView;
import com.orbit.discovery.domain.GeoPoint;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/** Location (W5), nearby grid (W6/W7), member profiles (W8) and favorites. */
@RestController
@RequestMapping("/api/v1")
@Validated
class DiscoveryController {

  private static final String CURSOR_PREFIX = "o:";

  private final DiscoveryService discovery;

  DiscoveryController(DiscoveryService discovery) {
    this.discovery = discovery;
  }

  /** Exact position from the device; only ever used to compute the snapped point. */
  record LocationRequest(
      @NotNull @DecimalMin("-90") @DecimalMax("90") Double lat,
      @NotNull @DecimalMin("-180") @DecimalMax("180") Double lng) {}

  /**
   * A grid page.
   *
   * @param nextCursor opaque cursor for the next page, or null at the end
   */
  record GridResponse(List<PersonView> items, String nextCursor) {}

  @PutMapping("/me/location")
  ResponseEntity<Void> updateLocation(
      @AuthenticationPrincipal Jwt token, @Valid @RequestBody LocationRequest request) {
    discovery.updateLocation(token.getSubject(), new GeoPoint(request.lat(), request.lng()));
    return ResponseEntity.noContent().build();
  }

  @GetMapping("/discovery/grid")
  GridResponse grid(
      @AuthenticationPrincipal Jwt token,
      @RequestParam(defaultValue = "18") @Min(18) @Max(99) int minAge,
      @RequestParam(defaultValue = "99") @Min(18) @Max(99) int maxAge,
      @RequestParam(defaultValue = "false") boolean onlineOnly,
      @RequestParam(required = false) List<String> lookingFor,
      @RequestParam(required = false) @Min(1) @Max(10) Integer maxDistanceKm,
      @RequestParam(required = false) String cursor,
      @RequestParam(defaultValue = "60") @Min(1) @Max(60) int limit) {
    List<String> goals =
        lookingFor == null
            ? List.of()
            : lookingFor.stream().map(g -> g.toUpperCase(Locale.ROOT)).toList();
    GridPage page =
        discovery.grid(
            token.getSubject(),
            new GridQuery(
                minAge,
                Math.max(minAge, maxAge),
                onlineOnly,
                goals,
                maxDistanceKm,
                decodeCursor(cursor),
                limit));
    return new GridResponse(page.items(), encodeCursor(page.nextOffset()));
  }

  @GetMapping("/profiles/{id}")
  PersonView person(@AuthenticationPrincipal Jwt token, @PathVariable UUID id) {
    return discovery.person(token.getSubject(), id);
  }

  @GetMapping("/favorites")
  List<PersonView> favorites(@AuthenticationPrincipal Jwt token) {
    return discovery.favorites(token.getSubject());
  }

  @PostMapping("/favorites/{id}")
  ResponseEntity<Void> addFavorite(@AuthenticationPrincipal Jwt token, @PathVariable UUID id) {
    discovery.addFavorite(token.getSubject(), id);
    return ResponseEntity.noContent().build();
  }

  @DeleteMapping("/favorites/{id}")
  ResponseEntity<Void> removeFavorite(@AuthenticationPrincipal Jwt token, @PathVariable UUID id) {
    discovery.removeFavorite(token.getSubject(), id);
    return ResponseEntity.noContent().build();
  }

  private static int decodeCursor(String cursor) {
    if (cursor == null || cursor.isBlank()) {
      return 0;
    }
    try {
      String raw = new String(Base64.getUrlDecoder().decode(cursor), StandardCharsets.UTF_8);
      if (!raw.startsWith(CURSOR_PREFIX)) {
        throw new InvalidCursorException();
      }
      int offset = Integer.parseInt(raw.substring(CURSOR_PREFIX.length()));
      if (offset < 0) {
        throw new InvalidCursorException();
      }
      return offset;
    } catch (IllegalArgumentException e) {
      throw new InvalidCursorException();
    }
  }

  private static String encodeCursor(Integer offset) {
    return offset == null
        ? null
        : Base64.getUrlEncoder()
            .withoutPadding()
            .encodeToString((CURSOR_PREFIX + offset).getBytes(StandardCharsets.UTF_8));
  }

  /** The cursor was not one this API issued. */
  static class InvalidCursorException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    InvalidCursorException() {
      super("Invalid cursor");
    }
  }

  @ExceptionHandler(InvalidCursorException.class)
  ProblemDetail invalidCursor() {
    return problem(HttpStatus.BAD_REQUEST, "invalid-cursor", "Invalid cursor", "Start over.");
  }

  @ExceptionHandler(LocationRateLimitedException.class)
  ProblemDetail rateLimited() {
    return problem(
        HttpStatus.TOO_MANY_REQUESTS,
        "location-rate-limited",
        "Too many location updates",
        "Location can be updated once a minute.");
  }

  @ExceptionHandler(ImplausibleMovementException.class)
  ProblemDetail implausible() {
    return problem(
        HttpStatus.UNPROCESSABLE_CONTENT,
        "implausible-movement",
        "Location rejected",
        "That location change isn't possible in the time since your last update.");
  }

  @ExceptionHandler(LocationRequiredException.class)
  ProblemDetail locationRequired() {
    return problem(
        HttpStatus.CONFLICT,
        "location-required",
        "Location required",
        "Share your location to see who's nearby.");
  }

  @ExceptionHandler(PersonNotFoundException.class)
  ProblemDetail personNotFound() {
    return problem(
        HttpStatus.NOT_FOUND,
        "profile-unavailable",
        "Profile unavailable",
        "This profile isn't available.");
  }

  private static ProblemDetail problem(
      HttpStatus status, String type, String title, String detail) {
    ProblemDetail problem = ProblemDetail.forStatusAndDetail(status, detail);
    problem.setType(URI.create("urn:orbit:problem:" + type));
    problem.setTitle(title);
    return problem;
  }
}

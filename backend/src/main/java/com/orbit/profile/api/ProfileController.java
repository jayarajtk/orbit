package com.orbit.profile.api;

import com.orbit.profile.application.MyProfile;
import com.orbit.profile.application.ProfileService;
import com.orbit.profile.application.ProfileService.BlockedMember;
import com.orbit.profile.application.ProfileService.ProfileNotFoundException;
import com.orbit.profile.application.ProfileService.TooManyPhotosException;
import com.orbit.profile.domain.LookingFor;
import com.orbit.profile.domain.Profile;
import com.orbit.profile.domain.ProfileDraft;
import com.orbit.profile.domain.Relationship;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.net.URI;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** The member's own profile (W4, W14) and their blocked list. */
@RestController
@RequestMapping("/api/v1/me")
class ProfileController {

  private final ProfileService profiles;

  ProfileController(ProfileService profiles) {
    this.profiles = profiles;
  }

  record ProfileRequest(
      @NotBlank @Size(max = 30) String displayName,
      @Size(max = 280) String bio,
      @Size(max = 20) String pronouns,
      @Min(120) @Max(230) Integer heightCm,
      Relationship relationship,
      @NotNull Set<LookingFor> lookingFor,
      @Size(max = Profile.MAX_TAGS) List<@NotBlank @Size(max = 30) String> tags,
      Boolean showAge,
      Boolean showDistance) {

    ProfileDraft toDraft() {
      return new ProfileDraft(
          displayName,
          bio == null ? "" : bio,
          pronouns == null ? "" : pronouns,
          heightCm,
          relationship,
          lookingFor,
          tags == null ? List.of() : tags,
          showAge == null || showAge,
          showDistance == null || showDistance);
    }
  }

  @GetMapping("/profile")
  MyProfile mine(@AuthenticationPrincipal Jwt token) {
    return profiles.mine(token.getSubject());
  }

  @PutMapping("/profile")
  MyProfile save(@AuthenticationPrincipal Jwt token, @Valid @RequestBody ProfileRequest request) {
    return profiles.save(token.getSubject(), request.toDraft());
  }

  record PhotosRequest(@NotNull @Size(max = 6) List<@NotNull UUID> mediaIds) {}

  @PutMapping("/photos")
  MyProfile setPhotos(
      @AuthenticationPrincipal Jwt token, @Valid @RequestBody PhotosRequest request) {
    return profiles.setPhotos(token.getSubject(), request.mediaIds());
  }

  @GetMapping("/blocked")
  List<BlockedMember> blocked(@AuthenticationPrincipal Jwt token) {
    return profiles.blocked(token.getSubject());
  }

  @ExceptionHandler(TooManyPhotosException.class)
  ProblemDetail tooManyPhotos() {
    ProblemDetail problem =
        ProblemDetail.forStatusAndDetail(
            HttpStatus.UNPROCESSABLE_CONTENT, "A profile can have up to 6 photos.");
    problem.setType(URI.create("urn:orbit:problem:too-many-photos"));
    problem.setTitle("Too many photos");
    return problem;
  }

  @ExceptionHandler(ProfileNotFoundException.class)
  ProblemDetail notFound() {
    ProblemDetail problem =
        ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, "Create your profile first.");
    problem.setType(URI.create("urn:orbit:problem:profile-not-found"));
    problem.setTitle("Profile not found");
    return problem;
  }
}

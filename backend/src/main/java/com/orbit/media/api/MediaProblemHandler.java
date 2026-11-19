package com.orbit.media.api;

import com.orbit.media.MediaApi.MediaUnavailableException;
import com.orbit.media.application.AlbumService.AlbumLimitException;
import com.orbit.media.application.AlbumService.AlbumNotFoundException;
import com.orbit.media.application.AlbumService.AlbumViewedException;
import com.orbit.media.application.MediaService.InvalidUploadException;
import com.orbit.media.application.MediaService.MediaNotFoundException;
import com.orbit.media.application.MediaService.MediaRejectedException;
import com.orbit.media.application.MediaService.UploadIncompleteException;
import com.orbit.media.application.MediaService.UploadRateLimitedException;
import java.net.URI;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * Problems for media errors, wherever they surface: {@link MediaUnavailableException} also comes
 * from chat and profile when they attach media.
 */
@RestControllerAdvice
@Order(Ordered.HIGHEST_PRECEDENCE)
class MediaProblemHandler {

  @ExceptionHandler(InvalidUploadException.class)
  ProblemDetail invalidUpload() {
    return problem(
        HttpStatus.UNPROCESSABLE_CONTENT,
        "invalid-upload",
        "Upload not accepted",
        "That file type or size isn't accepted here.");
  }

  @ExceptionHandler(UploadRateLimitedException.class)
  ProblemDetail rateLimited() {
    return problem(
        HttpStatus.TOO_MANY_REQUESTS,
        "upload-rate-limited",
        "Too many uploads",
        "Finish or wait for your current uploads, then try again.");
  }

  @ExceptionHandler(UploadIncompleteException.class)
  ProblemDetail incomplete() {
    return problem(
        HttpStatus.CONFLICT,
        "upload-incomplete",
        "Upload not received",
        "The file hasn't arrived yet. Upload it, then try again.");
  }

  @ExceptionHandler(MediaRejectedException.class)
  ProblemDetail rejected() {
    return problem(
        HttpStatus.UNPROCESSABLE_CONTENT,
        "media-rejected",
        "File not accepted",
        "This file couldn't be used. Try a different one.");
  }

  @ExceptionHandler({MediaNotFoundException.class, AlbumNotFoundException.class})
  ProblemDetail notFound() {
    return problem(HttpStatus.NOT_FOUND, "media-not-found", "Not found", "It isn't available.");
  }

  @ExceptionHandler(MediaUnavailableException.class)
  ProblemDetail unavailable() {
    return problem(
        HttpStatus.UNPROCESSABLE_CONTENT,
        "media-unavailable",
        "Media can't be used",
        "That photo, video or album can't be used here.");
  }

  @ExceptionHandler(AlbumViewedException.class)
  ProblemDetail viewed() {
    return problem(
        HttpStatus.GONE,
        "view-once-opened",
        "Already opened",
        "This was shared for one view and has been opened.");
  }

  @ExceptionHandler(AlbumLimitException.class)
  ProblemDetail limit() {
    return problem(
        HttpStatus.CONFLICT, "album-limit", "Limit reached", "You've reached the album limit.");
  }

  private static ProblemDetail problem(
      HttpStatus status, String type, String title, String detail) {
    ProblemDetail problem = ProblemDetail.forStatusAndDetail(status, detail);
    problem.setType(URI.create("urn:orbit:problem:" + type));
    problem.setTitle(title);
    return problem;
  }
}

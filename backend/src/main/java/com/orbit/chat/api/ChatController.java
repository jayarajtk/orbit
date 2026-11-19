package com.orbit.chat.api;

import com.orbit.chat.application.ChatService;
import com.orbit.chat.application.ChatService.InvalidMessageException;
import com.orbit.chat.application.ChatService.MessageNotFoundException;
import com.orbit.chat.application.ChatService.MessagePage;
import com.orbit.chat.application.ChatService.RecipientUnavailableException;
import com.orbit.chat.application.ChatService.SendCommand;
import com.orbit.chat.application.ChatService.SendResult;
import com.orbit.chat.application.ChatService.UnsendExpiredException;
import com.orbit.chat.application.ChatService.ViewOnceOpenedException;
import com.orbit.chat.application.ChatService.WaveLimitReachedException;
import com.orbit.chat.application.ConversationSummary;
import com.orbit.chat.application.MessageView;
import com.orbit.chat.domain.MessageKind;
import com.orbit.media.MediaApi.Links;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.net.URI;
import java.time.Clock;
import java.time.Duration;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpHeaders;
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

/**
 * Chat over REST: inbox, history and catch-up, plus every write as a fallback to the WebSocket
 * (W10, W11). Conversations are addressed by the other member's id.
 */
@RestController
@RequestMapping("/api/v1")
@Validated
class ChatController {

  private final ChatService chat;
  private final Clock clock;

  ChatController(ChatService chat, Clock clock) {
    this.chat = chat;
    this.clock = clock;
  }

  record SendRequest(
      @NotBlank @Size(max = 64) String clientMsgId,
      @NotNull MessageKind kind,
      @Size(max = ChatService.MAX_TEXT) String text,
      Integer locationMinutes,
      UUID mediaId,
      Boolean viewOnce,
      UUID albumId) {}

  record ReadRequest(@Min(0) long seq, boolean share) {}

  record MuteRequest(boolean muted) {}

  @GetMapping("/conversations")
  List<ConversationSummary> inbox(@AuthenticationPrincipal Jwt token) {
    return chat.inbox(chat.me(token.getSubject()));
  }

  @GetMapping("/conversations/{otherId}/messages")
  MessagePage history(
      @AuthenticationPrincipal Jwt token,
      @PathVariable UUID otherId,
      @RequestParam(required = false) @Min(0) Long before,
      @RequestParam(required = false) @Min(0) Long after) {
    return chat.history(chat.me(token.getSubject()), otherId, before, after);
  }

  @PostMapping("/conversations/{otherId}/messages")
  ResponseEntity<MessageView> send(
      @AuthenticationPrincipal Jwt token,
      @PathVariable UUID otherId,
      @Valid @RequestBody SendRequest request) {
    SendResult result =
        chat.send(
            chat.me(token.getSubject()),
            otherId,
            new SendCommand(
                request.clientMsgId(),
                request.kind(),
                request.text(),
                request.locationMinutes(),
                request.mediaId(),
                Boolean.TRUE.equals(request.viewOnce()),
                request.albumId()));
    return ResponseEntity.status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
        .body(result.message());
  }

  @PostMapping("/conversations/{otherId}/read")
  ResponseEntity<Void> read(
      @AuthenticationPrincipal Jwt token,
      @PathVariable UUID otherId,
      @Valid @RequestBody ReadRequest request) {
    chat.markRead(chat.me(token.getSubject()), otherId, request.seq(), request.share());
    return ResponseEntity.noContent().build();
  }

  @PutMapping("/conversations/{otherId}/mute")
  ResponseEntity<Void> mute(
      @AuthenticationPrincipal Jwt token,
      @PathVariable UUID otherId,
      @RequestBody MuteRequest request) {
    chat.setMuted(chat.me(token.getSubject()), otherId, request.muted());
    return ResponseEntity.noContent().build();
  }

  @DeleteMapping("/conversations/{otherId}")
  ResponseEntity<Void> delete(@AuthenticationPrincipal Jwt token, @PathVariable UUID otherId) {
    chat.delete(chat.me(token.getSubject()), otherId);
    return ResponseEntity.noContent().build();
  }

  /** Short-lived links to a message's photo, video or voice note. */
  @GetMapping("/messages/{messageId}/media")
  Links media(@AuthenticationPrincipal Jwt token, @PathVariable UUID messageId) {
    return chat.mediaLinks(chat.me(token.getSubject()), messageId);
  }

  @PostMapping("/messages/{messageId}/unsend")
  ResponseEntity<Void> unsend(@AuthenticationPrincipal Jwt token, @PathVariable UUID messageId) {
    chat.unsend(chat.me(token.getSubject()), messageId);
    return ResponseEntity.noContent().build();
  }

  @ExceptionHandler(RecipientUnavailableException.class)
  ProblemDetail recipientUnavailable() {
    return problem(
        HttpStatus.NOT_FOUND,
        "recipient-unavailable",
        "Member unavailable",
        "This member can't be messaged.");
  }

  @ExceptionHandler(InvalidMessageException.class)
  ProblemDetail invalidMessage() {
    return problem(
        HttpStatus.UNPROCESSABLE_CONTENT,
        "invalid-message",
        "Invalid message",
        "The message content doesn't match its type.");
  }

  @ExceptionHandler(MessageNotFoundException.class)
  ProblemDetail messageNotFound() {
    return problem(
        HttpStatus.NOT_FOUND, "message-not-found", "Message not found", "No such message.");
  }

  @ExceptionHandler(ViewOnceOpenedException.class)
  ProblemDetail viewOnceOpened() {
    return problem(
        HttpStatus.GONE,
        "view-once-opened",
        "Already opened",
        "This photo could be opened once and has been.");
  }

  @ExceptionHandler(UnsendExpiredException.class)
  ProblemDetail unsendExpired() {
    return problem(
        HttpStatus.CONFLICT,
        "unsend-expired",
        "Too late to unsend",
        "Messages can only be unsent within 10 minutes.");
  }

  @ExceptionHandler(WaveLimitReachedException.class)
  ResponseEntity<ProblemDetail> waveLimit(WaveLimitReachedException e) {
    ProblemDetail problem =
        problem(
            HttpStatus.TOO_MANY_REQUESTS,
            "wave-limit",
            "Wave limit reached",
            "You can wave at this member again later.");
    problem.setProperty("retryAt", e.retryAt());
    Duration wait = Duration.between(clock.instant(), e.retryAt());
    long seconds = wait.getSeconds() + (wait.getNano() > 0 ? 1 : 0);
    return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
        .header(HttpHeaders.RETRY_AFTER, String.valueOf(Math.max(1, seconds)))
        .body(problem);
  }

  private static ProblemDetail problem(
      HttpStatus status, String type, String title, String detail) {
    ProblemDetail problem = ProblemDetail.forStatusAndDetail(status, detail);
    problem.setType(URI.create("urn:orbit:problem:" + type));
    problem.setTitle(title);
    return problem;
  }
}

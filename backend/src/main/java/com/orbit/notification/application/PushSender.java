package com.orbit.notification.application;

import java.util.UUID;

/** Delivers a push to one device (FCM for Android and web, APNs through FCM for iOS). */
public interface PushSender {

  /** Sends {@code push}. Implementations must not log the token. */
  void send(Push push);

  /**
   * A push. Deliberately content-free (ADR-0004): no message text and no sender name; the app
   * fetches the conversation when opened.
   *
   * @param platform {@code IOS}, {@code ANDROID} or {@code WEB}
   */
  record Push(UUID accountId, String token, String platform, UUID conversationId) {}
}

package com.orbit.notification.application;

import com.orbit.chat.ChatApi;
import com.orbit.chat.ChatApi.MessageSent;
import com.orbit.identity.IdentityApi;
import com.orbit.notification.application.PushSender.Push;
import com.orbit.notification.infrastructure.DeviceStore;
import java.time.Clock;
import java.util.UUID;
import org.springframework.modulith.events.ApplicationModuleListener;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Device registration and message pushes. Pushes go only to members without a live chat connection,
 * never for muted conversations, and never with content (ADR-0004).
 */
@Service
public class NotificationService {

  private final DeviceStore devices;
  private final PushSender sender;
  private final ChatApi chat;
  private final IdentityApi identity;
  private final Clock clock;

  public NotificationService(
      DeviceStore devices, PushSender sender, ChatApi chat, IdentityApi identity, Clock clock) {
    this.devices = devices;
    this.sender = sender;
    this.chat = chat;
    this.identity = identity;
    this.clock = clock;
  }

  @Transactional
  public void register(String callerSubject, Platform platform, String token) {
    devices.register(identity.require(callerSubject).id(), platform.name(), token, clock.instant());
  }

  @Transactional
  public void unregister(String callerSubject, String token) {
    devices.unregister(identity.require(callerSubject).id(), token);
  }

  /**
   * Runs after the message commits, asynchronously, through the Modulith event log, so a crash
   * between commit and push is retried on restart.
   */
  @ApplicationModuleListener
  void onMessageSent(MessageSent event) {
    UUID recipient = event.recipientId();
    if (chat.isOnline(recipient) || chat.isMuted(recipient, event.conversationId())) {
      return;
    }
    for (DeviceStore.Device device : devices.devices(recipient)) {
      sender.send(new Push(recipient, device.token(), device.platform(), event.conversationId()));
    }
  }

  /** Push platform. */
  public enum Platform {
    IOS,
    ANDROID,
    WEB
  }
}

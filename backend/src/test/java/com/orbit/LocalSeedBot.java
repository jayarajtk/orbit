package com.orbit;

import com.orbit.chat.ChatApi.MessageSent;
import com.orbit.chat.application.ChatDelivery;
import com.orbit.chat.application.ChatService;
import com.orbit.chat.application.ChatService.MessagePage;
import com.orbit.chat.application.ChatService.SendCommand;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;
import java.util.stream.IntStream;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Makes the {@link LocalSeedData} members answer messages in {@code bootTestRun}, so a single
 * developer can see live delivery, typing and read receipts. Never part of the application.
 */
@TestConfiguration(proxyBeanMethods = false)
class LocalSeedBot {

  @Bean(destroyMethod = "shutdownNow")
  ScheduledExecutorService seedBotScheduler() {
    return Executors.newSingleThreadScheduledExecutor(Thread.ofVirtual().factory());
  }

  @Bean
  Replier seedBotReplier(
      ChatService chat, ChatDelivery delivery, ScheduledExecutorService seedBotScheduler) {
    return new Replier(chat, delivery, seedBotScheduler);
  }

  /** Reads, types for a moment, then replies with a canned line. */
  static class Replier {

    private static final Logger log = LoggerFactory.getLogger(Replier.class);

    private static final List<String> REPLIES =
        List.of(
            "Hey! How's your day going?",
            "Ha, nice. What are you up to tonight?",
            "I'm around the Mission most evenings.",
            "Sounds good to me 🙂",
            "Coffee sometime this week?",
            "Sorry, was on a call. Tell me more!");

    private final Set<UUID> seedIds =
        IntStream.rangeClosed(1, LocalSeedData.SEEDS.size())
            .mapToObj(LocalSeedData::id)
            .collect(Collectors.toUnmodifiableSet());

    private final ChatService chat;
    private final ChatDelivery delivery;
    private final ScheduledExecutorService scheduler;

    Replier(ChatService chat, ChatDelivery delivery, ScheduledExecutorService scheduler) {
      this.chat = chat;
      this.delivery = delivery;
      this.scheduler = scheduler;
    }

    @TransactionalEventListener
    void onMessageSent(MessageSent event) {
      UUID bot = event.recipientId();
      UUID member = event.senderId();
      if (!seedIds.contains(bot) || seedIds.contains(member)) {
        return;
      }
      scheduler.schedule(() -> readAndType(bot, member), 800, TimeUnit.MILLISECONDS);
      scheduler.schedule(() -> reply(bot, member), 2500, TimeUnit.MILLISECONDS);
    }

    private void readAndType(UUID bot, UUID member) {
      try {
        MessagePage page = chat.history(bot, member, null, null);
        if (!page.items().isEmpty()) {
          chat.markRead(bot, member, page.items().getLast().seq(), true);
        }
        delivery.typing(bot, member);
      } catch (RuntimeException e) {
        log.warn("Seed bot could not read for {}", bot, e);
      }
    }

    private void reply(UUID bot, UUID member) {
      String text = REPLIES.get(ThreadLocalRandom.current().nextInt(REPLIES.size()));
      try {
        chat.send(bot, member, SendCommand.text(UUID.randomUUID().toString(), text));
      } catch (RuntimeException e) {
        log.warn("Seed bot could not reply for {}", bot, e);
      }
    }
  }
}

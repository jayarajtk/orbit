package com.orbit;

import static com.orbit.LocalSeedData.id;

import com.orbit.chat.application.ChatService;
import com.orbit.chat.application.ChatService.SendCommand;
import com.orbit.safety.application.SafetyService;
import com.orbit.safety.domain.ReportReason;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.simple.JdbcClient;

/**
 * Fictional reports between seed members for {@code bootTestRun} only, so the admin console's queue
 * has cases to review. Filed through the real services, so evidence is copied as in production.
 * Runs once, after {@link LocalSeedData}.
 */
@TestConfiguration(proxyBeanMethods = false)
class LocalSeedReports {

  private static final Logger log = LoggerFactory.getLogger(LocalSeedReports.class);

  @Bean
  @Order(10)
  ApplicationRunner seedLocalReports(JdbcClient jdbc, ChatService chat, SafetyService safety) {
    return args -> {
      if (jdbc.sql("SELECT count(*) FROM report").query(Long.class).single() > 0) {
        return;
      }
      // Ren (5) harasses Jo (3); Jo reports and blocks.
      say(chat, 5, 3, "hey");
      say(chat, 3, 5, "Hi! How's your week going?");
      say(chat, 5, 3, "send pics");
      say(chat, 3, 5, "Not interested, sorry.");
      say(chat, 5, 3, "why are you even on here then. answer me");
      safety.report(
          "seed-03", id(5), ReportReason.HARASSMENT, "Kept pushing after I said no.", true, null);
      // Kai (4) thinks Theo (7) is using someone else's photos.
      say(chat, 4, 7, "Your profile looks familiar, are those your photos?");
      say(chat, 7, 4, "Of course. Want to move this to another app?");
      safety.report(
          "seed-04", id(7), ReportReason.FAKE, "Photos look like a model's.", false, null);
      // Sam (2) worries Leo (24) may be under 18.
      say(chat, 2, 24, "Hey, what are you studying?");
      say(chat, 24, 2, "Still in school actually, finishing year 12");
      safety.report(
          "seed-02", id(24), ReportReason.UNDERAGE, "Says they're still at school.", false, null);
      log.info("Seeded 3 local reports for the moderation queue");
    };
  }

  private static void say(ChatService chat, int from, int to, String text) {
    chat.send(id(from), id(to), SendCommand.text(UUID.randomUUID().toString(), text));
  }
}

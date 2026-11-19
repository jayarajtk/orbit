package com.orbit;

import com.orbit.discovery.domain.GeoPoint;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.simple.JdbcClient;

/**
 * Fictional members for {@code bootTestRun} only, placed around San Francisco so the grid has
 * people in it. Ids are fixed ({@link #id(int)}) so the app's development chat seed can refer to
 * them until real chat exists. Never part of the application itself.
 *
 * <p>Set the simulator near them: {@code xcrun simctl location booted set 37.7749,-122.4194}.
 */
@TestConfiguration(proxyBeanMethods = false)
class LocalSeedData {

  static final GeoPoint CENTRE = new GeoPoint(37.7749, -122.4194);

  private static final Logger log = LoggerFactory.getLogger(LocalSeedData.class);

  /** Fixed id for seed member {@code n} (1-based). */
  static UUID id(int n) {
    return UUID.fromString("00000000-0000-4000-8000-%012d".formatted(n));
  }

  record Seed(
      String name,
      int age,
      Integer km,
      boolean online,
      String bio,
      String pronouns,
      Integer height,
      String relationship,
      String lookingFor,
      String tags,
      int joinedDaysAgo) {}

  static final List<Seed> SEEDS =
      List.of(
          new Seed(
              "Alex",
              27,
              0,
              true,
              "Coffee, climbing, bad puns. New in town and looking for bouldering buddies.",
              "he/him",
              180,
              "SINGLE",
              "CHAT,DATES",
              "climbing,coffee,music",
              3),
          new Seed(
              "Sam",
              31,
              1,
              false,
              "Architect by day, amateur baker by night. Ask me about sourdough.",
              "he/they",
              175,
              "SINGLE",
              "DATES,FRIENDS",
              "baking,design,cycling",
              120),
          new Seed(
              "Jo",
              24,
              2,
              true,
              "Grad student. Will trade board game nights for good playlists.",
              "they/them",
              null,
              null,
              "FRIENDS,CHAT",
              "boardgames,indie,books",
              5),
          new Seed(
              "Kai",
              29,
              3,
              false,
              "Nurse, runner, part-time plant parent. Early mornings are my thing.",
              "he/him",
              172,
              "SINGLE",
              "DATES",
              "running,plants,brunch",
              40),
          new Seed(
              "Ren",
              35,
              3,
              true,
              "Chef. I will absolutely judge your hot sauce collection.",
              "",
              183,
              "OPEN",
              "CHAT,RIGHT_NOW",
              "food,travel,jazz",
              300),
          new Seed(
              "Mika",
              26,
              null,
              false,
              "Keeping it low-key. Say hi and tell me your favourite film.",
              "he/him",
              null,
              null,
              "CHAT",
              "film,photography",
              18),
          new Seed(
              "Theo",
              33,
              4,
              false,
              "Product manager who escapes to the mountains most weekends.",
              "he/him",
              188,
              "SINGLE",
              "DATES,NETWORKING",
              "hiking,skiing,tech",
              75),
          new Seed(
              "Dev",
              28,
              4,
              true,
              "Software engineer, karaoke enthusiast, terrible at mini golf.",
              "he/him",
              170,
              null,
              "FRIENDS,DATES",
              "karaoke,gaming,coding",
              2),
          new Seed(
              "Luca",
              30,
              5,
              false,
              "Language nerd — currently learning Portuguese. Teach me slang?",
              "he/him",
              178,
              "SINGLE",
              "CHAT,FRIENDS",
              "languages,travel,wine",
              210),
          new Seed(
              "Nico",
              25,
              5,
              false,
              "Dancer and choreographer. Always up for live music.",
              "he/they",
              null,
              null,
              "DATES,RIGHT_NOW",
              "dance,livemusic,fashion",
              9),
          new Seed(
              "Ash",
              38,
              6,
              true,
              "Teacher, dog dad, enthusiastic but mediocre gardener.",
              "he/him",
              181,
              "SINGLE",
              "DATES",
              "dogs,gardening,podcasts",
              400),
          new Seed(
              "Rui",
              27,
              7,
              false,
              "Illustrator. Doodling on napkins is my love language.",
              "",
              null,
              null,
              "CHAT,FRIENDS",
              "art,comics,tea",
              30),
          new Seed(
              "Omar",
              32,
              1,
              true,
              "Physio and weekend footballer. Looking for someone to explore food markets with.",
              "he/him",
              176,
              "SINGLE",
              "DATES,CHAT",
              "football,markets,fitness",
              1),
          new Seed(
              "Felix",
              22,
              2,
              false,
              "Music student. Piano, synths, and too many open browser tabs.",
              "he/him",
              null,
              null,
              "FRIENDS,CHAT",
              "piano,synths,anime",
              14),
          new Seed(
              "Jun",
              29,
              0,
              false,
              "UX researcher. I ask a lot of questions — occupational hazard.",
              "they/them",
              168,
              null,
              "NETWORKING,FRIENDS",
              "research,ceramics,tea",
              60),
          new Seed(
              "Mateo",
              34,
              8,
              true,
              "Firefighter. Calm in a crisis, chaos in the kitchen.",
              "he/him",
              186,
              "SINGLE",
              "DATES,RIGHT_NOW",
              "cooking,gym,beach",
              6),
          new Seed(
              "Sasha",
              26,
              3,
              false,
              "Bookseller with strong opinions about fonts.",
              "she/they",
              null,
              null,
              "FRIENDS,CHAT",
              "books,typography,cats",
              90),
          new Seed(
              "Eli",
              41,
              9,
              false,
              "Lawyer who would rather be sailing. Dry humour, warm heart.",
              "he/him",
              179,
              "PARTNERED",
              "FRIENDS,NETWORKING",
              "sailing,history,whisky",
              500),
          new Seed(
              "Noor",
              28,
              2,
              true,
              "Data analyst, amateur astronomer. Ask me what that bright star is (it is probably a planet).",
              "he/him",
              174,
              "SINGLE",
              "DATES,CHAT",
              "astronomy,data,hiking",
              4),
          new Seed(
              "Tomás",
              36,
              6,
              false,
              "Carpenter. I make furniture and very good pancakes.",
              "he/him",
              184,
              null,
              "DATES",
              "woodwork,pancakes,camping",
              150),
          new Seed(
              "Ezra",
              23,
              1,
              false,
              "Barista and part-time DJ. Your coffee order says a lot about you.",
              "he/they",
              null,
              null,
              "CHAT,RIGHT_NOW",
              "coffee,djing,vinyl",
              11),
          new Seed(
              "Rafa",
              31,
              10,
              true,
              "Marine biologist. Yes, I have opinions about octopuses.",
              "he/him",
              177,
              "SINGLE",
              "DATES,FRIENDS",
              "ocean,diving,science",
              22),
          new Seed(
              "Kian",
              45,
              7,
              false,
              "Grew up by the sea, settled in the city. Into long walks and longer conversations.",
              "he/him",
              182,
              "SINGLE",
              "DATES,CHAT",
              "walking,theatre,cooking",
              365),
          new Seed(
              "Leo",
              21,
              4,
              true,
              "First year of uni, figuring things out. Mostly here to make friends.",
              "he/him",
              null,
              null,
              "FRIENDS",
              "skating,gaming,memes",
              0));

  @Bean
  @Order(0)
  ApplicationRunner seedLocalMembers(JdbcClient jdbc, Clock clock) {
    return args -> {
      if (jdbc.sql("SELECT count(*) FROM account WHERE id = :id")
              .param("id", id(1))
              .query(Long.class)
              .single()
          > 0) {
        return;
      }
      Instant now = clock.instant();
      LocalDate today = LocalDate.now(clock);
      for (int i = 0; i < SEEDS.size(); i++) {
        insert(jdbc, i + 1, SEEDS.get(i), now, today);
      }
      log.info("Seeded {} local members around {}", SEEDS.size(), CENTRE);
    };
  }

  private static void insert(JdbcClient jdbc, int n, Seed s, Instant now, LocalDate today) {
    UUID id = id(n);
    Instant joined = now.minus(Duration.ofDays(s.joinedDaysAgo()));
    jdbc.sql(
            """
            INSERT INTO account (id, idp_subject, birth_date, status, created_at, updated_at)
            VALUES (:id, :subject, :birth, 'ACTIVE', :joined, :joined)
            """)
        .param("id", id)
        .param("subject", "seed-%02d".formatted(n))
        .param("birth", today.minusYears(s.age()).minusDays(100))
        .param("joined", joined.atOffset(ZoneOffset.UTC))
        .update();
    jdbc.sql(
            """
            INSERT INTO profile (account_id, display_name, bio, pronouns, height_cm, relationship,
                                 looking_for, tags, show_age, show_distance, last_active_at,
                                 created_at, updated_at)
            VALUES (:id, :name, :bio, :pronouns, :height, :relationship,
                    string_to_array(:lookingFor, ','), string_to_array(:tags, ','), TRUE,
                    :showDistance, :active, :joined, :joined)
            """)
        .param("id", id)
        .param("name", s.name())
        .param("bio", s.bio())
        .param("pronouns", s.pronouns())
        .param("height", s.height())
        .param("relationship", s.relationship())
        .param("lookingFor", s.lookingFor())
        .param("tags", s.tags())
        .param("showDistance", s.km() != null)
        .param(
            "active", (s.online() ? now : now.minus(Duration.ofHours(2))).atOffset(ZoneOffset.UTC))
        .param("joined", joined.atOffset(ZoneOffset.UTC))
        .update();
    double meters = s.km() == null ? 3_000 : s.km() * 1_000 + 400;
    GeoPoint point = CENTRE.offset((n * 47) % 360, meters);
    jdbc.sql(
            """
            INSERT INTO user_location (account_id, point, h3_cell, updated_at)
            VALUES (:id, ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)::geography, 'seed', :now)
            """)
        .param("id", id)
        .param("lat", point.lat())
        .param("lng", point.lng())
        .param("now", now.atOffset(ZoneOffset.UTC))
        .update();
  }
}

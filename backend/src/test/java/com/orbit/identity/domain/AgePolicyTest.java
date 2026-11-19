package com.orbit.identity.domain;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalDate;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

class AgePolicyTest {

  @ParameterizedTest(name = "born {0}, today {1} -> adult={2}")
  @CsvSource({
    "2008-11-09, 2026-11-09, true", // 18th birthday is today
    "2008-11-10, 2026-11-09, false", // 18th birthday is tomorrow
    "1990-01-01, 2026-11-09, true",
    "2010-06-15, 2026-11-09, false",
    "2008-02-29, 2026-02-28, false", // leap-day birthday: not yet 18 on Feb 28
    "2008-02-29, 2026-03-01, true", // leap-day birthday: 18 from Mar 1
  })
  void decidesWhetherSomeoneIsAnAdult(LocalDate birthDate, LocalDate today, boolean adult) {
    assertThat(AgePolicy.isAdult(birthDate, today)).isEqualTo(adult);
  }
}

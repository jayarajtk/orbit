package com.orbit.identity.domain;

import java.time.LocalDate;
import java.time.Period;

/** Orbit is 18+ only. Age is computed in whole years, so it changes on the birthday itself. */
public final class AgePolicy {

  /** Minimum age to hold an account. */
  public static final int MINIMUM_AGE = 18;

  private AgePolicy() {}

  /**
   * Whether someone born on {@code birthDate} is at least {@link #MINIMUM_AGE} on {@code today}.
   */
  public static boolean isAdult(LocalDate birthDate, LocalDate today) {
    return ageOn(birthDate, today) >= MINIMUM_AGE;
  }

  /** Age in whole years on {@code today}. */
  public static int ageOn(LocalDate birthDate, LocalDate today) {
    return Period.between(birthDate, today).getYears();
  }
}

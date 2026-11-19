package com.orbit.discovery.domain;

/**
 * The only distances the API ever returns (ADR-0003): 0 means under 1 km, 1–10 are whole kilometres
 * rounded down, and {@link #TEN_PLUS} means more than 10 km.
 */
public final class DistanceBucket {

  /** Bucket for anything beyond 10 km. */
  public static final int TEN_PLUS = 11;

  private DistanceBucket() {}

  /** Bucket for a distance in metres. */
  public static int of(double meters) {
    if (meters < 1_000) {
      return 0;
    }
    if (meters > 10_000) {
      return TEN_PLUS;
    }
    return (int) Math.floor(meters / 1_000);
  }
}

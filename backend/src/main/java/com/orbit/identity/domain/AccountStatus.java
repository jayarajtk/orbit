package com.orbit.identity.domain;

/** Account lifecycle; see the state diagram in design doc §8.1. */
public enum AccountStatus {
  /** Signed in and passed the age gate, profile not complete yet. */
  ONBOARDING,
  ACTIVE,
  SUSPENDED,
  BANNED,
  /** Deletion requested; can be cancelled during the grace period. */
  DELETING
}

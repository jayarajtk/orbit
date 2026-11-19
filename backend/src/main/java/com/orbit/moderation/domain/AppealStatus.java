package com.orbit.moderation.domain;

/** Where an appeal stands. */
public enum AppealStatus {
  OPEN,
  /** The action stays. */
  UPHELD,
  /** The action was undone and the account reinstated. */
  REVERSED
}

package com.orbit.moderation.domain;

/** What a moderator did to a member. */
public enum ActionKind {
  /** A notice the member sees once; the account stays active. */
  WARN,
  /** Temporarily refused everywhere; lifts on its own. */
  SUSPEND,
  /** Permanently refused everywhere. */
  BAN,
  /** One public photo taken down. */
  REMOVE_PHOTO,
  /** Reports reviewed, no violation found. */
  DISMISS,
  /** A suspension or ban lifted, by a moderator or a granted appeal. */
  REINSTATE;

  /** Whether this action resolves the member's open reports as actioned. */
  public boolean actionsReports() {
    return this == WARN || this == SUSPEND || this == BAN || this == REMOVE_PHOTO;
  }

  /** Whether the member is refused everywhere until it ends or is reversed. */
  public boolean restricts() {
    return this == SUSPEND || this == BAN;
  }
}

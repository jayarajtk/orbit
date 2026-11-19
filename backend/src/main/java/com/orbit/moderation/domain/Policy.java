package com.orbit.moderation.domain;

/** The community rule an action is based on; the app shows the member a plain-language version. */
public enum Policy {
  FAKE_PROFILE,
  HARASSMENT,
  UNDERAGE,
  EXPLICIT_PHOTO,
  THREAT,
  SPAM,
  OTHER,
  /** For dismissals: the reports didn't show a violation. */
  NO_VIOLATION,
  /** Set by the system when an appeal reverses an action; moderators can't choose it. */
  APPEAL_GRANTED
}

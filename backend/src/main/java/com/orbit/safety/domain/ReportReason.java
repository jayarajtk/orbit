package com.orbit.safety.domain;

/** Why a member was reported. {@link #UNDERAGE} and {@link #THREAT} are reviewed first. */
public enum ReportReason {
  FAKE,
  HARASSMENT,
  UNDERAGE,
  PHOTOS,
  THREAT;

  /** Whether reports for this reason go to the front of the moderation queue. */
  public boolean urgent() {
    return this == UNDERAGE || this == THREAT;
  }
}

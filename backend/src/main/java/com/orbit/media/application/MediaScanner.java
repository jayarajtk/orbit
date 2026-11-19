package com.orbit.media.application;

import com.orbit.media.MediaApi.Kind;

/**
 * Safety scanning of new media (design doc §7.4): hash matching against known illegal content and a
 * nudity classifier, provided by an external vendor.
 */
public interface MediaScanner {

  Verdict scan(Kind kind, byte[] content);

  /** What the scanner decided. */
  enum Verdict {
    /** Fine anywhere. */
    CLEAN,
    /** Explicit but legal: private albums and chat only. */
    PRIVATE_ONLY,
    /** Never stored. */
    REJECTED
  }
}

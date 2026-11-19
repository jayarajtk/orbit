package com.orbit.moderation.application;

import java.util.Objects;

/**
 * The moderator making a request, as named in the audit log and on actions.
 *
 * @param name their identity-provider username (or subject when there is none)
 */
public record Moderator(String name) {

  /** Longest name stored; matches the audit and action columns. */
  public static final int MAX_NAME = 255;

  public Moderator {
    Objects.requireNonNull(name, "name");
    if (name.isBlank() || name.length() > MAX_NAME) {
      throw new IllegalArgumentException("Moderator name must be 1–255 characters");
    }
  }
}

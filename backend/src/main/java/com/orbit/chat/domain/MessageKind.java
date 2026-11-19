package com.orbit.chat.domain;

/** What a message carries. */
public enum MessageKind {
  /** Plain text. */
  TEXT,
  /** A wave (a lightweight "hi"). */
  WAVE,
  /** A timed live-location share. */
  LOCATION,
  /** A private album shared with the other member. */
  ALBUM,

  /** A photo, optionally view-once. */
  PHOTO,

  /** A short video. */
  VIDEO,

  /** A voice note. */
  VOICE;

  /** Whether the message carries an uploaded media object. */
  public boolean hasMedia() {
    return this == PHOTO || this == VIDEO || this == VOICE;
  }
}

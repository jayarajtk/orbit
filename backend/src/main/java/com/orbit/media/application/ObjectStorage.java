package com.orbit.media.application;

import java.time.Duration;
import java.util.OptionalLong;

/** S3-compatible object storage. Objects are private; access goes through presigned links. */
public interface ObjectStorage {

  /** A link the client can PUT exactly {@code sizeBytes} of {@code contentType} to. */
  String presignPut(String key, String contentType, long sizeBytes, Duration ttl);

  /** A link to read {@code key}. */
  String presignGet(String key, Duration ttl);

  /** The object's size, or empty when it doesn't exist. */
  OptionalLong size(String key);

  /** The first {@code length} bytes of the object (fewer if it is shorter). */
  byte[] readHead(String key, int length);

  /** The whole object. Callers check the size first. */
  byte[] read(String key);

  void write(String key, byte[] bytes, String contentType);

  /** Deletes the object; does nothing if it doesn't exist. */
  void delete(String key);
}

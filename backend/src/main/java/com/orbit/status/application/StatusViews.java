package com.orbit.status.application;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/** What the status API returns. Grouped here because they only make sense together. */
public final class StatusViews {

  private StatusViews() {}

  /**
   * One of the caller's own live statuses.
   *
   * @param url short-lived link to the photo; null if moderation took the photo down
   * @param thumbUrl short-lived link to the thumbnail; null like {@code url}
   * @param caption null when there is none
   * @param viewers who viewed it, newest view first
   */
  public record MyStatus(
      UUID id,
      String url,
      String thumbUrl,
      String caption,
      Instant createdAt,
      Instant expiresAt,
      int viewCount,
      List<Viewer> viewers) {}

  /**
   * A member who viewed one of the caller's statuses.
   *
   * @param thumbUrl short-lived link to their main profile photo; null when they have none
   */
  public record Viewer(UUID id, String name, String thumbUrl, Instant viewedAt) {}

  /**
   * Another member's live status.
   *
   * @param caption null when there is none
   * @param seen whether the caller has viewed it
   */
  public record StatusItem(
      UUID id, String url, String thumbUrl, String caption, Instant createdAt, boolean seen) {}
}

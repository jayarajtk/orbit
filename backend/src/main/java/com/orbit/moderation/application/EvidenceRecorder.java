package com.orbit.moderation.application;

import com.orbit.chat.ChatApi;
import com.orbit.media.MediaApi;
import com.orbit.moderation.infrastructure.ModerationStore;
import com.orbit.moderation.infrastructure.ModerationStore.EvidenceRow;
import com.orbit.safety.SafetyApi.ReportFiled;
import com.orbit.status.StatusApi;
import java.time.Clock;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Copies the last messages between reporter and reported member into the report (ADR-0007), and the
 * reported status when the report names one.
 *
 * <p>A plain synchronous {@code @EventListener}, not an asynchronous module listener, on purpose:
 * it runs inside the transaction that files the report, so the copy is taken before the reported
 * member could unsend anything, and the report and its evidence commit or fail together.
 */
@Component
class EvidenceRecorder {

  /** Messages copied per report. */
  static final int MESSAGES = 20;

  /** The kind of an evidence row that is a status rather than a message. */
  static final String STATUS = "STATUS";

  private final ChatApi chat;
  private final StatusApi statuses;
  private final MediaApi media;
  private final ModerationStore store;
  private final Clock clock;

  EvidenceRecorder(
      ChatApi chat, StatusApi statuses, MediaApi media, ModerationStore store, Clock clock) {
    this.chat = chat;
    this.statuses = statuses;
    this.media = media;
    this.store = store;
    this.clock = clock;
  }

  @EventListener
  void onReportFiled(ReportFiled report) {
    List<EvidenceRow> rows = new ArrayList<>(messages(report));
    statusRow(report).ifPresent(rows::add);
    store.insertEvidence(report.reportId(), rows, clock.instant());
  }

  private List<EvidenceRow> messages(ReportFiled report) {
    return chat.recentBetween(report.reporterId(), report.subjectId(), MESSAGES).stream()
        .map(m ->
            new EvidenceRow(
                m.id(), m.senderId(), m.kind(), m.text(), m.mediaId(), m.sentAt(), m.unsent()))
        .toList();
  }

  /**
   * The reported status, if it is the subject's and still live. Its photo is held so expiry leaves
   * it; if the photo is already gone the row is kept without it, so a report never fails on an
   * expiry race.
   */
  private Optional<EvidenceRow> statusRow(ReportFiled report) {
    if (report.statusId() == null) {
      return Optional.empty();
    }
    return statuses
        .liveStatusOf(report.subjectId(), report.statusId())
        .map(status -> {
          UUID mediaId = media.holdAsEvidence(status.mediaId()) ? status.mediaId() : null;
          return new EvidenceRow(
              status.id(),
              report.subjectId(),
              STATUS,
              status.caption(),
              mediaId,
              status.createdAt(),
              false);
        });
  }
}

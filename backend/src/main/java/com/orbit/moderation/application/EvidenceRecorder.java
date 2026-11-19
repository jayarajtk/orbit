package com.orbit.moderation.application;

import com.orbit.chat.ChatApi;
import com.orbit.moderation.infrastructure.ModerationStore;
import com.orbit.moderation.infrastructure.ModerationStore.EvidenceRow;
import com.orbit.safety.SafetyApi.ReportFiled;
import java.time.Clock;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Copies the last messages between reporter and reported member into the report (ADR-0007).
 *
 * <p>A plain synchronous {@code @EventListener}, not an asynchronous module listener, on purpose:
 * it runs inside the transaction that files the report, so the copy is taken before the reported
 * member could unsend anything, and the report and its evidence commit or fail together.
 */
@Component
class EvidenceRecorder {

  /** Messages copied per report. */
  static final int MESSAGES = 20;

  private final ChatApi chat;
  private final ModerationStore store;
  private final Clock clock;

  EvidenceRecorder(ChatApi chat, ModerationStore store, Clock clock) {
    this.chat = chat;
    this.store = store;
    this.clock = clock;
  }

  @EventListener
  void onReportFiled(ReportFiled report) {
    var messages =
        chat.recentBetween(report.reporterId(), report.subjectId(), MESSAGES).stream()
            .map(m ->
                new EvidenceRow(
                    m.id(), m.senderId(), m.kind(), m.text(), m.mediaId(), m.sentAt(), m.unsent()))
            .toList();
    store.insertEvidence(report.reportId(), messages, clock.instant());
  }
}

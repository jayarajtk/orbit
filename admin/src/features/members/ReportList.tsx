import { formatDateTime, humanize } from '@/shared/lib/format';

import type { Evidence, Report } from './types';

type Props = { reports: Report[]; memberName: string };

/** Every report against the member, with the conversation copied when it was filed. */
export function ReportList({ reports, memberName }: Props) {
  if (reports.length === 0) return <p>No reports.</p>;
  return (
    <ol className="plain">
      {reports.map((report) => (
        <li key={report.id}>
          <article className="card" aria-labelledby={`report-${report.id}`}>
            <h3 id={`report-${report.id}`}>
              {humanize(report.reason)} · reported by {report.reporterName ?? 'a former member'}
            </h3>
            <p className="meta">
              <time dateTime={report.createdAt}>{formatDateTime(report.createdAt)}</time> ·{' '}
              {humanize(report.status)}
              {report.reviewer && ` · reviewer ${report.reviewer}`}
            </p>
            {report.details && <blockquote>{report.details}</blockquote>}
            <Transcript
              evidence={report.evidence}
              memberName={memberName}
              reporterName={report.reporterName ?? 'Reporter'}
            />
          </article>
        </li>
      ))}
    </ol>
  );
}

type TranscriptProps = { evidence: Evidence[]; memberName: string; reporterName: string };

function Transcript({ evidence, memberName, reporterName }: TranscriptProps) {
  if (evidence.length === 0) {
    return <p className="meta">No messages between them when the report was filed.</p>;
  }
  return (
    <details>
      <summary>Conversation at the time of the report ({evidence.length} messages)</summary>
      <ol className="transcript">
        {evidence.map((m) => (
          <li key={m.messageId} className={m.fromSubject ? 'from-subject' : 'from-reporter'}>
            <span className="sender">{m.fromSubject ? memberName : reporterName}</span>{' '}
            <time dateTime={m.sentAt} className="meta">
              {formatDateTime(m.sentAt)}
            </time>
            <MessageBody message={m} />
          </li>
        ))}
      </ol>
    </details>
  );
}

function MessageBody({ message }: { message: Evidence }) {
  if (message.kind === 'UNSENT') return <p className="meta">Unsent before the report</p>;
  if (message.kind === 'STATUS') return <StatusBody message={message} />;
  if (message.media) {
    return message.media.kind === 'PHOTO' ? (
      <a href={message.media.url} target="_blank" rel="noreferrer noopener">
        <img
          className="evidence-photo"
          src={message.media.thumbUrl ?? message.media.url}
          alt="Sent in the chat"
        />
      </a>
    ) : (
      <a href={message.media.url} target="_blank" rel="noreferrer noopener">
        Open {humanize(message.media.kind).toLowerCase()}
      </a>
    );
  }
  if (message.text) return <p>{message.text}</p>;
  return <p className="meta">{humanize(message.kind)}</p>;
}

/** A status the member posted, kept with its photo (if still held) and caption. */
function StatusBody({ message }: { message: Evidence }) {
  return (
    <>
      <p className="meta">Posted as a status</p>
      {message.media ? (
        <a href={message.media.url} target="_blank" rel="noreferrer noopener">
          <img
            className="evidence-photo"
            src={message.media.thumbUrl ?? message.media.url}
            alt="Posted as a status"
          />
        </a>
      ) : (
        <p className="meta">Photo no longer available</p>
      )}
      {message.text && <p>{message.text}</p>}
    </>
  );
}

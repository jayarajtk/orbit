import { Link } from 'react-router';

import { ProblemMessage } from '@/shared/components/ProblemMessage';
import { formatDateTime, formatRelative, humanize } from '@/shared/lib/format';

import { useCases } from './api';

/** Members with unresolved reports: minors and threats first, then the longest-waiting. */
export function QueuePage() {
  const cases = useCases();
  return (
    <>
      <h1>Queue</h1>
      {cases.isPending && <p aria-live="polite">Loading the queue…</p>}
      {cases.isError && <ProblemMessage error={cases.error} />}
      {cases.isSuccess && cases.data.length === 0 && <p>No open reports. The queue is clear.</p>}
      {cases.isSuccess && cases.data.length > 0 && (
        <div className="table-scroll">
          <table>
            <caption className="visually-hidden">Members with open reports</caption>
            <thead>
              <tr>
                <th scope="col">Member</th>
                <th scope="col">Reports</th>
                <th scope="col">Reasons</th>
                <th scope="col">Waiting since</th>
                <th scope="col">Reviewer</th>
              </tr>
            </thead>
            <tbody>
              {cases.data.map((c) => (
                <tr key={c.subjectId}>
                  <th scope="row">
                    <Link to={`/members/${c.subjectId}`}>{c.displayName ?? 'No profile'}</Link>
                    {c.urgent && <span className="badge badge-danger">Urgent</span>}
                  </th>
                  <td>{c.openReports}</td>
                  <td>{c.reasons.map(humanize).join(', ')}</td>
                  <td>
                    <time dateTime={c.oldestReportAt} title={formatDateTime(c.oldestReportAt)}>
                      {formatRelative(c.oldestReportAt)}
                    </time>
                  </td>
                  <td>{c.reviewer ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </>
  );
}

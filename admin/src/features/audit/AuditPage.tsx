import { Link, useSearchParams } from 'react-router';

import { ProblemMessage } from '@/shared/components/ProblemMessage';
import { formatDateTime, humanize } from '@/shared/lib/format';

import { useAuditLog } from './api';

/** The append-only record of what moderators did and looked at. */
export function AuditPage() {
  const [params] = useSearchParams();
  const accountId = params.get('accountId');
  const log = useAuditLog(accountId);
  const entries = log.data?.pages.flat() ?? [];

  return (
    <>
      <h1>Audit log</h1>
      {accountId && (
        <p>
          Showing activity for one member. <Link to="/audit">Show everything</Link>
        </p>
      )}
      {log.isPending && <p aria-live="polite">Loading the audit log…</p>}
      {log.isError && <ProblemMessage error={log.error} />}
      {log.isSuccess && entries.length === 0 && <p>Nothing recorded yet.</p>}
      {entries.length > 0 && (
        <div className="table-scroll">
          <table>
            <caption className="visually-hidden">Audit entries, newest first</caption>
            <thead>
              <tr>
                <th scope="col">When</th>
                <th scope="col">Moderator</th>
                <th scope="col">What</th>
                <th scope="col">Member</th>
                <th scope="col">Detail</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((e) => (
                <tr key={e.id}>
                  <td>
                    <time dateTime={e.createdAt}>{formatDateTime(e.createdAt)}</time>
                  </td>
                  <td>{e.actor}</td>
                  <td>{humanize(e.action)}</td>
                  <td>
                    {e.accountId ? <Link to={`/members/${e.accountId}`}>Open record</Link> : '—'}
                  </td>
                  <td>{e.detail || '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {log.hasNextPage && (
        <button
          type="button"
          className="secondary"
          onClick={() => void log.fetchNextPage()}
          disabled={log.isFetchingNextPage}
        >
          {log.isFetchingNextPage ? 'Loading…' : 'Load older entries'}
        </button>
      )}
    </>
  );
}

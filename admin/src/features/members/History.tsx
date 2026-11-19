import type { Appeal } from '@/features/appeals';
import { formatDateTime, humanize } from '@/shared/lib/format';
import { ACTION_LABELS } from '@/shared/lib/moderation';

import type { Action } from './types';

export function ActionHistory({ actions }: { actions: Action[] }) {
  if (actions.length === 0) return <p>No actions yet.</p>;
  return (
    <div className="table-scroll">
      <table>
        <caption className="visually-hidden">Actions taken on this member, newest first</caption>
        <thead>
          <tr>
            <th scope="col">When</th>
            <th scope="col">Action</th>
            <th scope="col">Rule</th>
            <th scope="col">By</th>
            <th scope="col">Message to member</th>
            <th scope="col">Note</th>
          </tr>
        </thead>
        <tbody>
          {actions.map((a) => (
            <tr key={a.id}>
              <td>
                <time dateTime={a.createdAt}>{formatDateTime(a.createdAt)}</time>
              </td>
              <td>
                {ACTION_LABELS[a.kind]}
                {a.suspendedUntil && ` until ${formatDateTime(a.suspendedUntil)}`}
                {a.reversedBy && <span className="badge badge-neutral">Reversed</span>}
                {a.kind === 'WARN' && (
                  <span className="meta"> · {a.acknowledgedAt ? 'seen' : 'not seen yet'}</span>
                )}
              </td>
              <td>{humanize(a.policy)}</td>
              <td>{a.moderator}</td>
              <td>{a.memberMessage || '—'}</td>
              <td>{a.internalNote || '—'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function AppealHistory({ appeals }: { appeals: Appeal[] }) {
  if (appeals.length === 0) return <p>No appeals.</p>;
  return (
    <ul className="plain">
      {appeals.map((a) => (
        <li key={a.id} className="card">
          <p>
            <strong>{humanize(a.status)}</strong> appeal against a{' '}
            {ACTION_LABELS[a.actionKind].toLowerCase()} ·{' '}
            <time dateTime={a.createdAt}>{formatDateTime(a.createdAt)}</time>
          </p>
          <blockquote>{a.text}</blockquote>
          {a.decidedBy && (
            <p className="meta">
              Decided by {a.decidedBy}
              {a.decisionMessage && `: "${a.decisionMessage}"`}
            </p>
          )}
        </li>
      ))}
    </ul>
  );
}

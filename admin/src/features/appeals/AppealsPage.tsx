import { Link } from 'react-router';

import { ProblemMessage } from '@/shared/components/ProblemMessage';
import { formatDateTime, humanize } from '@/shared/lib/format';
import { ACTION_LABELS } from '@/shared/lib/moderation';

import { DecisionForm } from './DecisionForm';
import { useOpenAppeals } from './api';

/** Open appeals, oldest first, each with its decision form. */
export function AppealsPage() {
  const appeals = useOpenAppeals();
  return (
    <>
      <h1>Appeals</h1>
      {appeals.isPending && <p aria-live="polite">Loading appeals…</p>}
      {appeals.isError && <ProblemMessage error={appeals.error} />}
      {appeals.isSuccess && appeals.data.length === 0 && <p>No open appeals.</p>}
      {appeals.data?.map((appeal) => (
        <article key={appeal.id} className="card" aria-labelledby={`appeal-${appeal.id}`}>
          <h2 id={`appeal-${appeal.id}`}>
            <Link to={`/members/${appeal.accountId}`}>{appeal.displayName ?? 'No profile'}</Link>{' '}
            appeals a {ACTION_LABELS[appeal.actionKind].toLowerCase()} for{' '}
            {humanize(appeal.policy).toLowerCase()}
          </h2>
          <p className="meta">
            Appealed <time dateTime={appeal.createdAt}>{formatDateTime(appeal.createdAt)}</time>
          </p>
          <blockquote>{appeal.text}</blockquote>
          <DecisionForm appealId={appeal.id} accountId={appeal.accountId} />
        </article>
      ))}
    </>
  );
}

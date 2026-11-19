import { useId } from 'react';
import { Link, useSearchParams } from 'react-router';

import { ProblemMessage } from '@/shared/components/ProblemMessage';
import { StatusBadge } from '@/shared/components/StatusBadge';

import { useMemberSearch } from './api';

/** Finds a member by account id or the start of their display name. The query lives in the URL. */
export function SearchPage() {
  const [params, setParams] = useSearchParams();
  const query = params.get('q') ?? '';
  const results = useMemberSearch(query);
  const id = useId();

  return (
    <>
      <h1>Find a member</h1>
      <form
        role="search"
        className="inline-form"
        onSubmit={(e) => {
          e.preventDefault();
          const value = new FormData(e.currentTarget).get('q');
          setParams(typeof value === 'string' && value.trim() ? { q: value.trim() } : {});
        }}
      >
        <label htmlFor={id}>Name or account id</label>
        <input id={id} name="q" type="search" defaultValue={query} maxLength={100} />
        <button type="submit">Search</button>
      </form>
      {results.isFetching && <p aria-live="polite">Searching…</p>}
      {results.isError && <ProblemMessage error={results.error} />}
      {results.isSuccess && (
        <>
          <p aria-live="polite">
            {results.data.length === 0
              ? 'No members found.'
              : `${results.data.length} ${results.data.length === 1 ? 'member' : 'members'} found.`}
          </p>
          <ul className="plain">
            {results.data.map((hit) => (
              <li key={hit.accountId}>
                <Link to={`/members/${hit.accountId}`}>{hit.displayName ?? hit.accountId}</Link>{' '}
                <StatusBadge status={hit.status} />
              </li>
            ))}
          </ul>
        </>
      )}
    </>
  );
}

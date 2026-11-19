import { isRouteErrorResponse, Link, useRouteError } from 'react-router';

import { describe } from '@/shared/components/ProblemMessage';

/** The error boundary for every route: explains the failure and offers a way back. */
export function RouteError() {
  const error = useRouteError();
  const message = isRouteErrorResponse(error)
    ? error.status === 404
      ? "That page doesn't exist."
      : error.statusText
    : describe(error);
  return (
    <main className="page">
      <h1>Something went wrong</h1>
      <p role="alert">{message}</p>
      <Link to="/">Back to the queue</Link>
    </main>
  );
}

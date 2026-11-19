import { ApiProblem } from '@/shared/lib/api';

type Props = { error: unknown };

/** Explains a failed request in words a moderator can act on. */
export function ProblemMessage({ error }: Props) {
  return (
    <p role="alert" className="problem">
      {describe(error)}
    </p>
  );
}

export function describe(error: unknown): string {
  if (error instanceof ApiProblem) {
    if (error.status === 403) return "Your account doesn't have moderator access.";
    if (error.status === 401) return 'Your session ended. Reload the page to sign in again.';
    if (error.detail) return error.detail;
  }
  return 'Something went wrong. Try again.';
}

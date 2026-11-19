import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router';

import { describe } from '@/shared/components/ProblemMessage';
import { useAuth } from '@/shared/lib/context';

/** Finishes the sign-in redirect, then continues where the moderator was going. */
export function CallbackPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const [error, setError] = useState<string | null>(null);
  // The callback can be completed only once; Strict Mode runs effects twice in development.
  const started = useRef(false);

  useEffect(() => {
    if (started.current) return;
    started.current = true;
    auth.completeSignIn().then(
      (returnTo) => void navigate(returnTo, { replace: true }),
      (e: unknown) => {
        setError(describe(e));
      },
    );
  }, [auth, navigate]);

  return (
    <main className="centred">
      {error ? (
        <p role="alert">
          Sign-in didn't complete: {error} <a href="/">Try again</a>
        </p>
      ) : (
        <p aria-live="polite">Signing in…</p>
      )}
    </main>
  );
}

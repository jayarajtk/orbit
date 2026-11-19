import { useQuery } from '@tanstack/react-query';
import { useEffect, type ReactNode } from 'react';
import { useLocation } from 'react-router';

import { useAuth } from '@/shared/lib/context';

export const SESSION_KEY = ['session'] as const;

/** Shows {@code children} once signed in; otherwise sends the browser to sign in. */
export function RequireAuth({ children }: { children: ReactNode }) {
  const auth = useAuth();
  const location = useLocation();
  const session = useQuery({ queryKey: SESSION_KEY, queryFn: () => auth.username() });
  const signedOut = session.isSuccess && session.data === null;

  useEffect(() => {
    if (signedOut) void auth.signIn(location.pathname + location.search);
  }, [auth, signedOut, location.pathname, location.search]);

  if (session.data) return children;
  return (
    <main className="centred">
      <p aria-live="polite">Signing in…</p>
    </main>
  );
}

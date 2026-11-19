import { render } from '@testing-library/react';
import * as axe from 'axe-core';
import { createMemoryRouter, RouterProvider } from 'react-router';

import { createQueryClient, Providers } from '@/app/providers';
import { routes } from '@/app/router';
import { createApi } from '@/shared/lib/api';
import type { AuthClient } from '@/shared/lib/auth';

/** Tests talk to this origin; MSW answers it. */
export const API = 'http://localhost/api/v1';

/** A signed-in moderator called "sam" unless a test says otherwise. */
export function fakeAuth(overrides: Partial<AuthClient> = {}): AuthClient {
  return {
    accessToken: () => Promise.resolve('token'),
    username: () => Promise.resolve('sam'),
    signIn: () => Promise.resolve(),
    completeSignIn: () => Promise.resolve('/'),
    signOut: () => Promise.resolve(),
    ...overrides,
  };
}

/** Renders the whole console at {@code path}, as a browser would load it. */
export function renderApp(path: string, auth: AuthClient = fakeAuth()) {
  const router = createMemoryRouter(routes, { initialEntries: [path] });
  const queryClient = createQueryClient();
  queryClient.setDefaultOptions({
    queries: { ...queryClient.getDefaultOptions().queries, retry: false },
  });
  const result = render(
    <Providers auth={auth} api={createApi(auth, API)} queryClient={queryClient}>
      <RouterProvider router={router} />
    </Providers>,
  );
  return { ...result, router };
}

/** Accessibility violations axe can detect in jsdom (contrast needs a real browser). */
export async function axeViolations(container: Element): Promise<string[]> {
  const results = await axe.run(container, { rules: { 'color-contrast': { enabled: false } } });
  return results.violations.map((v) => `${v.id}: ${v.help}`);
}

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactNode } from 'react';

import { ApiProblem, type Api } from '@/shared/lib/api';
import type { AuthClient } from '@/shared/lib/auth';
import { ServicesProvider } from '@/shared/lib/context';

const MAX_RETRIES = 2;

/** Server-state defaults in one place: short staleness, retries only for transient failures. */
export function createQueryClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 30_000,
        refetchOnWindowFocus: true,
        retry: (failures, error) =>
          failures < MAX_RETRIES &&
          error instanceof ApiProblem &&
          (error.status === 0 || error.status >= 500),
      },
      // Moderation actions aren't idempotent, so a failed one is never sent twice.
      mutations: { retry: false },
    },
  });
}

type Props = { auth: AuthClient; api: Api; queryClient: QueryClient; children: ReactNode };

export function Providers({ auth, api, queryClient, children }: Props) {
  return (
    <ServicesProvider auth={auth} api={api}>
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    </ServicesProvider>
  );
}

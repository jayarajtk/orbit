import { createBrowserRouter, type RouteObject } from 'react-router';

import { CallbackPage } from './CallbackPage';
import { Layout } from './Layout';
import { RequireAuth } from './RequireAuth';
import { RouteError } from './RouteError';

// Each page loads on first visit, so signing in doesn't wait for the whole console.
export const routes: RouteObject[] = [
  { path: '/callback', element: <CallbackPage />, errorElement: <RouteError /> },
  {
    element: (
      <RequireAuth>
        <Layout />
      </RequireAuth>
    ),
    errorElement: <RouteError />,
    children: [
      {
        index: true,
        errorElement: <RouteError />,
        lazy: async () => ({ Component: (await import('@/features/queue')).QueuePage }),
      },
      {
        path: 'members/:accountId',
        errorElement: <RouteError />,
        lazy: async () => ({ Component: (await import('@/features/members')).MemberPage }),
      },
      {
        path: 'search',
        errorElement: <RouteError />,
        lazy: async () => ({ Component: (await import('@/features/members')).SearchPage }),
      },
      {
        path: 'appeals',
        errorElement: <RouteError />,
        lazy: async () => ({ Component: (await import('@/features/appeals')).AppealsPage }),
      },
      {
        path: 'audit',
        errorElement: <RouteError />,
        lazy: async () => ({ Component: (await import('@/features/audit')).AuditPage }),
      },
    ],
  },
];

export function createRouter() {
  return createBrowserRouter(routes);
}

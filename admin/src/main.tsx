import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { RouterProvider } from 'react-router';

import { createQueryClient, Providers } from './app/providers';
import { createRouter } from './app/router';
import { createApi } from './shared/lib/api';
import { oidcAuthClient } from './shared/lib/auth';
import { readEnv } from './shared/lib/env';
import './app/styles.css';

const root = document.getElementById('root');
if (!root) throw new Error('Missing #root element');

const auth = oidcAuthClient(readEnv());

createRoot(root).render(
  <StrictMode>
    <Providers auth={auth} api={createApi(auth)} queryClient={createQueryClient()}>
      <RouterProvider router={createRouter()} />
    </Providers>
  </StrictMode>,
);

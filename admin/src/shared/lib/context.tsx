import { createContext, use, type ReactNode } from 'react';

import type { Api } from './api';
import type { AuthClient } from './auth';

interface Services {
  auth: AuthClient;
  api: Api;
}

const ServicesContext = createContext<Services | null>(null);

export function ServicesProvider({ auth, api, children }: Services & { children: ReactNode }) {
  return <ServicesContext value={{ auth, api }}>{children}</ServicesContext>;
}

function useServices(): Services {
  const services = use(ServicesContext);
  if (!services) throw new Error('ServicesProvider is missing');
  return services;
}

export function useApi(): Api {
  return useServices().api;
}

export function useAuth(): AuthClient {
  return useServices().auth;
}

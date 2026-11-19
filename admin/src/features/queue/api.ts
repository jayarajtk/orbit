import { useQuery } from '@tanstack/react-query';
import { z } from 'zod';

import { useApi } from '@/shared/lib/context';

import { caseSchema } from './types';

export const casesKey = ['cases'] as const;

export function useCases() {
  const api = useApi();
  return useQuery({
    queryKey: casesKey,
    queryFn: () => api.get('/admin/cases?limit=100', z.array(caseSchema)),
  });
}

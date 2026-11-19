import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { z } from 'zod';

import { useApi } from '@/shared/lib/context';

import { appealSchema } from './types';

export const appealsKey = ['appeals'] as const;

export function useOpenAppeals() {
  const api = useApi();
  return useQuery({
    queryKey: appealsKey,
    queryFn: () => api.get('/admin/appeals?status=OPEN', z.array(appealSchema)),
  });
}

export type Decision = { reverse: boolean; memberMessage: string };

export function useDecideAppeal(appealId: string, accountId: string) {
  const api = useApi();
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (decision: Decision) =>
      api.post(`/admin/appeals/${appealId}/decision`, decision, appealSchema),
    onSuccess: () =>
      Promise.all([
        queryClient.invalidateQueries({ queryKey: appealsKey }),
        queryClient.invalidateQueries({ queryKey: ['member', accountId] }),
      ]),
  });
}

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { z } from 'zod';

import { casesKey } from '@/features/queue';
import { useApi } from '@/shared/lib/context';
import type { ActionKind, Policy } from '@/shared/lib/moderation';

import { actionSchema, memberHitSchema, memberRecordSchema } from './types';

export const memberKey = (accountId: string) => ['member', accountId] as const;

export function useMember(accountId: string) {
  const api = useApi();
  return useQuery({
    queryKey: memberKey(accountId),
    queryFn: () => api.get(`/admin/members/${accountId}`, memberRecordSchema),
  });
}

export function useMemberSearch(query: string) {
  const api = useApi();
  const trimmed = query.trim();
  return useQuery({
    queryKey: ['members', 'search', trimmed] as const,
    queryFn: () =>
      api.get(`/admin/members?q=${encodeURIComponent(trimmed)}`, z.array(memberHitSchema)),
    enabled: trimmed.length > 0,
  });
}

export type ActionRequest = {
  kind: ActionKind;
  policy: Policy;
  memberMessage: string;
  internalNote: string;
  suspendHours: number | null;
  mediaId: string | null;
};

/** Everything an action can change: the member, the queue and the audit log. */
function useInvalidateAfterAction(accountId: string) {
  const queryClient = useQueryClient();
  return () =>
    Promise.all([
      queryClient.invalidateQueries({ queryKey: memberKey(accountId) }),
      queryClient.invalidateQueries({ queryKey: casesKey }),
      queryClient.invalidateQueries({ queryKey: ['audit'] }),
    ]);
}

export function useTakeAction(accountId: string) {
  const api = useApi();
  const invalidate = useInvalidateAfterAction(accountId);
  return useMutation({
    mutationFn: (request: ActionRequest) =>
      api.post(`/admin/members/${accountId}/actions`, request, actionSchema),
    onSuccess: invalidate,
  });
}

export function useClaim(accountId: string) {
  const api = useApi();
  const invalidate = useInvalidateAfterAction(accountId);
  return useMutation({
    mutationFn: () => api.postEmpty(`/admin/cases/${accountId}/claim`),
    onSuccess: invalidate,
  });
}

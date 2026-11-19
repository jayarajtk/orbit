import { useInfiniteQuery } from '@tanstack/react-query';
import { z } from 'zod';

import { useApi } from '@/shared/lib/context';

import { auditEntrySchema } from './types';

const PAGE = 100;

/** Audit entries newest first, a page at a time; each page starts before the last entry seen. */
export function useAuditLog(accountId: string | null) {
  const api = useApi();
  return useInfiniteQuery({
    queryKey: ['audit', accountId] as const,
    initialPageParam: null as string | null,
    queryFn: ({ pageParam }) => {
      const params = new URLSearchParams({ limit: String(PAGE) });
      if (accountId) params.set('accountId', accountId);
      if (pageParam) params.set('before', pageParam);
      return api.get(`/admin/audit?${params.toString()}`, z.array(auditEntrySchema));
    },
    getNextPageParam: (page) => (page.length === PAGE ? (page.at(-1)?.createdAt ?? null) : null),
  });
}

import { z } from 'zod';

import { ACTION_KINDS, APPEAL_STATUSES, POLICIES } from '@/shared/lib/moderation';

export const appealSchema = z.object({
  id: z.uuid(),
  actionId: z.uuid(),
  accountId: z.uuid(),
  displayName: z.string().nullable(),
  actionKind: z.enum(ACTION_KINDS),
  policy: z.enum(POLICIES),
  text: z.string(),
  status: z.enum(APPEAL_STATUSES),
  decidedBy: z.string().nullable(),
  decisionMessage: z.string().nullable(),
  createdAt: z.string(),
  decidedAt: z.string().nullable(),
});
export type Appeal = z.infer<typeof appealSchema>;

import { z } from 'zod';

export const auditEntrySchema = z.object({
  id: z.uuid(),
  actor: z.string(),
  action: z.string(),
  accountId: z.uuid().nullable(),
  detail: z.string(),
  createdAt: z.string(),
});
export type AuditEntry = z.infer<typeof auditEntrySchema>;

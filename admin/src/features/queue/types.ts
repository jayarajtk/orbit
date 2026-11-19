import { z } from 'zod';

export const caseSchema = z.object({
  subjectId: z.uuid(),
  displayName: z.string().nullable(),
  openReports: z.number().int(),
  urgent: z.boolean(),
  reasons: z.array(z.string()),
  oldestReportAt: z.string(),
  reviewer: z.string().nullable(),
});
export type Case = z.infer<typeof caseSchema>;

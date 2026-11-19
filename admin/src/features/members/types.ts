import { z } from 'zod';

import { appealSchema } from '@/features/appeals';
import { ACTION_KINDS, POLICIES } from '@/shared/lib/moderation';

export const actionSchema = z.object({
  id: z.uuid(),
  kind: z.enum(ACTION_KINDS),
  policy: z.enum(POLICIES),
  memberMessage: z.string(),
  internalNote: z.string(),
  suspendedUntil: z.string().nullable(),
  mediaId: z.uuid().nullable(),
  moderator: z.string(),
  acknowledgedAt: z.string().nullable(),
  reversedBy: z.uuid().nullable(),
  createdAt: z.string(),
});
export type Action = z.infer<typeof actionSchema>;

const mediaSchema = z.object({
  kind: z.string(),
  url: z.string(),
  thumbUrl: z.string().nullable(),
});

export const evidenceSchema = z.object({
  messageId: z.uuid(),
  fromSubject: z.boolean(),
  kind: z.string(),
  text: z.string().nullable(),
  sentAt: z.string(),
  media: mediaSchema.nullable(),
});
export type Evidence = z.infer<typeof evidenceSchema>;

export const reportSchema = z.object({
  id: z.uuid(),
  reporterId: z.uuid(),
  reporterName: z.string().nullable(),
  reason: z.string(),
  details: z.string(),
  status: z.string(),
  reviewer: z.string().nullable(),
  createdAt: z.string(),
  evidence: z.array(evidenceSchema),
});
export type Report = z.infer<typeof reportSchema>;

export const photoSchema = z.object({
  mediaId: z.uuid(),
  url: z.string(),
  thumbUrl: z.string().nullable(),
});
export type Photo = z.infer<typeof photoSchema>;

export const memberRecordSchema = z.object({
  accountId: z.uuid(),
  status: z.string(),
  suspendedUntil: z.string().nullable(),
  createdAt: z.string(),
  profile: z
    .object({
      displayName: z.string(),
      bio: z.string(),
      pronouns: z.string(),
      tags: z.array(z.string()),
      lastActiveAt: z.string(),
      photos: z.array(photoSchema),
    })
    .nullable(),
  reports: z.array(reportSchema),
  actions: z.array(actionSchema),
  appeals: z.array(appealSchema),
});
export type MemberRecord = z.infer<typeof memberRecordSchema>;

export const memberHitSchema = z.object({
  accountId: z.uuid(),
  displayName: z.string().nullable(),
  status: z.string(),
});
export type MemberHit = z.infer<typeof memberHitSchema>;

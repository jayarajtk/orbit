/** Codes shared with the API (ADR-0007). Kept in one place so forms and labels agree. */

export const ACTION_KINDS = [
  'WARN',
  'SUSPEND',
  'BAN',
  'REMOVE_PHOTO',
  'DISMISS',
  'REINSTATE',
] as const;
export type ActionKind = (typeof ACTION_KINDS)[number];

export const POLICIES = [
  'FAKE_PROFILE',
  'HARASSMENT',
  'UNDERAGE',
  'EXPLICIT_PHOTO',
  'THREAT',
  'SPAM',
  'OTHER',
  'NO_VIOLATION',
  'APPEAL_GRANTED',
] as const;
export type Policy = (typeof POLICIES)[number];

/** Policies a moderator can pick; APPEAL_GRANTED is set by appeal decisions only. */
export const SELECTABLE_POLICIES = POLICIES.filter((p) => p !== 'APPEAL_GRANTED');

export const APPEAL_STATUSES = ['OPEN', 'UPHELD', 'REVERSED'] as const;

/** The longest suspension the API accepts, in hours (a year). */
export const MAX_SUSPEND_HOURS = 24 * 365;

export const ACTION_LABELS: Record<ActionKind, string> = {
  WARN: 'Warn',
  SUSPEND: 'Suspend',
  BAN: 'Ban',
  REMOVE_PHOTO: 'Remove photo',
  DISMISS: 'Dismiss reports',
  REINSTATE: 'Reinstate',
};

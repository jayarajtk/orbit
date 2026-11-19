/** API responses shaped like the backend's, for tests. Ids are fixed so assertions can use them. */

export const BOB = '00000000-0000-4000-8000-000000000005';
export const JO = '00000000-0000-4000-8000-000000000003';
export const PHOTO = '11111111-1111-4111-8111-111111111111';
export const REPORT = '22222222-2222-4222-8222-222222222222';
export const APPEAL = '33333333-3333-4333-8333-333333333333';
export const ACTION = '44444444-4444-4444-8444-444444444444';

export const cases = [
  {
    subjectId: JO,
    displayName: 'Jo',
    openReports: 1,
    urgent: true,
    reasons: ['UNDERAGE'],
    oldestReportAt: '2026-11-18T10:00:00Z',
    reviewer: null,
  },
  {
    subjectId: BOB,
    displayName: 'Bob',
    openReports: 2,
    urgent: false,
    reasons: ['FAKE', 'HARASSMENT'],
    oldestReportAt: '2026-11-18T09:00:00Z',
    reviewer: 'alex',
  },
];

export function member(overrides: Record<string, unknown> = {}) {
  return {
    accountId: BOB,
    status: 'ACTIVE',
    suspendedUntil: null,
    createdAt: '2026-01-01T00:00:00Z',
    profile: {
      displayName: 'Bob',
      bio: 'Chef.',
      pronouns: 'he/him',
      tags: ['food'],
      lastActiveAt: '2026-11-18T11:00:00Z',
      photos: [
        {
          mediaId: PHOTO,
          url: 'https://storage.test/full',
          thumbUrl: 'https://storage.test/thumb',
        },
      ],
    },
    reports: [
      {
        id: REPORT,
        reporterId: JO,
        reporterName: 'Jo',
        reason: 'HARASSMENT',
        details: 'Kept pushing after I said no.',
        status: 'OPEN',
        reviewer: null,
        createdAt: '2026-11-18T09:00:00Z',
        evidence: [
          {
            messageId: '55555555-5555-4555-8555-555555555551',
            fromSubject: true,
            kind: 'TEXT',
            text: 'send pics',
            sentAt: '2026-11-18T08:58:00Z',
            media: null,
          },
          {
            messageId: '55555555-5555-4555-8555-555555555552',
            fromSubject: false,
            kind: 'TEXT',
            text: 'Not interested, sorry.',
            sentAt: '2026-11-18T08:59:00Z',
            media: null,
          },
          {
            messageId: '55555555-5555-4555-8555-555555555553',
            fromSubject: true,
            kind: 'UNSENT',
            text: null,
            sentAt: '2026-11-18T08:59:30Z',
            media: null,
          },
        ],
      },
    ],
    actions: [],
    appeals: [],
    ...overrides,
  };
}

export function action(overrides: Record<string, unknown> = {}) {
  return {
    id: ACTION,
    kind: 'WARN',
    policy: 'HARASSMENT',
    memberMessage: '',
    internalNote: '',
    suspendedUntil: null,
    mediaId: null,
    moderator: 'sam',
    acknowledgedAt: null,
    reversedBy: null,
    createdAt: '2026-11-18T12:00:00Z',
    ...overrides,
  };
}

export const openAppeal = {
  id: APPEAL,
  actionId: ACTION,
  accountId: BOB,
  displayName: 'Bob',
  actionKind: 'BAN',
  policy: 'THREAT',
  text: 'It was a joke between friends.',
  status: 'OPEN',
  decidedBy: null,
  decisionMessage: null,
  createdAt: '2026-11-18T12:00:00Z',
  decidedAt: null,
};

import { useQueryClient } from '@tanstack/react-query';
import { Link, useParams } from 'react-router';

import { ProblemMessage } from '@/shared/components/ProblemMessage';
import { StatusBadge } from '@/shared/components/StatusBadge';
import { formatDateTime } from '@/shared/lib/format';

import { ActionForm } from './ActionForm';
import { ActionHistory, AppealHistory } from './History';
import { ReportList } from './ReportList';
import { useClaim, useMember } from './api';
import type { MemberRecord } from './types';

/** One member's record: profile, reports with evidence, actions, appeals, and the action form. */
export function MemberPage() {
  const { accountId = '' } = useParams();
  const member = useMember(accountId);
  if (member.isPending) return <p aria-live="polite">Loading member…</p>;
  if (member.isError) return <ProblemMessage error={member.error} />;
  return <MemberDetail member={member.data} />;
}

function MemberDetail({ member }: { member: MemberRecord }) {
  const name = member.profile?.displayName ?? 'No profile';
  const openReports = member.reports.filter((r) => r.status === 'OPEN' || r.status === 'IN_REVIEW');
  const username = useQueryClient().getQueryData<string | null>(['session']);
  const reviewing = openReports.some((r) => r.reviewer === username);
  const claim = useClaim(member.accountId);

  return (
    <>
      <h1>
        {name} <StatusBadge status={member.status} />
      </h1>
      <dl className="facts">
        <dt>Account</dt>
        <dd>
          <code>{member.accountId}</code>
        </dd>
        <dt>Joined</dt>
        <dd>{formatDateTime(member.createdAt)}</dd>
        {member.suspendedUntil && (
          <>
            <dt>Suspended until</dt>
            <dd>{formatDateTime(member.suspendedUntil)}</dd>
          </>
        )}
        {member.profile && (
          <>
            <dt>Last active</dt>
            <dd>{formatDateTime(member.profile.lastActiveAt)}</dd>
          </>
        )}
        <dt>Audit</dt>
        <dd>
          <Link to={`/audit?accountId=${member.accountId}`}>
            Moderator activity for this member
          </Link>
        </dd>
      </dl>
      {openReports.length > 0 && !reviewing && (
        <p>
          <button
            type="button"
            className="secondary"
            onClick={() => {
              claim.mutate();
            }}
            disabled={claim.isPending}
          >
            Start review ({openReports.length} open{' '}
            {openReports.length === 1 ? 'report' : 'reports'})
          </button>
        </p>
      )}
      {claim.isError && <ProblemMessage error={claim.error} />}

      <div className="columns">
        <div>
          <section aria-labelledby="profile">
            <h2 id="profile">Profile</h2>
            {member.profile ? (
              <>
                {member.profile.bio && <p>{member.profile.bio}</p>}
                <p className="meta">
                  {[member.profile.pronouns, ...member.profile.tags].filter(Boolean).join(' · ')}
                </p>
                <ul className="photos">
                  {member.profile.photos.map((photo, index) => (
                    <li key={photo.mediaId}>
                      <a href={photo.url} target="_blank" rel="noreferrer noopener">
                        <img
                          src={photo.thumbUrl ?? photo.url}
                          alt={`Profile, ${index + 1} of ${member.profile?.photos.length ?? 0}`}
                        />
                      </a>
                    </li>
                  ))}
                </ul>
              </>
            ) : (
              <p>This member never created a profile.</p>
            )}
          </section>
          <section aria-labelledby="reports">
            <h2 id="reports">Reports ({member.reports.length})</h2>
            <ReportList reports={member.reports} memberName={name} />
          </section>
        </div>
        <section aria-labelledby="act" className="card sticky">
          <h2 id="act">Take action</h2>
          <ActionForm member={member} />
        </section>
      </div>

      <section aria-labelledby="history">
        <h2 id="history">History</h2>
        <ActionHistory actions={member.actions} />
      </section>
      <section aria-labelledby="appeals">
        <h2 id="appeals">Appeals</h2>
        <AppealHistory appeals={member.appeals} />
      </section>
    </>
  );
}

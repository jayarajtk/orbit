import { humanize } from '@/shared/lib/format';

type Props = { status: string };

const TONES: Record<string, string> = {
  ACTIVE: 'ok',
  ONBOARDING: 'neutral',
  SUSPENDED: 'warn',
  BANNED: 'danger',
  DELETING: 'neutral',
};

/** An account status as a labelled badge; the text carries the meaning, colour only helps. */
export function StatusBadge({ status }: Props) {
  return <span className={`badge badge-${TONES[status] ?? 'neutral'}`}>{humanize(status)}</span>;
}

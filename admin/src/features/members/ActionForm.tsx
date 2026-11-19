import { zodResolver } from '@hookform/resolvers/zod';
import { useId } from 'react';
import { useForm, useWatch } from 'react-hook-form';
import { z } from 'zod';

import { ProblemMessage } from '@/shared/components/ProblemMessage';
import { humanize } from '@/shared/lib/format';
import {
  ACTION_KINDS,
  ACTION_LABELS,
  MAX_SUSPEND_HOURS,
  SELECTABLE_POLICIES,
  type ActionKind,
} from '@/shared/lib/moderation';

import { useTakeAction } from './api';
import type { MemberRecord } from './types';

const schema = z
  .object({
    kind: z.enum(ACTION_KINDS, { message: 'Choose an action.' }),
    policy: z.enum(SELECTABLE_POLICIES, { message: 'Choose the rule this is based on.' }),
    suspendHours: z.string().trim(),
    mediaId: z.string(),
    memberMessage: z.string().trim().max(500, 'Keep the message under 500 characters.'),
    internalNote: z.string().trim().max(1000, 'Keep the note under 1,000 characters.'),
  })
  .superRefine((v, ctx) => {
    const hours = Number(v.suspendHours);
    if (
      v.kind === 'SUSPEND' &&
      !(Number.isInteger(hours) && hours >= 1 && hours <= MAX_SUSPEND_HOURS)
    ) {
      ctx.addIssue({
        code: 'custom',
        path: ['suspendHours'],
        message: `Enter a whole number of hours from 1 to ${MAX_SUSPEND_HOURS}.`,
      });
    }
    if (v.kind === 'REMOVE_PHOTO' && v.mediaId === '') {
      ctx.addIssue({ code: 'custom', path: ['mediaId'], message: 'Choose the photo to remove.' });
    }
    if ((v.kind === 'DISMISS') !== (v.policy === 'NO_VIOLATION')) {
      ctx.addIssue({
        code: 'custom',
        path: ['policy'],
        message: 'Use "No violation" for dismissals, and only for dismissals.',
      });
    }
  });
type Values = z.input<typeof schema>;

const EMPTY: Values = {
  kind: 'WARN',
  policy: 'HARASSMENT',
  suspendHours: '24',
  mediaId: '',
  memberMessage: '',
  internalNote: '',
};

/** Which actions fit the member's current state; the API enforces the same rules. */
function availableKinds(member: MemberRecord): ActionKind[] {
  const restricted = member.status === 'SUSPENDED' || member.status === 'BANNED';
  return ACTION_KINDS.filter((kind) => {
    if (kind === 'REINSTATE') return restricted;
    if (kind === 'SUSPEND' || kind === 'BAN') return member.status !== 'BANNED';
    if (kind === 'REMOVE_PHOTO') return (member.profile?.photos.length ?? 0) > 0;
    return true;
  });
}

type Props = { member: MemberRecord };

export function ActionForm({ member }: Props) {
  const act = useTakeAction(member.accountId);
  const id = useId();
  const {
    register,
    handleSubmit,
    control,
    setValue,
    reset,
    formState: { errors },
  } = useForm<Values>({ resolver: zodResolver(schema), defaultValues: EMPTY });
  const kind = useWatch({ control, name: 'kind' });
  const photos = member.profile?.photos ?? [];

  const submit = handleSubmit((v) => {
    act.mutate(
      {
        kind: v.kind,
        policy: v.policy,
        memberMessage: v.memberMessage.trim(),
        internalNote: v.internalNote.trim(),
        suspendHours: v.kind === 'SUSPEND' ? Number(v.suspendHours) : null,
        mediaId: v.kind === 'REMOVE_PHOTO' ? v.mediaId : null,
      },
      {
        onSuccess: () => {
          reset(EMPTY);
        },
      },
    );
  });

  const field = (name: keyof Values) => ({
    id: `${id}-${name}`,
    'aria-invalid': errors[name] ? true : undefined,
    'aria-describedby': errors[name] ? `${id}-${name}-error` : undefined,
  });
  const error = (name: keyof Values) =>
    errors[name] && (
      <p id={`${id}-${name}-error`} role="alert" className="field-error">
        {errors[name].message}
      </p>
    );

  return (
    <form onSubmit={(e) => void submit(e)} className="stack" noValidate>
      <label htmlFor={`${id}-kind`}>Action</label>
      <select
        {...field('kind')}
        {...register('kind', {
          onChange: (e: { target: { value: string } }) => {
            setValue('policy', e.target.value === 'DISMISS' ? 'NO_VIOLATION' : 'HARASSMENT');
          },
        })}
      >
        {availableKinds(member).map((k) => (
          <option key={k} value={k}>
            {ACTION_LABELS[k]}
          </option>
        ))}
      </select>
      {error('kind')}

      <label htmlFor={`${id}-policy`}>Rule</label>
      <select {...field('policy')} {...register('policy')}>
        {SELECTABLE_POLICIES.map((p) => (
          <option key={p} value={p}>
            {humanize(p)}
          </option>
        ))}
      </select>
      {error('policy')}

      {kind === 'SUSPEND' && (
        <>
          <label htmlFor={`${id}-suspendHours`}>Suspend for (hours)</label>
          <input
            type="number"
            inputMode="numeric"
            min={1}
            max={MAX_SUSPEND_HOURS}
            {...field('suspendHours')}
            {...register('suspendHours')}
          />
          {error('suspendHours')}
        </>
      )}

      {kind === 'REMOVE_PHOTO' && (
        <fieldset aria-describedby={errors.mediaId ? `${id}-mediaId-error` : undefined}>
          <legend>Photo to remove</legend>
          <div className="photo-choices">
            {photos.map((photo, index) => (
              <label key={photo.mediaId} className="photo-choice">
                <input type="radio" value={photo.mediaId} {...register('mediaId')} />
                <img
                  src={photo.thumbUrl ?? photo.url}
                  alt={`Profile, ${index + 1} of ${photos.length}`}
                />
              </label>
            ))}
          </div>
          {error('mediaId')}
        </fieldset>
      )}

      <label htmlFor={`${id}-memberMessage`}>Message to the member (optional)</label>
      <textarea rows={3} {...field('memberMessage')} {...register('memberMessage')} />
      {error('memberMessage')}

      <label htmlFor={`${id}-internalNote`}>Note for moderators (optional)</label>
      <textarea rows={3} {...field('internalNote')} {...register('internalNote')} />
      {error('internalNote')}

      {act.isError && <ProblemMessage error={act.error} />}
      {act.isSuccess && (
        <p role="status" className="success">
          {ACTION_LABELS[act.data.kind]} recorded.
        </p>
      )}
      <button
        type="submit"
        className={kind === 'BAN' ? 'danger' : undefined}
        disabled={act.isPending}
      >
        {act.isPending ? 'Saving…' : ACTION_LABELS[kind]}
      </button>
    </form>
  );
}

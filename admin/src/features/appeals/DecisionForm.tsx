import { zodResolver } from '@hookform/resolvers/zod';
import { useId } from 'react';
import { useForm } from 'react-hook-form';
import { z } from 'zod';

import { ProblemMessage } from '@/shared/components/ProblemMessage';

import { useDecideAppeal } from './api';

const schema = z.object({
  outcome: z.enum(['uphold', 'reverse'], { message: 'Choose an outcome.' }),
  memberMessage: z.string().trim().min(1, 'Tell the member the outcome.').max(500),
});
type Values = z.infer<typeof schema>;

type Props = { appealId: string; accountId: string };

/** Upholds or reverses one appeal, with the message the member will see. */
export function DecisionForm({ appealId, accountId }: Props) {
  const decide = useDecideAppeal(appealId, accountId);
  const id = useId();
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<Values>({ resolver: zodResolver(schema) });

  const submit = handleSubmit((values) => {
    decide.mutate({ reverse: values.outcome === 'reverse', memberMessage: values.memberMessage });
  });

  return (
    <form onSubmit={(e) => void submit(e)} className="stack" noValidate>
      <fieldset aria-describedby={errors.outcome ? `${id}-outcome-error` : undefined}>
        <legend>Decision</legend>
        <label>
          <input type="radio" value="uphold" {...register('outcome')} /> Uphold: the action stays
        </label>
        <label>
          <input type="radio" value="reverse" {...register('outcome')} /> Reverse: reinstate the
          account
        </label>
        {errors.outcome && (
          <p id={`${id}-outcome-error`} role="alert" className="field-error">
            {errors.outcome.message}
          </p>
        )}
      </fieldset>
      <label htmlFor={`${id}-message`}>Message to the member</label>
      <textarea
        id={`${id}-message`}
        rows={3}
        aria-invalid={errors.memberMessage ? true : undefined}
        aria-describedby={errors.memberMessage ? `${id}-message-error` : undefined}
        {...register('memberMessage')}
      />
      {errors.memberMessage && (
        <p id={`${id}-message-error`} role="alert" className="field-error">
          {errors.memberMessage.message}
        </p>
      )}
      {decide.isError && <ProblemMessage error={decide.error} />}
      <button type="submit" disabled={decide.isPending}>
        {decide.isPending ? 'Saving…' : 'Record decision'}
      </button>
    </form>
  );
}

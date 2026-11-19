import { z } from 'zod';

/** Build-time settings, checked once at startup so a misconfigured build fails loudly. */
const schema = z.object({
  VITE_OIDC_AUTHORITY: z.url(),
  VITE_OIDC_CLIENT_ID: z.string().min(1),
});

export type Env = z.infer<typeof schema>;

export function readEnv(source: Record<string, unknown> = import.meta.env): Env {
  const result = schema.safeParse(source);
  if (!result.success) {
    throw new Error(`Invalid console configuration: ${z.prettifyError(result.error)}`);
  }
  return result.data;
}

import { z } from 'zod';

import type { AuthClient } from './auth';

const PROBLEM_PREFIX = 'urn:orbit:problem:';

/** An RFC 9457 problem from the API, or a network failure (status 0). */
export class ApiProblem extends Error {
  constructor(
    readonly status: number,
    /** The problem type without the `urn:orbit:problem:` prefix, e.g. `invalid-action`. */
    readonly type: string,
    readonly detail: string | null,
  ) {
    super(detail ?? `Request failed (${status}, ${type})`);
    this.name = 'ApiProblem';
  }
}

const problemSchema = z.object({
  type: z.string().optional(),
  title: z.string().optional(),
  detail: z.string().optional(),
});

/** A typed client for `/api/v1`. Every response is validated against a schema. */
export interface Api {
  get<T>(path: string, schema: z.ZodType<T>): Promise<T>;
  post<T>(path: string, body: unknown, schema: z.ZodType<T>): Promise<T>;
  /** For endpoints that answer 204 No Content. */
  postEmpty(path: string, body?: unknown): Promise<void>;
}

export function createApi(auth: AuthClient, baseUrl = '/api/v1'): Api {
  async function request(method: string, path: string, body?: unknown): Promise<Response> {
    const token = await auth.accessToken();
    const headers = new Headers({ Accept: 'application/json' });
    if (token) headers.set('Authorization', `Bearer ${token}`);
    if (body !== undefined) headers.set('Content-Type', 'application/json');
    let response: Response;
    try {
      response = await fetch(`${baseUrl}${path}`, {
        method,
        headers,
        body: body === undefined ? null : JSON.stringify(body),
      });
    } catch {
      throw new ApiProblem(0, 'network', 'Could not reach the server. Check your connection.');
    }
    if (!response.ok) throw await toProblem(response);
    return response;
  }

  return {
    async get(path, schema) {
      return schema.parse(await (await request('GET', path)).json());
    },
    async post(path, body, schema) {
      return schema.parse(await (await request('POST', path, body)).json());
    },
    async postEmpty(path, body) {
      await request('POST', path, body);
    },
  };
}

async function toProblem(response: Response): Promise<ApiProblem> {
  let parsed: z.infer<typeof problemSchema> = {};
  try {
    parsed = problemSchema.parse(await response.json());
  } catch {
    // Not problem+json (e.g. a proxy error page); fall back to the status alone.
  }
  const type = parsed.type?.startsWith(PROBLEM_PREFIX)
    ? parsed.type.slice(PROBLEM_PREFIX.length)
    : (parsed.type ?? 'about:blank');
  return new ApiProblem(response.status, type, parsed.detail ?? parsed.title ?? null);
}

import { http, HttpResponse } from 'msw';
import { z } from 'zod';

import { API, fakeAuth } from '@/test/render';
import { server } from '@/test/server';

import { ApiProblem, createApi } from './api';

describe('API client', () => {
  const api = createApi(fakeAuth(), API);

  it('sends the bearer token and validates the response', async () => {
    let auth: string | null = null;
    server.use(
      http.get(`${API}/thing`, ({ request }) => {
        auth = request.headers.get('Authorization');
        return HttpResponse.json({ n: 1 });
      }),
    );

    await expect(api.get('/thing', z.object({ n: z.number() }))).resolves.toEqual({ n: 1 });
    expect(auth).toBe('Bearer token');
  });

  it('turns problem+json into an ApiProblem with the short type', async () => {
    server.use(
      http.post(`${API}/thing`, () =>
        HttpResponse.json(
          { type: 'urn:orbit:problem:appeal-decided', detail: 'Already decided.' },
          { status: 409 },
        ),
      ),
    );

    const error: unknown = await api.post('/thing', {}, z.unknown()).catch((e: unknown) => e);

    expect(error).toBeInstanceOf(ApiProblem);
    expect(error).toMatchObject({
      status: 409,
      type: 'appeal-decided',
      detail: 'Already decided.',
    });
  });

  it('reports an unreachable server as a network problem', async () => {
    server.use(http.get(`${API}/thing`, () => HttpResponse.error()));

    await expect(api.get('/thing', z.unknown())).rejects.toMatchObject({
      status: 0,
      type: 'network',
    });
  });

  it('rejects a response that does not match the schema', async () => {
    server.use(http.get(`${API}/thing`, () => HttpResponse.json({ n: 'one' })));

    await expect(api.get('/thing', z.object({ n: z.number() }))).rejects.toBeInstanceOf(z.ZodError);
  });
});

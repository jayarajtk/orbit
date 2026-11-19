import { screen, waitFor } from '@testing-library/react';
import { http, HttpResponse } from 'msw';

import { fakeAuth, API, renderApp } from '@/test/render';
import { server } from '@/test/server';

describe('Sign-in', () => {
  it('sends a signed-out visitor to sign in, remembering where they were going', async () => {
    const signIn = vi.fn(() => Promise.resolve());

    renderApp('/appeals?x=1', fakeAuth({ username: () => Promise.resolve(null), signIn }));

    await waitFor(() => {
      expect(signIn).toHaveBeenCalledWith('/appeals?x=1');
    });
    expect(screen.getByText('Signing in…')).toBeInTheDocument();
  });

  it('finishes the redirect and continues to the page', async () => {
    server.use(http.get(`${API}/admin/appeals`, () => HttpResponse.json([])));
    const completeSignIn = vi.fn(() => Promise.resolve('/appeals'));

    const { router } = renderApp('/callback', fakeAuth({ completeSignIn }));

    expect(await screen.findByText('No open appeals.')).toBeInTheDocument();
    expect(completeSignIn).toHaveBeenCalledTimes(1);
    expect(router.state.location.pathname).toBe('/appeals');
  });
});

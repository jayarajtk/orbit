import { screen, within } from '@testing-library/react';
import { http, HttpResponse } from 'msw';

import { BOB, cases } from '@/test/fixtures';
import { API, axeViolations, renderApp } from '@/test/render';
import { server } from '@/test/server';

describe('Queue', () => {
  it('lists members with open reports, urgent ones marked', async () => {
    server.use(http.get(`${API}/admin/cases`, () => HttpResponse.json(cases)));

    const { container } = renderApp('/');

    const rows = await screen.findAllByRole('row');
    expect(rows).toHaveLength(3); // header + 2 cases
    const first = rows[1];
    if (!first) throw new Error('missing row');
    expect(within(first).getByRole('link', { name: 'Jo' })).toBeInTheDocument();
    expect(within(first).getByText('Urgent')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Bob' })).toHaveAttribute('href', `/members/${BOB}`);
    expect(screen.getByText('Fake, Harassment')).toBeInTheDocument();
    expect(await axeViolations(container)).toEqual([]);
  });

  it('says when the queue is clear', async () => {
    server.use(http.get(`${API}/admin/cases`, () => HttpResponse.json([])));

    renderApp('/');

    expect(await screen.findByText('No open reports. The queue is clear.')).toBeInTheDocument();
  });

  it('explains when the account is not a moderator', async () => {
    server.use(
      http.get(`${API}/admin/cases`, () =>
        HttpResponse.json(
          { type: 'about:blank', title: 'Forbidden', status: 403 },
          { status: 403, headers: { 'Content-Type': 'application/problem+json' } },
        ),
      ),
    );

    renderApp('/');

    expect(await screen.findByRole('alert')).toHaveTextContent(
      "Your account doesn't have moderator access.",
    );
  });
});

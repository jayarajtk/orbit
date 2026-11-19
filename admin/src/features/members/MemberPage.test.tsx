import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';

import { action, BOB, member, PHOTO } from '@/test/fixtures';
import { API, axeViolations, renderApp } from '@/test/render';
import { server } from '@/test/server';

const MEMBER_URL = `${API}/admin/members/${BOB}`;

function serveMember(record = member()) {
  server.use(http.get(MEMBER_URL, () => HttpResponse.json(record)));
}

/** Captures action requests and answers with a recorded action of the same kind. */
function captureActions() {
  const sent: unknown[] = [];
  server.use(
    http.post(`${MEMBER_URL}/actions`, async ({ request }) => {
      const body = (await request.json()) as { kind: string };
      sent.push(body);
      return HttpResponse.json(action({ kind: body.kind }), { status: 201 });
    }),
  );
  return sent;
}

describe('Member record', () => {
  it('shows the profile, the report and the copied conversation', async () => {
    serveMember();
    const user = userEvent.setup();

    const { container } = renderApp(`/members/${BOB}`);

    expect(await screen.findByRole('heading', { level: 1, name: /Bob/ })).toBeInTheDocument();
    expect(screen.getByText('Chef.')).toBeInTheDocument();
    expect(screen.getByRole('img', { name: 'Profile, 1 of 1' })).toBeInTheDocument();
    expect(
      screen.getByRole('heading', { name: 'Harassment · reported by Jo' }),
    ).toBeInTheDocument();

    await user.click(screen.getByText(/Conversation at the time of the report/));
    expect(screen.getByText('send pics')).toBeVisible();
    expect(screen.getByText('Unsent before the report')).toBeVisible();
    expect(await axeViolations(container)).toEqual([]);
  });

  it('suspends for the hours given', async () => {
    serveMember();
    const sent = captureActions();
    const user = userEvent.setup();
    renderApp(`/members/${BOB}`);

    await user.selectOptions(await screen.findByLabelText('Action'), 'SUSPEND');
    await user.selectOptions(screen.getByLabelText('Rule'), 'HARASSMENT');
    const hours = screen.getByLabelText('Suspend for (hours)');
    await user.clear(hours);
    await user.type(hours, '48');
    await user.type(screen.getByLabelText('Message to the member (optional)'), 'Be respectful.');
    await user.click(screen.getByRole('button', { name: 'Suspend' }));

    expect(await screen.findByRole('status')).toHaveTextContent('Suspend recorded.');
    expect(sent).toEqual([
      {
        kind: 'SUSPEND',
        policy: 'HARASSMENT',
        memberMessage: 'Be respectful.',
        internalNote: '',
        suspendHours: 48,
        mediaId: null,
      },
    ]);
  });

  it('checks the suspension length before sending anything', async () => {
    serveMember();
    const sent = captureActions();
    const user = userEvent.setup();
    renderApp(`/members/${BOB}`);

    await user.selectOptions(await screen.findByLabelText('Action'), 'SUSPEND');
    await user.clear(screen.getByLabelText('Suspend for (hours)'));
    await user.click(screen.getByRole('button', { name: 'Suspend' }));

    expect(await screen.findByText(/Enter a whole number of hours/)).toBeInTheDocument();
    expect(screen.getByLabelText('Suspend for (hours)')).toHaveAttribute('aria-invalid', 'true');
    expect(sent).toEqual([]);
  });

  it('removes the chosen photo', async () => {
    serveMember();
    const sent = captureActions();
    const user = userEvent.setup();
    renderApp(`/members/${BOB}`);

    await user.selectOptions(await screen.findByLabelText('Action'), 'REMOVE_PHOTO');
    await user.selectOptions(screen.getByLabelText('Rule'), 'EXPLICIT_PHOTO');
    await user.click(screen.getByRole('radio', { name: 'Profile, 1 of 1' }));
    await user.click(screen.getByRole('button', { name: 'Remove photo' }));

    await waitFor(() => {
      expect(sent).toEqual([expect.objectContaining({ kind: 'REMOVE_PHOTO', mediaId: PHOTO })]);
    });
  });

  it('dismissing switches the rule to no violation', async () => {
    serveMember();
    const sent = captureActions();
    const user = userEvent.setup();
    renderApp(`/members/${BOB}`);

    await user.selectOptions(await screen.findByLabelText('Action'), 'DISMISS');
    await user.click(screen.getByRole('button', { name: 'Dismiss reports' }));

    await waitFor(() => {
      expect(sent).toEqual([expect.objectContaining({ kind: 'DISMISS', policy: 'NO_VIOLATION' })]);
    });
  });

  it('only offers actions that fit a banned member', async () => {
    serveMember(member({ status: 'BANNED' }));
    renderApp(`/members/${BOB}`);

    const options = (await screen.findAllByRole('option')).map((o) => o.getAttribute('value'));

    expect(options).toContain('REINSTATE');
    expect(options).not.toContain('BAN');
    expect(options).not.toContain('SUSPEND');
  });

  it("shows the API's reason when an action is refused", async () => {
    serveMember();
    server.use(
      http.post(`${MEMBER_URL}/actions`, () =>
        HttpResponse.json(
          { type: 'urn:orbit:problem:invalid-action', detail: 'The member is already banned.' },
          { status: 422, headers: { 'Content-Type': 'application/problem+json' } },
        ),
      ),
    );
    const user = userEvent.setup();
    renderApp(`/members/${BOB}`);

    await user.selectOptions(await screen.findByLabelText('Action'), 'BAN');
    await user.click(screen.getByRole('button', { name: 'Ban' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('The member is already banned.');
  });

  it('starts a review of open reports', async () => {
    serveMember();
    let claimed = false;
    server.use(
      http.post(`${API}/admin/cases/${BOB}/claim`, () => {
        claimed = true;
        return new HttpResponse(null, { status: 204 });
      }),
    );
    const user = userEvent.setup();
    renderApp(`/members/${BOB}`);

    await user.click(await screen.findByRole('button', { name: /Start review \(1 open report\)/ }));

    await waitFor(() => {
      expect(claimed).toBe(true);
    });
  });
});

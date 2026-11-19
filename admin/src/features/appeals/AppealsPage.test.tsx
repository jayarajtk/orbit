import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { http, HttpResponse } from 'msw';

import { APPEAL, openAppeal } from '@/test/fixtures';
import { API, axeViolations, renderApp } from '@/test/render';
import { server } from '@/test/server';

describe('Appeals', () => {
  it('reverses an appeal and clears it from the list', async () => {
    let open = [openAppeal];
    const decisions: unknown[] = [];
    server.use(
      http.get(`${API}/admin/appeals`, () => HttpResponse.json(open)),
      http.post(`${API}/admin/appeals/${APPEAL}/decision`, async ({ request }) => {
        decisions.push(await request.json());
        open = [];
        return HttpResponse.json({ ...openAppeal, status: 'REVERSED', decidedBy: 'sam' });
      }),
    );
    const user = userEvent.setup();
    const { container } = renderApp('/appeals');

    expect(await screen.findByText('It was a joke between friends.')).toBeInTheDocument();
    expect(await axeViolations(container)).toEqual([]);
    await user.click(screen.getByRole('radio', { name: /Reverse/ }));
    await user.type(screen.getByLabelText('Message to the member'), 'Welcome back.');
    await user.click(screen.getByRole('button', { name: 'Record decision' }));

    expect(await screen.findByText('No open appeals.')).toBeInTheDocument();
    expect(decisions).toEqual([{ reverse: true, memberMessage: 'Welcome back.' }]);
  });

  it('needs an outcome and a message', async () => {
    server.use(http.get(`${API}/admin/appeals`, () => HttpResponse.json([openAppeal])));
    const user = userEvent.setup();
    renderApp('/appeals');

    await user.click(await screen.findByRole('button', { name: 'Record decision' }));

    await waitFor(() => {
      expect(screen.getByText('Choose an outcome.')).toBeInTheDocument();
    });
    expect(screen.getByText('Tell the member the outcome.')).toBeInTheDocument();
  });
});

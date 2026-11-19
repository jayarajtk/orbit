import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

import { member } from '@/test/fixtures';

import { ReportList } from './ReportList';
import { reportSchema } from './types';

const STATUS_ID = '66666666-6666-4666-8666-666666666666';

function reportWithStatus(media: unknown) {
  const base = member().reports[0];
  return reportSchema.parse({
    ...base,
    evidence: [
      {
        messageId: STATUS_ID,
        fromSubject: true,
        kind: 'STATUS',
        text: 'Look at me',
        sentAt: '2026-11-18T08:00:00Z',
        media,
      },
    ],
  });
}

describe('Report evidence', () => {
  it('shows a reported status with its photo and caption', async () => {
    const report = reportWithStatus({
      kind: 'PHOTO',
      url: 'https://storage.test/status-full',
      thumbUrl: 'https://storage.test/status-thumb',
    });
    const user = userEvent.setup();
    render(<ReportList reports={[report]} memberName="Bob" />);

    await user.click(screen.getByText(/Conversation at the time of the report/));

    expect(screen.getByRole('img', { name: 'Posted as a status' })).toHaveAttribute(
      'src',
      'https://storage.test/status-thumb',
    );
    expect(screen.getByRole('link')).toHaveAttribute('href', 'https://storage.test/status-full');
    expect(screen.getByText('Look at me')).toBeVisible();
  });

  it('says so when the photo of a reported status is no longer available', async () => {
    const report = reportWithStatus(null);
    const user = userEvent.setup();
    render(<ReportList reports={[report]} memberName="Bob" />);

    await user.click(screen.getByText(/Conversation at the time of the report/));

    expect(screen.getByText('Photo no longer available')).toBeVisible();
    expect(screen.getByText('Look at me')).toBeVisible();
    expect(screen.queryByRole('img')).not.toBeInTheDocument();
  });
});

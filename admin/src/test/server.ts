import { setupServer } from 'msw/node';

/** The API boundary for tests; each test registers the responses it needs. */
export const server = setupServer();

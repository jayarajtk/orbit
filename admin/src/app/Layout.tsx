import { useQueryClient } from '@tanstack/react-query';
import { NavLink, Outlet } from 'react-router';

import { useAuth } from '@/shared/lib/context';

import { SESSION_KEY } from './RequireAuth';

const LINKS = [
  { to: '/', label: 'Queue', end: true },
  { to: '/appeals', label: 'Appeals', end: false },
  { to: '/search', label: 'Find a member', end: false },
  { to: '/audit', label: 'Audit log', end: false },
];

export function Layout() {
  const auth = useAuth();
  const username = useQueryClient().getQueryData<string | null>(SESSION_KEY);
  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <header className="topbar">
        <span className="brand">Orbit moderation</span>
        <nav aria-label="Main">
          <ul>
            {LINKS.map((link) => (
              <li key={link.to}>
                <NavLink to={link.to} end={link.end}>
                  {link.label}
                </NavLink>
              </li>
            ))}
          </ul>
        </nav>
        <span className="who">{username}</span>
        <button type="button" className="secondary" onClick={() => void auth.signOut()}>
          Sign out
        </button>
      </header>
      <main id="main" className="page">
        <Outlet />
      </main>
    </>
  );
}

import { InMemoryWebStorage, UserManager, WebStorageStateStore } from 'oidc-client-ts';

import type { Env } from './env';

/** What the rest of the console needs from sign-in. Swapped for a fake in tests. */
export interface AuthClient {
  /** The current access token, or null when signed out. */
  accessToken(): Promise<string | null>;
  /** The moderator's username, or null when signed out. */
  username(): Promise<string | null>;
  /** Sends the browser to the identity provider; returns to {@code returnTo} afterwards. */
  signIn(returnTo: string): Promise<void>;
  /** Completes a sign-in on the callback page; returns where to go next. */
  completeSignIn(): Promise<string>;
  signOut(): Promise<void>;
}

const RETURN_TO_DEFAULT = '/';

/**
 * Sign-in with Keycloak through the authorization code flow with PKCE (ADR-0007).
 *
 * Tokens live in memory only (`InMemoryWebStorage`), never in web storage, per the React
 * standards. A reload therefore signs in again, which the Keycloak session makes immediate.
 * Only the one-time PKCE state for an in-flight redirect is kept in sessionStorage, because it
 * must survive the round trip to Keycloak; it holds no token.
 */
export function oidcAuthClient(env: Env, origin: string = window.location.origin): AuthClient {
  const manager = new UserManager({
    authority: env.VITE_OIDC_AUTHORITY,
    client_id: env.VITE_OIDC_CLIENT_ID,
    redirect_uri: `${origin}/callback`,
    post_logout_redirect_uri: `${origin}/`,
    response_type: 'code',
    scope: 'openid profile',
    userStore: new WebStorageStateStore({ store: new InMemoryWebStorage() }),
    stateStore: new WebStorageStateStore({ store: window.sessionStorage }),
    automaticSilentRenew: true,
  });

  async function currentUser() {
    const user = await manager.getUser();
    return user && !user.expired ? user : null;
  }

  return {
    async accessToken() {
      return (await currentUser())?.access_token ?? null;
    },
    async username() {
      const user = await currentUser();
      return user ? (user.profile.preferred_username ?? user.profile.sub) : null;
    },
    signIn(returnTo) {
      return manager.signinRedirect({ state: { returnTo } });
    },
    async completeSignIn() {
      const user = await manager.signinRedirectCallback();
      const state = user.state as { returnTo?: unknown } | undefined;
      return typeof state?.returnTo === 'string' && state.returnTo.startsWith('/')
        ? state.returnTo
        : RETURN_TO_DEFAULT;
    },
    async signOut() {
      const user = await currentUser();
      await manager.removeUser();
      await manager.signoutRedirect(user ? { id_token_hint: user.id_token } : undefined);
    },
  };
}

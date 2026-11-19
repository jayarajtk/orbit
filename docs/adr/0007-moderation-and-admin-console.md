# ADR-0007: Moderation and the admin console

- **Status:** Accepted
- **Date:** 2026-11-18
- **Deciders:** Product owner, tech lead

## Context

Members can already block and report (design doc §7.5), and accounts have `SUSPENDED` and `BANNED` states (§8.1), but nobody can review a report or act on one. App stores require working moderation for dating apps (design doc R1), so moderation comes before calls (Phase E in `docs/gap-analysis.md`). The product owner chose a React single-page app for the console and asked for member appeals in this phase.

## Decision

1. **Role.** Moderators are Keycloak users with the realm role `moderator`. The API turns the token's `realm_access.roles` into Spring authorities, and every `/api/v1/admin/**` request requires `ROLE_MODERATOR`. Checks are on the server only; the console hides nothing that the API doesn't also refuse. A moderator does not need an Orbit member account.
2. **Module.** A new `moderation` module owns cases, actions, appeals, evidence and the audit log. It depends on `identity`, `profile`, `media`, `safety` and `chat` through their public APIs. Nothing depends on it, so there are no cycles. `safety` keeps filing reports and exposes the queries and status changes moderation needs.
3. **Cases.** The queue groups open reports by the reported member. Acting on a member resolves all of that member's open reports. Reports of minors (`UNDERAGE`) and threats (`THREAT`) sort first, then the oldest report.
4. **Evidence.** When a report is filed, the last 20 messages between the reporter and the reported member are copied into the case. The reported member can unsend messages, so without the copy the evidence could disappear before review. Only the conversation the reporter was part of is copied, and only moderators can read it. Each time a moderator opens it, that read is written to the audit log.
5. **Actions.** Warn, suspend (for a set number of hours), ban, remove a profile photo, dismiss, and reinstate.
   - Each action records a policy reason, a message the member sees, and an internal note only moderators see.
   - Suspending or banning changes the account status. The member is then refused everywhere, their live chat connections are closed (on every server, through Redis), and they drop out of the grid. Suspensions lift automatically.
6. **Appeals.**
   - A suspended or banned member sees why, and can appeal that action once (up to 1,000 characters).
   - Appeals form their own queue.
   - Upholding an appeal keeps the action. Reversing it reinstates the account and records a reinstate action.
   - These member endpoints work for restricted accounts. Every other endpoint returns `403 urn:orbit:problem:account-restricted`, so the app knows to show the restriction screen instead of onboarding.
7. **Audit log.** Append-only. Every admin change, and every read of evidence or of a member's record, writes who did it, what they did, to whom, and when. The admin API cannot edit or delete audit entries.
8. **Console.** It lives in `admin/` and is built with Vite, React 19, TypeScript in strict mode, TanStack Query, React Router, React Hook Form with Zod, and `oidc-client-ts`, following `standards/react.md`.
   - It signs in with Keycloak's authorization code flow with PKCE, as a separate public client `orbit-admin`.
   - Its access token is held in memory only, never in web storage. Reloading the page signs in again silently through the Keycloak session.
   - Locally, Vite proxies `/api` to the API, so the API needs no CORS settings. In production the console is served from the same origin as the API, under `/admin`, by the ingress.

## Consequences

- Moderators sign in again after every page reload, which is quick while their Keycloak session is alive. An HttpOnly-cookie backend-for-frontend would remove that step, but it would add a server-side session tier. We can revisit if it becomes a burden.
- A banned member's Keycloak sign-in still works. The API refuses them everywhere except the standing and appeal endpoints. Disabling the identity itself (and removing their data under the retention policy) is a follow-up.
- Evidence copies are personal data. They are kept while the case is open and for 180 days after it is resolved. Deleting them on schedule is a follow-up, along with the other retention jobs.
- No automatic classifier yet: the "auto-actioned" path in design doc §8.3 waits for the media-scanning vendor.

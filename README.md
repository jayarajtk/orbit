# Orbit (working title)

Orbit is a fast, battery-light, ad-free, privacy-first location-based social and dating app for iOS and Android. It is an original, clean-room design.

## Documents

| Doc | What it covers |
|---|---|
| [docs/design/design-doc.md](docs/design/design-doc.md) | Goals, features, architecture, data model, sequence and state diagrams, API, security, testing |
| [docs/design/wireframes.md](docs/design/wireframes.md) | Navigation map and 17 low-fidelity screen wireframes |
| [docs/plan.md](docs/plan.md) | Phased roadmap (Gantt), milestones, first sprint |
| [docs/adr/](docs/adr/) | Architecture decisions: Spring Boot backend, Flutter client, location privacy, chat transport |

## Stack at a glance

- **Mobile:** Flutter (Riverpod, go_router, dio, drift)
- **Backend:** Spring Boot modular monolith on Java 21, using Spring Modulith
- **Data:** PostgreSQL + PostGIS, Redis, S3-compatible object storage + CDN
- **Realtime:** WebSocket while the app is open, FCM/APNs push while it is in the background

## Repository layout

| Folder | Contents |
|---|---|
| [backend/](backend/) | Spring Boot 4.1 modular monolith (Java 21, Gradle wrapper). Modules: identity, profile, discovery, chat, media, safety, notification, billing, shared. |
| [mobile/](mobile/) | Flutter app for iOS and Android (Riverpod, go_router, gen-l10n). |
| [admin/](admin/) | Moderation console: Vite + React 19 single-page app (TypeScript strict, TanStack Query), see [ADR-0007](docs/adr/0007-moderation-and-admin-console.md). |
| [docs/](docs/) | Design doc, wireframes, plan, ADRs. |
| [.github/workflows/ci.yml](.github/workflows/ci.yml) | CI for both apps. |

## Running locally

Prerequisites: JDK 21, Docker (for Testcontainers), Flutter 3.41, and Node.js 22 (for the console).

**Backend.** Build and run every test against real PostGIS and Redis containers:

```bash
cd backend && ./gradlew build
```

Run the API locally on port 8080. No setup is needed: it starts throwaway PostGIS, Redis and **Keycloak** containers. Keycloak is a local OIDC issuer on port 8180, with realm `orbit`, public clients `orbit-mobile` and `orbit-admin`, test users `dev-user` and `dev-user-2`, and a moderator, `dev-moderator` (passwords are in `backend/src/test/resources/keycloak/orbit-realm.json`). Media goes to a throwaway S3-compatible store (Adobe S3Mock) on a random local port; upload and download links point at it, so the iOS Simulator can reach them. It also seeds **24 fictional members** around San Francisco so the grid has people in it. The seeded members read and answer chat messages after a couple of seconds (typing indicator, read receipt, then a canned reply), so live chat can be tried with one device. Three fictional reports between seeded members are filed at start-up, so the moderation queue has cases in it. Everything resets when it stops:

```bash
cd backend && ./gradlew bootTestRun
```

Get a token for `dev-user` and call the API:

```bash
TOKEN=$(backend/scripts/dev-token.sh) && curl -H "Authorization: Bearer $TOKEN" localhost:8080/api/v1/me/profile
```

The local realm lives in `backend/src/test/resources/keycloak/orbit-realm.json`. It's for development only: the test password is a fixture, and the password grant used by `dev-token.sh` is enabled only for curl testing. The mobile app will use Authorization Code + PKCE.

Deployed environments supply `SPRING_DATASOURCE_*`, `SPRING_DATA_REDIS_URL` and `SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_*` as environment variables. See `backend/src/main/resources/application.yml`.

**Moderation console.** With the API running, start the console on port 5174 and sign in as `dev-moderator`. Vite proxies `/api` to the API on 8080, so no CORS setup is needed.

```bash
cd admin && npm ci && npm run dev
```

Check it the way CI would:

```bash
cd admin && npm run lint && npm run typecheck && npm test && npm run build
```

**Mobile.** The app has two modes:

- **`config/dev.json`** talks to the local API above. You sign in on the real Keycloak page with `dev-user` (the password is in the realm file).
- **`config/demo.json`** runs on built-in fake data with no server. The tests use this mode.

```bash
cd mobile && flutter test
```

Put the iOS Simulator near the seeded members, then run against the local API:

```bash
xcrun simctl location booted set 37.7749,-122.4194
```

```bash
cd mobile && flutter run --dart-define-from-file=config/dev.json
```

On the Android emulator, first forward the API and Keycloak ports so `localhost` works:

```bash
adb reverse tcp:8080 tcp:8080 && adb reverse tcp:8180 tcp:8180
```

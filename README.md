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
| [docs/](docs/) | Design doc, wireframes, plan, ADRs. |
| [.github/workflows/ci.yml](.github/workflows/ci.yml) | CI for both apps. |

## Running locally

Prerequisites: JDK 21, Docker (for Testcontainers), and Flutter 3.41.

**Backend.** Build and run every test against real PostGIS and Redis containers:

```bash
cd backend && ./gradlew build
```

Run the API locally on port 8080. No setup is needed: it starts throwaway PostGIS, Redis and **Keycloak** containers. Keycloak is a local OIDC issuer on port 8180, with realm `orbit`, public client `orbit-mobile` and test user `dev-user`:

```bash
cd backend && ./gradlew bootTestRun
```

Get a token for `dev-user` and call the API:

```bash
TOKEN=$(backend/scripts/dev-token.sh) && curl -H "Authorization: Bearer $TOKEN" localhost:8080/api/v1/me/profile
```

The local realm lives in `backend/src/test/resources/keycloak/orbit-realm.json`. It's for development only: the test password is a fixture, and the password grant used by `dev-token.sh` is enabled only for curl testing. The mobile app will use Authorization Code + PKCE.

Deployed environments supply `SPRING_DATASOURCE_*`, `SPRING_DATA_REDIS_URL` and `SPRING_SECURITY_OAUTH2_RESOURCESERVER_JWT_*` as environment variables. See `backend/src/main/resources/application.yml`.

**Mobile.**

```bash
cd mobile && flutter test
```

```bash
cd mobile && flutter run --dart-define-from-file=config/dev.json
```

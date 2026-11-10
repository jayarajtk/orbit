# Orbit — Delivery Plan

Status: Draft v0.1 · 2026-11-09. This plan assumes a small team: 2 backend, 2 Flutter, 1 design, with QA shared. Dates are relative to a kickoff, week 0.

## Phases

```mermaid
gantt
    title Orbit v1 roadmap (weeks from kickoff)
    dateFormat  YYYY-MM-DD
    axisFormat  W%W
    section Phase 0 · Foundations
    Repo, CI, envs, IaC skeleton          :p0a, 2026-11-16, 2w
    Identity provider decision (ADR-0005) :p0b, 2026-11-16, 1w
    Hi-fi design system + key screens     :p0c, 2026-11-16, 3w
    section Phase 1 · MVP core
    Accounts + age gate + profile          :p1a, after p0a, 2w
    Location + discovery grid              :p1b, after p1a, 2w
    Media upload + scanning pipeline       :p1c, after p1a, 2w
    Chat (WS, persistence, push)           :p1d, after p1b, 3w
    Blocks + reports + admin console v0    :p1e, after p1b, 2w
    section Phase 2 · Complete v1
    Albums + sharing + view-once           :p2a, after p1d, 2w
    Filters, favorites, waves              :p2b, after p1d, 1w
    Safety centre, discreet icon, panic    :p2c, after p1e, 2w
    Orbit+ billing + entitlements          :p2d, after p2b, 2w
    Data export + deletion                 :p2e, after p1e, 1w
    section Phase 3 · Hardening & launch
    Load, battery, perf tuning             :p3a, after p2d, 2w
    Security pen test + DPIA               :p3b, after p2d, 2w
    Closed beta (one city)                 :p3c, after p3a, 3w
    Store submission + launch              :milestone, p3d, after p3c, 0d
```

## Milestones and exit criteria

| Milestone | Exit criteria |
|---|---|
| **M0 Foundations** | CI green on an empty Spring Boot and Flutter skeleton. Staging environment up. Design system ready in Figma. ADR-0005 accepted. |
| **M1 MVP core** | A tester can sign up, set up a profile, see a real grid, chat with another tester in real time, and block and report. Grid p95 under 150 ms in staging with 100k seeded users. |
| **M2 Feature-complete v1** | Every feature in design doc §2 works end to end on both platforms. |
| **M3 Launch-ready** | Performance and battery targets in design doc §1 met on reference devices. Pen test findings fixed. DPIA signed off. Beta crash-free rate of at least 99.5%. |

## First sprint backlog (Phase 0 → Phase 1 start)

1. `chore:` monorepo layout: `backend/` (Gradle wrapper, Spring Boot, Spring Modulith), `mobile/` (Flutter with dev, staging and prod flavors), `infra/`, `docs/`.
2. `chore:` CI pipeline: Spotless, Checkstyle, Error Prone, tests with Testcontainers (PostGIS, Redis), `dart format`, `very_good_analysis`, `flutter test`, and OWASP dependency scanning.
3. `feat(identity):` OIDC resource server config, `POST /api/v1/accounts` with age gate, ProblemDetail error handler.
4. `feat(profile):` profile entity, Flyway V1 migration, `GET/PUT /me/profile`.
5. `feat(mobile):` app shell with go_router, theme tokens, onboarding screens W1–W5 with mocked API.
6. `test:` ArchUnit and Modulith boundary tests from day one.

## Proposed repository layout

```
orbit/
├── backend/            # Spring Boot modular monolith (orbit-api + orbit-worker profiles)
├── mobile/             # Flutter app
├── admin/              # Moderator console (later; Next.js or Spring + server-rendered pages)
├── infra/              # Terraform / Helm
└── docs/
    ├── adr/
    ├── design/
    └── plan.md
```

## Decisions needed from the product owner

1. The final app name. "Orbit" is a placeholder.
2. Managed identity provider or self-hosted Keycloak (ADR-0005).
3. Orbit+ price points and which features are paid.
4. The beta launch city.

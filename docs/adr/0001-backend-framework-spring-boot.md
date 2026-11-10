# ADR-0001: Backend framework — Spring Boot over FastAPI

- **Status:** Accepted
- **Date:** 2026-11-09
- **Deciders:** Product owner, tech lead

## Context

Orbit (working title) is a location-based social and dating app for iOS and Android. The backend must serve:

- A nearby-profiles grid backed by geospatial queries (PostGIS).
- Real-time 1:1 chat over long-lived WebSocket connections, with push fallback.
- Media uploads (photos, private albums) through object storage.
- Safety and moderation workflows (reports, blocks, bans).
- A security bar of OWASP ASVS Level 2, because the app handles sensitive personal data (sexual orientation, location).

The team knows Spring Boot well. FastAPI is attractive for its simplicity. We scored both options on the needs above and chose the one with more pros.

## Options scored

| # | Criterion | Spring Boot (Java 21+) | FastAPI (Python 3.12+) |
|---|---|---|---|
| 1 | Team expertise | ✅ Strong — fewer mistakes, faster reviews | ❌ Weaker |
| 2 | Many concurrent WebSockets | ✅ Virtual threads give blocking-style code at high concurrency | ✅ Native async/await |
| 3 | Security framework | ✅ Spring Security (OIDC resource server, method-level authz) is mature | ⚠️ Assembled from smaller libraries |
| 4 | Geospatial + migrations | ✅ Hibernate Spatial, Flyway, jOOQ for complex SQL | ✅ GeoAlchemy2, Alembic |
| 5 | Enforcing module boundaries | ✅ Spring Modulith + ArchUnit check boundaries at build time | ⚠️ Convention only |
| 6 | Resilience and observability | ✅ Resilience4j, Micrometer, OpenTelemetry starter are first class | ⚠️ Available, more wiring |
| 7 | Static typing end to end | ✅ Compiler-enforced | ⚠️ mypy/pyright, opt-in strictness |
| 8 | House standards coverage | ✅ `java.md` + `springboot.md` are the most complete | ✅ `python.md` |
| 9 | Less boilerplate, faster MVP | ❌ More ceremony | ✅ Very concise |
| 10 | Memory and cold start | ❌ Higher RAM per pod, slower start | ✅ Lighter |
| 11 | ML for moderation in-process | ❌ Weaker ecosystem | ✅ Python ML ecosystem |

**Tally:** Spring Boot has 8 clear pros. FastAPI has 6, with 3 of them partial.

## Decision

Use **Spring Boot** (current supported line: 3.5.x, or 4.x if it is stable when we scaffold) on **Java 21 LTS** (25 LTS if the toolchain supports it at scaffold time). Build it as a **modular monolith** with Spring Modulith: one deployable artifact, with internal modules for `identity`, `profile`, `discovery`, `chat`, `media`, `safety`, `notification` and `billing`.

## Consequences

- **Positive:** the team works in its strongest stack. We get mature security, compile-time module boundaries, and virtual threads, which keep chat code simple at high connection counts.
- **Negative:** pods use more memory and start more slowly. We mitigate this with right-sized containers, class data sharing (CDS), and keeping replicas warm. We are not targeting scale-to-zero.
- **Escape hatch:** ML-heavy moderation, such as image nudity or abuse classification, can run as a separate Python worker behind a queue. The core app does not need Python for that.
- **Revisit when:** a single module, such as chat, needs to scale independently. Spring Modulith boundaries make it practical to extract that module into its own service.

# ADR-0002: Mobile client — single Flutter codebase for iOS and Android

- **Status:** Accepted
- **Date:** 2026-11-09

## Context

We need iOS and Android at launch with one small team. The main complaints about incumbent apps are slowness, battery drain and ads. That makes rendering performance and control over background work the main requirements.

## Decision

Build one **Flutter** app with **Riverpod** (code generation) for state, **go_router** for navigation, **dio** for HTTP, **drift** for the local cache, **freezed** and **json_serializable** for models, and **flutter_secure_storage** for tokens. Folders are organized by feature, as `standards/flutter.md` requires.

**Options considered:** native Swift plus Kotlin would be fastest at runtime but would need two codebases and double the work. React Native lags Flutter on grid-scroll smoothness and is outside the house standards.

## Consequences

- One codebase and one design system. Flutter compiles ahead of time to native code and renders with Impeller, so the image-heavy grid can scroll smoothly.
- Battery-sensitive code (location, push) goes through well-maintained plugins (`geolocator`, `firebase_messaging`) that wrap the platform's low-power APIs. Platform channels are kept to a minimum.
- **Hard rule:** no advertising SDKs, and no third-party analytics SDK that runs background work. ADR-0003 covers the battery budget.

# Orbit — Gap Analysis and Delivery Plan (v1 + media, calls and admin)

Status: Draft · 2026-11-17. This compares everything envisioned — design doc §2, plus the new asks for photo, video and audio sharing, voice and video calls, and admin tools — against what is built today.

## 1. Where we are

| Layer | Built | Not built |
|---|---|---|
| **Backend** | Security (OIDC resource server, default-deny), RFC 9457 errors, Flyway V1–V3, `identity` module (`POST /accounts` with the 18+ check, `GET /me`), local Keycloak, 30 tests | 7 of 8 modules are empty: profile, discovery, chat, media, safety, notification, billing. No admin API. No object storage. |
| **Mobile** | All 17 wireframe screens, working on **in-memory fake data** (24 dummy profiles, seeded chats, canned replies), 46 tests | No API client, no real sign-in, no persistence (everything resets on restart), no device permissions (camera, mic, photos, location), no push |
| **Admin** | — | Nothing: no console, no moderation API, no admin role |

**In short:** the app shows every v1 interaction, but the only one backed by the server is creating an account. "Everything works" means building the server side of every feature, connecting the app to it, and adding the three new capabilities.

## 2. Feature-by-feature gap

Legend: ✅ done · 🟡 UI only on fake data · ❌ missing

| Feature | App UI | Backend | What is needed |
|---|---|---|---|
| Sign-in (Apple, Google, phone) | 🟡 stub | ✅ token validation | Login with `flutter_appauth` (PKCE), tokens in Keychain/Keystore, refresh, ADR-0005 for the identity provider |
| Age gate and account | ✅ | ✅ | Connect the app to `POST /accounts` and `GET /me` |
| Profile (view and edit) | 🟡 | ❌ | `profile` module + API, connect the app |
| Profile photos (up to 6) | ❌ placeholders | ❌ | Media pipeline (below) + photo picker and editor |
| Location + nearby grid | 🟡 dummy distances | ❌ | `discovery`: PostGIS, H3 snapping, distance buckets, rate and velocity limits (ADR-0003); `geolocator` in the app |
| Filters, favorites, waves | 🟡 | ❌ | Endpoints + connect the app |
| Block / report | 🟡 | ❌ | `safety` module: two-way blocks applied in every query, reports with an evidence snapshot |
| Chat: text, read receipts, typing, unsend | 🟡 canned replies | ❌ | `chat` module: WebSocket gateway, Redis fan-out between servers, persistence, idempotent sends, catch-up sync (ADR-0004) |
| Timed location share | 🟡 card only | ❌ | Live-location message with expiry; map preview |
| **Photo sharing in chat** | ❌ button disabled | ❌ | Media pipeline + `image_picker` + full-screen viewer |
| **Video sharing in chat** | ❌ | ❌ | Media pipeline (larger limits, thumbnail), `video_player` |
| **Voice notes** | ❌ | ❌ | `record` (capture) + `just_audio` (playback), waveform UI |
| Private albums, share and revoke, view-once | 🟡 | ❌ | Album API, signed short-lived URLs, server-enforced view-once |
| **Voice calls** | ❌ | ❌ | WebRTC (`flutter_webrtc`), signalling over the chat WebSocket, TURN server (coturn), CallKit / ConnectionService, call screen. **Needs ADR-0006**: the design doc listed calls as v2 |
| **Video calls** | ❌ | ❌ | Same as voice, plus camera and camera switching. Needs physical devices to test properly: the iOS Simulator has no camera |
| Inbox, unread, mute, delete | 🟡 | ❌ | Comes with `chat` |
| Push notifications | ❌ | ❌ | `notification` module + FCM/APNs; payloads carry IDs only |
| Safety centre content | ✅ | — | Done (static content) |
| Discreet icon, shake to hide, app lock, screenshot protection | 🟡 toggles only | — | Platform work: alternate app icons, `sensors_plus`, `local_auth`, `FLAG_SECURE`, iOS screenshot notification |
| Settings, export, deletion | 🟡 | ❌ | Settings API, data-export job, deletion with a 14-day grace period then hard delete |
| Orbit+ | 🟡 local toggle | ❌ | `billing`: StoreKit / Play Billing, receipt checks, server-side entitlements |
| **Admin console** | ❌ | ❌ | Moderation queue, user lookup, actions (warn, suspend, ban, remove photo), appeals, audit log, admin role in Keycloak, content-scan results |
| Image safety scanning | ❌ | ❌ | Hash matching against known CSAM databases + nudity classifier (external vendor), routing to private-only or reject |

## 3. Calls need a decision first (ADR-0006)

Calls were a **non-goal for v1** in the design doc. Adding them is reasonable, but it affects safety, privacy and cost:

- **IP privacy:** a plain peer-to-peer call exposes each person's IP address, which reveals their approximate location — the very thing ADR-0003 protects. **Proposal:** relay all call traffic through our own TURN server (`iceTransportPolicy: relay`). This costs bandwidth, but nobody's IP is exposed to the other person.
- **Consent:** only allow calls between members who have already exchanged messages, require one tap to accept, and end any call immediately when either person blocks the other.
- **No recording:** the server never records calls. The server keeps call metadata only (who, when, how long), for safety reports.
- **Infrastructure:** coturn with TLS on 443 so it works on restrictive networks, and time-limited TURN credentials issued per call by the API.

## 4. Proposed phases

Each phase ends with something working end to end: API, app, tests, and a manual run on the simulator.

| Phase | Scope | Main new pieces | Size* |
|---|---|---|---|
| **A. Real core** | Real sign-in in the app; profile, discovery and safety modules; API client; replace fake profiles with the server | `dio`, `flutter_appauth`, `flutter_secure_storage`, `geolocator`; Flyway V4–V7 | L |
| **B. Real chat** | WebSocket chat, Redis fan-out, persistence, catch-up sync, inbox, receipts, typing, unsend, waves, push | `web_socket_channel`, `drift`, `firebase_messaging`; notification module | L |
| **C. Media** | Object storage (MinIO locally, S3 in the cloud), presigned upload, thumbnails, profile photos, photo / video / voice-note messages, real albums, view-once, scanning hook | `image_picker`, `video_player`, `record`, `just_audio`; AWS SDK S3 client; S3-compatible test container (S3Mock) | L |
| **D. Calls** | ADR-0006, signalling, TURN, 1:1 voice and video, CallKit / ConnectionService, call history | `flutter_webrtc`, `flutter_callkit_incoming` (or native), coturn container | XL |
| **E. Admin** | Admin role, moderation API (queue, actions, audit log), web console, appeals | Vite + React SPA in `admin/` ([ADR-0007](adr/0007-moderation-and-admin-console.md)) | L |
| **F. Safety and account polish** | Discreet icon, app lock, shake to hide, screenshot protection, data export, deletion job | `local_auth`, `sensors_plus` | M |
| **G. Billing** | Orbit+ via StoreKit / Play Billing and server-side entitlements | `in_app_purchase` | M |

\*Size is relative: each L is roughly a few focused sessions; D is the largest and riskiest.

**Agreed order (2026-11-17):** A → B → C → E → D → F → G. Chat and media are the heart of the product, and media must exist before calls. Admin comes before calls because moderation has to work before launch, while calls are new scope. Calls follow the now-accepted [ADR-0006](adr/0006-voice-and-video-calls.md), which relays all call traffic so no IP addresses are exposed.

## 4a. Progress

| Phase | Status | Notes |
|---|---|---|
| **A. Real core** | ✅ Done (2026-11-17) | Real sign-in (PKCE, Keycloak locally) · account and 18+ check · profile · snapped location (H3 res 8 + per-member offset, 1 update per minute, impossible-speed check) · nearby grid with filters and cursor · member profiles · favorites · two-way blocks · reports · blocked list. App connected to all of it, with demo mode kept for tests. Verified on the iPhone simulator against the local API with 24 seeded members. Backend: 57 tests. Mobile: 62 tests. |
| **B. Real chat** | ✅ Done (2026-11-18) | Server-stored 1:1 chat with per-conversation sequence numbers, idempotent sends (`clientMsgId`), history and catch-up paging, inbox with unread counts, read receipts (optional), typing, mute, delete-for-me, 10-minute unsend, block checks on every write. WebSocket `/ws/v1` with Redis fan-out and presence; REST fallback. Push to offline, unmuted members only, with no message content (logging sender until FCM/APNs keys exist). App: live chat with pending/sent/read/failed states, retry, reconnect with backoff and catch-up, resend of pending messages, socket only while in the foreground. Local seed members answer messages. Verified on the iPhone simulator against the local API. Backend: 70 tests. Mobile: 82 tests. |
| **C. Media** | ✅ Done (2026-11-18) | `media` module: presigned uploads straight to S3-compatible storage (type and length signed into the link), photos decoded and re-encoded server-side at 2048 px and 480 px (EXIF orientation applied, then all EXIF/GPS dropped), MP4-container check for video and voice, a scanner hook with private-only and reject verdicts (allow-all stand-in until a vendor is chosen), upload rate limit. Up to 6 public profile photos, shown in the grid, on profiles and in chat. Private albums with photos, sharing for 24 h / 7 days / until revoked, view-once shares, revoke, and blocks ending access. Photo, view-once photo, video and voice messages; recipients fetch short-lived links per message, and a view-once photo opens once (the sender sees "Opened"). App: photo editor, attach menu, voice recording, photo/video/voice bubbles, full-screen viewers, server albums with "Shared with you". Verified on the iPhone simulator: profile photo upload and a photo message to a seeded member (stored copies checked for size and missing EXIF/GPS). Backend: 96 tests. Mobile: 101 tests. |
| **E. Admin** | ✅ Done (2026-11-18) | [ADR-0007](adr/0007-moderation-and-admin-console.md). Keycloak realm role `moderator`, required on every `/api/v1/admin/**` call. New `moderation` module: a queue grouped by member (minors and threats first), the last 20 messages between reporter and reported member copied into each report when it's filed (so unsending can't destroy evidence), warn / suspend (hours) / ban / remove photo / dismiss / reinstate, each with a policy reason, a message to the member and an internal note, and an append-only audit log of every action and every read of a member's record. Suspensions lift on their own (a job every minute; already treated as lifted before it runs). A suspension or ban closes the member's live chat connections on every server, hides them from the grid and makes every member endpoint answer `403 account-restricted`. Members see why and appeal once; reversing an appeal reinstates them. Console in `admin/` (Vite, React 19, TypeScript strict, TanStack Query, React Hook Form + Zod, `oidc-client-ts` with PKCE and in-memory tokens): queue, member record with evidence, action form, appeals, search, audit log. App: restriction screen with appeal, `account-restricted` handling from any request or the chat socket, and warnings shown once. Verified end to end: console sign-in as `dev-moderator`, suspension of a seeded member, a ban seen at sign-in on the simulator, appeal from the phone, reversal in the console, a live ban moving the open app to the restriction screen within two seconds, reinstatement and the warning dialog. Backend: 118 tests. Mobile: 134 tests. Console: 19 tests. |
| D. Calls | Next | ADR-0006: signalling, TURN, 1:1 voice and video. |

Known follow-ups from Phase E:
- **Identity side of a ban:** the API refuses a banned member everywhere except their standing and appeal, but their Keycloak sign-in still works. Disabling the identity, and purging data under the retention policy, are still to do.
- **Retention:** evidence copies and the audit log are kept indefinitely for now. ADR-0007 sets 180 days after a case closes for evidence; a scheduled deletion job is needed (with the other retention jobs in Phase F).
- **Automatic actions:** design doc §8.3's "auto-actioned" path waits for the media-scanning vendor.
- **Audit noise:** every reload of a member's record writes a `MEMBER_VIEWED` entry, including the automatic refresh after each action. It's accurate but noisy; consider merging repeat views by the same moderator within a few minutes.
- **Console bundle:** the first load is 153 KB gzipped (React, React Router, Zod, OIDC client); the build warns above 500 KB unminified. Fine for an internal tool; `zod/mini` would shrink it if needed.
- **Tooling versions:** `eslint-plugin-jsx-a11y` doesn't support ESLint 10 yet, so the console uses ESLint 9 (marked deprecated upstream), and `typescript-eslint` needs TypeScript below 6.1, so it uses TypeScript 6.0. Upgrade both when the plugins catch up.
- **End-to-end tests:** the console has component tests with MSW and axe checks; Playwright journeys against a running stack are still to add.
- **Report endpoint fix:** `alsoBlock` on `POST /reports` is now optional, as documented. It was a required primitive, so any report that left it out got a 400 (the app always sent it).

Known follow-ups from Phase C:
- **Local S3 stand-in:** MinIO no longer publishes public images, so tests and local runs use Adobe S3Mock (`adobe/s3mock:5.2.3`). It speaks the S3 API, including presigned links, but doesn't check signatures or link expiry. Verify both against real S3 in staging.
- **Scanning vendor:** `AllowAllMediaScanner` logs a warning at startup and allows everything. A real hash-matching and classifier vendor must replace it before launch, along with escalation (account freeze, reporting) when content is rejected.
- **Video:** no server-side transcoding or poster frames yet; videos are stored as uploaded (MP4/MOV, 60 s, 50 MB) and shown as a play tile.
- **Cleanup:** abandoned uploads (still `PENDING`) and media no longer referenced anywhere aren't deleted yet; a scheduled job should remove both.
- **Location in uploads (privacy):** ✅ fixed. On iOS, `image_picker` keeps the GPS block in the JPEG it produces from a HEIC photo, even with `requestFullMetadata: false`. The app now strips photo metadata before upload (`mobile/lib/features/media/data/photo_metadata.dart`, called from `ApiMediaRepository.upload` for every photo): EXIF, XMP, IPTC, comments and appended gain-map images are dropped from JPEGs (only the rotation is kept, which the server applies), and text, EXIF and time chunks from PNGs. Pixels are not re-encoded, so it costs a few milliseconds and no quality. A photo that can't be parsed is refused rather than sent unchanged. Checked on the real picker file: GPS, XMP and IPTC gone, and the server's processor still decodes it upright.
- **Location in videos (privacy):** ✅ fixed. Checked on the simulator: the iOS picker hands over the library's original file byte for byte (the system picker shows "Location Is Included" by default), and the server stores videos as uploaded, so a test video's location (`moov/meta` ISO 6709 key and `moov/udta/©xyz`, where iPhone and Android cameras write it) reached storage unchanged. The app now strips it before upload (`mobile/lib/features/media/data/video_metadata.dart`, called from `ApiMediaRepository.upload` for videos and voice notes): every `udta`/`meta` box in the movie and its tracks and any XMP `uuid` box becomes a zero-filled `free` box of the same size, so no offsets move and nothing is re-encoded. Verified end to end: the re-sent video in storage has no location or other metadata and AVFoundation still plays it (same length, frames decode). Not covered: location written as a timed-metadata track inside the media data, which ordinary camera videos don't have; server-side transcoding (already listed) would remove that too.
- **SDK limits:** `record` 7 and `video_player` 2.12+ need Dart 3.12; the app uses `record` 6.2.1 and `video_player` 2.11.1 until Flutter is upgraded.

Known follow-ups from Phase B:
- **Real push delivery:** device registration and the push rules exist, but the sender only logs. It needs your Firebase project (FCM, and APNs keys for iOS) and app-side token registration.
- **Older history:** the app loads the newest 50 messages; the API already pages backwards with `before`, but the app has no scroll-to-load-more yet.
- **Two-person live test:** chat between two simulators (dev-user and dev-user-2) is covered by the backend's two-client WebSocket test, but hasn't been tried by hand yet.

Known follow-ups from Phase A:
- **Grid paging:** the grid loads one page of 60. The API already supports the next-page cursor; the app needs infinite scroll.
- **Orbit+ distance filter:** it's only gated in the app. The server needs an entitlement check (Phase G).
- **Web sign-in:** `flutter_appauth` has no web support, so Chrome can only run in demo mode for now. A web sign-in path is needed before two-person testing in Phase B.
- **Android emulator:** run `adb reverse tcp:8080 tcp:8080` and `adb reverse tcp:8180 tcp:8180` so `localhost` works.

## 5. Testing approach

- **Backend:** each module gets unit, slice and Testcontainers tests (PostGIS, Redis, S3Mock, Keycloak). Chat gets a two-node WebSocket test. Calls get signalling tests; the media path itself is verified manually.
- **Mobile:** unit and widget tests per feature, with the repository layer faked, plus `integration_test` flows against the local backend for sign-in → grid → chat.
- **Two-person testing:** run the iOS Simulator and Chrome (web) side by side as two different Keycloak test users. That covers chat, media and voice calls. Video calls and push notifications need at least one physical device.
- **Limits:** the iOS Simulator has no camera and limited audio, push notifications need a real device, and the TURN server needs a reachable host to test outside the local network.

## 6. New dependencies to approve

Mobile: `dio`, `flutter_appauth`, `flutter_secure_storage`, `geolocator`, `web_socket_channel`, `drift`, `firebase_messaging`, `image_picker`, `video_player`, `record`, `just_audio`, `flutter_webrtc`, a CallKit plugin, `local_auth`, `sensors_plus`, `in_app_purchase`. All are the standard, well-maintained choice for their job. `dio`, `flutter_secure_storage` and `drift` are already named in the house standards.

Backend: AWS SDK for Java v2 (S3); infrastructure: an S3-compatible container (S3Mock, since MinIO images are no longer public) and coturn for local development.

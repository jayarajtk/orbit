# Polish pass, wave limit, photo viewer and 24-hour status — design

Status: approved in chat 2026-11-18 · Spec awaiting review

## 1. Why

A two-member walkthrough on two iOS Simulators (Robin as `dev-user`, Sam as `dev-user-2`) found that the core features work but the app does not feel finished. The member asked for:

- Photos and albums that feel as smooth as Instagram.
- Messaging that feels as light as WhatsApp.
- Grid tiles that look like photos, not boxes.
- An overall look close to a Tesla or iPhone interface, without copying either.
- Waves limited, not unlimited.
- Tapping the Me picture to open it, with editing in that screen (like WhatsApp).
- A 24-hour status, like Instagram or WhatsApp stories.

**Success:** the same two-phone walkthrough passes with none of the bugs below. Waves stop at the limit. A member can post a status that the other member sees, views, and that disappears after 24 hours. The grid, chat and photo screens match the visual rules in section 7.

## 2. Decisions (from the member)

| Topic | Decision |
|---|---|
| Wave limit | **2 waves per sender per recipient**, in a rolling 24-hour window. The server enforces it. A rolling window was chosen over a midnight reset because the server does not know each member's time zone, and a reset at midnight would allow 4 waves within minutes. |
| Status audience | **Anyone who can see the profile.** Blocked members, in either direction, never see it. |
| Status viewers | **The poster sees who viewed** each live status. |
| Look | **Follows the phone's light/dark setting.** Minimal, with frosted-glass bars, edge-to-edge photos and one accent colour. |

**Out of scope:**
- Video statuses.
- Swipe-to-reply.
- Photo cropping.
- Status replies and reactions.
- Archiving statuses after they expire.

## 3. Delivery order

Five parts. Each part is a single-purpose change with its own tests, and is retested on both phones.

1. **Bug fixes** (section 4)
2. **Wave limit** (section 5)
3. **Profile photo viewer and editing** (section 6)
4. **24-hour status** (section 8)
5. **Visual refresh** (section 7)

The visual refresh lands last so that the status rings and the photo viewer are restyled once, not twice. Parts 3 and 4 already follow the section 7 rules, using the current theme tokens.

## 4. Bug fixes (part 1)

Each fix gets a regression test that fails before the fix.

| # | Bug | Fix |
|---|---|---|
| B1 | Message times show UTC: 23:00 CST was shown as "5:00 AM". | `shortTimestamp` formats `time.toLocal()`, and compares local calendar days. The same goes for every other place that formats a message time. |
| B2 | Opening a profile logs a Riverpod "markNeedsBuild called during build" assertion. | Find the provider that invalidates itself while `profileByIdProvider` is first watched. It is a dependency rebuilding during `ProfileScreen.build`. Fix the dependency so that it no longer refreshes synchronously during build. A widget test asserts no Flutter error when opening a profile. |
| B3 | The profile back and action buttons are unreadable over light photos. | Put the buttons on circular translucent backings with a blur, plus a top gradient scrim, which follows the style in section 7. |
| B4 | "Share an album" with no albums is a dead end. | Show an empty state with a "Create album" action. It creates the album and returns to the share screen with that album selected. |
| B5 | Tapping an existing photo in Edit profile appends a new photo. | Tapping a photo opens the photo viewer (part 3). Only the "Add photo" tile opens the picker. |
| B6 | The profile screen keeps showing stale photos after the other member edits them. | Refresh `profileByIdProvider` when the profile screen opens, showing cached data while the refresh runs. |

## 5. Wave limit (part 2)

### 5.1 Backend (`chat` module)

- **Where it's checked:** `ChatService.send`, for `MessageKind.WAVE`. After `requireReachable`, count the WAVE messages from `me` to `to` in the conversation with `created_at > now - 24h`. If the count is 2 or more, throw `WaveLimitReachedException(retryAt)`.
  - `retryAt` is the creation time of the oldest counted wave, plus 24 hours.
  - A retry of an already-stored message, identified by its client message id, still returns the stored message. The idempotency check stays first.
- **Race safety:** two concurrent waves must not both pass the check. Take the existing per-conversation sequence lock (`nextSeq`) before counting, inside the same transaction as the insert.
- **Index:** add `(conversation_id, sender_id, kind, created_at)` in migration `V12`, or extend an existing index if the query plan shows it is already covered.
- **REST:** respond with `429 Too Many Requests`, using `application/problem+json`:
  - type `urn:orbit:problem:wave-limit`
  - a `Retry-After` header
  - a `retryAt` extension member (ISO-8601 UTC)
- **WebSocket:** send an error frame `{type:"error", code:"wave-limit", clientMsgId, retryAt}`.
- **Configuration:** the limit and the window live in `@ConfigurationProperties` (`orbit.chat.wave-limit=2`, `orbit.chat.wave-window=PT24H`). They are validated at startup.

### 5.2 Mobile

- **Gateway errors:** `SendFailed` gains an optional `reason` (`waveLimit`) and `retryAt`. The gateway maps both the REST 429 and the WebSocket error to them.
- **Pending wave:** the chat controller removes the pending wave bubble when it is rejected. It does not show "failed": nothing was sent.
- **Limit state:** a `waveLimitProvider` family, keyed by profile id, tracks the rejection. It is set from the rejection. It is also derived on open, from the wave messages loaded in the last 24 hours, so the button is right before any tap.
- **Profile Wave button:**
  - Normal state: "Wave".
  - At the limit: it is disabled and labelled "Wave again in 6h". The label is computed from `retryAt` and rounded up to the hour, or to minutes when under an hour is left.
  - A snackbar explains the limit if a rejection still arrives.
- **Collapsing in chat:** consecutive waves from the same sender, with nothing else between them, collapse into one bubble: "Sam waved ×2". This is display only.

### 5.3 Tests

**Backend (integration, Testcontainers):**
- The third wave within 24 hours gets a 429 with `retryAt`.
- A wave to a different member is allowed.
- A wave after the window has passed is allowed (with a fake clock).
- A duplicate client message id returns the stored wave.
- The WebSocket gets the error frame.
- Two concurrent sends store at most 2.

**Mobile:**
- The gateway maps 429 and the WebSocket error.
- The controller drops the pending wave.
- The button shows the countdown.
- Waves collapse in the bubble list.

## 6. Profile photo viewer and editing (part 3)

Mobile only. `PUT /api/v1/me/photos` already takes the ordered list of up to 6 media ids. The first id is the main photo.

- **On the Me tab:**
  - Tapping the avatar opens `MyPhotosViewer`, a full-screen route with a hero transition from the avatar.
  - When the member has no photos, the tap opens the picker instead.
  - A small "+" badge on the avatar adds a status (part 4).
- **`MyPhotosViewer`:**
  - **Gestures:** a horizontal pager of the member's photos, with pinch and double-tap zoom (`InteractiveViewer`). Swipe down to dismiss, with the background fading as you drag.
  - **Indicator:** a page indicator, like "2 / 4".
  - **Bottom bar actions:**
    - **Add:** shown only when there are fewer than 6 photos.
    - **Replace:** pick a photo, upload it, and swap the id in place.
    - **Make main:** shown when the photo is not first; moves it to index 0.
    - **Delete:** asks for confirmation first. When it is the last photo, the warning says the profile will show no photo.
  - **Saving:** each action calls the existing `myProfileProvider` photo update. The viewer shows progress for that one photo, and on failure keeps the old state and shows an error.
- **Edit profile:**
  - Photos can be dragged to reorder (`ReorderableWrap`-style, built on `LongPressDraggable` and `DragTarget`; no new dependency).
  - A "Main" label marks the first photo.
  - Tapping a photo opens `MyPhotosViewer` at that index (fixes B5).
- **Upload progress:** the photo uploads through the existing `MediaRepository` with the `PROFILE_PHOTO` purpose. Location and EXIF stripping are already done there.

**Tests:**
- The viewer opens at the tapped index.
- Each action produces the right ordered id list.
- A failed save restores the order.
- The Me avatar opens the viewer when there are photos, and the picker when there are none.

## 7. Visual system (part 5, applied throughout)

### 7.1 Tokens

`app/theme.dart` becomes `buildOrbitTheme(Brightness)`, with `OrbitTokens` as a `ThemeExtension`. `MaterialApp` gets `theme`, `darkTheme` and `themeMode: ThemeMode.system`.

| Token | Dark | Light |
|---|---|---|
| ground (background) | `#000000` | `#F5F5F7` |
| surface (cards, sheets) | `#1C1C1E` | `#FFFFFF` |
| surfaceRaised | `#2C2C2E` | `#E9E9EB` |
| hairline | `#38383A` at 60% | `#C6C6C8` at 60% |
| text | `#FFFFFF` | `#000000` |
| textMuted | `#98989F` | `#6C6C70` |
| accent (one brand colour) | `#FF6A55` | `#E8513D` |
| online | `#30D158` | `#28A745` |
| ring (unseen status) | accent → `#FF9F0A` gradient | same |

Every text and background pair meets WCAG AA (4.5:1 for body text, 3:1 for large text and icons). A unit test checks the main pairs.

### 7.2 Rules

- **Type:** the platform system font, which is SF Pro on iOS. Large titles are 34 pt bold on the main tabs and collapse to 17 pt semibold when scrolled. The body is 17 pt and secondary text is 15 pt.
- **Shape:** corner radius is 20 for sheets, 16 for cards and 12 for tiles. Borders are hairlines only where needed. Depth comes from surface contrast, not outlines.
- **Bars:** the app bars and the bottom navigation are frosted glass (`BackdropFilter` blur 20 over a translucent surface). The bottom navigation shows icons with small labels and an accent tint for the selected tab, with no pill indicator.
- **Motion:**
  - 250 ms ease-out curves.
  - Hero transitions for photos (grid tile → profile, avatar → viewer, chat thumbnail → viewer).
  - All motion respects the system "reduce motion" setting (`MediaQuery.disableAnimations`).

### 7.3 Grid (Nearby)

- **Layout:** 3 columns with 2 px gutters, edge to edge, in portrait tiles (aspect ratio 0.8).
- **Tile:** a full-bleed photo with a bottom gradient scrim. Over the scrim: the name and age (15 pt semibold), the distance (13 pt, muted white), and a green online dot.
- **Status ring:** an unseen status shows a 2.5 px gradient ring inset on the tile; a seen one shows a grey ring.
- **No photo:** instead of a person icon on a flat box, a soft two-stop gradient picked from the member's id, with a large initial.
- **Fresh faces:** a row of circular avatars with status rings.
- **Pull to refresh.**
- **Loading:** skeleton tiles with a shimmer built in-house, not a dependency.

### 7.4 Chat (WhatsApp-light)

- **Bubbles:**
  - The time (`h:mm a`, local) and delivery ticks sit inside the bottom-right corner of each bubble. One tick means sent, two mean delivered, and two accent-coloured ticks mean read.
  - The read receipt setting still applies: when receipts are off, it shows two grey ticks.
  - Consecutive bubbles from the same sender within 2 minutes are grouped: tighter spacing, and only the last one has a tail.
- **Day separators:** "Today", "Yesterday", the weekday, or the date.
- **Composer:**
  - A single "+" button opens a compact sheet with: Photos & videos (multi-select up to 10), Camera, View-once photo, Album, Location and Quick phrase.
  - The text field grows to 5 lines.
  - The trailing button is the mic when the field is empty and turns into send when it isn't, with an animated swap.
- **Photos in chat:**
  - Several photos sent together show as a 2×2 mosaic with "+N".
  - Tapping opens the shared viewer.
- **Header:** the avatar, name and "online" / "typing…" / "last seen" line all open the profile.

### 7.5 Photos (Instagram-smooth)

- **One shared viewer:** a single `PhotoViewer` is used everywhere (chat, albums, profiles, Me). It has:
  - Hero in and out.
  - A pager with pinch and double-tap zoom.
  - Swipe down to dismiss.
  - Preloading of the next and previous image.
- **Caching:** add `cached_network_image` (MIT). Today every view downloads the photo again (`Image.network`, no disk cache). Signed URLs change on every request, so the cache key is the media id plus its size variant, not the URL. Thumbnails load first and the full size fades in on top.
- **Albums:**
  - A 3-column edge-to-edge grid; tapping opens the pager.
  - "Add photos" multi-selects with `image_picker.pickMultiImage`, which is already a dependency, and shows per-photo upload progress tiles.
  - Long press selects photos for deletion.
- **Profile screen:** a full-width photo pager with segment indicators at the top (Instagram-style), and the details in a card that slides up over the photo.

## 8. 24-hour status (part 4)

### 8.1 Backend: new `status` module (Spring Modulith)

The module has `api`, `application`, `domain` and `infrastructure` packages, and depends on `media`, `safety` (blocks), `identity` (restriction) and `profile` (visibility) through their published APIs only.

**Media:** add `MediaPurpose.STATUS_PHOTO`, with the same limits as profile photos. The upload goes through the existing flow, with the same scanning and EXIF/location stripping.

**Migration `V14__create_status.sql`** (the media purpose and evidence hold go in `V13__status_media.sql`):

```sql
create table status (
  id          uuid primary key,
  owner_id    uuid not null references account(id),
  media_id    uuid not null,
  caption     varchar(100),
  created_at  timestamptz not null,
  expires_at  timestamptz not null,
  updated_at  timestamptz not null
);
create index status_owner_live on status (owner_id, expires_at);
create index status_expiry on status (expires_at);

create table status_view (
  status_id  uuid not null references status(id) on delete cascade,
  viewer_id  uuid not null references account(id),
  viewed_at  timestamptz not null,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  primary key (status_id, viewer_id)
);
create index status_view_viewer on status_view (viewer_id);
```

**Rules:**
- A member may have at most **10** live statuses. The 11th gets `409`, with type `urn:orbit:problem:status-limit`.
- A status needs the `STATUS_PHOTO` media to be owned by the poster and fully uploaded.
- **Visibility:** the viewer can see the owner's profile under the same rules as `GET /profiles/{id}`: not blocked in either direction, owner not restricted, and the viewer has a profile. Restricted (suspended or banned) members cannot post, and their statuses are hidden.
- **Recording views:** views are recorded once per viewer. The owner's own views are not recorded.

**Endpoints** (all under `/api/v1`, validated with Bean Validation):

| Method and path | Purpose |
|---|---|
| `POST /me/statuses` `{mediaId, caption?}` | Post. `201` with the status. |
| `GET /me/statuses` | My live statuses, each with `viewCount` and `viewers[{id, name, thumbUrl, viewedAt}]`, newest view first. |
| `DELETE /me/statuses/{id}` | Delete early. `204`. Deletes the media too. |
| `GET /profiles/{id}/statuses` | That member's live statuses, oldest first, each with a short-lived signed `url` and `seen` for me. `404` if the profile isn't visible. |
| `PUT /statuses/{id}/view` | Mark it seen. Idempotent, `204`. |

**Discovery:** grid and profile responses gain `status: NONE | UNSEEN | SEEN` for the viewer. It is computed with a single query per grid page (no N+1): a lateral or `EXISTS` join on live statuses, and a left join on the viewer's views.

**Expiry:** a `StatusReaper` `@Scheduled` job runs every minute.
- It deletes statuses with `expires_at <= now` in batches of 500. Views cascade.
- It publishes `StatusExpired(mediaId)`. A media-module listener calls `MediaApi.purge`. It is published through the existing Modulith event publication registry, so a failed delete is retried. `DELETE /me/statuses/{id}` takes the same path.
- It is idempotent and safe to run on every server.
- Reads also filter on `expires_at > now`, so an expired status is never served, even before the reaper runs.

**Reporting:** `ReportRequest` gains an optional `statusId`, which is carried on the `ReportFiled` event.
- **Recording the evidence:** `EvidenceRecorder` already runs synchronously inside the report transaction and copies the last 20 messages as evidence rows. It also asks `StatusApi` for that status, if it belongs to the reported member and is still live. It inserts one evidence row of kind `STATUS`, holding the caption, the `mediaId` and `createdAt`.
- **Protecting the photo:** the recorder calls a new `MediaApi.holdAsEvidence(mediaId)`.
- **Deleting on expiry:** a new `MediaApi.purge(mediaId)` deletes the stored objects and the media row, but skips media held as evidence. The `StatusExpired` listener calls it, so a reported status photo outlives the 24 hours for moderators only.
- **Moderation console:** the console's evidence view shows `STATUS` rows with the photo.

**Observability:** counters for `orbit.status.posted`, `orbit.status.viewed` and `orbit.status.expired`. The logs carry no captions or media URLs.

### 8.2 Mobile: `features/status`

- **Data:**
  - `StatusRepository` covers the five endpoints.
  - `myStatusesProvider` holds my live statuses.
  - `profileStatusesProvider(id)` holds another member's statuses.
  - The `status` field is added to `Profile`.
- **Posting:**
  - From the "+" badge on the Me avatar, or from a "My status" tile on Me.
  - Pick a photo, then a preview screen with an optional caption (100 characters, counter shown) and a Post button.
  - It uploads with the `STATUS_PHOTO` purpose and shows progress on the Me avatar ring.
- **Rings:** shown on grid tiles, Fresh faces, the profile header and the Me avatar. An unseen status shows the gradient ring and a seen one shows a grey ring. Tapping a ring (or the profile header) opens the viewer. Tapping elsewhere on a grid tile opens the profile as before.
- **`StatusViewer`:**
  - **Layout:** full screen, with segmented progress bars at the top, one per status, 5 s each. The poster's avatar, name and "3h ago" sit in the header, and the caption sits at the bottom over a scrim.
  - **Controls:** tap the right side for next and the left side for previous. Hold to pause. Swipe down to close.
  - **Seen state:** marks each status seen when it is shown, and updates the ring locally at once.
  - **Report:** for another member's status, the "…" menu offers Report, which passes `statusId`.
  - **My own status:** the bottom bar shows "👁 12" and opens a "Viewed by" sheet (avatar, name, time) and a Delete action.
- **Images:** cached and preloaded, the next status included, using the rules in section 7.5.

### 8.3 Tests

**Backend:**
- Posting, and the 10-status limit.
- The media must be owned by the poster and be a status photo.
- Visibility: blocked in either direction, a restricted owner, and an expired status.
- A view is recorded once, and the owner's own views are not recorded.
- The viewers list.
- The grid `status` flag, with a single query asserted by query count.
- The reaper deletes the status and emits `StatusExpired`, with a fake clock.
- A report with `statusId` keeps the evidence.

**Mobile:**
- The repository mapping.
- The viewer: progress, tap navigation, pause on hold, marking seen.
- The ring state on a tile.
- The posting flow and caption limit.
- The viewers sheet.

## 9. Testing and verification

- **Each part runs the full checks:**
  - Mobile: `dart format`, `flutter analyze` and `flutter test`.
  - Backend: `./gradlew spotlessCheck check`, with Testcontainers integration tests.
- **Two-phone retest checklist after each part:**
  - Times are local.
  - The third wave is refused, with a countdown.
  - Me photo viewer: add, replace, make main and delete.
  - Post a status on one phone, see the ring and view it on the other, and the viewer appears in "Viewed by".
  - Delete a status early.
  - Light and dark mode on every main screen.
  - Grid, chat and album flows.
- **Expiry:** checked by running the reaper against a status whose `expires_at` was moved back. The server has no time-travel hook in production code; tests use a fake clock.

## 10. Risks

- **Scope:** five parts touch most screens. Mitigation: land and retest them in order; each is reviewable on its own (aiming for under about 400 changed lines per part, splitting a part further if needed).
- **Light mode:** it exposes hard-coded colours. Mitigation: find them with a search for `Color(0x` outside `theme.dart`, and add a golden test per main screen in both modes.
- **Cache and privacy:** cached images stay on the device after a block or unmatch. Mitigation: clear the image cache on sign-out, and evict a member's media when you block them. View-once photos are never cached.
- **Status visibility:** this widens what non-contacts see. That is intentional and matches the member's decision; blocked members are excluded on the server.

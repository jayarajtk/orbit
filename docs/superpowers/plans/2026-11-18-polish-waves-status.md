# Polish pass, wave limit, photo viewer and 24-hour status: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the six bugs found in the two-phone walkthrough. Then:
- Limit waves to 2 per sender per recipient in any rolling 24 hours.
- Add a Me photo viewer with editing.
- Add a 24-hour photo status with viewers.
- Restyle the app to a minimal look that follows the phone's light/dark setting.

**Architecture:**
- The work lands as five parts, in spec order: bugs, waves, photo viewer, status, visual refresh.
- **Backend:** a Spring Boot 4.1.2 / Java 21 modular monolith, with modules talking only through their published `*Api` interfaces and events.
  - Waves are enforced in `chat`.
  - Status is a new `status` module that uses `media`, `safety`, `identity` and `profile`.
  - `discovery` asks `StatusApi` for ring states, in one batch query per page.
- **Mobile:** a Flutter app with Riverpod, go_router and feature-first folders. One shared `PhotoViewer` and one cached image widget serve every photo surface.

**Tech Stack:**
- Backend: Spring Boot 4.1.2, Java 21, Spring Modulith, JdbcClient, Flyway, PostgreSQL/PostGIS, S3 (s3mock locally), JUnit 5, AssertJ and Testcontainers.
- Mobile: Flutter, Riverpod 3, go_router, dio, image_picker, and the new `cached_network_image`.
- Admin: React, Vite and Vitest.

**Spec:** [docs/superpowers/specs/2026-11-18-polish-waves-status-design.md](../specs/2026-11-18-polish-waves-status-design.md)

## Global Constraints

- **Wave limit:** `orbit.chat.wave-limit=2` and `orbit.chat.wave-window=PT24H`, counted per (sender, recipient) over a rolling window and enforced on the server.
- **Wave problem:**
  - REST: `429`, type `urn:orbit:problem:wave-limit`, a `Retry-After` header (seconds), and a `retryAt` extension (ISO-8601 UTC).
  - WebSocket: an error frame `{type:"error", code:"wave-limit", clientMsgId, retryAt}`.
- **Statuses:**
  - Photos only.
  - Caption is 100 characters at most.
  - At most **10** live per member; the 11th gets `409`, type `urn:orbit:problem:status-limit`.
  - Each lives 24 hours. Viewers see each one for **5 s**.
  - When it expires, it is deleted outright; nothing is archived.
- **Status visibility:** the same rules as `GET /api/v1/profiles/{id}`. Never shown to members blocked in either direction. Hidden when the owner is restricted. The owner's own views are never recorded.
- **Endpoints** live under `/api/v1`. Errors are RFC 9457 `application/problem+json`, and input is checked with Bean Validation.
- **Migrations:** the next free numbers are **V12** (wave index), **V13** (media purpose and evidence hold) and **V14** (status tables). Existing migrations are never edited.
- **One new dependency:** `cached_network_image` (MIT). Its cache key is the media id plus its variant (`thumb` or `full`), never the signed URL. View-once media is never cached. The cache is cleared on sign-out, and a member's media is evicted when you block them.
- **Theme:**
  - `ThemeMode.system`, with the tokens in spec §7.1 copied exactly.
  - All text and background pairs meet WCAG AA (4.5:1 for body text, 3:1 for large text and icons).
  - Motion takes 250 ms with ease-out, and is skipped when `MediaQuery.disableAnimations` is set.
- **Fonts and shapes:** the platform system font. Corner radii are sheets 20, cards 16, tiles 12. Frosted bars use `BackdropFilter` blur 20.
- **Times** are formatted from `toLocal()`. Messages show `h:mm a` in the locale's form.
- **Logs** never contain captions, message text, media URLs or tokens.
- **Commits:** the user commits only on request. At the start of execution, ask once whether to commit after each task. If they say no, skip every "Commit" step and leave the changes uncommitted.
- **Checks after every task:**
  - Mobile: `cd mobile && dart format --set-exit-if-changed . && flutter analyze && flutter test`
  - Backend: `cd backend && ./gradlew spotlessCheck check`
  - Admin (Task 15): `cd admin && npm run lint && npm test -- --run`

## Review Focus

1. **A wave retried by the client after the limit was hit.** A resend with the same `clientMsgId` returns the already-stored wave, never a 429. The pending bubble must not get stuck. *Covered by Task 5, `duplicateClientIdAfterLimitReturnsStoredWave`.*
2. **A status that expires while someone is watching it.** The viewer reaches the expired status, its URL returns 404 or 410, and the viewer skips it instead of hanging or crashing. *Covered by Task 17, `skips a status whose image fails to load`.*
3. **Blocking a member who has a status ring on your grid.** After the block, the grid, the profile and the status endpoint all hide that member, and their cached images are evicted. *Covered by Task 12, `blockedViewerGets404`, and Task 9, `evicts a member's images when blocked`.*
4. **Dark-mode leftovers.** A screen still using a hard-coded colour shows dark text on a dark background. *Covered by Task 19, `no hard-coded colours outside theme`, plus the golden tests in Task 25.*
5. **The day boundary near midnight.** A message sent at 23:59 local time, with "now" at 00:01, shows under "Yesterday" with its local time. *Covered by Task 1 and Task 22, `day separator uses local midnight`.*

---

# Part 1: Bug fixes

### Task 1: Message times in local time (B1)

**Files:**
- Modify: `mobile/lib/features/chat/presentation/message_preview.dart:25-33`
- Test: `mobile/test/features/domain_rules_test.dart`

**Interfaces:**
- Produces: `String shortTimestamp(BuildContext context, DateTime time, DateTime now)`. It keeps its signature, and both arguments may be UTC. Also produces `String messageTime(BuildContext context, DateTime time)` (local `DateFormat.jm`), which Task 22 uses.

- [ ] **Step 1: Write failing tests in `domain_rules_test.dart`.** Set the zone with `TZ`-independent values: build `time` as `DateTime.utc(...)`, and compute the expected string from `time.toLocal()`.
  - `shortTimestamp shows the local time for a UTC message today`: expect `DateFormat.jm('en').format(t.toLocal())`.
  - `shortTimestamp uses the local day`: take `now = DateTime(2026, 11, 19, 0, 1)` (local) and `time = DateTime(2026, 11, 18, 23, 59).toUtc()`; expect `DateFormat.E('en').format(time.toLocal())`.
- [ ] **Step 2:** Run `cd mobile && flutter test test/features/domain_rules_test.dart`. Expect a FAIL, because the time is shown in UTC.
- [ ] **Step 3:** Convert `time` and `now` with `toLocal()` before comparing and formatting. Add `messageTime`.
- [ ] **Step 4:** Run the same command. Expect a PASS.
- [ ] **Step 5:** Commit: `fix(mobile): show message times in local time`

### Task 2: Profile screen opens cleanly and refreshes (B2, B6)

**Files:**
- Modify: `mobile/lib/features/discovery/presentation/profile_screen.dart`
- Modify: `mobile/lib/features/discovery/presentation/discovery_providers.dart` (the `profileByIdProvider` definition)
- Test: `mobile/test/features/discovery_flow_test.dart`

- [ ] **Step 1: Write the failing test** `opening a profile reports no framework errors`. Pump the app, tap a grid tile, `pumpAndSettle`, and then `expect(tester.takeException(), isNull)`. Also collect `FlutterError.onError` calls into a list and expect it to be empty.
- [ ] **Step 2:** Run the test. Expect a FAIL with "markNeedsBuild() called during build". If it passes in tests, reproduce with the live trace instead: frame #26 is `ProfileScreen.build`, and frame #8 is `invalidateSelf` from `Ref.watch` inside `ProviderElement._maybeRebuildDependencies`. Make the test use the same provider overrides as the app's real wiring.
- [ ] **Step 3: Fix the provider that rebuilds a dependency synchronously during first watch.** It is the `profileByIdProvider` chain reading a provider that `ref.watch`es a notifier that gets mutated during build.
  - Make the derived read use `ref.watch(...select(...))` on the already-built state, or move the mutation into `Future.microtask`. Pick whichever removes the synchronous invalidation, and explain it in one comment.
  - For B6, make `profileByIdProvider` `autoDispose`, so each visit refetches, and keep the grid's cached `Profile` as initial data while it loads.
- [ ] **Step 4: Add the test** `profile shows photos added since the grid loaded`. The fake API returns 1 photo for the grid and 2 photos for `/profiles/{id}`; expect the page indicator "1 / 2".
- [ ] **Step 5:** Run `flutter test test/features/discovery_flow_test.dart`. Expect a PASS.
- [ ] **Step 6:** Commit: `fix(mobile): open profiles without build errors and refetch them`

### Task 3: Readable buttons over photos (B3)

**Files:**
- Create: `mobile/lib/core/widgets/glass_icon_button.dart`
- Modify: `mobile/lib/features/discovery/presentation/profile_screen.dart` (app bar)
- Test: `mobile/test/features/discovery_flow_test.dart`

**Interfaces:**
- Produces: `GlassIconButton({required IconData icon, required String tooltip, required VoidCallback onPressed, bool selected = false, IconData? selectedIcon})`. It is a 40×40 circle with `BackdropFilter` blur 20 and `Colors.black.withValues(alpha: 0.35)` fill, with a white icon. Tasks 10, 17 and 24 reuse it.

- [ ] **Step 1: Write the failing test** `profile app bar buttons sit on glass backings`. Expect `find.byType(GlassIconButton)` to find 3 (back, favourite, more), and each to have tooltips.
- [ ] **Step 2:** Run the test. Expect a FAIL.
- [ ] **Step 3:** Build `GlassIconButton`. Use it for the leading back button and both actions, and add a 120 px top `LinearGradient` scrim (black at 45% → transparent) over the photo.
- [ ] **Step 4:** Run the test. Expect a PASS.
- [ ] **Step 5:** Commit: `fix(mobile): make profile buttons readable over photos`

### Task 4: Share-album empty state (B4)

**Files:**
- Modify: `mobile/lib/features/albums/presentation/share_album_screen.dart`
- Modify: `mobile/lib/l10n/app_en.arb` (`shareAlbumEmpty`, `createAlbum`), then run `flutter gen-l10n`
- Test: `mobile/test/features/chat_flow_test.dart`

**Interfaces:**
- Consumes: the existing album creation in `albums_controller.dart` (`albumsProvider.notifier`). Use whatever `create(name)` method it exposes, and check the name in the file.

- [ ] **Step 1: Write the failing test** `sharing with no albums offers to create one`. Open share-album with an empty album list, and expect the text `shareAlbumEmpty` and a "Create album" button. Tap it, enter "Weekend" and confirm. Expect the new album to be listed and selected, and the Share button to be enabled.
- [ ] **Step 2:** Run the test. Expect a FAIL.
- [ ] **Step 3:** Add `EmptyState` with the action. It opens the same name dialog that My albums uses, extracted into a `Future<String?> askAlbumName(BuildContext)` in `my_albums_screen.dart` if it isn't shared already. Select the created album.
- [ ] **Step 4:** Run the test. Expect a PASS.
- [ ] **Step 5:** Commit: `fix(mobile): let members create an album from the share screen`

---

# Part 2: Wave limit

### Task 5: Backend wave limit

**Files:**
- Create: `backend/src/main/resources/db/migration/V12__message_wave_index.sql`
- Modify: `backend/src/main/java/com/orbit/chat/application/ChatService.java` (in `send`/`store`, plus the new exception)
- Modify: `backend/src/main/java/com/orbit/chat/infrastructure/ChatStore.java` (the new count query)
- Modify: `backend/src/main/java/com/orbit/chat/api/ChatWebSocketConfig.java` (`ChatProperties`)
- Modify: `backend/src/main/java/com/orbit/chat/api/ChatController.java` (the 429 handler)
- Modify: `backend/src/main/java/com/orbit/chat/api/ChatWebSocketHandler.java` (the error frame)
- Modify: `backend/src/main/resources/application.yml` (`orbit.chat.wave-limit: 2`, `orbit.chat.wave-window: PT24H`)
- Test: `backend/src/test/java/com/orbit/chat/ChatIntegrationTests.java`

**Interfaces:**
- Produces:
  - `ChatService.WaveLimitReachedException(Instant retryAt)`, with an accessor `retryAt()`.
  - `ChatStore.wavesSince(UUID conversationId, UUID senderId, Instant since): List<Instant>`, which returns the created times, oldest first.
  - `ChatProperties(List<String> allowedOrigins, @Min(1) int waveLimit, @NotNull Duration waveWindow)`, annotated `@Validated`. Defaults are 2 and 24 h when the values are absent.
- Migration body: `CREATE INDEX message_wave_idx ON message (conversation_id, sender_id, created_at) WHERE kind = 'WAVE';`

- [ ] **Step 1: Write failing tests in `ChatIntegrationTests`.** Use the existing helpers for two members, REST send and a socket, plus the test `Clock` bean the suite already uses for time-dependent tests. If there is none, add a `MutableClock` test bean in `src/test/java/com/orbit/shared/` and register it with `@TestConfiguration`.
  - `thirdWaveWithin24hIsRefused`: send 2 WAVEs and expect 201. On the 3rd, expect 429, `type == "urn:orbit:problem:wave-limit"`, `retryAt == firstWaveAt + 24h`, and a `Retry-After` header equal to the seconds until then.
  - `waveToAnotherMemberIsAllowed`: after 2 waves to B, a wave to C gets 201.
  - `waveAllowedAfterWindow`: after 2 waves, advance the clock 24 h plus 1 s; the 3rd gets 201.
  - `duplicateClientIdAfterLimitReturnsStoredWave`: resend the 2nd wave's `clientMsgId` and get 200 or 201 with the same message id. Match whatever the existing idempotent-retry status is.
  - `socketGetsWaveLimitError`: the 3rd wave over the socket gets the frame `{"type":"error","code":"wave-limit","clientMsgId":..., "retryAt":...}`.
  - `concurrentWavesStoreAtMostTwo`: fire 5 sends in parallel with distinct client ids (`ExecutorService`, `CountDownLatch` start gate, no sleeps). Expect exactly 2 stored WAVE rows.
- [ ] **Step 2:** Run `cd backend && ./gradlew test --tests '*ChatIntegrationTests*'`. Expect the new tests to FAIL.
- [ ] **Step 3: Implement the limit.** In `store(...)`, after `conversationFor` and `nextSeq`, count the waves when `kind == WAVE`. `nextSeq`'s `UPDATE … RETURNING` row lock serializes concurrent senders in the same transaction, so the count is race-safe.
  - If `wavesSince(conv, me, now - window).size() >= limit`, throw `WaveLimitReachedException(oldest.plus(window))`. The transaction rolls back, so the sequence number is not used.
  - The idempotency check in `send` stays first.
- [ ] **Step 4: Add the handlers.**
  - Controller: `@ExceptionHandler(WaveLimitReachedException.class)` builds a `ResponseEntity<ProblemDetail>`. Use 429, `problem(TOO_MANY_REQUESTS, "wave-limit", "Wave limit reached", "You can wave at this member again later.")`, `setProperty("retryAt", e.retryAt())`, and the header `Retry-After: max(1, ceil(seconds))`.
  - WebSocket: catch it, and send `error("wave-limit", clientMsgId)` plus `retryAt`. Extend the `error(...)` helper with an optional extra map.
- [ ] **Step 5:** Run the same command. Expect a PASS. Then run `./gradlew spotlessCheck check`, and expect a PASS.
- [ ] **Step 6:** Commit: `feat(chat): limit waves to two per member per rolling day`

### Task 6: Mobile wave limit

**Files:**
- Modify: `mobile/lib/core/network/api_client.dart` (`ApiException.retryAt`, parsed in `toApiException`)
- Modify: `mobile/lib/features/chat/data/chat_gateway.dart` (`SendFailed`, the REST path around :470, the WebSocket path around :392)
- Create: `mobile/lib/features/chat/presentation/wave_limit.dart`
- Modify: `mobile/lib/features/chat/presentation/live_chat_controller.dart` (handle `SendFailed` around :288)
- Modify: `mobile/lib/features/discovery/presentation/profile_screen.dart` (`_wave`, the Wave button)
- Modify: `mobile/lib/l10n/app_en.arb`: `waveAgainIn` "Wave again in {time}" and `waveLimitReached` "You've waved twice today. Try again in {time}."
- Test: `mobile/test/features/chat_gateway_test.dart`, `mobile/test/features/live_chat_controller_test.dart` and `mobile/test/features/discovery_flow_test.dart`

**Interfaces:**
- Produces:
  - `ApiException.retryAt: DateTime?` (UTC).
  - `enum SendFailure { refused, waveLimit }`.
  - `SendFailed(String clientMsgId, {SendFailure reason = SendFailure.refused, DateTime? retryAt})`.
  - `waveLimitProvider`: a `NotifierProvider.family<WaveLimit, DateTime?, String>` keyed by profile id, whose state is `retryAt` or null.
    - `WaveLimit.block(DateTime retryAt)`.
    - `WaveLimit.fromHistory(List<Message> messages, DateTime now)`: sets the state when the last 24 h holds 2 or more `fromMe` waves.
    - The state clears itself once `retryAt` has passed (checked on read against `clockProvider`).
  - `String waitLabel(Duration d)`: returns "6h" rounded up to the hour, or "25m" when under an hour.

- [ ] **Step 1: Write failing tests.**
  - Gateway: `REST 429 wave-limit becomes SendFailed with waveLimit` uses a `FakeAdapter` handler returning `(429, {'type':'urn:orbit:problem:wave-limit','status':429,'retryAt':'2026-11-19T05:00:00Z'})`. Expect `SendFailed` with `reason == SendFailure.waveLimit` and `retryAt == DateTime.utc(2026,11,19,5)`.
  - Gateway: `socket wave-limit error becomes SendFailed with waveLimit`.
  - Controller: `a refused wave disappears and blocks the button`. Emit `SendFailed(id, reason: waveLimit, retryAt: …)`; the pending wave is removed from the conversation, and `waveLimitProvider('bob')` equals `retryAt`.
  - Flow: `Wave button counts down after the limit`. With 2 `fromMe` waves in the loaded history from the last hour, the profile shows a disabled "Wave again in 24h". Tapping does nothing.
  - Unit: `waitLabel(Duration(hours: 5, minutes: 1)) == '6h'` and `waitLabel(Duration(minutes: 24, seconds: 10)) == '25m'`.
- [ ] **Step 2:** Run `cd mobile && flutter test test/features/chat_gateway_test.dart test/features/live_chat_controller_test.dart test/features/discovery_flow_test.dart`. Expect a FAIL.
- [ ] **Step 3:** Implement the interfaces above. In the controller, for `SendFailure.waveLimit`, remove the pending message (no failed state), call `block`, and emit a one-shot UI notice via the existing snackbar mechanism with `waveLimitReached`.
- [ ] **Step 4:** Run the same tests. Expect a PASS. Then run the full mobile checks, and expect a PASS.
- [ ] **Step 5:** Commit: `feat(mobile): show the wave limit and when waving unlocks`

### Task 7: Collapse repeated waves in chat

**Files:**
- Create: `mobile/lib/features/chat/presentation/chat_items.dart`
- Modify: `mobile/lib/features/chat/presentation/chat_screen.dart` (build the list from `chatItems`)
- Modify: `mobile/lib/features/chat/presentation/message_bubble.dart` (show the wave count)
- Modify: `mobile/lib/l10n/app_en.arb`: `waveInCount` "{name} waved ×{count}" and `waveOutCount` "You waved ×{count}"
- Test: `mobile/test/features/chat_flow_test.dart`

**Interfaces:**
- Produces: `sealed class ChatItem`, with these subclasses:
  - `MessageItem(Message message, {bool groupedWithNext, bool groupedWithPrevious})`
  - `WaveRunItem(List<Message> waves)`
  - `DaySeparatorItem(DateTime localDay)`
  - `PhotoMosaicItem(List<Message> photos)`

  Also produces `List<ChatItem> chatItems(List<Message> messages)`. This task produces only `MessageItem` and `WaveRunItem`; Task 22 adds grouping and day separators, and Task 23 adds the mosaic. Keep the function pure.

- [ ] **Step 1: Write failing tests.**
  - Unit: `three consecutive waves from one sender become one run`: `[waveA, waveA, waveA]` gives a single `WaveRunItem` with 3 waves.
  - Unit: `a text between waves splits the run`.
  - Unit: `waves from different senders are separate runs`.
  - Widget: `chat shows "Sam waved ×3"`.
- [ ] **Step 2:** Run `flutter test test/features/chat_flow_test.dart`. Expect a FAIL.
- [ ] **Step 3:** Implement `chatItems`, and render `WaveRunItem` as one bubble. A run of 1 keeps today's copy.
- [ ] **Step 4:** Run the test. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(mobile): collapse repeated waves into one bubble`

---

# Part 3: Profile photo viewer and editing

### Task 8: Shared photo actions, reorder, and tap-to-open in Edit profile (B5)

**Files:**
- Create: `mobile/lib/features/profile/presentation/my_photos_actions.dart`
- Modify: `mobile/lib/features/profile/presentation/photo_editor.dart` (use the actions, drag to reorder, "Main" label, tap opens the viewer route)
- Modify: `mobile/lib/app/router.dart` (`AppRoutes.myPhotos = '/me/photos'`, with the query parameter `?index=N`)
- Modify: `mobile/lib/l10n/app_en.arb`: `photoMain`, `photoMakeMain`, `photoReplace`, `photoDelete`, `photoDeleteConfirm`, `photoDeleteLastWarning`, `photoAdd`
- Test: `mobile/test/features/me_flow_test.dart`

**Interfaces:**
- Produces:
  - `List<String> movePhoto(List<String> ids, int from, int to)`
  - `List<String> replacePhoto(List<String> ids, String oldId, String newId)`
  - `List<String> makeMain(List<String> ids, String id)`
  - `List<String> withoutPhoto(List<String> ids, String id)`
  - These are all pure, top level, in `my_photos_actions.dart`.
  - `myPhotosActionsProvider`: a `Provider<MyPhotosActions>`, with these methods:
    - `Future<void> add(PickedMedia picked)`
    - `Future<void> replace(String oldId, PickedMedia picked)`
    - `Future<void> makeMain(String id)`
    - `Future<void> delete(String id)`
    - `Future<void> reorder(int from, int to)`

    Each one uploads if needed (`MediaPurpose.profilePhoto`), then calls `accountRepositoryProvider.setPhotos(ids)`, then `myProfileProvider.notifier.save(saved)`. Each throws `ApiException` on failure, leaving `myProfileProvider` untouched.
  - The route `AppRoutes.myPhotos` takes `index`.

- [ ] **Step 1: Write failing tests.**
  - Unit: `movePhoto(['a','b','c'], 2, 0) == ['c','a','b']`, `makeMain(['a','b','c'], 'b') == ['b','a','c']`, `replacePhoto(['a','b'], 'b', 'z') == ['a','z']` and `withoutPhoto(['a','b'], 'a') == ['b']`.
  - `a failed save keeps the old order`: the fake `PUT /me/photos` returns 500; after `reorder(0, 1)`, `myProfileProvider` photos are unchanged.
  - `tapping a photo in Edit profile opens the viewer at that photo`: tap the 2nd tile; the route is `/me/photos?index=1`, and the picker was not called (the fake picker's call count is 0).
  - `dragging a photo to the front makes it main`: long-press drag the 2nd tile onto the 1st; `PUT /me/photos` is called with `['b','a']`, and the first tile shows `photoMain`.
- [ ] **Step 2:** Run `flutter test test/features/me_flow_test.dart`. Expect a FAIL.
- [ ] **Step 3: Implement the actions.** In `PhotoEditor`, wire them up. Build the reorder from `LongPressDraggable<int>` and `DragTarget<int>` per tile (no new dependency). Tap pushes `AppRoutes.myPhotos`; the route itself is built in Task 10, so for now register it with a placeholder. Only `_AddTile` opens the picker.
- [ ] **Step 4:** Run the tests. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(mobile): reorder profile photos and open them instead of re-adding`

### Task 9: Shared PhotoViewer and cached images

**Files:**
- Modify: `mobile/pubspec.yaml`: add `cached_network_image`, the latest stable version compatible with the installed Flutter SDK. Run `flutter pub add cached_network_image`; never edit the lockfile by hand.
- Create: `mobile/lib/core/widgets/media_image.dart`
- Create: `mobile/lib/core/widgets/photo_viewer.dart` (replaces `PhotoViewer` and `openPhoto` in `message_media.dart`)
- Modify: `mobile/lib/features/chat/presentation/message_media.dart` (use the shared viewer; view-once uses `cache: false`)
- Modify: `mobile/lib/core/widgets/profile_avatar.dart` (use `MediaImage`)
- Modify: `mobile/lib/app/session.dart` (`signOut` clears the image cache)
- Modify: `mobile/lib/features/safety/presentation/safety_providers.dart` (blocking evicts that member's images)
- Test: `mobile/test/app/photo_viewer_test.dart` (new), `mobile/test/features/message_media_test.dart` and `mobile/test/features/me_flow_test.dart`

**Interfaces:**
- Produces:
  - `MediaImage({required String mediaId, required String url, String? thumbUrl, MediaVariant variant = MediaVariant.full, bool cache = true, BoxFit fit = BoxFit.cover, String? ownerId})`. The cache key is `'$mediaId:${variant.name}'`, and the thumbnail is shown first with the full image cross-fading over it. `ownerId` registers the key for eviction.
  - `enum MediaVariant { thumb, full }`.
  - `OrbitImageCache`: a `Provider` with `Future<void> clearAll()` and `Future<void> evictOwner(String ownerId)`. It tracks the keys per owner in memory and wraps `DefaultCacheManager`.
  - `PhotoViewerItem({required String mediaId, required String url, String? thumbUrl, bool cache = true})`.
  - `Future<void> openPhotos(BuildContext context, List<PhotoViewerItem> items, {int initialIndex = 0, String? heroTag, Widget Function(BuildContext, int index)? bottomBar})`.
  - `PhotoViewer` has:
    - A `PageView` of `InteractiveViewer` (min 1, max 4; double-tap toggles 2.5× at the tap point).
    - Vertical drag to dismiss: dismisses past 120 px or 800 px/s, with the background opacity following the drag.
    - Precaching of the neighbouring images.
    - A "2 / 4" indicator, and the `bottomBar` slot.

- [ ] **Step 1: Write failing tests.**
  - `viewer opens at the given index and pages`: 3 items with `initialIndex: 1` shows "2 / 3"; after a fling left, it shows "3 / 3".
  - `dragging down past the threshold closes the viewer`.
  - `view-once photos are not cached`: `MediaImage(cache: false)` builds a plain `Image.network`, with no `CachedNetworkImage` in the tree.
  - `cache key ignores the signed URL`: two `MediaImage`s with the same `mediaId` and different `url` share the key `'m1:full'`.
  - `sign-out clears the image cache` and `evicts a member's images when blocked`: with a fake `OrbitImageCache`, record the calls.
- [ ] **Step 2:** Run `flutter test test/app/photo_viewer_test.dart test/features/message_media_test.dart`. Expect a FAIL.
- [ ] **Step 3:** Implement the interfaces above. `MediaImage` is used by `ProfileAvatar` and the chat media. Disable the hero and drag animations when `MediaQuery.disableAnimations` is set.
- [ ] **Step 4:** Run the full mobile checks. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(mobile): cache photos by media id and share one photo viewer`

### Task 10: Me photo viewer with editing

**Files:**
- Create: `mobile/lib/features/profile/presentation/my_photos_viewer.dart`
- Modify: `mobile/lib/app/router.dart` (replace the Task 8 placeholder for `AppRoutes.myPhotos`)
- Modify: `mobile/lib/features/profile/presentation/me_screen.dart` (tappable avatar with a hero, and a "+" badge that is an empty callback until Task 18)
- Test: `mobile/test/features/me_flow_test.dart`

**Interfaces:**
- Consumes: `myPhotosActionsProvider` (Task 8), and `openPhotos` / `PhotoViewer` with `bottomBar` (Task 9).
- Produces:
  - `MyPhotosViewer({int initialIndex = 0})`. Its bottom bar has Add (when there are fewer than 6 photos), Replace, Make main (when the index is above 0) and Delete (confirmation dialog; `photoDeleteLastWarning` when it's the only photo).
  - `MeAvatar({VoidCallback? onAddStatus})`, a widget in `me_screen.dart` that Task 18 also uses.

- [ ] **Step 1: Write failing tests.**
  - `tapping my avatar opens my photos`: there are 2 photos; tap the avatar and expect `MyPhotosViewer` with "1 / 2".
  - `tapping my avatar with no photos opens the picker`.
  - `make main from the viewer saves the new order`: on page 2, tap Make main; `PUT /me/photos` gets `['b','a']`, and the viewer now shows "1 / 2".
  - `deleting my only photo warns first`: the dialog contains `photoDeleteLastWarning`; after confirming, the PUT gets `[]` and the viewer closes.
  - `a failed replace shows an error and keeps the photo`.
- [ ] **Step 2:** Run `flutter test test/features/me_flow_test.dart`. Expect a FAIL.
- [ ] **Step 3:** Implement the interfaces above. Show a progress overlay on the current page only while its action runs.
- [ ] **Step 4:** Run the full mobile checks. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(mobile): open and edit my photos from the Me tab`

---

# Part 4: 24-hour status

### Task 11: Media support for statuses (purpose, purge, evidence hold)

**Files:**
- Create: `backend/src/main/resources/db/migration/V13__status_media.sql`
- Modify: `backend/src/main/java/com/orbit/media/domain/MediaPurpose.java` (`STATUS_PHOTO(Kind.PHOTO, Limits.PHOTO_BYTES, Limits.PHOTO_TYPES, null)`)
- Modify: `backend/src/main/java/com/orbit/media/MediaApi.java` (`purge`, `holdAsEvidence`)
- Modify: `backend/src/main/java/com/orbit/media/application/MediaService.java`, `backend/src/main/java/com/orbit/media/infrastructure/MediaStore.java` and `backend/src/main/java/com/orbit/media/application/ObjectStorage.java` (adding a `delete(String key)` if absent)
- Modify: `mobile/lib/features/media/domain/media.dart` (`MediaPurpose.statusPhoto('STATUS_PHOTO')`)
- Test: `backend/src/test/java/com/orbit/media/MediaIntegrationTests.java`

**Interfaces:**
- Produces:
  - `boolean MediaApi.purge(UUID mediaId)`: deletes the stored objects (the original and the thumbnail) and the media row, unless `evidence_hold` is set. Returns whether it deleted anything, and is idempotent.
  - `void MediaApi.holdAsEvidence(UUID mediaId)`: sets `evidence_hold = true`, and is idempotent.
- Migration:

  ```sql
  ALTER TABLE media ADD COLUMN evidence_hold BOOLEAN NOT NULL DEFAULT FALSE;
  ALTER TABLE media DROP CONSTRAINT media_purpose_ck;
  ALTER TABLE media ADD CONSTRAINT media_purpose_ck CHECK (purpose IN (<existing values>, 'STATUS_PHOTO'));
  ```

  Copy `<existing values>` from V9 and V10.

- [ ] **Step 1: Write failing tests.**
  - `statusPhotoUploadIsAccepted`
  - `purgeDeletesObjectsAndRow`: after an upload, `purge` returns true; the object is gone from s3mock, and `links([id])` is empty.
  - `purgeSkipsHeldMedia`: after `holdAsEvidence(id)`, `purge` returns false and the object still exists.
  - `purgeIsIdempotent`: a second call returns false without an error.
- [ ] **Step 2:** Run `./gradlew test --tests '*MediaIntegrationTests*'`. Expect a FAIL.
- [ ] **Step 3:** Implement the interfaces above. Delete the object first and the row second, so a failed object delete leaves the row for a retry.
- [ ] **Step 4:** Run `./gradlew spotlessCheck check`. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(media): add status photos, purge and evidence hold`

### Task 12: Status module: post, list, view, delete and visibility

**Files:**
- Create the package `backend/src/main/java/com/orbit/status/`:
  - `StatusApi.java`
  - `package-info.java` (an `@ApplicationModule` that depends on media, safety, identity and profile)
  - `api/StatusController.java`
  - `application/StatusService.java`
  - `application/StatusViews.java`
  - `infrastructure/StatusStore.java`
- Create: `backend/src/main/resources/db/migration/V14__create_status.sql` (the tables from spec §8.1, exactly)
- Test: `backend/src/test/java/com/orbit/status/StatusIntegrationTests.java`

**Interfaces:**
- Consumes:
  - `MediaApi.requireAttachable(owner, mediaId, Kind.PHOTO, false)`, which must also check the purpose `STATUS_PHOTO`. If `requireAttachable` cannot tell purposes apart, add `MediaApi.requirePurpose(UUID owner, UUID mediaId, String purpose)` in this task.
  - `MediaApi.links`
  - `SafetyApi.isBlockedEitherWay` and `SafetyApi.blockedEitherWay`
  - `IdentityApi.findById(id).restricted()`
  - `ProfileApi.card` (to check the viewer has a profile) and `ProfileApi.displayNames`
- Produces:
  - `Map<UUID, StatusApi.StatusState> statesFor(UUID viewerId, Collection<UUID> ownerIds)`, where `enum StatusState { NONE, UNSEEN, SEEN }`. It runs exactly **one** SQL query.
  - `Optional<StatusApi.StatusEvidence> StatusApi.liveStatusOf(UUID ownerId, UUID statusId)`, where `record StatusEvidence(UUID id, UUID mediaId, String caption, Instant createdAt)`.
  - `record StatusApi.StatusExpired(UUID statusId, UUID mediaId)`, an event.
  - REST, per spec §8.1:
    - `POST /me/statuses {mediaId, caption?}` returns `201 MyStatus`.
    - `GET /me/statuses` returns `List<MyStatus{id, url, thumbUrl, caption, createdAt, expiresAt, viewCount, viewers[{id, name, thumbUrl, viewedAt}]}>`.
    - `DELETE /me/statuses/{id}` returns `204`.
    - `GET /profiles/{id}/statuses` returns `List<StatusItem{id, url, thumbUrl, caption, createdAt, seen}>`.
    - `PUT /statuses/{id}/view` returns `204`.
  - Problems: `409 status-limit`, `404 status-not-found` (also for invisible profiles), and `422 invalid-status` (bad media or a caption over 100 characters).
  - `DELETE` publishes `StatusExpired`.

- [ ] **Step 1: Write failing tests**, using the shared test `Clock` from Task 5.
  - `postAndListMyStatus`
  - `eleventhLiveStatusIsRefused`: expect 409 `urn:orbit:problem:status-limit`.
  - `captionOver100Refused`
  - `otherMembersMediaRefused`
  - `profilePhotoPurposeRefused`
  - `visibleMemberSeesStatusOldestFirst`
  - `blockedViewerGets404` (in both block directions)
  - `restrictedOwnerHidden`
  - `restrictedMemberCannotPost` (403, using the existing `account-restricted` problem)
  - `expiredStatusNotServedBeforeReaper`: advance the clock 24 h plus 1 s.
  - `viewRecordedOnceAndOwnViewIgnored`: viewing twice gives `viewCount == 1`; the owner viewing their own status leaves it at 1.
  - `viewersNewestFirstWithNames`
  - `deleteRemovesAndPublishesStatusExpired`: use the Modulith `PublishedEvents` / `Scenario` test support that the suite already uses, or `@RecordApplicationEvents`.
  - `statesForUsesOneQuery`: for 3 owners (unseen, seen, none), assert the map, and assert one statement with a datasource-proxy or JdbcClient counting wrapper. If no query counter exists in the test suite, add `CountingDataSource` in `src/test/java/com/orbit/shared/`.
  - The Modulith `ApplicationModules.verify()` test still passes. It already exists if the suite has `ModularityTests`; otherwise add it.
- [ ] **Step 2:** Run `./gradlew test --tests '*StatusIntegrationTests*'`. Expect a FAIL.
- [ ] **Step 3: Implement the interfaces above.**
  - The visibility check is one private method, `requireVisible(viewer, owner)`, used by `GET /profiles/{id}/statuses` and `PUT /statuses/{id}/view`.
  - The 10-status limit is checked under `SELECT … FOR UPDATE` on the owner's account row, so two concurrent posts can't both pass.
  - Record Micrometer counters `orbit.status.posted` and `orbit.status.viewed`.
- [ ] **Step 4:** Run `./gradlew spotlessCheck check`. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(status): post, view and list 24-hour photo statuses`

### Task 13: Status expiry reaper

**Files:**
- Create: `backend/src/main/java/com/orbit/status/application/StatusReaper.java`
- Create: `backend/src/main/java/com/orbit/media/application/StatusMediaPurger.java`. It is an `@ApplicationModuleListener` on `StatusApi.StatusExpired` that calls `MediaApi.purge`. Media then depends on status's event type; if that creates a module cycle, move the record `StatusExpired` to a neutral `com.orbit.shared.events` package and say so in the commit body.
- Test: `backend/src/test/java/com/orbit/status/StatusIntegrationTests.java`

**Interfaces:**
- Produces: `StatusReaper.reap(): int`, the number deleted. It is `@Scheduled(fixedDelayString = "PT1M", initialDelayString = "PT1M")` and works in batches of 500 using `DELETE … WHERE id IN (SELECT id … WHERE expires_at <= :now LIMIT 500) RETURNING id, media_id`. It loops until a batch comes back short, publishes one `StatusExpired` per row, and counts `orbit.status.expired`.

- [ ] **Step 1: Write failing tests.**
  - `reaperDeletesExpiredAndPurgesMedia`: post a status, advance 24 h plus 1 s, run `reap()` and get 1. The status row is gone, and the media object is gone after the event publication completes; wait with the Modulith `Scenario` or Awaitility, not sleeps.
  - `reaperKeepsLiveStatuses`
  - `reaperIsIdempotent`: a second run returns 0.
  - `reaperKeepsHeldEvidenceMedia`: call `holdAsEvidence` first; after reaping, the media object still exists.
- [ ] **Step 2:** Run the tests. Expect a FAIL.
- [ ] **Step 3:** Implement the interfaces above.
- [ ] **Step 4:** Run `./gradlew spotlessCheck check`. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(status): delete statuses and their photos after 24 hours`

### Task 14: Ring state in discovery responses

**Files:**
- Modify: `backend/src/main/java/com/orbit/discovery/application/PersonView.java` (add `String status`, with the value `NONE`, `UNSEEN` or `SEEN`)
- Modify: `backend/src/main/java/com/orbit/discovery/application/DiscoveryService.java` (`grid`, `person` and `favorites` call `StatusApi.statesFor` once per response)
- Modify: `backend/src/main/java/com/orbit/discovery/package-info.java` (allow the dependency on `status`, if the modules are declared explicitly)
- Test: `backend/src/test/java/com/orbit/discovery/PeopleIntegrationTests.java`

**Interfaces:**
- Consumes: `StatusApi.statesFor` (Task 12).
- Produces: a JSON field `status` on every grid item, profile and favorite.

- [ ] **Step 1: Write failing tests.**
  - `gridShowsUnseenThenSeenStatus`: B posts; A's grid shows B as `UNSEEN`. After A views it, A's grid shows `SEEN`. C has no status and shows `NONE`.
  - `gridStatusAddsOneQueryPerPage`: the statement count for one grid page rises by exactly 1 compared with the same request when no member has a status.
- [ ] **Step 2:** Run `./gradlew test --tests '*PeopleIntegrationTests*'`. Expect a FAIL.
- [ ] **Step 3:** Implement it, and run `./gradlew spotlessCheck check`. Expect a PASS.
- [ ] **Step 4:** Commit: `feat(discovery): include each member's status ring state`

### Task 15: Reporting a status keeps evidence

**Files:**
- Modify: `backend/src/main/java/com/orbit/safety/SafetyApi.java` (`ReportFiled` gains `UUID statusId`, which may be null)
- Modify: `backend/src/main/java/com/orbit/safety/api/SafetyController.java` (`ReportRequest` gains `UUID statusId`, optional)
- Modify: `backend/src/main/java/com/orbit/safety/application/SafetyService.java:69` (pass it through)
- Modify: `backend/src/main/java/com/orbit/moderation/application/EvidenceRecorder.java`
- Modify: `admin/src/features/members/ReportList.tsx` and `admin/src/features/members/types.ts` (render `kind === 'STATUS'` with its photo and caption)
- Modify: `mobile/lib/features/safety/data/safety_repository.dart` (the report call takes `String? statusId`)
- Test: `backend/src/test/java/com/orbit/moderation/ModerationIntegrationTests.java` and `admin/src/features/members/ReportList.test.tsx` (create it next to the component if there is none, following the existing Vitest setup)

**Interfaces:**
- Consumes: `StatusApi.liveStatusOf` (Task 12) and `MediaApi.holdAsEvidence` (Task 11).
- Produces: an evidence row `EvidenceRow(statusId, ownerId, "STATUS", caption, mediaId, createdAt, false)`, inserted alongside the message rows.

- [ ] **Step 1: Write failing tests.**
  - `reportingAStatusKeepsItAsEvidence`: B posts, and A reports B with `statusId`. The moderation case evidence includes a `STATUS` row with B's caption and media. After advancing 24 h plus 1 s and reaping, the evidence photo link still resolves for the moderator.
  - `statusIdOfAnotherMemberIsIgnored`: no `STATUS` row, and the report still succeeds.
  - Admin: `shows a reported status with its photo and caption`.
- [ ] **Step 2:** Run `./gradlew test --tests '*ModerationIntegrationTests*'` and `cd admin && npm test -- --run`. Expect a FAIL.
- [ ] **Step 3:** Implement it. The recorder stays synchronous inside the report transaction.
- [ ] **Step 4:** Run the backend and admin checks. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(moderation): keep a reported status as evidence`

### Task 16: Mobile status data layer

**Files:**
- Create: `mobile/lib/features/status/domain/status.dart`
- Create: `mobile/lib/features/status/data/status_repository.dart`
- Create: `mobile/lib/features/status/presentation/status_providers.dart`
- Modify: `mobile/lib/features/discovery/domain/profile.dart` (`StatusRing status`, parsed from `status`)
- Modify: `mobile/lib/features/discovery/data/api_profile_repository.dart`, `mobile/lib/features/discovery/data/fake_profile_repository.dart` and `mobile/lib/features/discovery/data/dummy_profiles.dart`
- Modify: `mobile/lib/app/session.dart` (`signOut` invalidates the status providers)
- Test: `mobile/test/features/api_repositories_test.dart`

**Interfaces:**
- Produces:
  - `enum StatusRing { none, unseen, seen }`.
  - `StatusItem({id, url, thumbUrl, caption, createdAt, seen})`.
  - `MyStatus({id, url, thumbUrl, caption, createdAt, expiresAt, viewCount, List<StatusSeenBy> viewers})`.
  - `StatusSeenBy({id, name, thumbUrl, viewedAt})`.
  - `StatusRepository` (`statusRepositoryProvider`), with these methods:
    - `Future<MyStatus> post(String mediaId, {String? caption})`
    - `Future<List<MyStatus>> mine()`
    - `Future<void> delete(String id)`
    - `Future<List<StatusItem>> of(String profileId)`
    - `Future<void> markViewed(String id)`
  - `myStatusesProvider`: an `AsyncNotifier<List<MyStatus>>` with `post` and `delete`.
  - `profileStatusesProvider`: a family of `FutureProvider` keyed by profile id.
  - `seenStatusOwnersProvider`: a `Notifier<Set<String>>`, which holds rings seen locally so they turn grey at once.
  - `StatusRing ringFor(Profile p, Set<String> seenLocally)`.

- [ ] **Step 1: Write failing tests.** Each endpoint maps both ways (the request path and body, and the parsed response). `status: "UNSEEN"` parses to `StatusRing.unseen`, and a missing field parses to `none`. A 409 `status-limit` surfaces as an `ApiException` with `type == 'status-limit'`.
- [ ] **Step 2:** Run `flutter test test/features/api_repositories_test.dart`. Expect a FAIL.
- [ ] **Step 3:** Implement it.
- [ ] **Step 4:** Run the full mobile checks. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(mobile): add the status data layer`

### Task 17: Status viewer

**Files:**
- Create: `mobile/lib/features/status/presentation/status_viewer.dart`
- Create: `mobile/lib/features/status/presentation/viewers_sheet.dart`
- Modify: `mobile/lib/app/router.dart`: `/status/:profileId`, and `/status/me` for your own
- Modify: `mobile/lib/features/safety/presentation/safety_sheet.dart` (accept an optional `statusId`)
- Modify: `mobile/lib/l10n/app_en.arb`: `statusAgo`, `statusViewedBy`, `statusViews`, `statusDelete`, `statusDeleteConfirm` and `statusReport`
- Test: `mobile/test/features/status_viewer_test.dart` (new)

**Interfaces:**
- Consumes: Task 16's providers, `MediaImage` (Task 9) and `GlassIconButton` (Task 3).
- Produces: `StatusViewerScreen({required String profileId})`. `profileId == 'me'` shows your own statuses.
  - Segments advance every 5 s, driven by an `AnimationController`, so tests use `tester.pump(Duration)`.
  - Tapping the right third goes to the next status, and the left third to the previous. Long press pauses. A vertical drag dismisses.
  - It calls `markViewed` and adds to `seenStatusOwnersProvider` when each status is first shown. It never does this for your own.
  - It precaches the next image.
  - When an image fails, the viewer moves on to the next status.

- [ ] **Step 1: Write failing tests.**
  - `advances after 5 seconds and closes after the last`.
  - `tap right goes next, tap left goes back`.
  - `holding pauses progress`.
  - `marks each status viewed once`: the fake API records each `PUT /statuses/{id}/view` call once.
  - `own status shows view count and opens Viewed by`: shows "👁 2", then a sheet with 2 names, newest first.
  - `delete own status asks first, then removes it`.
  - `report passes the status id`.
  - `skips a status whose image fails to load`: the fake image provider errors on item 1, and the viewer shows item 2 without waiting 5 s.
- [ ] **Step 2:** Run `flutter test test/features/status_viewer_test.dart`. Expect a FAIL.
- [ ] **Step 3:** Implement it.
- [ ] **Step 4:** Run the full mobile checks. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(mobile): add the status viewer`

### Task 18: Posting a status and showing rings

**Files:**
- Create: `mobile/lib/features/status/presentation/status_composer.dart` (a preview screen with a caption field, a counter of 100, and Post)
- Create: `mobile/lib/core/widgets/status_ring.dart`
- Modify: `mobile/lib/features/profile/presentation/me_screen.dart` (`MeAvatar.onAddStatus` opens the picker and then the composer; adds a "My status" tile)
- Modify: `mobile/lib/features/discovery/presentation/nearby_screen.dart` (rings on tiles and Fresh faces; tapping a ring opens the viewer)
- Modify: `mobile/lib/features/discovery/presentation/profile_screen.dart` (a ring on the header, which is tappable)
- Modify: `mobile/lib/l10n/app_en.arb`: `statusAdd`, `statusMine`, `statusCaptionHint`, `statusPost` and `statusLimitReached`
- Test: `mobile/test/features/status_flow_test.dart` (new)

**Interfaces:**
- Consumes: Task 16 and Task 17.
- Produces: `StatusRingFrame({required StatusRing ring, required Widget child, double width = 2.5, BorderRadius? radius})`.
  - When the ring is unseen, it draws a gradient from `OrbitTokens.accent` to `#FF9F0A`. Until Task 19 lands, use the current coral as the accent.
  - When seen, it uses `textMuted` at 50%. When there is no status, it draws nothing.
  - For a circle, pass `radius: null`; for a tile, pass the tile radius.

- [ ] **Step 1: Write failing tests.**
  - `posting a status uploads, posts and shows my ring`: pick, enter a caption, tap Post. Expect `POST /media/uploads` with `STATUS_PHOTO`, then `POST /me/statuses`, and the Me avatar shows an unseen-style ring.
  - `caption stops at 100 characters`.
  - `the eleventh status shows the limit message`: a 409 shows `statusLimitReached`.
  - `grid tile with UNSEEN status shows a gradient ring; tapping the ring opens the viewer; tapping elsewhere opens the profile`.
  - `ring turns grey after viewing without a refetch`.
- [ ] **Step 2:** Run `flutter test test/features/status_flow_test.dart`. Expect a FAIL.
- [ ] **Step 3:** Implement it.
- [ ] **Step 4:** Run the full mobile checks. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(mobile): post statuses and show status rings`

---

# Part 5: Visual refresh

### Task 19: Light and dark tokens following the phone

**Files:**
- Modify: `mobile/lib/app/theme.dart` (`OrbitTokens extends ThemeExtension<OrbitTokens>`, `buildOrbitTheme(Brightness)`, and removing `OrbitColors` once it has no users)
- Modify: `mobile/lib/app/app.dart` (`theme`, `darkTheme` and `themeMode: ThemeMode.system`)
- Modify: every file that hard-codes a colour (find them with `grep -rn "Color(0x\|Colors\.\(white\|black\)" lib --include=*.dart | grep -v theme.dart`). Photo scrims and glass may keep black and white with alpha; note them in a comment.
- Test: `mobile/test/app/theme_test.dart`

**Interfaces:**
- Produces: `OrbitTokens` fields `ground`, `surface`, `surfaceRaised`, `hairline`, `text`, `textMuted`, `accent`, `online`, `ringStart` and `ringEnd`, with the values from spec §7.1 exactly. `ringEnd = #FF9F0A`. `hairline` is `#38383A` (dark) or `#C6C6C8` (light), at alpha 0.6.
  - Read them with `context.tokens`, through an extension on `BuildContext` in `theme.dart`.
  - The `ColorScheme` maps `primary` to `accent`, `surface` to `ground`, `surfaceContainer` to `surface`, `surfaceContainerHighest` to `surfaceRaised`, `onSurface` to `text`, `onSurfaceVariant` to `textMuted` and `outline` to `hairline`.

- [ ] **Step 1: Write failing tests in `theme_test.dart`.**
  - `tokens match the spec in both modes`: check every hex value.
  - `text pairs meet WCAG AA`:
    - `text`/`ground`, `text`/`surface` and `textMuted`/`surface` are at least 4.5.
    - `accent` on `ground` is at least 3.0.
    - `onPrimary` on `accent` is at least 4.5.

    Compute this with a `contrastRatio(Color a, Color b)` helper in the test.
  - `app follows the platform brightness`: pumped with `platformBrightness: Brightness.light`, `Theme.of(context).brightness` is light.
  - `no hard-coded colours outside theme`: the test reads every `lib/**/*.dart` file except `theme.dart` and fails on `Color(0x` unless the same line holds the comment `// photo-overlay`.
- [ ] **Step 2:** Run `flutter test test/app/theme_test.dart`. Expect a FAIL.
- [ ] **Step 3:** Implement it, and replace the hard-coded colours. If `onPrimary` (white) on the light accent `#E8513D` fails 4.5, use black text on the accent in light mode, and note it in the theme.
- [ ] **Step 4:** Run the full mobile checks. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(mobile): add light and dark themes that follow the phone`

### Task 20: Frosted bars, large titles and type

**Files:**
- Create: `mobile/lib/core/widgets/glass_bar.dart`
- Modify: `mobile/lib/app/home_shell.dart` (the bottom navigation)
- Modify: `mobile/lib/app/theme.dart` (text theme: body 17, secondary 15, large title 34 bold, compact title 17 semibold; radii: sheets 20, cards 16, tiles 12; cards with no border)
- Modify: `mobile/lib/features/chat/presentation/inbox_screen.dart` and `mobile/lib/features/profile/presentation/me_screen.dart` (a `SliverAppBar.large` that collapses)
- Test: `mobile/test/app/navigation_test.dart`

**Interfaces:**
- Produces: `GlassBar({required Widget child})`, a `ClipRect` with `BackdropFilter` blur 20 over `surface` at alpha 0.72, with a top hairline. `HomeShell` sets `extendBody: true` and puts a `NavigationBar` inside `GlassBar` with no indicator, the selected icon in `accent`, and labels at 11 pt.

- [ ] **Step 1: Write failing tests.**
  - `bottom bar is frosted and has no pill indicator`: find a `BackdropFilter` under the `NavigationBar`, and the `NavigationBar` has `indicatorColor == Colors.transparent`.
  - `inbox title collapses when scrolled`: the 34 pt title is visible at the top; after a drag of 200 px, the 17 pt title is.
- [ ] **Step 2:** Run `flutter test test/app/navigation_test.dart`. Expect a FAIL.
- [ ] **Step 3:** Implement it. Re-run `test/app/small_screen_test.dart` to check that no layout overflows.
- [ ] **Step 4:** Run the full mobile checks. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(mobile): add frosted bars and large titles`

### Task 21: Grid tiles and Fresh faces

**Files:**
- Create: `mobile/lib/features/discovery/presentation/profile_tile.dart`
- Create: `mobile/lib/core/widgets/skeleton.dart` (an in-house shimmer, with no dependency)
- Modify: `mobile/lib/features/discovery/presentation/nearby_screen.dart` (3 columns, 2 px gutters, aspect ratio 0.8, edge to edge, `RefreshIndicator`, skeletons while loading, a hero tag `'profile-photo-${id}'`)
- Modify: `mobile/lib/core/widgets/profile_avatar.dart` (the no-photo placeholder becomes a two-stop gradient from the id hash with a large initial, replacing the person icon)
- Test: `mobile/test/features/discovery_flow_test.dart`

**Interfaces:**
- Consumes: `MediaImage` (Task 9), `StatusRingFrame` (Task 18) and `context.tokens` (Task 19).
- Produces: `ProfileTile({required Profile profile, required VoidCallback onOpen, required VoidCallback onOpenStatus})`.
  - A full-bleed photo with a bottom scrim (transparent → black 70%).
  - The name and age at 15 pt semibold, and the distance at 13 pt in white at 80%.
  - A green online dot (`tokens.online`).
  - A ring inset by 2.5 px.
  - A `Semantics` label: "{name}, {age}, {distance}, online, has a new status".

- [ ] **Step 1: Write failing tests.**
  - `tile shows name, age, distance and online dot over the photo`.
  - `member without photo shows a gradient and initial, not a person icon`: `find.byIcon(Icons.person_outline)` finds nothing.
  - `pull to refresh reloads the grid`: the fake grid endpoint is called twice.
  - `skeletons show while the grid loads`.
  - `tile semantics label reads naturally`.
- [ ] **Step 2:** Run `flutter test test/features/discovery_flow_test.dart`. Expect a FAIL.
- [ ] **Step 3:** Implement it.
- [ ] **Step 4:** Run the full mobile checks. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(mobile): redesign grid tiles with photos edge to edge`

### Task 22: Chat bubbles (time, ticks, grouping and days)

**Files:**
- Modify: `mobile/lib/features/chat/presentation/chat_items.dart` (grouping and day separators)
- Modify: `mobile/lib/features/chat/presentation/message_bubble.dart` (the time and ticks inside, and a tail only when not grouped with the next)
- Modify: `mobile/lib/features/chat/presentation/chat_screen.dart` (render `DaySeparatorItem`; the header opens the profile)
- Modify: `mobile/lib/l10n/app_en.arb`: `dayToday`, `dayYesterday`, plus semantics strings for the ticks: `tickSent`, `tickDelivered` and `tickRead`
- Test: `mobile/test/features/chat_flow_test.dart`

**Interfaces:**
- Consumes: `messageTime` (Task 1) and the `chatItems` types (Task 7).
- Produces:
  - `chatItems` now sets `groupedWithPrevious` and `groupedWithNext`: true when the sender is the same, the gap is 2 minutes or less, and no day boundary lies between.
  - It inserts `DaySeparatorItem` at each change of local calendar day.
  - `String dayLabel(BuildContext, DateTime localDay, DateTime now)` returns "Today", "Yesterday", the weekday within 6 days, or else `yMMMd`.
  - Ticks:
    - `pending` shows a clock icon.
    - `sent` shows one tick.
    - Delivered shows two grey ticks. The message model has no delivered state yet, so use `sent` until a delivered status exists; do not invent one.
    - `read` shows two accent ticks.
    - With read receipts off, `read` shows two grey ticks.

- [ ] **Step 1: Write failing tests.**
  - `messages within two minutes group and only the last has a tail`.
  - `day separator uses local midnight`: messages at local 23:59 and 00:01 show separators "Yesterday" and then "Today", with `now` at local 00:05.
  - `bubble shows local time and read ticks`.
  - `read receipts off shows grey ticks`.
  - `tapping the chat header opens the profile`.
- [ ] **Step 2:** Run `flutter test test/features/chat_flow_test.dart`. Expect a FAIL.
- [ ] **Step 3:** Implement it.
- [ ] **Step 4:** Run the full mobile checks. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(mobile): show times, ticks and day separators in chat`

### Task 23: Chat composer and photo mosaic

**Files:**
- Create: `mobile/lib/features/chat/presentation/composer.dart` (extracted from the `_Composer` part of `chat_screen.dart`)
- Create: `mobile/lib/features/chat/presentation/attach_sheet.dart`
- Modify: `mobile/lib/features/media/data/media_capture.dart` (`MediaPicker.pickPhotos({int limit = 10}): Future<List<PickedMedia>>` via `pickMultiImage(limit:)`, applying the same resizing and metadata stripping as `pickPhoto`)
- Modify: `mobile/lib/features/chat/presentation/chat_items.dart` (`PhotoMosaicItem` for 2 or more consecutive non-view-once photos from one sender within 2 minutes)
- Modify: `mobile/lib/features/chat/presentation/chat_screen.dart`
- Test: `mobile/test/features/chat_flow_test.dart` and `mobile/test/features/photo_metadata_test.dart`

**Interfaces:**
- Produces:
  - `Composer({required onSend, required onAttach, required onVoiceStart, required onVoiceStop, required onVoiceCancel, required onTyping})`.
    - A "+" button on the left.
    - A field that grows from 1 to 5 lines.
    - A trailing button that `AnimatedSwitcher`s between the mic (when the field is empty, or blank after trimming) and send.
  - `AttachSheet`: returns an `AttachChoice { photos, camera, viewOnce, album, location, quickPhrase }`. These are the existing behaviours plus multi-photos.
  - Picking photos sends each photo as its own PHOTO message, in order. No server change.
  - `PhotoMosaicItem` renders a 2×2 grid with "+N" on the 4th tile; tapping opens `openPhotos` at that photo.

- [ ] **Step 1: Write failing tests.**
  - `composer shows mic when empty and send when typing`.
  - `field grows to five lines then scrolls`.
  - `plus opens the attach sheet with six options`.
  - `picking three photos sends three photo messages in order`: the fake picker returns 3, and the fake gateway records 3 sends with ascending order.
  - `pickPhotos strips location metadata from every photo`: in `photo_metadata_test.dart`, with the existing GPS fixture.
  - `five consecutive photos show a mosaic with +1`.
- [ ] **Step 2:** Run `flutter test test/features/chat_flow_test.dart test/features/photo_metadata_test.dart`. Expect a FAIL.
- [ ] **Step 3:** Implement it.
- [ ] **Step 4:** Run the full mobile checks. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(mobile): add a lighter chat composer and photo mosaics`

### Task 24: Albums and profile photos, Instagram-smooth

**Files:**
- Modify: `mobile/lib/features/albums/presentation/album_screen.dart` (a 3-column edge-to-edge grid; tapping opens `openPhotos`; "Add photos" uses `pickPhotos(limit: 10)` with progress tiles per upload; long press enters selection mode with a Delete action)
- Modify: `mobile/lib/features/albums/presentation/albums_controller.dart` (`Future<void> addPhotos(String albumId, List<PickedMedia>)`, which uploads each photo and reports progress per item)
- Modify: `mobile/lib/features/discovery/presentation/profile_screen.dart` (a full-width pager with segment indicators at the top, details in a card overlapping the photo by 24 px, a hero from the grid tile, and tapping a photo opens `openPhotos`)
- Test: `mobile/test/features/me_flow_test.dart` and `mobile/test/features/discovery_flow_test.dart`

**Interfaces:**
- Consumes: `pickPhotos` (Task 23), `openPhotos` and `MediaImage` (Task 9), and the hero tag from Task 21.
- Produces: `AlbumUpload({String localId, Uint8List preview, double progress, bool failed})`, the album controller's per-item state.

- [ ] **Step 1: Write failing tests.**
  - `adding three photos shows three progress tiles then three photos`.
  - `a failed upload tile offers retry`.
  - `long-press selects photos and deletes them`: the fake API records 2 `DELETE /albums/{id}/photos/{mediaId}` calls.
  - `tapping an album photo opens the viewer at that photo`.
  - `profile shows one segment per photo and advances on tap`.
- [ ] **Step 2:** Run `flutter test test/features/me_flow_test.dart test/features/discovery_flow_test.dart`. Expect a FAIL.
- [ ] **Step 3:** Implement it.
- [ ] **Step 4:** Run the full mobile checks. Expect a PASS.
- [ ] **Step 5:** Commit: `feat(mobile): smoother albums and profile photos`

### Task 25: Golden tests and the two-phone retest

**Files:**
- Create: `mobile/test/goldens/main_screens_golden_test.dart`, with goldens under `mobile/test/goldens/`

- [ ] **Step 1: Write golden tests** for Nearby, Profile, Inbox, Chat, Me, the Status viewer and the Album, each in light and dark mode, at 393×852. Use the fake repositories and a fixed clock; network images use a fake image provider that returns a solid colour.
- [ ] **Step 2:** Run `flutter test --update-goldens test/goldens`. Review every generated image and check that none shows dark text on a dark background. Then run `flutter test test/goldens`, and expect a PASS.
- [ ] **Step 3: Run the full checks.**
  - Mobile: `dart format --set-exit-if-changed . && flutter analyze && flutter test`
  - Backend: `./gradlew spotlessCheck check`
  - Admin: `npm run lint && npm test -- --run`

  All must PASS. Report the real counts.
- [ ] **Step 4: Two-phone retest.** Restart the API and both apps (Robin on the iPhone 17 Pro, Sam on the iPhone 17 Pro Max), then work through spec §9:
  - Times are local.
  - Sam's 3rd wave to Robin is refused, with a countdown.
  - Robin's Me photo viewer: add, replace, make main and delete.
  - Sam posts a status; Robin sees an unseen ring, views it, and the ring turns grey; Sam's "Viewed by" shows Robin.
  - Sam deletes a status early.
  - Robin reports a status; it appears in the moderation console at `localhost:5174`.
  - Switch each simulator to light mode (`xcrun simctl ui <udid> appearance light`) and check every main screen.
  - Expiry: in the dev database, set one status's `expires_at` to the past, wait for the next reaper run, and check that the ring is gone and the image has been deleted.

  Record the results, with screenshots, for the user.
- [ ] **Step 5:** Commit: `test(mobile): add golden tests for main screens in both themes`

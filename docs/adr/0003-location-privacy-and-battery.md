# ADR-0003: Location handling — privacy-preserving and battery-light

- **Status:** Accepted
- **Date:** 2026-11-09

## Context

Location-based apps have repeatedly leaked users' exact positions through **trilateration**. An attacker spoofs their own position to three points and uses the exact distances the app shows to work out where a target is. For LGBTQ+ users in hostile places, that leak can put them in physical danger. Separately, apps that ask for continuous high-accuracy GPS drain the battery.

## Decision

1. **Snap on the server.** The server snaps each reported position to the centre of an H3 cell at resolution 8 (about 0.7 km² per cell), plus a stable per-user random offset inside the cell. The exact coordinates are never stored. They are used only during the request that converts them, then discarded.
2. **Show distances in buckets.** The API never returns a raw distance. It returns a bucket: `<1 km`, `1 km`, `2 km`, … `10 km`, `10+ km`. Users can also hide their distance entirely, and it is hidden by default in high-risk regions.
3. **Rate-limit and detect spoofing.** Location updates are limited to 1 per 60 seconds per account. A jump that would require travelling faster than 900 km/h is flagged. Users who keep "teleporting" have their discovery requests throttled. This makes trilateration slow and easy to detect.
4. **Use location only in the foreground.** The app asks for "While Using" permission only, and never for background location. It updates location when the app opens and after the user moves 500 m or more, using `LocationAccuracy.medium` and a `distanceFilter` of 500 m. There is no polling.
5. **Run no background work.** The WebSocket closes when the app goes to the background. Push notifications (FCM, and APNs through FCM) deliver messages while the app is in the background.

## Consequences

- Distance ordering is approximate within roughly a few hundred metres. That is acceptable for this product.
- Keeping one random offset per user stops attackers from averaging many readings to find the cell centre.
- We need a small policy table of high-risk countries that changes the defaults: hide distance, show a discreet app icon option, and show a safety notice.

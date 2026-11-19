# ADR-0006: Voice and video calls — WebRTC, always relayed

- **Status:** Accepted
- **Date:** 2026-11-17
- **Deciders:** Product owner, tech lead

## Context

The product owner has moved 1:1 voice and video calls into scope; the design doc had them as v2. On Orbit, a call must not undo the location privacy in ADR-0003. A direct peer-to-peer WebRTC connection exposes each person's public IP address, and an IP address reveals approximate location. That risk is serious for members in hostile places.

## Decision

1. **Media:** WebRTC through `flutter_webrtc`, audio with Opus and video with VP8/H.264, 1:1 only.
2. **Always relayed:** clients set `iceTransportPolicy: relay`, so every call goes through our **TURN** servers (coturn) and no host or server-reflexive ICE candidates are ever exchanged. TURN listens on TLS port 443 so calls also work on restrictive networks.
3. **Credentials:** the API issues short-lived TURN credentials for each call (the TURN REST API pattern, HMAC, 10-minute expiry). There are no static TURN passwords in the app.
4. **Signalling:** offer, answer and ICE messages travel over the existing chat WebSocket (ADR-0004) as `call.*` frames. The server checks every frame against the block list and both accounts' status.
5. **Consent:** someone can only call members they have already exchanged messages with. The recipient must accept the call. A block, ban or suspension ends any live call immediately.
6. **No recording:** the server keeps call metadata only (participants, start time, duration, end reason), for safety reports and call history. Media is never recorded or stored.
7. **Ringing:** CallKit (iOS) and ConnectionService (Android), so calls ring like phone calls. The incoming-call push carries no caller name unless message previews are turned on.

## Consequences

- TURN bandwidth is a real cost, since every byte of media is relayed. TURN usage gets per-region monitoring and alerts.
- Testing video needs physical devices; the iOS Simulator has no camera. Voice calls can be tested between the iOS Simulator and Chrome.
- Calls are delivered after media sharing and the admin console (Phase D in `docs/gap-analysis.md`).

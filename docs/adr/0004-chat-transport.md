# ADR-0004: Chat transport — WebSocket while foreground, push while background

- **Status:** Accepted
- **Date:** 2026-11-09

## Context

Chat must feel instant while the app is open and cost almost no battery when it is not. Polling wastes battery and adds server load.

## Decision

- **Foreground:** one authenticated WebSocket per device (`/ws/v1`) carrying a small JSON protocol: `msg.send`, `msg.ack`, `msg.new`, `msg.read`, `typing` and `presence`. We use plain Spring WebSocket handlers rather than STOMP, because the protocol is small and an explicit protocol is easier to version.
- **Fan-out:** instances fan messages out to each other through **Redis Pub/Sub**, keyed by the user's channel. Presence is stored in Redis with a time-to-live.
- **Persistence:** messages are stored in **PostgreSQL**, partitioned by month. Each message has an idempotency key (`client_msg_id`), so retries never create duplicates.
- **Background:** the server sends a push through FCM, which also covers APNs. The push carries only the message ID and sender display name, never the message text. Showing a preview is opt-in.
- **Catch-up:** when the app reconnects, it calls `GET /api/v1/conversations/{id}/messages?after={cursor}`.

## Consequences

- The client handles reconnect with exponential backoff and jitter.
- When load requires it, chat can move to a separate deployment. Kafka is not needed at the planned launch scale, so we will not add it yet.

-- Chat (ADR-0004): 1:1 conversations, per-member state and messages.

-- One row per pair of members; member_a sorts before member_b so each pair is unique.
CREATE TABLE conversation (
    id              UUID                     NOT NULL PRIMARY KEY,
    member_a        UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    member_b        UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    last_seq        BIGINT                   NOT NULL DEFAULT 0,
    last_message_at TIMESTAMP WITH TIME ZONE,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT conversation_pair_uk UNIQUE (member_a, member_b),
    CONSTRAINT conversation_order_ck CHECK (member_a < member_b)
);

CREATE INDEX conversation_member_b_idx ON conversation (member_b);

-- Each member's own view: what they've read, whether it's muted, and what they deleted.
CREATE TABLE conversation_member (
    conversation_id UUID    NOT NULL REFERENCES conversation (id) ON DELETE CASCADE,
    account_id      UUID    NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    last_read_seq   BIGINT  NOT NULL DEFAULT 0,
    cleared_seq     BIGINT  NOT NULL DEFAULT 0,
    muted           BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (conversation_id, account_id)
);

CREATE INDEX conversation_member_account_idx ON conversation_member (account_id);

CREATE TABLE message (
    id               UUID                     NOT NULL PRIMARY KEY,
    conversation_id  UUID                     NOT NULL REFERENCES conversation (id) ON DELETE CASCADE,
    seq              BIGINT                   NOT NULL,
    sender_id        UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    client_msg_id    VARCHAR(64)              NOT NULL,
    kind             VARCHAR(16)              NOT NULL,
    text             VARCHAR(2000),
    location_minutes SMALLINT,
    album_name       VARCHAR(60),
    created_at       TIMESTAMP WITH TIME ZONE NOT NULL,
    unsent_at        TIMESTAMP WITH TIME ZONE,
    -- Paging and catch-up by sequence number.
    CONSTRAINT message_seq_uk UNIQUE (conversation_id, seq),
    -- A retried send with the same client id never creates a second message.
    CONSTRAINT message_client_uk UNIQUE (sender_id, client_msg_id),
    CONSTRAINT message_kind_ck CHECK (kind IN ('TEXT', 'WAVE', 'LOCATION', 'ALBUM')),
    CONSTRAINT message_location_ck CHECK (location_minutes IS NULL OR location_minutes IN (15, 30, 60))
);

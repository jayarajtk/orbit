-- Media (design doc §7.4): uploads go straight to S3-compatible storage through presigned URLs.
-- This schema holds ownership, processing state and the scanner's decision; objects live under
-- opaque keys that never contain account ids.
CREATE TABLE media (
    id           UUID                     NOT NULL PRIMARY KEY,
    owner_id     UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    purpose      VARCHAR(16)              NOT NULL,
    kind         VARCHAR(8)               NOT NULL,
    status       VARCHAR(8)               NOT NULL,
    content_type VARCHAR(64)              NOT NULL,
    size_bytes   BIGINT                   NOT NULL,
    storage_key  VARCHAR(128)             NOT NULL,
    thumb_key    VARCHAR(128),
    width        INTEGER,
    height       INTEGER,
    duration_ms  INTEGER,
    -- Explicit but legal: allowed in private albums and chat, never as a public profile photo.
    private_only BOOLEAN                  NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at   TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT media_purpose_ck CHECK (purpose IN
        ('PROFILE_PHOTO', 'ALBUM_PHOTO', 'CHAT_PHOTO', 'CHAT_VIDEO', 'VOICE_NOTE')),
    CONSTRAINT media_kind_ck CHECK (kind IN ('PHOTO', 'VIDEO', 'AUDIO')),
    CONSTRAINT media_status_ck CHECK (status IN ('PENDING', 'READY', 'REJECTED')),
    CONSTRAINT media_size_ck CHECK (size_bytes > 0)
);

CREATE INDEX media_owner_created_idx ON media (owner_id, created_at);
-- Finds abandoned uploads for cleanup.
CREATE INDEX media_pending_created_idx ON media (created_at) WHERE status = 'PENDING';

-- Public profile photos in display order, at most six.
CREATE TABLE profile_photo (
    account_id UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    position   SMALLINT                 NOT NULL,
    media_id   UUID                     NOT NULL REFERENCES media (id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (account_id, position),
    CONSTRAINT profile_photo_media_uk UNIQUE (media_id),
    CONSTRAINT profile_photo_position_ck CHECK (position BETWEEN 0 AND 5)
);

CREATE TABLE album (
    id         UUID                     NOT NULL PRIMARY KEY,
    owner_id   UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    name       VARCHAR(60)              NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX album_owner_idx ON album (owner_id);

CREATE TABLE album_item (
    album_id   UUID                     NOT NULL REFERENCES album (id) ON DELETE CASCADE,
    media_id   UUID                     NOT NULL REFERENCES media (id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (album_id, media_id)
);

CREATE INDEX album_item_media_idx ON album_item (media_id);

-- Who may see an album, until when, and whether they may open it only once.
CREATE TABLE album_grant (
    album_id   UUID                     NOT NULL REFERENCES album (id) ON DELETE CASCADE,
    grantee_id UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITH TIME ZONE,
    view_once  BOOLEAN                  NOT NULL DEFAULT FALSE,
    viewed_at  TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (album_id, grantee_id)
);

CREATE INDEX album_grant_grantee_idx ON album_grant (grantee_id);

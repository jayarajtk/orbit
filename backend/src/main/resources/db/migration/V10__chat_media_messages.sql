-- Photo, video and voice messages, view-once photos, and albums shared by id.
-- Additive: every existing row stays valid, so a rolling deploy is safe (expand step).
ALTER TABLE message
    ADD COLUMN media_id  UUID REFERENCES media (id) ON DELETE SET NULL,
    ADD COLUMN album_id  UUID REFERENCES album (id) ON DELETE SET NULL,
    ADD COLUMN view_once BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN viewed_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE message DROP CONSTRAINT message_kind_ck;
ALTER TABLE message
    ADD CONSTRAINT message_kind_ck
        CHECK (kind IN ('TEXT', 'WAVE', 'LOCATION', 'ALBUM', 'PHOTO', 'VIDEO', 'VOICE'));

CREATE INDEX message_media_idx ON message (media_id) WHERE media_id IS NOT NULL;
CREATE INDEX message_album_idx ON message (album_id) WHERE album_id IS NOT NULL;

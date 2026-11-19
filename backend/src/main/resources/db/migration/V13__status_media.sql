-- Status photos (24-hour statuses) and a hold that keeps reported media from being purged.
-- Additive except for the widened purpose check, so a rolling deploy is safe (expand step).

-- Set when a report copies the media as evidence; purge then leaves it alone.
ALTER TABLE media ADD COLUMN evidence_hold BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE media DROP CONSTRAINT media_purpose_ck;
ALTER TABLE media
    ADD CONSTRAINT media_purpose_ck CHECK (purpose IN
        ('PROFILE_PHOTO', 'ALBUM_PHOTO', 'CHAT_PHOTO', 'CHAT_VIDEO', 'VOICE_NOTE', 'STATUS_PHOTO'));

-- A purge claims the row first, so a hold that arrives mid-purge is refused instead of
-- silently protecting a row whose objects are already gone.
ALTER TABLE media DROP CONSTRAINT media_status_ck;
ALTER TABLE media
    ADD CONSTRAINT media_status_ck CHECK (status IN
        ('PENDING', 'READY', 'REJECTED', 'REMOVED', 'PURGING'));

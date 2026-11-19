-- Safety: two-way blocks and member reports (design doc §6, §7.5).
CREATE TABLE block (
    blocker_id UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    blocked_id UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (blocker_id, blocked_id),
    CONSTRAINT block_not_self_ck CHECK (blocker_id <> blocked_id)
);

-- Blocks are checked in both directions on every read path.
CREATE INDEX block_blocked_idx ON block (blocked_id, blocker_id);

CREATE TABLE report (
    id          UUID                     NOT NULL PRIMARY KEY,
    reporter_id UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    subject_id  UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    reason      VARCHAR(16)              NOT NULL,
    details     VARCHAR(500)             NOT NULL DEFAULT '',
    status      VARCHAR(16)              NOT NULL DEFAULT 'OPEN',
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT report_reason_ck CHECK (reason IN ('FAKE', 'HARASSMENT', 'UNDERAGE', 'PHOTOS', 'THREAT')),
    CONSTRAINT report_status_ck CHECK (status IN ('OPEN', 'IN_REVIEW', 'ACTIONED', 'DISMISSED'))
);

-- Moderation queue: open reports, oldest first; per-subject history.
CREATE INDEX report_queue_idx ON report (status, created_at);
CREATE INDEX report_subject_idx ON report (subject_id, created_at);

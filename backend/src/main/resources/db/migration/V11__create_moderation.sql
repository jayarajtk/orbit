-- Moderation (ADR-0007): actions, appeals, evidence copied at report time, and an audit log.
-- Additive except for widened check constraints, so a rolling deploy is safe (expand step).

-- Suspensions end on their own; the job that lifts them finds them by this column.
ALTER TABLE account ADD COLUMN suspended_until TIMESTAMP WITH TIME ZONE;
CREATE INDEX account_suspension_idx ON account (suspended_until) WHERE status = 'SUSPENDED';

-- A photo a moderator removed: links stop working and it can't be attached again.
ALTER TABLE media DROP CONSTRAINT media_status_ck;
ALTER TABLE media
    ADD CONSTRAINT media_status_ck CHECK (status IN ('PENDING', 'READY', 'REJECTED', 'REMOVED'));

CREATE TABLE moderation_action (
    id              UUID                     NOT NULL PRIMARY KEY,
    subject_id      UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    kind            VARCHAR(16)              NOT NULL,
    policy          VARCHAR(24)              NOT NULL,
    -- Shown to the member; the note is for moderators only.
    member_message  VARCHAR(500)             NOT NULL DEFAULT '',
    internal_note   VARCHAR(1000)            NOT NULL DEFAULT '',
    suspended_until TIMESTAMP WITH TIME ZONE,
    media_id        UUID                     REFERENCES media (id) ON DELETE SET NULL,
    moderator       VARCHAR(255)             NOT NULL,
    -- Warnings: when the member saw it in the app.
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    -- The reinstate action that undid this one, if any.
    reversed_by     UUID                     REFERENCES moderation_action (id) ON DELETE SET NULL,
    created_at      TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at      TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT moderation_action_kind_ck
        CHECK (kind IN ('WARN', 'SUSPEND', 'BAN', 'REMOVE_PHOTO', 'DISMISS', 'REINSTATE')),
    CONSTRAINT moderation_action_policy_ck
        CHECK (policy IN ('FAKE_PROFILE', 'HARASSMENT', 'UNDERAGE', 'EXPLICIT_PHOTO', 'THREAT',
                          'SPAM', 'OTHER', 'NO_VIOLATION', 'APPEAL_GRANTED')),
    CONSTRAINT moderation_action_suspension_ck
        CHECK ((kind = 'SUSPEND') = (suspended_until IS NOT NULL)),
    CONSTRAINT moderation_action_photo_ck CHECK (kind <> 'REMOVE_PHOTO' OR media_id IS NOT NULL)
);

CREATE INDEX moderation_action_subject_idx ON moderation_action (subject_id, created_at);
-- Unread warnings, looked up on every app launch.
CREATE INDEX moderation_action_warning_idx ON moderation_action (subject_id)
    WHERE kind = 'WARN' AND acknowledged_at IS NULL;

-- Which moderator has a report open, and the action that resolved it.
ALTER TABLE report
    ADD COLUMN reviewer           VARCHAR(255),
    ADD COLUMN resolved_by_action UUID REFERENCES moderation_action (id) ON DELETE SET NULL;

-- One appeal per suspension or ban.
CREATE TABLE appeal (
    id               UUID                     NOT NULL PRIMARY KEY,
    action_id        UUID                     NOT NULL REFERENCES moderation_action (id) ON DELETE CASCADE,
    account_id       UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    text             VARCHAR(1000)            NOT NULL,
    status           VARCHAR(16)              NOT NULL DEFAULT 'OPEN',
    decided_by       VARCHAR(255),
    decision_message VARCHAR(500),
    decided_at       TIMESTAMP WITH TIME ZONE,
    created_at       TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at       TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT appeal_action_uk UNIQUE (action_id),
    CONSTRAINT appeal_status_ck CHECK (status IN ('OPEN', 'UPHELD', 'REVERSED'))
);

CREATE INDEX appeal_queue_idx ON appeal (status, created_at);
CREATE INDEX appeal_account_idx ON appeal (account_id);

-- Messages between reporter and reported member, copied when the report is filed so that
-- unsending can't destroy evidence. Rows never change; updated_at equals created_at.
CREATE TABLE report_evidence (
    report_id  UUID                     NOT NULL REFERENCES report (id) ON DELETE CASCADE,
    position   SMALLINT                 NOT NULL,
    message_id UUID                     NOT NULL,
    sender_id  UUID                     NOT NULL,
    kind       VARCHAR(16)              NOT NULL,
    text       VARCHAR(2000),
    media_id   UUID                     REFERENCES media (id) ON DELETE SET NULL,
    sent_at    TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (report_id, position)
);

-- Append-only record of what moderators did and looked at. No foreign key on the account, so
-- entries outlive account deletion. Rows never change; updated_at equals created_at.
CREATE TABLE admin_audit (
    id         UUID                     NOT NULL PRIMARY KEY,
    actor      VARCHAR(255)             NOT NULL,
    action     VARCHAR(32)              NOT NULL,
    account_id UUID,
    detail     VARCHAR(500)             NOT NULL DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX admin_audit_created_idx ON admin_audit (created_at);
CREATE INDEX admin_audit_account_idx ON admin_audit (account_id, created_at);

-- Moderators find members by the start of their display name.
CREATE INDEX profile_display_name_idx ON profile (lower(display_name) text_pattern_ops);

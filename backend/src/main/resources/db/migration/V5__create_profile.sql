-- Profile: what members show each other (design doc §6, PROFILE). Photos arrive with media.
CREATE TABLE profile (
    account_id     UUID                     NOT NULL PRIMARY KEY REFERENCES account (id) ON DELETE CASCADE,
    display_name   VARCHAR(30)              NOT NULL,
    bio            VARCHAR(280)             NOT NULL DEFAULT '',
    pronouns       VARCHAR(20)              NOT NULL DEFAULT '',
    height_cm      SMALLINT,
    relationship   VARCHAR(16),
    looking_for    TEXT[]                   NOT NULL DEFAULT '{}',
    tags           TEXT[]                   NOT NULL DEFAULT '{}',
    show_age       BOOLEAN                  NOT NULL DEFAULT TRUE,
    show_distance  BOOLEAN                  NOT NULL DEFAULT TRUE,
    last_active_at TIMESTAMP WITH TIME ZONE NOT NULL,
    version        BIGINT                   NOT NULL DEFAULT 0,
    created_at     TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at     TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT profile_height_ck CHECK (height_cm IS NULL OR height_cm BETWEEN 120 AND 230),
    CONSTRAINT profile_relationship_ck
        CHECK (relationship IS NULL OR relationship IN ('SINGLE', 'DATING', 'PARTNERED', 'OPEN'))
);

-- Grid filters: "looking for" overlap and "online now".
CREATE INDEX profile_looking_for_idx ON profile USING GIN (looking_for);
CREATE INDEX profile_last_active_idx ON profile (last_active_at);

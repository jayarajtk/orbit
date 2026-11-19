-- Push notification targets (design doc §6, DEVICE).
CREATE TABLE device (
    id           UUID                     NOT NULL PRIMARY KEY,
    account_id   UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    platform     VARCHAR(8)               NOT NULL,
    push_token   VARCHAR(512)             NOT NULL,
    created_at   TIMESTAMP WITH TIME ZONE NOT NULL,
    last_seen_at TIMESTAMP WITH TIME ZONE NOT NULL,
    -- A token belongs to one install; re-registering moves it to the current account.
    CONSTRAINT device_token_uk UNIQUE (push_token),
    CONSTRAINT device_platform_ck CHECK (platform IN ('IOS', 'ANDROID', 'WEB'))
);

CREATE INDEX device_account_idx ON device (account_id);

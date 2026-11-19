-- Discovery: snapped member locations (ADR-0003) and favorites (design doc §6).
-- Only the snapped point is stored; the exact position never reaches the database.
CREATE TABLE user_location (
    account_id UUID                     NOT NULL PRIMARY KEY REFERENCES account (id) ON DELETE CASCADE,
    point      GEOGRAPHY(POINT, 4326)   NOT NULL,
    h3_cell    VARCHAR(16)              NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Nearest-neighbour grid query (ORDER BY point <-> me) and ST_DWithin.
CREATE INDEX user_location_point_idx ON user_location USING GIST (point);
CREATE INDEX user_location_h3_idx ON user_location (h3_cell);

CREATE TABLE favorite (
    owner_id   UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    target_id  UUID                     NOT NULL REFERENCES account (id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    PRIMARY KEY (owner_id, target_id),
    CONSTRAINT favorite_not_self_ck CHECK (owner_id <> target_id)
);

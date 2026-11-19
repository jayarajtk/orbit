-- Identity: one Orbit account per sign-in identity (design doc §6, ACCOUNT).
CREATE TABLE account (
    id          UUID                     NOT NULL PRIMARY KEY,
    idp_subject VARCHAR(255)             NOT NULL,
    birth_date  DATE                     NOT NULL,
    status      VARCHAR(16)              NOT NULL,
    version     BIGINT                   NOT NULL DEFAULT 0,
    created_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at  TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT account_idp_subject_uk UNIQUE (idp_subject),
    CONSTRAINT account_status_ck CHECK (status IN ('ONBOARDING', 'ACTIVE', 'SUSPENDED', 'BANNED', 'DELETING'))
);

-- Transactional outbox for cross-module domain events (Spring Modulith JPA event registry).
-- Columns mirror org.springframework.modulith.events.jpa.JpaEventPublication (Modulith 2.1).
CREATE TABLE event_publication (
    id                     UUID                     NOT NULL PRIMARY KEY,
    listener_id            VARCHAR(512)             NOT NULL,
    event_type             VARCHAR(512)             NOT NULL,
    serialized_event       TEXT                     NOT NULL,
    publication_date       TIMESTAMP WITH TIME ZONE NOT NULL,
    completion_date        TIMESTAMP WITH TIME ZONE,
    status                 VARCHAR(16),
    completion_attempts    INTEGER                  NOT NULL DEFAULT 0,
    last_resubmission_date TIMESTAMP WITH TIME ZONE
);

-- Incomplete publications are re-submitted on restart; this keeps that scan cheap.
CREATE INDEX event_publication_incomplete_idx
    ON event_publication (publication_date)
    WHERE completion_date IS NULL;

-- Only used if spring.modulith.events.completion-mode is switched to ARCHIVE.
CREATE TABLE event_publication_archive (LIKE event_publication INCLUDING ALL);

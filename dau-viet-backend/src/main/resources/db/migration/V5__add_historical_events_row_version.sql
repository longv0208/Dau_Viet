-- Dấu Việt MVP | V5 | Optimistic-lock column for historical_events (TASK-0008).
ALTER TABLE historical_events
    ADD COLUMN row_version BIGINT NOT NULL DEFAULT 0;

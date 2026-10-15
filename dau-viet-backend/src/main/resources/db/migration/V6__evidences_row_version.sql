-- Dấu Việt MVP | V6 | TASK-0009 — optimistic-lock parity for evidence authoring.
ALTER TABLE evidences ADD COLUMN row_version BIGINT NOT NULL DEFAULT 0;

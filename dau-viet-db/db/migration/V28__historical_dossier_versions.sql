-- Dau Viet | V28 | GAME-06 Admin dossier versioning.
-- historical_dossier_versions: append-only snapshot cua moi lan publish —
-- user_dossier_unlocks.dossier_version pin content admin da kiem duyet,
-- doc-side co the render dung version learner da mo khoa.
-- row_version tren historical_dossiers: optimistic lock cho PUT admin
-- (expectedRowVersion) — tranh two-tab overwrite.

ALTER TABLE historical_dossiers
    ADD COLUMN row_version BIGINT NOT NULL DEFAULT 0;

CREATE TABLE historical_dossier_versions (
    id UUID PRIMARY KEY,
    dossier_id UUID NOT NULL REFERENCES historical_dossiers(id),
    dossier_version INTEGER NOT NULL,
    dossier_type VARCHAR(16) NOT NULL,
    title VARCHAR(255) NOT NULL,
    summary TEXT,
    description TEXT,
    source_json JSONB,
    asset_id UUID,
    status VARCHAR(16) NOT NULL,
    published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_by UUID REFERENCES users(id),
    CONSTRAINT chk_dv_type CHECK (
        dossier_type IN ('PERSON','LOCATION','ARTIFACT','CONTEXT')),
    CONSTRAINT chk_dv_status CHECK (status IN ('PUBLISHED','ARCHIVED')),
    CONSTRAINT chk_dv_source CHECK (
        source_json IS NULL OR jsonb_typeof(source_json) = 'object'),
    CONSTRAINT ux_dossier_version UNIQUE (dossier_id, dossier_version)
);
CREATE INDEX idx_dv_dossier ON historical_dossier_versions(dossier_id);

-- Backfill version hien tai cho cac dossier PUBLISHED co san tu V22 —
-- learner da unlock pin version nay, can snapshot de doc-side truy vet.
INSERT INTO historical_dossier_versions
    (id, dossier_id, dossier_version, dossier_type, title, summary,
     description, source_json, asset_id, status, published_at, published_by)
SELECT gen_random_uuid(), id, dossier_version, dossier_type, title, summary,
       description, source_json, asset_id, status, updated_at, created_by
  FROM historical_dossiers
 WHERE status = 'PUBLISHED'
   AND NOT EXISTS (
       SELECT 1 FROM historical_dossier_versions v
        WHERE v.dossier_id = historical_dossiers.id
          AND v.dossier_version = historical_dossiers.dossier_version);

-- Dấu Việt MVP | V3 | Lesson builder + publishing + source-backed evidence.
-- Draft and published Stage/Activity configurations are JSONB (DATABASE_DESIGN.md §2).
CREATE TABLE assets (
    id UUID PRIMARY KEY,
    storage_key VARCHAR(512) NOT NULL UNIQUE,
    original_filename VARCHAR(255),
    mime_type VARCHAR(160) NOT NULL,
    size_bytes BIGINT NOT NULL CHECK (size_bytes >= 0),
    checksum_sha256 CHAR(64),
    state VARCHAR(24) NOT NULL DEFAULT 'ACTIVE',
    alt_text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID REFERENCES users(id),
    retired_at TIMESTAMPTZ,
    CONSTRAINT chk_asset_state CHECK (state IN ('UPLOADING','ACTIVE','RETIRED','FAILED'))
);
CREATE INDEX idx_assets_state ON assets(state);

CREATE TABLE evidences (
    id UUID PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES historical_events(id),
    title VARCHAR(255) NOT NULL,
    evidence_type VARCHAR(48) NOT NULL,
    description TEXT,
    source_title VARCHAR(255) NOT NULL,
    source_author VARCHAR(255),
    source_url TEXT,
    source_citation TEXT,
    source_published_at DATE,
    reliability VARCHAR(24),
    relevance TEXT,
    asset_id UUID REFERENCES assets(id),
    status VARCHAR(24) NOT NULL DEFAULT 'DRAFT',
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_evidence_status CHECK (status IN ('DRAFT','APPROVED','ARCHIVED')),
    CONSTRAINT chk_evidence_reliability CHECK (reliability IS NULL OR reliability IN ('HIGH','MEDIUM','LOW','UNASSESSED'))
);
CREATE INDEX idx_evidence_event_status ON evidences(event_id, status);
CREATE INDEX idx_evidence_asset ON evidences(asset_id);

CREATE TABLE lesson_templates (
    id UUID PRIMARY KEY,
    code VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    schema_version INTEGER NOT NULL CHECK (schema_version >= 1),
    preset_json JSONB NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_template_json CHECK (jsonb_typeof(preset_json) = 'object')
);

CREATE TABLE lessons (
    id UUID PRIMARY KEY,
    event_id UUID NOT NULL REFERENCES historical_events(id),
    template_id UUID NOT NULL REFERENCES lesson_templates(id),
    title VARCHAR(255) NOT NULL,
    central_question TEXT NOT NULL,
    objectives_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    draft_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    status VARCHAR(24) NOT NULL DEFAULT 'DRAFT',
    current_version_id UUID,
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    row_version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_lesson_status CHECK (status IN ('DRAFT','PUBLISHED','ARCHIVED')),
    CONSTRAINT chk_lesson_objectives CHECK (jsonb_typeof(objectives_json) = 'array'),
    CONSTRAINT chk_lesson_draft CHECK (jsonb_typeof(draft_json) = 'object'),
    CONSTRAINT chk_lesson_published_version CHECK (status <> 'PUBLISHED' OR current_version_id IS NOT NULL)
);
CREATE INDEX idx_lessons_event_status ON lessons(event_id, status);
CREATE INDEX idx_lessons_template ON lessons(template_id);

CREATE TABLE lesson_versions (
    id UUID PRIMARY KEY,
    lesson_id UUID NOT NULL REFERENCES lessons(id),
    version_no INTEGER NOT NULL CHECK (version_no >= 1),
    schema_version INTEGER NOT NULL CHECK (schema_version >= 1),
    snapshot_json JSONB NOT NULL,
    published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_by UUID NOT NULL REFERENCES users(id),
    UNIQUE (lesson_id, version_no),
    UNIQUE (id, lesson_id),
    CONSTRAINT chk_lesson_snapshot CHECK (jsonb_typeof(snapshot_json) = 'object')
);
CREATE INDEX idx_version_lesson_published ON lesson_versions(lesson_id, published_at DESC);
-- The current published version must belong to the SAME lesson.
ALTER TABLE lessons ADD CONSTRAINT fk_lessons_current_own_version
    FOREIGN KEY (current_version_id, id) REFERENCES lesson_versions(id, lesson_id)
    DEFERRABLE INITIALLY IMMEDIATE;

-- Published snapshot is immutable; new publication inserts a new version.
CREATE FUNCTION prevent_lesson_version_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'lesson_versions are immutable; publish a new version instead';
END;
$$;
CREATE TRIGGER trg_lesson_versions_immutable
    BEFORE UPDATE OR DELETE ON lesson_versions
    FOR EACH ROW EXECUTE FUNCTION prevent_lesson_version_mutation();

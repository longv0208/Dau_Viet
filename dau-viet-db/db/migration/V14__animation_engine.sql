-- Dấu Việt | V14 | Data-driven Historical Animation Engine.
-- Animation Template -> Animation Scene -> Animation Scene Version -> Lesson Version.
-- Scene drafts are JSONB; published manifests live in animation_scene_versions
-- (immutable, same pattern as lesson_versions V3). No cascade delete of
-- published content: every FK that could point at a version is plain REFERENCES.

CREATE TABLE animation_templates (
    id UUID PRIMARY KEY,
    code VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    renderer_code VARCHAR(48) NOT NULL,
    renderer_version INTEGER NOT NULL DEFAULT 1 CHECK (renderer_version >= 1),
    schema_version INTEGER NOT NULL CHECK (schema_version >= 1),
    capabilities_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    default_config_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    thumbnail_asset_id UUID REFERENCES assets(id),
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_animation_tpl_capabilities CHECK (jsonb_typeof(capabilities_json) = 'object'),
    CONSTRAINT chk_animation_tpl_default_config CHECK (jsonb_typeof(default_config_json) = 'object')
);
CREATE INDEX idx_animation_tpl_renderer ON animation_templates(renderer_code, enabled);

CREATE TABLE animation_scenes (
    id UUID PRIMARY KEY,
    template_id UUID NOT NULL REFERENCES animation_templates(id),
    event_id UUID REFERENCES historical_events(id),
    title VARCHAR(255) NOT NULL,
    draft_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    status VARCHAR(24) NOT NULL DEFAULT 'DRAFT',
    current_version_id UUID,
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    row_version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT chk_animation_scene_status CHECK (status IN ('DRAFT','PUBLISHED','ARCHIVED')),
    CONSTRAINT chk_animation_scene_draft CHECK (jsonb_typeof(draft_json) = 'object'),
    CONSTRAINT chk_animation_scene_published_version
        CHECK (status <> 'PUBLISHED' OR current_version_id IS NOT NULL)
);
CREATE INDEX idx_animation_scenes_event_status ON animation_scenes(event_id, status);
CREATE INDEX idx_animation_scenes_template ON animation_scenes(template_id);

CREATE TABLE animation_scene_versions (
    id UUID PRIMARY KEY,
    scene_id UUID NOT NULL REFERENCES animation_scenes(id),
    version_no INTEGER NOT NULL CHECK (version_no >= 1),
    schema_version INTEGER NOT NULL CHECK (schema_version >= 1),
    renderer_code VARCHAR(48) NOT NULL,
    renderer_version INTEGER NOT NULL CHECK (renderer_version >= 1),
    snapshot_json JSONB NOT NULL,
    manifest_checksum CHAR(64) NOT NULL,
    published_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    published_by UUID NOT NULL REFERENCES users(id),
    UNIQUE (scene_id, version_no),
    UNIQUE (id, scene_id),
    CONSTRAINT chk_animation_snapshot CHECK (jsonb_typeof(snapshot_json) = 'object')
);
CREATE INDEX idx_anim_version_scene_published
    ON animation_scene_versions(scene_id, published_at DESC);

-- The current published version must belong to the SAME scene.
ALTER TABLE animation_scenes ADD CONSTRAINT fk_anim_scenes_current_own_version
    FOREIGN KEY (current_version_id, id)
    REFERENCES animation_scene_versions(id, scene_id)
    DEFERRABLE INITIALLY IMMEDIATE;

-- Published manifests are immutable; re-publish inserts a new version.
CREATE FUNCTION prevent_animation_scene_version_mutation() RETURNS trigger
    LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'animation_scene_versions are immutable; publish a new version instead';
END;
$$;
CREATE TRIGGER trg_animation_scene_versions_immutable
    BEFORE UPDATE OR DELETE ON animation_scene_versions
    FOR EACH ROW EXECUTE FUNCTION prevent_animation_scene_version_mutation();

-- Asset references recorded at publish time: an asset cannot be retired while
-- a published manifest still references it (checked by application layer,
-- indexed here for the in-use lookup).
CREATE TABLE animation_scene_asset_refs (
    scene_version_id UUID NOT NULL REFERENCES animation_scene_versions(id),
    asset_id UUID NOT NULL REFERENCES assets(id),
    role VARCHAR(48) NOT NULL,
    PRIMARY KEY (scene_version_id, asset_id, role)
);
CREATE INDEX idx_anim_asset_refs_asset ON animation_scene_asset_refs(asset_id);

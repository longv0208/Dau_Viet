--- Dấu Việt | V19 | HTML WebView animation scenes.
--- One generic HTML_WEBVIEW renderer/template; admins import a single
--- self-contained .html file per scene. Draft HTML is mutable (re-uploadable);
--- published versions copy the bytes into an immutable side table so old
--- lesson versions keep rendering the exact HTML they pinned.
--- Full bytes live OUTSIDE animation_scene_versions.snapshot_json — the
--- snapshot only carries metadata (filename/size/sha256).

-- Shared template: one row, every HTML scene binds to it.
INSERT INTO animation_templates (
    id, code, name, description,
    renderer_code, renderer_version, schema_version,
    capabilities_json, default_config_json, enabled
) VALUES (
    'd7a11000-0000-4000-8000-000000000001',
    'html-webview',
    'Hoạt họa HTML',
    'Self-contained HTML file rendered inside an app WebView',
    'HTML_WEBVIEW', 1, 2,
    '{"html": true}'::jsonb,
    '{"schemaVersion": 2, "rendererCode": "HTML_WEBVIEW", "rendererVersion": 1}'::jsonb,
    TRUE
) ON CONFLICT (code) DO NOTHING;

-- Mutable draft HTML, 1:1 with the scene. Re-upload replaces the row.
CREATE TABLE animation_scene_html (
    scene_id UUID PRIMARY KEY REFERENCES animation_scenes(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    sha256 VARCHAR(64) NOT NULL,
    size_bytes BIGINT NOT NULL CHECK (size_bytes > 0),
    original_filename VARCHAR(255),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Immutable published HTML, 1:1 with a scene version. Bytes never change
-- after publish: a lesson snapshot pinned to version N keeps working even
-- after the draft is replaced and vN+1 is published.
CREATE TABLE animation_scene_version_html (
    version_id UUID PRIMARY KEY REFERENCES animation_scene_versions(id) ON DELETE RESTRICT,
    content TEXT NOT NULL,
    sha256 VARCHAR(64) NOT NULL,
    size_bytes BIGINT NOT NULL CHECK (size_bytes > 0),
    original_filename VARCHAR(255)
);

-- Same immutability rule as animation_scene_versions (V14). Cloned function
-- so the error names the right table.
CREATE FUNCTION prevent_animation_scene_version_html_mutation() RETURNS trigger
    LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'animation_scene_version_html is immutable; publish a new version instead';
END;
$$;
CREATE TRIGGER trg_animation_scene_version_html_immutable
    BEFORE UPDATE OR DELETE ON animation_scene_version_html
    FOR EACH ROW EXECUTE FUNCTION prevent_animation_scene_version_html_mutation();

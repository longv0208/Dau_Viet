-- Extend PATH-01 in place. Legacy nodes had no unlock semantics.
ALTER TABLE learning_path_versions ADD COLUMN revision BIGINT NOT NULL DEFAULT 0;
ALTER TABLE learning_path_event_nodes ADD COLUMN participation_type VARCHAR(24)
    NOT NULL DEFAULT 'EXPLORATION_ONLY'
    CHECK (participation_type IN ('REQUIRED', 'EXPLORATION_ONLY'));

-- Full-list reorder may swap occupied positions inside one transaction.
ALTER TABLE learning_path_chapters DROP CONSTRAINT ux_path_chapter_version_sort,
    ADD CONSTRAINT ux_path_chapter_version_sort UNIQUE (path_version_id, sort_order) DEFERRABLE;
ALTER TABLE learning_path_event_nodes DROP CONSTRAINT ux_path_event_node_chapter_sort,
    ADD CONSTRAINT ux_path_event_node_chapter_sort UNIQUE (chapter_id, sort_order) DEFERRABLE;
ALTER TABLE learning_path_lesson_nodes DROP CONSTRAINT ux_path_lesson_node_sort,
    ADD CONSTRAINT ux_path_lesson_node_sort UNIQUE (event_node_id, sort_order) DEFERRABLE;

-- Canonical identity is data instead of event-specific Java branches.
CREATE TABLE historical_event_canonical_aliases (
    alias_event_id UUID PRIMARY KEY REFERENCES historical_events(id),
    canonical_event_id UUID NOT NULL REFERENCES historical_events(id),
    CHECK (alias_event_id <> canonical_event_id)
);
INSERT INTO historical_event_canonical_aliases(alias_event_id, canonical_event_id)
SELECT alias.id, canonical.id FROM (VALUES
    ('khoi-nghia-hai-ba-trung-40', 'hai-ba-trung-40'),
    ('history-thang-long-1010', 'ly-thai-to-1010')
) AS pair(alias_slug, canonical_slug)
JOIN historical_events alias ON alias.slug = pair.alias_slug
JOIN historical_events canonical ON canonical.slug = pair.canonical_slug;

CREATE OR REPLACE FUNCTION assert_learning_path_draft(target_id UUID)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_status VARCHAR(24);
BEGIN
    SELECT status INTO v_status FROM learning_path_versions WHERE id = target_id FOR UPDATE;
    IF v_status IN ('PUBLISHED', 'ARCHIVED') THEN
        RAISE EXCEPTION 'Cannot modify nodes of a % learning path version', v_status;
    END IF;
END;
$$;

-- Check both parents on reparenting, closing the published-to-draft move loophole.
CREATE OR REPLACE FUNCTION prevent_published_path_chapter_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN PERFORM assert_learning_path_draft(OLD.path_version_id); END IF;
    IF TG_OP <> 'DELETE' THEN PERFORM assert_learning_path_draft(NEW.path_version_id); RETURN NEW; END IF;
    RETURN OLD;
END;
$$;

CREATE OR REPLACE FUNCTION prevent_published_path_event_node_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN PERFORM assert_learning_path_draft(OLD.path_version_id); END IF;
    IF TG_OP <> 'DELETE' THEN PERFORM assert_learning_path_draft(NEW.path_version_id); RETURN NEW; END IF;
    RETURN OLD;
END;
$$;

CREATE OR REPLACE FUNCTION prevent_published_path_lesson_node_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE target_id UUID;
BEGIN
    IF TG_OP <> 'INSERT' THEN
        SELECT path_version_id INTO target_id FROM learning_path_event_nodes WHERE id = OLD.event_node_id;
        PERFORM assert_learning_path_draft(target_id);
    END IF;
    IF TG_OP <> 'DELETE' THEN
        SELECT path_version_id INTO target_id FROM learning_path_event_nodes WHERE id = NEW.event_node_id;
        PERFORM assert_learning_path_draft(target_id);
        RETURN NEW;
    END IF;
    RETURN OLD;
END;
$$;

CREATE OR REPLACE FUNCTION prevent_published_path_version_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status IN ('PUBLISHED', 'ARCHIVED') THEN
        IF (to_jsonb(NEW) - 'status' - 'updated_at') = (to_jsonb(OLD) - 'status' - 'updated_at')
           AND (NEW.status = OLD.status OR (OLD.status = 'PUBLISHED' AND NEW.status = 'ARCHIVED')) THEN
            RETURN NEW;
        END IF;
        RAISE EXCEPTION 'Published and archived learning path versions are immutable';
    END IF;
    RETURN NEW;
END;
$$;

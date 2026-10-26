-- Dấu Việt | V34 | Learning Path 2.0 Immutability Triggers (Child Nodes & Version Protection)

-- ============================================================================
-- 1. UPDATE TRIGGER ON learning_path_versions
-- ============================================================================
CREATE OR REPLACE FUNCTION prevent_published_path_version_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status IN ('PUBLISHED', 'ARCHIVED') THEN
        -- Cho phép chuyển trạng thái PUBLISHED -> ARCHIVED khi nội dung không đổi
        IF OLD.status = 'PUBLISHED' AND NEW.status = 'ARCHIVED'
           AND OLD.title = NEW.title
           AND OLD.description IS NOT DISTINCT FROM NEW.description
           AND OLD.path_code = NEW.path_code
           AND OLD.version_no = NEW.version_no THEN
            RETURN NEW;
        END IF;

        -- Cho phép chạm updated_at nếu không đổi nội dung hoặc trạng thái
        IF OLD.title = NEW.title
           AND OLD.description IS NOT DISTINCT FROM NEW.description
           AND OLD.path_code = NEW.path_code
           AND OLD.version_no = NEW.version_no
           AND OLD.status = NEW.status THEN
            RETURN NEW;
        END IF;

        RAISE EXCEPTION 'learning_path_versions row in % status is immutable; publish a new version instead', OLD.status;
    END IF;
    RETURN NEW;
END;
$$;

-- Ngăn DELETE đối với version đang ở PUBLISHED hoặc ARCHIVED
CREATE OR REPLACE FUNCTION prevent_published_path_version_deletion()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.status IN ('PUBLISHED', 'ARCHIVED') THEN
        RAISE EXCEPTION 'Cannot delete learning_path_versions in % status', OLD.status;
    END IF;
    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_learning_path_version_prevent_delete ON learning_path_versions;
CREATE TRIGGER trg_learning_path_version_prevent_delete
    BEFORE DELETE ON learning_path_versions
    FOR EACH ROW EXECUTE FUNCTION prevent_published_path_version_deletion();

-- ============================================================================
-- 2. IMMUTABILITY TRIGGER ON learning_path_chapters
-- ============================================================================
CREATE OR REPLACE FUNCTION prevent_published_path_chapter_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    target_version_id UUID;
    v_status VARCHAR(24);
BEGIN
    IF TG_OP = 'DELETE' THEN
        target_version_id := OLD.path_version_id;
    ELSE
        target_version_id := NEW.path_version_id;
    END IF;

    SELECT status INTO v_status FROM learning_path_versions WHERE id = target_version_id;
    IF v_status IN ('PUBLISHED', 'ARCHIVED') THEN
        RAISE EXCEPTION 'Cannot modify chapters of a % learning path version', v_status;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_learning_path_chapter_immutable ON learning_path_chapters;
CREATE TRIGGER trg_learning_path_chapter_immutable
    BEFORE INSERT OR UPDATE OR DELETE ON learning_path_chapters
    FOR EACH ROW EXECUTE FUNCTION prevent_published_path_chapter_mutation();

-- ============================================================================
-- 3. IMMUTABILITY TRIGGER ON learning_path_event_nodes
-- ============================================================================
CREATE OR REPLACE FUNCTION prevent_published_path_event_node_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    target_version_id UUID;
    v_status VARCHAR(24);
BEGIN
    IF TG_OP = 'DELETE' THEN
        target_version_id := OLD.path_version_id;
    ELSE
        target_version_id := NEW.path_version_id;
    END IF;

    SELECT status INTO v_status FROM learning_path_versions WHERE id = target_version_id;
    IF v_status IN ('PUBLISHED', 'ARCHIVED') THEN
        RAISE EXCEPTION 'Cannot modify event nodes of a % learning path version', v_status;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_learning_path_event_node_immutable ON learning_path_event_nodes;
CREATE TRIGGER trg_learning_path_event_node_immutable
    BEFORE INSERT OR UPDATE OR DELETE ON learning_path_event_nodes
    FOR EACH ROW EXECUTE FUNCTION prevent_published_path_event_node_mutation();

-- ============================================================================
-- 4. IMMUTABILITY TRIGGER ON learning_path_lesson_nodes
-- ============================================================================
CREATE OR REPLACE FUNCTION prevent_published_path_lesson_node_mutation()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    target_event_node_id UUID;
    v_status VARCHAR(24);
BEGIN
    IF TG_OP = 'DELETE' THEN
        target_event_node_id := OLD.event_node_id;
    ELSE
        target_event_node_id := NEW.event_node_id;
    END IF;

    SELECT v.status INTO v_status
    FROM learning_path_event_nodes e
    JOIN learning_path_versions v ON v.id = e.path_version_id
    WHERE e.id = target_event_node_id;

    IF v_status IN ('PUBLISHED', 'ARCHIVED') THEN
        RAISE EXCEPTION 'Cannot modify lesson nodes of a % learning path version', v_status;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_learning_path_lesson_node_immutable ON learning_path_lesson_nodes;
CREATE TRIGGER trg_learning_path_lesson_node_immutable
    BEFORE INSERT OR UPDATE OR DELETE ON learning_path_lesson_nodes
    FOR EACH ROW EXECUTE FUNCTION prevent_published_path_lesson_node_mutation();

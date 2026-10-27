-- Serialize alias graph writers. Updating a real row also rejects a stale
-- REPEATABLE READ transaction instead of validating against an old graph.
CREATE TABLE historical_event_alias_guard (
    singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (singleton),
    revision BIGINT NOT NULL DEFAULT 0
);
INSERT INTO historical_event_alias_guard(singleton) VALUES (TRUE);

CREATE FUNCTION serialize_historical_event_aliases()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    UPDATE historical_event_alias_guard SET revision = revision + 1 WHERE singleton;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_historical_event_alias_lock
    BEFORE INSERT OR UPDATE OR DELETE ON historical_event_canonical_aliases
    FOR EACH STATEMENT EXECUTE FUNCTION serialize_historical_event_aliases();

CREATE FUNCTION reject_historical_event_alias_cycles()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (
        WITH RECURSIVE reachable(origin, target) AS (
            SELECT alias_event_id, canonical_event_id FROM historical_event_canonical_aliases
            UNION
            SELECT r.origin, a.canonical_event_id
            FROM reachable r
            JOIN historical_event_canonical_aliases a ON a.alias_event_id = r.target
        )
        SELECT 1 FROM reachable WHERE origin = target
    ) THEN
        RAISE EXCEPTION 'Historical event canonical aliases cannot contain cycles'
            USING ERRCODE = '23514';
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_historical_event_alias_cycle
    AFTER INSERT OR UPDATE ON historical_event_canonical_aliases
    FOR EACH STATEMENT EXECUTE FUNCTION reject_historical_event_alias_cycles();

-- Validate pre-existing registry entries as well; no event or path identity changes.
UPDATE historical_event_canonical_aliases SET canonical_event_id = canonical_event_id;

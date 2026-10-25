--
-- PostgreSQL database dump
--

\restrict XvJrgfS4ENlcHLRVfcBumvu1UewAlLBl2b2JL4JqK0kyvWW8LCNCPVU5peBQe9V

-- Dumped from database version 16.14
-- Dumped by pg_dump version 16.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.user_inventory DROP CONSTRAINT IF EXISTS user_inventory_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.user_inventory DROP CONSTRAINT IF EXISTS user_inventory_source_lesson_id_fkey;
ALTER TABLE IF EXISTS ONLY public.user_inventory DROP CONSTRAINT IF EXISTS user_inventory_source_attempt_id_fkey;
ALTER TABLE IF EXISTS ONLY public.user_inventory DROP CONSTRAINT IF EXISTS user_inventory_item_id_fkey;
ALTER TABLE IF EXISTS ONLY public.user_evidence DROP CONSTRAINT IF EXISTS user_evidence_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.user_evidence DROP CONSTRAINT IF EXISTS user_evidence_learner_attempt_id_fkey;
ALTER TABLE IF EXISTS ONLY public.user_evidence DROP CONSTRAINT IF EXISTS user_evidence_evidence_id_fkey;
ALTER TABLE IF EXISTS ONLY public.user_evidence DROP CONSTRAINT IF EXISTS user_evidence_event_id_fkey;
ALTER TABLE IF EXISTS ONLY public.reward_transactions DROP CONSTRAINT IF EXISTS reward_transactions_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.reward_transactions DROP CONSTRAINT IF EXISTS reward_transactions_learner_attempt_id_fkey;
ALTER TABLE IF EXISTS ONLY public.map_locations DROP CONSTRAINT IF EXISTS map_locations_unlock_lesson_id_fkey;
ALTER TABLE IF EXISTS ONLY public.map_locations DROP CONSTRAINT IF EXISTS map_locations_event_id_fkey;
ALTER TABLE IF EXISTS ONLY public.lessons DROP CONSTRAINT IF EXISTS lessons_updated_by_fkey;
ALTER TABLE IF EXISTS ONLY public.lessons DROP CONSTRAINT IF EXISTS lessons_template_id_fkey;
ALTER TABLE IF EXISTS ONLY public.lessons DROP CONSTRAINT IF EXISTS lessons_event_id_fkey;
ALTER TABLE IF EXISTS ONLY public.lessons DROP CONSTRAINT IF EXISTS lessons_created_by_fkey;
ALTER TABLE IF EXISTS ONLY public.lesson_versions DROP CONSTRAINT IF EXISTS lesson_versions_published_by_fkey;
ALTER TABLE IF EXISTS ONLY public.lesson_versions DROP CONSTRAINT IF EXISTS lesson_versions_lesson_id_fkey;
ALTER TABLE IF EXISTS ONLY public.lesson_results DROP CONSTRAINT IF EXISTS lesson_results_learner_attempt_id_fkey;
ALTER TABLE IF EXISTS ONLY public.learner_attempts DROP CONSTRAINT IF EXISTS learner_attempts_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.learner_attempts DROP CONSTRAINT IF EXISTS learner_attempts_lesson_version_id_fkey;
ALTER TABLE IF EXISTS ONLY public.item_unlock_rule DROP CONSTRAINT IF EXISTS item_unlock_rule_lesson_id_fkey;
ALTER TABLE IF EXISTS ONLY public.item_unlock_rule DROP CONSTRAINT IF EXISTS item_unlock_rule_item_id_fkey;
ALTER TABLE IF EXISTS ONLY public.item_catalog DROP CONSTRAINT IF EXISTS item_catalog_asset_id_fkey;
ALTER TABLE IF EXISTS ONLY public.idempotency_records DROP CONSTRAINT IF EXISTS idempotency_records_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.map_locations DROP CONSTRAINT IF EXISTS fk_map_location_unlock_lesson_same_event;
ALTER TABLE IF EXISTS ONLY public.lessons DROP CONSTRAINT IF EXISTS fk_lessons_current_own_version;
ALTER TABLE IF EXISTS ONLY public.animation_scenes DROP CONSTRAINT IF EXISTS fk_anim_scenes_current_own_version;
ALTER TABLE IF EXISTS ONLY public.evidences DROP CONSTRAINT IF EXISTS evidences_event_id_fkey;
ALTER TABLE IF EXISTS ONLY public.evidences DROP CONSTRAINT IF EXISTS evidences_created_by_fkey;
ALTER TABLE IF EXISTS ONLY public.evidences DROP CONSTRAINT IF EXISTS evidences_asset_id_fkey;
ALTER TABLE IF EXISTS ONLY public.auth_refresh_tokens DROP CONSTRAINT IF EXISTS auth_refresh_tokens_user_id_fkey;
ALTER TABLE IF EXISTS ONLY public.auth_refresh_tokens DROP CONSTRAINT IF EXISTS auth_refresh_tokens_previous_token_id_fkey;
ALTER TABLE IF EXISTS ONLY public.assets DROP CONSTRAINT IF EXISTS assets_created_by_fkey;
ALTER TABLE IF EXISTS ONLY public.animation_templates DROP CONSTRAINT IF EXISTS animation_templates_thumbnail_asset_id_fkey;
ALTER TABLE IF EXISTS ONLY public.animation_scenes DROP CONSTRAINT IF EXISTS animation_scenes_updated_by_fkey;
ALTER TABLE IF EXISTS ONLY public.animation_scenes DROP CONSTRAINT IF EXISTS animation_scenes_template_id_fkey;
ALTER TABLE IF EXISTS ONLY public.animation_scenes DROP CONSTRAINT IF EXISTS animation_scenes_event_id_fkey;
ALTER TABLE IF EXISTS ONLY public.animation_scenes DROP CONSTRAINT IF EXISTS animation_scenes_created_by_fkey;
ALTER TABLE IF EXISTS ONLY public.animation_scene_versions DROP CONSTRAINT IF EXISTS animation_scene_versions_scene_id_fkey;
ALTER TABLE IF EXISTS ONLY public.animation_scene_versions DROP CONSTRAINT IF EXISTS animation_scene_versions_published_by_fkey;
ALTER TABLE IF EXISTS ONLY public.animation_scene_version_html DROP CONSTRAINT IF EXISTS animation_scene_version_html_version_id_fkey;
ALTER TABLE IF EXISTS ONLY public.animation_scene_html DROP CONSTRAINT IF EXISTS animation_scene_html_scene_id_fkey;
ALTER TABLE IF EXISTS ONLY public.animation_scene_asset_refs DROP CONSTRAINT IF EXISTS animation_scene_asset_refs_scene_version_id_fkey;
ALTER TABLE IF EXISTS ONLY public.animation_scene_asset_refs DROP CONSTRAINT IF EXISTS animation_scene_asset_refs_asset_id_fkey;
ALTER TABLE IF EXISTS ONLY public.activity_attempts DROP CONSTRAINT IF EXISTS activity_attempts_learner_attempt_id_fkey;
DROP TRIGGER IF EXISTS trg_lesson_versions_immutable ON public.lesson_versions;
DROP TRIGGER IF EXISTS trg_animation_scene_versions_immutable ON public.animation_scene_versions;
DROP TRIGGER IF EXISTS trg_animation_scene_version_html_immutable ON public.animation_scene_version_html;
DROP INDEX IF EXISTS public.ux_users_email_lower;
DROP INDEX IF EXISTS public.ux_user_evidence_user_evidence;
DROP INDEX IF EXISTS public.ux_item_unlock_rule_item;
DROP INDEX IF EXISTS public.ux_historical_events_slug;
DROP INDEX IF EXISTS public.ux_attempt_active_user_version;
DROP INDEX IF EXISTS public.idx_version_lesson_published;
DROP INDEX IF EXISTS public.idx_users_role_status;
DROP INDEX IF EXISTS public.idx_user_inventory_user;
DROP INDEX IF EXISTS public.idx_user_evidence_user_event;
DROP INDEX IF EXISTS public.idx_user_evidence_user;
DROP INDEX IF EXISTS public.idx_reward_user_created;
DROP INDEX IF EXISTS public.idx_reward_attempt;
DROP INDEX IF EXISTS public.idx_refresh_user;
DROP INDEX IF EXISTS public.idx_refresh_family;
DROP INDEX IF EXISTS public.idx_refresh_active_expiry;
DROP INDEX IF EXISTS public.idx_map_locations_unlock_lesson;
DROP INDEX IF EXISTS public.idx_map_locations_event;
DROP INDEX IF EXISTS public.idx_lessons_template;
DROP INDEX IF EXISTS public.idx_lessons_event_status;
DROP INDEX IF EXISTS public.idx_item_unlock_rule_lesson;
DROP INDEX IF EXISTS public.idx_item_catalog_active;
DROP INDEX IF EXISTS public.idx_idempotency_expiry;
DROP INDEX IF EXISTS public.idx_historical_events_status;
DROP INDEX IF EXISTS public.idx_historical_events_start_year;
DROP INDEX IF EXISTS public.idx_historical_events_published_year;
DROP INDEX IF EXISTS public.idx_evidence_event_status;
DROP INDEX IF EXISTS public.idx_evidence_asset;
DROP INDEX IF EXISTS public.idx_attempt_version;
DROP INDEX IF EXISTS public.idx_attempt_user_status;
DROP INDEX IF EXISTS public.idx_assets_state;
DROP INDEX IF EXISTS public.idx_animation_tpl_renderer;
DROP INDEX IF EXISTS public.idx_animation_scenes_template;
DROP INDEX IF EXISTS public.idx_animation_scenes_event_status;
DROP INDEX IF EXISTS public.idx_anim_version_scene_published;
DROP INDEX IF EXISTS public.idx_anim_asset_refs_asset;
DROP INDEX IF EXISTS public.idx_activity_attempt_history;
DROP INDEX IF EXISTS public.flyway_schema_history_s_idx;
ALTER TABLE IF EXISTS ONLY public.user_inventory DROP CONSTRAINT IF EXISTS ux_user_inventory;
ALTER TABLE IF EXISTS ONLY public.lessons DROP CONSTRAINT IF EXISTS ux_lessons_event_id;
ALTER TABLE IF EXISTS ONLY public.users DROP CONSTRAINT IF EXISTS users_pkey;
ALTER TABLE IF EXISTS ONLY public.user_inventory DROP CONSTRAINT IF EXISTS user_inventory_pkey;
ALTER TABLE IF EXISTS ONLY public.user_evidence DROP CONSTRAINT IF EXISTS user_evidence_pkey;
ALTER TABLE IF EXISTS ONLY public.user_evidence DROP CONSTRAINT IF EXISTS user_evidence_learner_attempt_id_evidence_id_key;
ALTER TABLE IF EXISTS ONLY public.reward_transactions DROP CONSTRAINT IF EXISTS reward_transactions_pkey;
ALTER TABLE IF EXISTS ONLY public.reward_transactions DROP CONSTRAINT IF EXISTS reward_transactions_cause_key_key;
ALTER TABLE IF EXISTS ONLY public.map_locations DROP CONSTRAINT IF EXISTS map_locations_pkey;
ALTER TABLE IF EXISTS ONLY public.lessons DROP CONSTRAINT IF EXISTS lessons_pkey;
ALTER TABLE IF EXISTS ONLY public.lesson_versions DROP CONSTRAINT IF EXISTS lesson_versions_pkey;
ALTER TABLE IF EXISTS ONLY public.lesson_versions DROP CONSTRAINT IF EXISTS lesson_versions_lesson_id_version_no_key;
ALTER TABLE IF EXISTS ONLY public.lesson_versions DROP CONSTRAINT IF EXISTS lesson_versions_id_lesson_id_key;
ALTER TABLE IF EXISTS ONLY public.lesson_templates DROP CONSTRAINT IF EXISTS lesson_templates_pkey;
ALTER TABLE IF EXISTS ONLY public.lesson_templates DROP CONSTRAINT IF EXISTS lesson_templates_code_key;
ALTER TABLE IF EXISTS ONLY public.lesson_results DROP CONSTRAINT IF EXISTS lesson_results_pkey;
ALTER TABLE IF EXISTS ONLY public.lesson_results DROP CONSTRAINT IF EXISTS lesson_results_learner_attempt_id_key;
ALTER TABLE IF EXISTS ONLY public.learner_attempts DROP CONSTRAINT IF EXISTS learner_attempts_pkey;
ALTER TABLE IF EXISTS ONLY public.item_unlock_rule DROP CONSTRAINT IF EXISTS item_unlock_rule_pkey;
ALTER TABLE IF EXISTS ONLY public.item_catalog DROP CONSTRAINT IF EXISTS item_catalog_pkey;
ALTER TABLE IF EXISTS ONLY public.item_catalog DROP CONSTRAINT IF EXISTS item_catalog_code_key;
ALTER TABLE IF EXISTS ONLY public.idempotency_records DROP CONSTRAINT IF EXISTS idempotency_records_user_id_operation_idempotency_key_key;
ALTER TABLE IF EXISTS ONLY public.idempotency_records DROP CONSTRAINT IF EXISTS idempotency_records_pkey;
ALTER TABLE IF EXISTS ONLY public.historical_events DROP CONSTRAINT IF EXISTS historical_events_pkey;
ALTER TABLE IF EXISTS ONLY public.flyway_schema_history DROP CONSTRAINT IF EXISTS flyway_schema_history_pk;
ALTER TABLE IF EXISTS ONLY public.evidences DROP CONSTRAINT IF EXISTS evidences_pkey;
ALTER TABLE IF EXISTS ONLY public.auth_refresh_tokens DROP CONSTRAINT IF EXISTS auth_refresh_tokens_token_hash_key;
ALTER TABLE IF EXISTS ONLY public.auth_refresh_tokens DROP CONSTRAINT IF EXISTS auth_refresh_tokens_pkey;
ALTER TABLE IF EXISTS ONLY public.assets DROP CONSTRAINT IF EXISTS assets_storage_key_key;
ALTER TABLE IF EXISTS ONLY public.assets DROP CONSTRAINT IF EXISTS assets_pkey;
ALTER TABLE IF EXISTS ONLY public.animation_templates DROP CONSTRAINT IF EXISTS animation_templates_pkey;
ALTER TABLE IF EXISTS ONLY public.animation_templates DROP CONSTRAINT IF EXISTS animation_templates_code_key;
ALTER TABLE IF EXISTS ONLY public.animation_scenes DROP CONSTRAINT IF EXISTS animation_scenes_pkey;
ALTER TABLE IF EXISTS ONLY public.animation_scene_versions DROP CONSTRAINT IF EXISTS animation_scene_versions_scene_id_version_no_key;
ALTER TABLE IF EXISTS ONLY public.animation_scene_versions DROP CONSTRAINT IF EXISTS animation_scene_versions_pkey;
ALTER TABLE IF EXISTS ONLY public.animation_scene_versions DROP CONSTRAINT IF EXISTS animation_scene_versions_id_scene_id_key;
ALTER TABLE IF EXISTS ONLY public.animation_scene_version_html DROP CONSTRAINT IF EXISTS animation_scene_version_html_pkey;
ALTER TABLE IF EXISTS ONLY public.animation_scene_html DROP CONSTRAINT IF EXISTS animation_scene_html_pkey;
ALTER TABLE IF EXISTS ONLY public.animation_scene_asset_refs DROP CONSTRAINT IF EXISTS animation_scene_asset_refs_pkey;
ALTER TABLE IF EXISTS ONLY public.activity_attempts DROP CONSTRAINT IF EXISTS activity_attempts_pkey;
ALTER TABLE IF EXISTS ONLY public.activity_attempts DROP CONSTRAINT IF EXISTS activity_attempts_learner_attempt_id_activity_id_attempt_no_key;
DROP TABLE IF EXISTS public.users;
DROP TABLE IF EXISTS public.user_inventory;
DROP TABLE IF EXISTS public.user_evidence;
DROP TABLE IF EXISTS public.reward_transactions;
DROP TABLE IF EXISTS public.map_locations;
DROP TABLE IF EXISTS public.lessons;
DROP TABLE IF EXISTS public.lesson_versions;
DROP TABLE IF EXISTS public.lesson_templates;
DROP TABLE IF EXISTS public.lesson_results;
DROP TABLE IF EXISTS public.learner_attempts;
DROP TABLE IF EXISTS public.item_unlock_rule;
DROP TABLE IF EXISTS public.item_catalog;
DROP TABLE IF EXISTS public.idempotency_records;
DROP TABLE IF EXISTS public.historical_events;
DROP TABLE IF EXISTS public.flyway_schema_history;
DROP TABLE IF EXISTS public.evidences;
DROP TABLE IF EXISTS public.auth_refresh_tokens;
DROP TABLE IF EXISTS public.assets;
DROP TABLE IF EXISTS public.animation_templates;
DROP TABLE IF EXISTS public.animation_scenes;
DROP TABLE IF EXISTS public.animation_scene_versions;
DROP TABLE IF EXISTS public.animation_scene_version_html;
DROP TABLE IF EXISTS public.animation_scene_html;
DROP TABLE IF EXISTS public.animation_scene_asset_refs;
DROP TABLE IF EXISTS public.activity_attempts;
DROP FUNCTION IF EXISTS public.prevent_lesson_version_mutation();
DROP FUNCTION IF EXISTS public.prevent_animation_scene_version_mutation();
DROP FUNCTION IF EXISTS public.prevent_animation_scene_version_html_mutation();
DROP EXTENSION IF EXISTS pgcrypto;
--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: prevent_animation_scene_version_html_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_animation_scene_version_html_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'animation_scene_version_html is immutable; publish a new version instead';
END;
$$;


--
-- Name: prevent_animation_scene_version_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_animation_scene_version_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'animation_scene_versions are immutable; publish a new version instead';
END;
$$;


--
-- Name: prevent_lesson_version_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.prevent_lesson_version_mutation() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    RAISE EXCEPTION 'lesson_versions are immutable; publish a new version instead';
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: activity_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_attempts (
    id uuid NOT NULL,
    learner_attempt_id uuid NOT NULL,
    activity_id character varying(100) NOT NULL,
    attempt_no integer NOT NULL,
    submitted_answer_json jsonb NOT NULL,
    result_json jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT activity_attempts_attempt_no_check CHECK ((attempt_no >= 1)),
    CONSTRAINT chk_activity_result CHECK ((jsonb_typeof(result_json) = 'object'::text))
);


--
-- Name: animation_scene_asset_refs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.animation_scene_asset_refs (
    scene_version_id uuid NOT NULL,
    asset_id uuid NOT NULL,
    role character varying(48) NOT NULL
);


--
-- Name: animation_scene_html; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.animation_scene_html (
    scene_id uuid NOT NULL,
    content text NOT NULL,
    sha256 character varying(64) NOT NULL,
    size_bytes bigint NOT NULL,
    original_filename character varying(255),
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT animation_scene_html_size_bytes_check CHECK ((size_bytes > 0))
);


--
-- Name: animation_scene_version_html; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.animation_scene_version_html (
    version_id uuid NOT NULL,
    content text NOT NULL,
    sha256 character varying(64) NOT NULL,
    size_bytes bigint NOT NULL,
    original_filename character varying(255),
    CONSTRAINT animation_scene_version_html_size_bytes_check CHECK ((size_bytes > 0))
);


--
-- Name: animation_scene_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.animation_scene_versions (
    id uuid NOT NULL,
    scene_id uuid NOT NULL,
    version_no integer NOT NULL,
    schema_version integer NOT NULL,
    renderer_code character varying(48) NOT NULL,
    renderer_version integer NOT NULL,
    snapshot_json jsonb NOT NULL,
    manifest_checksum character varying(64) NOT NULL,
    published_at timestamp with time zone DEFAULT now() NOT NULL,
    published_by uuid NOT NULL,
    CONSTRAINT animation_scene_versions_renderer_version_check CHECK ((renderer_version >= 1)),
    CONSTRAINT animation_scene_versions_schema_version_check CHECK ((schema_version >= 1)),
    CONSTRAINT animation_scene_versions_version_no_check CHECK ((version_no >= 1)),
    CONSTRAINT chk_animation_snapshot CHECK ((jsonb_typeof(snapshot_json) = 'object'::text))
);


--
-- Name: animation_scenes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.animation_scenes (
    id uuid NOT NULL,
    template_id uuid NOT NULL,
    event_id uuid,
    title character varying(255) NOT NULL,
    draft_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying(24) DEFAULT 'DRAFT'::character varying NOT NULL,
    current_version_id uuid,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 0 NOT NULL,
    CONSTRAINT chk_animation_scene_draft CHECK ((jsonb_typeof(draft_json) = 'object'::text)),
    CONSTRAINT chk_animation_scene_published_version CHECK ((((status)::text <> 'PUBLISHED'::text) OR (current_version_id IS NOT NULL))),
    CONSTRAINT chk_animation_scene_status CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'PUBLISHED'::character varying, 'ARCHIVED'::character varying])::text[])))
);


--
-- Name: animation_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.animation_templates (
    id uuid NOT NULL,
    code character varying(64) NOT NULL,
    name character varying(150) NOT NULL,
    description text,
    renderer_code character varying(48) NOT NULL,
    renderer_version integer DEFAULT 1 NOT NULL,
    schema_version integer NOT NULL,
    capabilities_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    default_config_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    thumbnail_asset_id uuid,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT animation_templates_renderer_version_check CHECK ((renderer_version >= 1)),
    CONSTRAINT animation_templates_schema_version_check CHECK ((schema_version >= 1)),
    CONSTRAINT chk_animation_tpl_capabilities CHECK ((jsonb_typeof(capabilities_json) = 'object'::text)),
    CONSTRAINT chk_animation_tpl_default_config CHECK ((jsonb_typeof(default_config_json) = 'object'::text))
);


--
-- Name: assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assets (
    id uuid NOT NULL,
    storage_key character varying(512) NOT NULL,
    original_filename character varying(255),
    mime_type character varying(160) NOT NULL,
    size_bytes bigint NOT NULL,
    checksum_sha256 character(64),
    state character varying(24) DEFAULT 'ACTIVE'::character varying NOT NULL,
    alt_text text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    retired_at timestamp with time zone,
    CONSTRAINT assets_size_bytes_check CHECK ((size_bytes >= 0)),
    CONSTRAINT chk_asset_state CHECK (((state)::text = ANY ((ARRAY['UPLOADING'::character varying, 'ACTIVE'::character varying, 'RETIRED'::character varying, 'FAILED'::character varying])::text[])))
);


--
-- Name: auth_refresh_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_refresh_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_hash character varying(128) NOT NULL,
    token_family_id uuid NOT NULL,
    previous_token_id uuid,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_used_at timestamp with time zone,
    CONSTRAINT chk_refresh_expiry CHECK ((expires_at > created_at))
);


--
-- Name: evidences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evidences (
    id uuid NOT NULL,
    event_id uuid NOT NULL,
    title character varying(255) NOT NULL,
    evidence_type character varying(48) NOT NULL,
    description text,
    source_title character varying(255) NOT NULL,
    source_author character varying(255),
    source_url text,
    source_citation text,
    source_published_at date,
    reliability character varying(24),
    relevance text,
    asset_id uuid,
    status character varying(24) DEFAULT 'DRAFT'::character varying NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 0 NOT NULL,
    CONSTRAINT chk_evidence_reliability CHECK (((reliability IS NULL) OR ((reliability)::text = ANY ((ARRAY['HIGH'::character varying, 'MEDIUM'::character varying, 'LOW'::character varying, 'UNASSESSED'::character varying])::text[])))),
    CONSTRAINT chk_evidence_status CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'APPROVED'::character varying, 'ARCHIVED'::character varying])::text[])))
);


--
-- Name: flyway_schema_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flyway_schema_history (
    installed_rank integer NOT NULL,
    version character varying(50),
    description character varying(200) NOT NULL,
    type character varying(20) NOT NULL,
    script character varying(1000) NOT NULL,
    checksum integer,
    installed_by character varying(100) NOT NULL,
    installed_on timestamp without time zone DEFAULT now() NOT NULL,
    execution_time integer NOT NULL,
    success boolean NOT NULL
);


--
-- Name: historical_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.historical_events (
    id uuid NOT NULL,
    slug character varying(150) NOT NULL,
    title character varying(255) NOT NULL,
    era character varying(100),
    period character varying(100),
    start_year integer,
    summary text NOT NULL,
    description text,
    location character varying(255),
    cover_asset_key character varying(512),
    tags text[] DEFAULT '{}'::text[] NOT NULL,
    status character varying(24) DEFAULT 'DRAFT'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 0 NOT NULL,
    CONSTRAINT chk_historical_events_status CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'PUBLISHED'::character varying, 'ARCHIVED'::character varying])::text[])))
);


--
-- Name: idempotency_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.idempotency_records (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    idempotency_key character varying(160) NOT NULL,
    operation character varying(100) NOT NULL,
    request_hash character varying(128) NOT NULL,
    response_json jsonb,
    http_status integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone,
    CONSTRAINT chk_idempotency_response CHECK (((response_json IS NULL) OR (jsonb_typeof(response_json) = 'object'::text))),
    CONSTRAINT idempotency_records_http_status_check CHECK (((http_status >= 100) AND (http_status <= 599)))
);


--
-- Name: item_catalog; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.item_catalog (
    id uuid NOT NULL,
    code character varying(80) NOT NULL,
    name character varying(160) NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    category character varying(48) NOT NULL,
    item_type character varying(48) NOT NULL,
    rarity character varying(24) DEFAULT 'COMMON'::character varying NOT NULL,
    asset_id uuid,
    source_metadata jsonb,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 0 NOT NULL,
    CONSTRAINT chk_item_rarity CHECK (((rarity)::text = ANY ((ARRAY['COMMON'::character varying, 'UNCOMMON'::character varying, 'RARE'::character varying, 'EPIC'::character varying])::text[]))),
    CONSTRAINT chk_item_source_meta CHECK (((source_metadata IS NULL) OR (jsonb_typeof(source_metadata) = 'object'::text))),
    CONSTRAINT chk_item_type CHECK (((item_type)::text = ANY ((ARRAY['HISTORICAL_REPLICA'::character varying, 'DIGITAL_EDITION'::character varying, 'COMMEMORATIVE_BADGE'::character varying])::text[])))
);


--
-- Name: item_unlock_rule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.item_unlock_rule (
    id uuid NOT NULL,
    item_id uuid NOT NULL,
    rule_type character varying(48) NOT NULL,
    lesson_id uuid,
    threshold integer,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_unlock_rule_shape CHECK (((((rule_type)::text = 'LESSON_COMPLETED'::text) AND (lesson_id IS NOT NULL) AND (threshold IS NULL)) OR (((rule_type)::text = ANY ((ARRAY['COLLECTION_COUNT'::character varying, 'LESSON_COUNT'::character varying])::text[])) AND (threshold IS NOT NULL) AND (threshold > 0) AND (lesson_id IS NULL)))),
    CONSTRAINT chk_unlock_rule_type CHECK (((rule_type)::text = ANY ((ARRAY['LESSON_COMPLETED'::character varying, 'COLLECTION_COUNT'::character varying, 'LESSON_COUNT'::character varying])::text[])))
);


--
-- Name: learner_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.learner_attempts (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    lesson_version_id uuid NOT NULL,
    status character varying(24) DEFAULT 'IN_PROGRESS'::character varying NOT NULL,
    current_stage_id character varying(100),
    current_activity_id character varying(100),
    state_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    last_active_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone,
    row_version bigint DEFAULT 0 NOT NULL,
    CONSTRAINT chk_attempt_completion CHECK ((((status)::text <> 'COMPLETED'::text) OR (completed_at IS NOT NULL))),
    CONSTRAINT chk_attempt_state CHECK ((jsonb_typeof(state_json) = 'object'::text)),
    CONSTRAINT chk_attempt_status CHECK (((status)::text = ANY ((ARRAY['IN_PROGRESS'::character varying, 'COMPLETED'::character varying, 'ABANDONED'::character varying])::text[])))
);


--
-- Name: lesson_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lesson_results (
    id uuid NOT NULL,
    learner_attempt_id uuid NOT NULL,
    score numeric(10,2) DEFAULT 0 NOT NULL,
    result_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    completed_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_lesson_result_json CHECK ((jsonb_typeof(result_json) = 'object'::text)),
    CONSTRAINT lesson_results_score_check CHECK ((score >= (0)::numeric))
);


--
-- Name: lesson_templates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lesson_templates (
    id uuid NOT NULL,
    code character varying(64) NOT NULL,
    name character varying(150) NOT NULL,
    description text,
    schema_version integer NOT NULL,
    preset_json jsonb NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chk_template_json CHECK ((jsonb_typeof(preset_json) = 'object'::text)),
    CONSTRAINT lesson_templates_schema_version_check CHECK ((schema_version >= 1))
);


--
-- Name: lesson_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lesson_versions (
    id uuid NOT NULL,
    lesson_id uuid NOT NULL,
    version_no integer NOT NULL,
    schema_version integer NOT NULL,
    snapshot_json jsonb NOT NULL,
    published_at timestamp with time zone DEFAULT now() NOT NULL,
    published_by uuid NOT NULL,
    CONSTRAINT chk_lesson_snapshot CHECK ((jsonb_typeof(snapshot_json) = 'object'::text)),
    CONSTRAINT lesson_versions_schema_version_check CHECK ((schema_version >= 1)),
    CONSTRAINT lesson_versions_version_no_check CHECK ((version_no >= 1))
);


--
-- Name: lessons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lessons (
    id uuid NOT NULL,
    event_id uuid NOT NULL,
    template_id uuid NOT NULL,
    title character varying(255) NOT NULL,
    central_question text NOT NULL,
    objectives_json jsonb DEFAULT '[]'::jsonb NOT NULL,
    draft_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying(24) DEFAULT 'DRAFT'::character varying NOT NULL,
    current_version_id uuid,
    created_by uuid,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 0 NOT NULL,
    CONSTRAINT chk_lesson_draft CHECK ((jsonb_typeof(draft_json) = 'object'::text)),
    CONSTRAINT chk_lesson_objectives CHECK ((jsonb_typeof(objectives_json) = 'array'::text)),
    CONSTRAINT chk_lesson_published_version CHECK ((((status)::text <> 'PUBLISHED'::text) OR (current_version_id IS NOT NULL))),
    CONSTRAINT chk_lesson_status CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'PUBLISHED'::character varying, 'ARCHIVED'::character varying])::text[])))
);


--
-- Name: map_locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.map_locations (
    id uuid NOT NULL,
    event_id uuid NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    unlock_lesson_id uuid,
    display_order integer DEFAULT 0 NOT NULL,
    status character varying(24) DEFAULT 'DRAFT'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 0 NOT NULL,
    published_at timestamp with time zone,
    CONSTRAINT chk_map_location_lat CHECK (((latitude >= ('-90'::integer)::double precision) AND (latitude <= (90)::double precision))),
    CONSTRAINT chk_map_location_lng CHECK (((longitude >= ('-180'::integer)::double precision) AND (longitude <= (180)::double precision))),
    CONSTRAINT chk_map_location_status CHECK (((status)::text = ANY ((ARRAY['DRAFT'::character varying, 'PUBLISHED'::character varying, 'ARCHIVED'::character varying])::text[])))
);


--
-- Name: reward_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reward_transactions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    learner_attempt_id uuid,
    reward_type character varying(48) NOT NULL,
    amount bigint NOT NULL,
    reason character varying(160) NOT NULL,
    cause_key character varying(200) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reward_transactions_amount_check CHECK ((amount > 0))
);


--
-- Name: user_evidence; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_evidence (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    learner_attempt_id uuid NOT NULL,
    evidence_id uuid NOT NULL,
    collected_at timestamp with time zone DEFAULT now() NOT NULL,
    snapshot_json jsonb,
    evidence_type character varying(48),
    event_id uuid,
    CONSTRAINT chk_user_evidence_snapshot CHECK (((snapshot_json IS NULL) OR (jsonb_typeof(snapshot_json) = 'object'::text)))
);


--
-- Name: user_inventory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_inventory (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    item_id uuid NOT NULL,
    acquired_at timestamp with time zone DEFAULT now() NOT NULL,
    acquisition_source character varying(48) NOT NULL,
    source_lesson_id uuid,
    source_attempt_id uuid,
    CONSTRAINT chk_inventory_source CHECK (((acquisition_source)::text = ANY ((ARRAY['LESSON_COMPLETED'::character varying, 'COLLECTION_COUNT'::character varying, 'LESSON_COUNT'::character varying, 'ADMIN_GRANT'::character varying])::text[])))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    email character varying(320) NOT NULL,
    password_hash character varying(255) NOT NULL,
    display_name character varying(120),
    role character varying(32) DEFAULT 'LEARNER'::character varying NOT NULL,
    status character varying(24) DEFAULT 'ACTIVE'::character varying NOT NULL,
    email_verified_at timestamp with time zone,
    last_login_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    row_version bigint DEFAULT 0 NOT NULL,
    CONSTRAINT chk_users_email_nonempty CHECK ((length(btrim((email)::text)) > 3)),
    CONSTRAINT chk_users_role CHECK (((role)::text = ANY ((ARRAY['LEARNER'::character varying, 'CONTENT_ADMIN'::character varying])::text[]))),
    CONSTRAINT chk_users_status CHECK (((status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'LOCKED'::character varying, 'DISABLED'::character varying])::text[])))
);


--
-- Data for Name: activity_attempts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.activity_attempts (id, learner_attempt_id, activity_id, attempt_no, submitted_answer_json, result_json, created_at) FROM stdin;
da0473d3-192a-4554-ac71-50e2e31887d4	b29f88c1-0f90-41ef-a833-ff1cf8a98dea	read-hbt-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 14:59:48.175504+00
427747f2-c9c8-4a12-a083-b95acc79e48c	b29f88c1-0f90-41ef-a833-ff1cf8a98dea	mc-hbt-cause	1	{"selectedOptionIds": ["opt-1"]}	{"output": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "COMPLETED", "completed": true}	2026-10-24 14:59:51.692197+00
d74506e3-6189-4a11-9503-2bc6e67f2a53	b29f88c1-0f90-41ef-a833-ff1cf8a98dea	read-hbt-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 14:59:54.295424+00
da171afe-45ca-4d0c-987e-7d2eedc447cf	9bc7e6d0-5d8f-4a6b-8197-85a8beddd6e2	read-hbt-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:06:22.791429+00
8980f8a0-c618-487c-afc2-c430c04bddbe	9bc7e6d0-5d8f-4a6b-8197-85a8beddd6e2	mc-hbt-cause	1	{"selectedOptionIds": ["opt-2"]}	{"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true}	2026-10-24 16:06:43.830943+00
711f3bcd-2cda-419d-9ef0-998626a37158	9bc7e6d0-5d8f-4a6b-8197-85a8beddd6e2	read-hbt-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:08:23.902281+00
ac8446c1-ee3a-471e-a07a-a460540449b1	76ee8a1a-8c08-4f8a-b79e-12de8c6efb9c	read-hbt-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:11:22.510742+00
56be7b9a-08fc-4081-9b77-8dd449d786bc	76ee8a1a-8c08-4f8a-b79e-12de8c6efb9c	mc-hbt-cause	1	{"selectedOptionIds": ["opt-3"]}	{"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true}	2026-10-24 16:12:09.359246+00
e2092904-e768-4f8c-8cff-be2a7680746e	76ee8a1a-8c08-4f8a-b79e-12de8c6efb9c	read-hbt-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:18:13.984684+00
a035f45f-60ff-4aae-9273-b6eea0027642	a1cdbc7f-e176-4824-be1e-1a0a3de60ed6	read-hbt-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:18:23.027849+00
8b5cea3f-4f41-4d87-b1a2-bf65f64d6b83	a1cdbc7f-e176-4824-be1e-1a0a3de60ed6	mc-hbt-cause	1	{"selectedOptionIds": ["opt-2"]}	{"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true}	2026-10-24 16:18:26.106141+00
a32aadb8-1163-46d0-a874-c91b0d07adaf	a1cdbc7f-e176-4824-be1e-1a0a3de60ed6	read-hbt-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:18:29.987593+00
e4d45ed3-0875-4ca9-924b-978c36f8c00f	652de175-1eb1-4fb7-81f4-e2ce7177e758	read-hbt-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:25:53.461783+00
1867ca4c-66dd-4928-b2c4-caceec026084	652de175-1eb1-4fb7-81f4-e2ce7177e758	mc-hbt-cause	1	{"selectedOptionIds": ["opt-3"]}	{"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true}	2026-10-24 16:26:28.515273+00
d943f8bb-ee05-41b3-816c-f1c2941aed02	652de175-1eb1-4fb7-81f4-e2ce7177e758	read-hbt-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:26:34.352315+00
b8cdfec0-b936-4f7f-ace7-23f88e4f56c3	055d991d-2b51-40fd-b4d4-fb6ed68afddf	read-hbt-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:28:34.385532+00
88c8f322-ffc9-4f6b-90f9-11e916d7fae8	055d991d-2b51-40fd-b4d4-fb6ed68afddf	mc-hbt-cause	1	{"selectedOptionIds": ["opt-1"]}	{"output": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:28:43.305242+00
0aebfd2e-4d1a-40e4-ae66-ceff37a7d5cb	055d991d-2b51-40fd-b4d4-fb6ed68afddf	read-hbt-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:28:44.913262+00
7a0508e3-763d-421a-af50-d8e54ee527ba	6ed3df0f-9aa5-4aba-9880-a4ef2ad40b72	read-hbt-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:47:20.893171+00
2fbbdd67-5518-4420-ac4a-cfc10a0f3b8a	6ed3df0f-9aa5-4aba-9880-a4ef2ad40b72	mc-hbt-cause	1	{"selectedOptionIds": ["opt-2"]}	{"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true}	2026-10-24 16:47:23.658513+00
6db82e7a-0a5f-4712-8083-22c8b8f44c5f	6ed3df0f-9aa5-4aba-9880-a4ef2ad40b72	read-hbt-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:47:26.948562+00
82d59915-ed29-444d-8340-7eb3219b6885	8f03c376-529b-4279-b25b-38b8d0339182	read-hbt-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:52:10.907822+00
5799d89a-45f5-412e-a34f-ca408e8d1e22	8f03c376-529b-4279-b25b-38b8d0339182	mc-hbt-cause	1	{"selectedOptionIds": ["opt-2"]}	{"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true}	2026-10-24 16:52:13.323648+00
f97dac12-ca03-4edd-942a-085c57eb8d01	8f03c376-529b-4279-b25b-38b8d0339182	read-hbt-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 16:52:16.689627+00
82823372-a21a-46b7-8895-dab3745b1628	b2186fce-e2e4-4e14-a875-c738ed1e2417	read-hbt-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 17:13:52.749516+00
6ba27d39-2389-49f3-9d27-06b6d1223342	b2186fce-e2e4-4e14-a875-c738ed1e2417	mc-hbt-cause	1	{"selectedOptionIds": ["opt-3"]}	{"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true}	2026-10-24 17:14:29.999453+00
1a6a7f9a-9145-44af-8451-2edfc99f2d73	b2186fce-e2e4-4e14-a875-c738ed1e2417	read-hbt-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 17:14:37.365482+00
591e86c3-cde8-47fe-832f-d115bda502ab	ac7205c6-7933-4d00-9f87-aa2fb5b0f59a	read-hbt-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 17:40:09.546925+00
522d3177-ea8a-4f6f-9e0b-451cdb05711f	ac7205c6-7933-4d00-9f87-aa2fb5b0f59a	mc-hbt-cause	1	{"selectedOptionIds": ["opt-1"]}	{"output": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "COMPLETED", "completed": true}	2026-10-24 17:40:20.735874+00
a27ddd6f-068b-45d6-90c2-f1721a46b0fe	ac7205c6-7933-4d00-9f87-aa2fb5b0f59a	read-hbt-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 17:40:31.084114+00
6f4dc10a-f3fd-466e-aeb5-446aeb50e0bb	25c2b985-104e-4fbe-a499-a9e199681b3e	read-hbt-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 18:05:21.536951+00
3b795f66-f8d3-49cd-86bf-81f5f3b981e8	25c2b985-104e-4fbe-a499-a9e199681b3e	mc-hbt-cause	1	{"selectedOptionIds": ["opt-3"]}	{"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true}	2026-10-24 18:05:29.218114+00
5b1a1930-af9e-4777-9181-872125bccdf4	25c2b985-104e-4fbe-a499-a9e199681b3e	read-hbt-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 18:05:35.630334+00
8d3ee1b0-a373-4e32-8a16-3a1afb224b79	f299af52-46fd-4b45-8078-5dd762497caa	read-hbt-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 18:06:12.611468+00
8b4b90de-4252-4f13-94f5-cb0fd36c2d8c	f299af52-46fd-4b45-8078-5dd762497caa	mc-hbt-cause	1	{"selectedOptionIds": ["opt-3"]}	{"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true}	2026-10-24 18:06:15.867062+00
58b95e37-a6d3-4c87-a1da-2dbf651d4a09	f299af52-46fd-4b45-8078-5dd762497caa	read-hbt-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 18:06:17.803539+00
73d6569e-80a9-4861-84f1-86559baad201	1a15cdd0-315e-4353-b0ac-e0d5a4597db4	read-hbt-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 18:13:33.071343+00
82252b7a-e044-44ff-96da-e4894d13cc30	1a15cdd0-315e-4353-b0ac-e0d5a4597db4	mc-hbt-cause	1	{"selectedOptionIds": ["opt-3"]}	{"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true}	2026-10-24 18:13:36.149239+00
3eb5fe15-dbe0-44c3-aca5-db8d2c62e37a	1a15cdd0-315e-4353-b0ac-e0d5a4597db4	read-hbt-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 18:13:37.812069+00
acbf5dfb-314f-4395-b371-2e89733b7134	bfe3e17a-e8c9-471c-adcf-58597abf2eee	read-hbt-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 19:29:34.140589+00
32ae5422-6ba3-477d-a3b4-ffefb5836f95	bfe3e17a-e8c9-471c-adcf-58597abf2eee	mc-hbt-cause	1	{"selectedOptionIds": ["opt-1"]}	{"output": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "COMPLETED", "completed": true}	2026-10-24 20:04:38.535323+00
4657f302-5ea1-42d9-99d6-0b3db358e4ad	bfe3e17a-e8c9-471c-adcf-58597abf2eee	read-hbt-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 20:44:02.051998+00
222e20e5-77e6-48ce-8501-2be7135443fc	0349305f-568e-4ee2-9299-0a49d109f4ef	read-dbp-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 21:06:08.72637+00
e6b6e7bb-1564-4f91-b960-e5331a8de77d	0349305f-568e-4ee2-9299-0a49d109f4ef	mc-dbp-decision	1	{"selectedOptionIds": ["opt-1"]}	{"output": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "COMPLETED", "completed": true}	2026-10-24 21:06:14.738997+00
e9c05c05-5ac9-4245-ac4b-ce0d4f47562f	0349305f-568e-4ee2-9299-0a49d109f4ef	read-dbp-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-24 21:06:16.467188+00
00ed61d9-ee35-4e35-bcd5-22628ba0cecb	3927bcd2-1e9e-451a-bf9e-147d06d456d4	read-dbp-context	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-25 00:45:21.402104+00
9a8746df-4abb-408e-bd86-888b4c4134aa	3927bcd2-1e9e-451a-bf9e-147d06d456d4	mc-dbp-decision	1	{"selectedOptionIds": ["opt-1"]}	{"output": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "COMPLETED", "completed": true}	2026-10-25 00:45:28.433417+00
9a661982-526b-4349-b75f-a2e9e91e1979	3927bcd2-1e9e-451a-bf9e-147d06d456d4	read-dbp-conclusion	1	{}	{"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true}	2026-10-25 00:45:31.211787+00
\.


--
-- Data for Name: animation_scene_asset_refs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.animation_scene_asset_refs (scene_version_id, asset_id, role) FROM stdin;
d7a90000-0000-4000-8000-000000000001	d7a70000-0000-4000-8000-000000000001	BACKGROUND
d7a90000-0000-4000-8000-000000000001	d7a70000-0000-4000-8000-000000000002	OBJECT
d7a90000-0000-4000-8000-000000000001	d7a70000-0000-4000-8000-000000000003	AUDIO
\.


--
-- Data for Name: animation_scene_html; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.animation_scene_html (scene_id, content, sha256, size_bytes, original_filename, updated_at) FROM stdin;
\.


--
-- Data for Name: animation_scene_version_html; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.animation_scene_version_html (version_id, content, sha256, size_bytes, original_filename) FROM stdin;
\.


--
-- Data for Name: animation_scene_versions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.animation_scene_versions (id, scene_id, version_no, schema_version, renderer_code, renderer_version, snapshot_json, manifest_checksum, published_at, published_by) FROM stdin;
d7a30000-0000-4000-8000-000000000001	d7a20000-0000-4000-8000-000000000001	1	1	RIVER_TIDE	1	{"river": {"stakes": [{"x": 0.42, "id": "stake-1", "length": 0.20}, {"x": 0.47, "id": "stake-2", "length": 0.22}, {"x": 0.52, "id": "stake-3", "length": 0.17}, {"x": 0.57, "id": "stake-4", "length": 0.24}, {"x": 0.62, "id": "stake-5", "length": 0.19}, {"x": 0.45, "id": "stake-6", "length": 0.16}, {"x": 0.55, "id": "stake-7", "length": 0.21}, {"x": 0.65, "id": "stake-8", "length": 0.23}, {"x": 0.60, "id": "stake-9", "length": 0.18}]}, "steps": [{"id": "prepare", "hint": "Quan sát vị trí các cọc nhô lên từ đáy sông.", "title": "Chuẩn bị", "easing": "easeInOut", "narration": "Trước trận đánh, quân ta đã đóng sẵn một bãi cọc gỗ ngầm dưới lòng sông. Sơ đồ chỉ vẽ cọc mang tính minh họa — sử liệu không ghi bố trí chính xác từng cọc.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.30, "boatProgress": 0.0}}, {"id": "tide-rise", "hint": "Kéo thanh mực nước để tự thấy cọc bị che đi.", "title": "Nước dâng", "easing": "easeInOut", "narration": "Khi thủy triều dâng, mặt nước cao dần và che khuất đỉnh cọc. Từ trên thuyền nhìn xuống, khó nhận ra chướng ngại vật đang ẩn phía dưới.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.90, "boatProgress": 0.0}, "allowedInteractions": ["WATER_LEVEL_CONTROL"]}, {"id": "decoy", "hint": "Thuyền dụ địch (buồm xanh lục) và vệt đường dẫn nét đứt đi trước đoàn địch về phía bãi cọc.", "title": "Dụ địch vào bãi", "easing": "easeInOut", "narration": "Sử liệu ghi nhận quân ta đã lợi dụng lúc nước lớn dụ hoặc dẫn thuyền địch vào vùng bãi cọc. Trên sơ đồ, thuyền xanh lục (phòng thủ) đi trước dẫn hướng đoàn địch tiến vào — đây là chỉ báo sơ đồ chiến thuật, không phải lộ trình cụ thể được ghi lại.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.90, "boatProgress": 0.72, "decoyProgress": 1}}, {"id": "tide-fall", "hint": "Thử kéo mực nước xuống thấp để thấy cọc lộ rõ.", "title": "Nước rút", "easing": "easeInOut", "narration": "Khi triều rút, mực nước hạ dần và những đỉnh cọc lộ ra. Đường đi của thuyền bỗng trở nên nguy hiểm.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.28, "boatProgress": 0.85, "decoyProgress": 1}, "allowedInteractions": ["WATER_LEVEL_CONTROL"]}, {"id": "counterattack", "hint": "Thuyền địch mắc cọc + thuyền xanh lục tiến vào từ mép trái + mũi tên phối hợp cùng hướng.", "title": "Phản công phối hợp", "easing": "easeInOut", "narration": "Thuyền địch vướng vào bãi cọc, khó di chuyển. Sử liệu ghi nhận quân ta đã đánh úp, phối hợp phản công đúng lúc triều hạ. Trên sơ đồ, thuyền phòng thủ (buồm xanh lục) tiến vào từ phía sau cùng mũi tên phối hợp hướng về bãi — minh họa hướng tác chiến, không phải đội hình hay vị trí thật.", "durationMs": 1100, "targetState": {"obstructed": true, "waterLevel": 0.28, "boatProgress": 0.85, "decoyProgress": 1, "counterattackProgress": 1}}, {"id": "summary", "hint": "Sơ đồ chuỗi 5 giai đoạn: đây là kết luận, không phải một cảnh hành động mới.", "title": "Tổng kết", "easing": "easeInOut", "effects": ["SHOW_SEQUENCE_SUMMARY"], "narration": "Chiến thắng đến từ một chuỗi chủ động: chuẩn bị bãi cọc → tính toán nhịp thủy triều → dụ thuyền địch vào đúng lúc nước lớn → vật cản khống chế → phản công phối hợp khi triều rút. Cơ chế vật lý chỉ là một phần của mưu lược — sơ đồ bên trên tóm tắt lại trình tự đó.", "durationMs": 1100, "targetState": {"obstructed": true, "waterLevel": 0.28, "boatProgress": 0.85, "decoyProgress": 1, "showSequenceSummary": true, "counterattackProgress": 1}}], "title": "Trận Bạch Đằng năm 938", "assets": [], "canvas": {"aspectRatio": 1.6}, "objects": [], "disclaimer": "Sơ đồ minh họa chiến thuật, không theo tỉ lệ và không phải phục dựng chính xác trận đánh.", "prediction": {"options": [{"text": "Các cọc vẫn chìm sâu và không ảnh hưởng đến đường đi."}, {"text": "Các cọc dần lộ ra, khiến thuyền khó di chuyển."}], "question": "Khi nước triều rút xuống, điều gì thay đổi đối với thuyền tiến vào khu vực bãi cọc?", "retryHint": "Thử kéo mực nước xuống thấp rồi quan sát: phần cọc nào còn chìm, phần nào đã lộ? Thuyền nổi trên mặt nước sẽ chạm vào đâu?", "explanation": "Khi mực nước hạ, đỉnh cọc nhô lên khỏi mặt sông. Thuyền đã tiến vào vùng bãi cọc lúc nước lớn sẽ vướng phải chướng ngại vật này — chính là cơ chế khiến đội hình địch bị khống chế để phản công.", "revealTargetState": {"obstructed": true, "waterLevel": 0.22, "boatProgress": 0.85, "highlightStakes": true}, "explainedOptionIndex": 1}, "initialState": {}, "interactions": ["WATER_LEVEL_CONTROL", "PREDICTION"], "rendererCode": "RIVER_TIDE", "schemaVersion": 1, "rendererVersion": 1, "sourceReferences": [{"title": "Bảo tàng Lịch sử Quốc gia — \\"Ngô Quyền và chiến thắng Bạch Đằng năm 938\\" (baotanglichsuquocgia.vn)."}], "learningObjective": "Hiểu mối liên hệ giữa bãi cọc được chuẩn bị trước, thủy triều, việc dụ thuyền địch và thời điểm phản công phối hợp trong chiến thắng Bạch Đằng."}	e5ef42f90332c6517c3a0e0188c122ac10d98b75c083db935d7b9e721736ee9b	2026-10-24 13:08:01.670146+00	00000000-0000-4000-8000-000000000001
d7a30000-0000-4000-8000-000000000002	d7a20000-0000-4000-8000-000000000002	1	1	JOURNEY_MAP	1	{"map": {"routes": [{"id": "gather", "to": "me-linh", "via": [{"x": 0.40, "y": 0.55}], "from": "hat-mon", "explanation": "Từ điểm phát khởi, lực lượng và người dân quy tụ về Mê Linh — sơ đồ minh họa, không phải đường đi cụ thể."}, {"id": "advance", "to": "luy-lau", "via": [{"x": 0.60, "y": 0.40}], "from": "me-linh", "explanation": "Cuộc khởi nghĩa hướng về Luy Lâu, trung tâm cai trị của nhà Hán — tuyến chỉ mang tính minh họa hướng phát triển."}], "locations": [{"x": 0.30, "y": 0.62, "id": "hat-mon", "name": "Hát Môn", "description": "Khu vực sông Hát / Hát Môn — nơi cuộc khởi nghĩa bắt đầu năm 40 theo truyền thống lịch sử được ghi nhận rộng rãi.", "contextLabel": "Nơi phát khởi"}, {"x": 0.48, "y": 0.42, "id": "me-linh", "name": "Mê Linh", "description": "Vùng Mê Linh — quê hương và nơi quy tụ lực lượng, người dân các vùng lân cận hưởng ứng cuộc khởi nghĩa.", "contextLabel": "Nơi quy tụ"}, {"x": 0.72, "y": 0.34, "id": "luy-lau", "name": "Luy Lâu", "description": "Luy Lâu — trung tâm hành chính của nhà Đông Hán ở Giao Chỉ, đại diện cho bộ máy cai trị mà cuộc khởi nghĩa hướng tới.", "contextLabel": "Trung tâm Hán"}]}, "steps": [{"id": "context", "hint": "Quan sát sơ đồ khu vực rồi tiếp tục.", "title": "Bối cảnh", "easing": "easeInOut", "narration": "Đầu thế kỷ I sau Công nguyên, vùng đồng bằng Bắc Bộ chịu sự cai trị của nhà Đông Hán. Sơ đồ chỉ gợi ý một số địa điểm tiêu biểu — không phải bản đồ hành chính của thời kỳ đó.", "durationMs": 1100, "targetState": {"markerVisibility": {}}}, {"id": "outbreak", "hint": "Địa điểm sáng lên là nơi khởi nghĩa bắt đầu.", "title": "Khởi nghĩa bùng lên", "easing": "easeInOut", "narration": "Năm 40, cuộc khởi nghĩa do Hai Bà Trưng khởi xướng bắt đầu ở khu vực sông Hát / Hát Môn. Sử liệu không ghi lại vị trí chính xác từng điểm — đây chỉ là minh họa vùng.", "durationMs": 1100, "targetState": {"markerVisibility": {"hat-mon": 1}, "focusedLocationId": "hat-mon"}}, {"id": "gather", "hint": "Tuyến nét đứt chỉ mang tính sơ đồ hóa quan hệ giữa hai vùng.", "title": "Quy tụ lực lượng", "easing": "easeInOut", "narration": "Từ điểm phát khởi, lực lượng và người dân các nơi quy tụ về Mê Linh — quê hương của Hai Bà Trưng. Tuyến nối trên sơ đồ là minh họa sự lan rộng, không khẳng định đường đi thật.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1}, "markerVisibility": {"hat-mon": 1, "me-linh": 1}, "focusedLocationId": "me-linh"}}, {"id": "advance", "hint": "Vì sao Luy Lâu lại là điểm quan trọng?", "title": "Hướng về Luy Lâu", "easing": "easeInOut", "narration": "Cuộc khởi nghĩa lan rộng và hướng tới Luy Lâu — trung tâm hành chính của nhà Đông Hán ở Giao Chỉ, nơi đặt bộ máy cai trị của Tô Định.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}, "focusedLocationId": "luy-lau"}}, {"id": "explore", "hint": "Thử chạm vào Hát Môn, Mê Linh và Luy Lâu.", "title": "Khám phá bản đồ", "easing": "easeInOut", "narration": "Chạm vào từng địa điểm để đọc ý nghĩa lịch sử của nó. Mỗi địa điểm là một mảnh của bức tranh khởi nghĩa: nơi phát khởi, nơi quy tụ và mục tiêu chính trị.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}}, "allowedInteractions": ["TAP_TO_EXPLORE"]}, {"id": "meaning", "hint": "Có thể tua lại các bước hoặc chạm địa điểm để xem lại.", "title": "Ý nghĩa", "easing": "easeInOut", "narration": "Cuộc khởi nghĩa năm 40 thể hiện tinh thần độc lập mạnh mẽ và trực tiếp thách thức bộ máy cai trị của nhà Hán tại Luy Lâu. Tuy nhiên, đây mới là giai đoạn đầu — cuộc đấu tranh còn kéo dài và chưa mang lại độc lập lâu dài ngay lúc đó.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}}}], "title": "Khởi nghĩa Hai Bà Trưng năm 40", "assets": [], "canvas": {"aspectRatio": 1.6}, "objects": [], "disclaimer": "Bản đồ minh họa schematic, không theo tỉ lệ, không phải bản đồ địa lý hay phục dựng chính xác đường đi.", "prediction": {"options": [{"text": "Vì đây là nơi cuộc khởi nghĩa bắt đầu năm 40."}, {"text": "Vì đây là trung tâm hành chính của nhà Hán ở Giao Chỉ, đại diện cho bộ máy cai trị mà cuộc khởi nghĩa hướng tới."}], "question": "Tại sao Luy Lâu là một địa điểm quan trọng trong diễn biến khởi nghĩa?", "retryHint": "Nhìn lại sơ đồ: Hát Môn mới là nơi phát khởi. Luy Lâu đóng vai trò khác trong thể chế cai trị — thử suy nghĩ về vai trò đó.", "explanation": "Luy Lâu là trung tâm hành chính của nhà Đông Hán tại Giao Chỉ. Việc cuộc khởi nghĩa hướng về Luy Lâu cho thấy sức lan tỏa của phong trào và thách thức trực tiếp đến bộ máy cai trị — chứ không chỉ là một cuộc nổi dậy cục bộ.", "revealTargetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}, "focusedLocationId": "luy-lau"}, "explainedOptionIndex": 1}, "initialState": {}, "interactions": ["TAP_TO_EXPLORE", "PREDICTION"], "rendererCode": "JOURNEY_MAP", "schemaVersion": 1, "rendererVersion": 1, "sourceReferences": [{"title": "Bảo tàng Lịch sử Quốc gia — \\"Cuộc khởi nghĩa Hai Bà Trưng (năm 40–43 sau Công nguyên)\\" (baotanglichsuquocgia.vn)."}], "learningObjective": "Nhận biết các địa điểm then chốt của cuộc khởi nghĩa năm 40 và hiểu vai trò của Luy Lâu như trung tâm cai trị của nhà Hán."}	92841e1b1064a1780c97905c5056f3af83f5ce4df560aa19b48117bb3a6865a0	2026-10-24 13:08:01.670146+00	00000000-0000-4000-8000-000000000001
d7a30000-0000-4000-8000-000000000003	d7a20000-0000-4000-8000-000000000003	1	1	JOURNEY_MAP	1	{"map": {"routes": [{"id": "relocation", "to": "dai-la", "via": [{"x": 0.45, "y": 0.58}], "from": "hoa-lu", "explanation": "Dời kinh đô từ Hoa Lư về Đại La — tuyến minh họa khái niệm, không phải đường đi hay đường thủy thật."}], "locations": [{"x": 0.28, "y": 0.70, "id": "hoa-lu", "name": "Hoa Lư", "description": "Hoa Lư — kinh đô của các triều Đinh và Tiền Lê, kinh đô cũ trước khi triều Lý quyết định dời đô năm 1010.", "contextLabel": "Kinh đô cũ"}, {"x": 0.62, "y": 0.40, "id": "dai-la", "name": "Đại La — Thăng Long", "description": "Thành Đại La — nơi Lý Thái Tổ chọn làm kinh đô mới năm 1010, sau đổi tên thành Thăng Long. Đại La và Thăng Long là CÙNG một địa điểm, không phải hai thành khác nhau.", "contextLabel": "Kinh đô mới"}]}, "steps": [{"id": "old-capital", "hint": "Địa điểm sáng lên là kinh đô cũ.", "title": "Hoa Lư — kinh đô cũ", "easing": "easeInOut", "narration": "Hoa Lư từng là kinh đô của các triều Đinh và Tiền Lê — trung tâm chính trị trước khi nhà Lý lên ngôi. Địa thế núi non hiểm trở phù hợp phòng thủ nhưng hạn chế cho phát triển lâu dài.", "durationMs": 1100, "targetState": {"markerVisibility": {"hoa-lu": 1}, "focusedLocationId": "hoa-lu"}}, {"id": "considering", "hint": "Vì sao một kinh đô mới lại được cân nhắc?", "title": "Cân nhắc dời đô", "easing": "easeInOut", "narration": "Sau khi lên ngôi, Lý Thái Tổ và triều thần cân nhắc vị trí kinh đô. Theo tư liệu truyền thống, việc chọn địa điểm mới gắn với cân nhắc về địa thế và hướng phát triển lâu dài của đất nước — sử liệu không ghi đầy đủ mọi lý do cụ thể.", "durationMs": 1100, "targetState": {"markerVisibility": {"hoa-lu": 1}}}, {"id": "chosen", "hint": "Địa điểm mới xuất hiện là kinh đô được chọn.", "title": "Đại La được chọn", "easing": "easeInOut", "narration": "Năm 1010, Lý Thái Tổ chọn vùng thành Đại La làm kinh đô mới. Vị trí trung tâm vùng đồng bằng, thuận lợi giao thông và phát triển — theo cách hiểu được ghi nhận trong tư liệu.", "durationMs": 1100, "targetState": {"markerVisibility": {"dai-la": 1, "hoa-lu": 1}, "focusedLocationId": "dai-la"}}, {"id": "relocated", "hint": "Tuyến đứt nét là sơ đồ khái niệm, không phải đường thật.", "title": "Dời đô năm 1010", "easing": "easeInOut", "narration": "Quyết định dời đô từ Hoa Lư về Đại La được thực hiện năm 1010. Tuyến nối trên sơ đồ chỉ minh họa quan hệ giữa hai địa điểm — không phải đường đi hay hành trình cụ thể của triều đình.", "durationMs": 1100, "targetState": {"routeProgress": {"relocation": 1}, "markerVisibility": {"dai-la": 1, "hoa-lu": 1}, "focusedLocationId": "dai-la"}}, {"id": "thang-long", "hint": "Chạm vào từng địa điểm để đọc vai trò của nó.", "title": "Thăng Long", "easing": "easeInOut", "narration": "Kinh đô mới ở Đại La được đặt tên Thăng Long — \\"rồng bay lên\\". Quyết định năm 1010 đặt nền móng cho một trung tâm chính trị lâu dài, gắn với Hà Nội ngày nay.", "durationMs": 1100, "targetState": {"routeProgress": {"relocation": 1}, "markerHighlight": ["dai-la"], "markerVisibility": {"dai-la": 1, "hoa-lu": 1}}, "allowedInteractions": ["TAP_TO_EXPLORE"]}], "title": "Lý Thái Tổ dời đô năm 1010", "assets": [], "canvas": {"aspectRatio": 1.6}, "objects": [], "disclaimer": "Bản đồ minh họa schematic, không theo tỉ lệ, không phải bản đồ địa lý hay đường đi thực tế của triều đình.", "prediction": {"options": [{"text": "Hoa Lư — kinh đô cũ được giữ nguyên."}, {"text": "Đại La — sau này mang tên Thăng Long."}], "question": "Địa điểm nào được Lý Thái Tổ lựa chọn làm kinh đô mới?", "retryHint": "Hoa Lư là kinh đô CŨ. Hãy xem lại sơ đồ: địa điểm nào vừa xuất hiện ở bước \\"Đại La được chọn\\"?", "explanation": "Năm 1010, Lý Thái Tổ chọn thành Đại La làm kinh đô mới và đổi tên thành Thăng Long. Đại La và Thăng Long là cùng một địa điểm — quyết định này gắn với cân nhắc địa thế trung tâm và tầm phát triển lâu dài.", "revealTargetState": {"routeProgress": {"relocation": 1}, "markerHighlight": ["dai-la"], "markerVisibility": {"dai-la": 1, "hoa-lu": 1}, "focusedLocationId": "dai-la"}, "explainedOptionIndex": 1}, "initialState": {}, "interactions": ["TAP_TO_EXPLORE", "PREDICTION"], "rendererCode": "JOURNEY_MAP", "schemaVersion": 1, "rendererVersion": 1, "sourceReferences": [{"title": "Bảo tàng Lịch sử Quốc gia — \\"Thăng Long thời nhà Lý (1009–1225)\\" và \\"Hà Nội — địa linh nhân kiệt\\" (baotanglichsuquocgia.vn)."}], "learningObjective": "Hiểu vì sao Lý Thái Tổ chọn Đại La làm kinh đô mới và ý nghĩa lâu dài của quyết định dời đô năm 1010."}	85543dafefebd0bde7ce28d40a0f52154cb447025958ce33dac696c13e7371c6	2026-10-24 13:08:01.670146+00	00000000-0000-4000-8000-000000000001
d7a50000-0000-4000-8000-000000000001	d7a40000-0000-4000-8000-000000000001	1	2	RIVER_TIDE	1	{"audio": [{"cue": "LOOP", "stepId": "prepare", "volume": 0.4, "assetRef": "amb-river"}, {"cue": "ENTER", "stepId": "tide-fall", "volume": 0.5, "assetRef": "amb-river"}, {"cue": "ENTER", "stepId": "counterattack", "volume": 0.7, "assetRef": "amb-river"}, {"cue": "EXIT", "fadeMs": 600, "stepId": "summary", "assetRef": "amb-river"}], "river": {"stakes": [{"x": 0.42, "id": "stake-1", "length": 0.20}, {"x": 0.47, "id": "stake-2", "length": 0.22}, {"x": 0.52, "id": "stake-3", "length": 0.17}, {"x": 0.57, "id": "stake-4", "length": 0.24}, {"x": 0.62, "id": "stake-5", "length": 0.19}, {"x": 0.45, "id": "stake-6", "length": 0.16}, {"x": 0.55, "id": "stake-7", "length": 0.21}, {"x": 0.65, "id": "stake-8", "length": 0.23}, {"x": 0.60, "id": "stake-9", "length": 0.18}]}, "steps": [{"id": "prepare", "hint": "Quan sát vị trí các cọc nhô lên từ đáy sông.", "title": "Chuẩn bị", "easing": "easeInOut", "narration": "Trước trận đánh, quân ta đã đóng sẵn một bãi cọc gỗ ngầm dưới lòng sông. Sơ đồ chỉ vẽ cọc mang tính minh họa — sử liệu không ghi bố trí chính xác từng cọc.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.30, "boatProgress": 0.0}}, {"id": "tide-rise", "hint": "Kéo thanh mực nước để tự thấy cọc bị che đi.", "title": "Nước dâng", "easing": "easeInOut", "narration": "Khi thủy triều dâng, mặt nước cao dần và che khuất đỉnh cọc. Từ trên thuyền nhìn xuống, khó nhận ra chướng ngại vật đang ẩn phía dưới.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.90, "boatProgress": 0.0}, "allowedInteractions": ["WATER_LEVEL_CONTROL"]}, {"id": "decoy", "hint": "Camera theo thuyền dụ vào vùng bãi cọc.", "title": "Dụ địch vào bãi", "easing": "easeInOut", "narration": "Sử liệu ghi nhận quân ta đã lợi dụng lúc nước lớn dụ hoặc dẫn thuyền địch vào vùng bãi cọc. Thuyền dụ địch (track keyframe) trượt về phía bãi.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.90, "boatProgress": 0.72, "decoyProgress": 1}}, {"id": "tide-fall", "hint": "Camera zoom + ripple overlay đánh dấu bãi cọc lộ.", "title": "Nước rút", "easing": "easeInOut", "narration": "Khi triều rút, mực nước hạ dần và những đỉnh cọc lộ ra — camera zoom vào bãi cọc; gợn nước đánh dấu điểm mấu chốt.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.28, "boatProgress": 0.85, "decoyProgress": 1}, "allowedInteractions": ["WATER_LEVEL_CONTROL"]}, {"id": "counterattack", "hint": "Glow + camera zoom tối đa khi phản công.", "title": "Phản công phối hợp", "easing": "easeInOut", "narration": "Thuyền địch vướng vào bãi cọc, khó di chuyển. Camera zoom sâu hơn; glow quanh thuyền dụ đánh dấu điểm dồn lực phản công.", "durationMs": 1100, "targetState": {"obstructed": true, "waterLevel": 0.28, "boatProgress": 0.85, "decoyProgress": 1, "counterattackProgress": 1}}, {"id": "summary", "hint": "Fade out kết thúc cinematic.", "title": "Tổng kết", "easing": "easeInOut", "effects": ["SHOW_SEQUENCE_SUMMARY"], "narration": "Chiến thắng đến từ chuỗi chủ động: chuẩn bị bãi cọc → tính nhịp thủy triều → dụ địch → khống chế → phản công. Fade out khép lại cảnh điện ảnh.", "durationMs": 1100, "targetState": {"obstructed": true, "waterLevel": 0.28, "boatProgress": 0.85, "decoyProgress": 1, "showSequenceSummary": true, "counterattackProgress": 1}}], "title": "Trận Bạch Đằng năm 938 — Cinematic", "assets": [{"id": "amb-river", "role": "AUDIO", "assetId": "d7a60000-0000-4000-8000-000000000001"}], "camera": {"steps": [{"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, {"target": {"x": 0.55, "y": 0.55, "zoom": 1.2, "focusObjectId": "boat-decoy"}}, {"target": {"x": 0.52, "y": 0.55, "zoom": 1.6}}, {"target": {"x": 0.55, "y": 0.5, "zoom": 1.8}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}], "initial": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, "canvas": {"aspectRatio": 1.6}, "tracks": [{"objectId": "boat-decoy", "property": "position", "keyframes": [{"tMs": 0, "value": {"x": 0.15, "y": 0.45}, "easing": "linear"}, {"tMs": 2200, "value": {"x": 0.45, "y": 0.42}, "easing": "linear"}, {"tMs": 4400, "value": {"x": 0.62, "y": 0.40}, "easing": "linear"}, {"tMs": 6600, "value": {"x": 0.62, "y": 0.40}, "easing": "linear"}]}, {"objectId": "boat-decoy", "property": "rotation", "keyframes": [{"tMs": 0, "value": 0, "easing": "easeInOut"}, {"tMs": 4400, "value": 0, "easing": "easeInOut"}, {"tMs": 6600, "value": -25, "easing": "easeInOut"}]}], "effects": [{"type": "MIST", "params": {"intensity": 0.3}}, {"type": "WATER_RIPPLE", "params": {"x": 0.55, "y": 0.62, "intensity": 0.7}, "stepId": "tide-fall", "durationMs": 2200}, {"type": "GLOW", "params": {"x": 0.55, "y": 0.45, "objectId": "boat-decoy", "intensity": 0.5}, "stepId": "counterattack", "durationMs": 2200}, {"type": "FADE_OUT", "stepId": "summary", "durationMs": 800}], "objects": [{"id": "boat-decoy", "type": "BOAT", "layer": 1, "scale": 0.14, "opacity": 1, "visible": true, "position": {"x": 0.15, "y": 0.45}, "rotation": 0}], "disclaimer": "Sơ đồ minh họa chiến thuật + cinematic camera — không theo tỉ lệ, không phải phục dựng chính xác trận đánh.", "prediction": {"options": [{"text": "Các cọc vẫn chìm sâu và không ảnh hưởng đến đường đi."}, {"text": "Các cọc dần lộ ra, khiến thuyền khó di chuyển."}], "question": "Khi nước triều rút xuống, điều gì thay đổi đối với thuyền tiến vào khu vực bãi cọc?", "retryHint": "Thử kéo mực nước xuống thấp rồi quan sát: phần cọc nào còn chìm, phần nào đã lộ?", "explanation": "Khi mực nước hạ, đỉnh cọc nhô lên khỏi mặt sông — thuyền đã tiến vào vùng bãi cọc lúc nước lớn sẽ vướng phải chướng ngại vật này.", "revealTargetState": {"obstructed": true, "waterLevel": 0.22, "boatProgress": 0.85, "highlightStakes": true}, "explainedOptionIndex": 1}, "environment": {"glow": 0.2, "mist": 0.35}, "initialState": {}, "interactions": ["WATER_LEVEL_CONTROL", "PREDICTION"], "rendererCode": "RIVER_TIDE", "schemaVersion": 2, "rendererVersion": 1, "sourceReferences": [{"title": "Bảo tàng Lịch sử Quốc gia — \\"Ngô Quyền và chiến thắng Bạch Đằng năm 938\\" (baotanglichsuquocgia.vn)."}], "learningObjective": "Hiểu mối liên hệ giữa bãi cọc, thủy triều, việc dụ địch và phản công phối hợp — qua lăng kính điện ảnh: camera pan/zoom, object chuyển động, hiệu ứng môi trường."}	0466c8c01b6524ace9805a577b09b9c0edc50e66e57a34631f86e7945f862d97	2026-10-24 13:08:01.730606+00	00000000-0000-4000-8000-000000000001
d7a50000-0000-4000-8000-000000000002	d7a40000-0000-4000-8000-000000000002	1	2	JOURNEY_MAP	1	{"map": {"routes": [{"id": "gather", "to": "me-linh", "via": [{"x": 0.40, "y": 0.55}], "from": "hat-mon", "explanation": "Từ điểm phát khởi, lực lượng quy tụ về Mê Linh."}, {"id": "advance", "to": "luy-lau", "via": [{"x": 0.60, "y": 0.40}], "from": "me-linh", "explanation": "Cuộc khởi nghĩa hướng về Luy Lâu."}], "locations": [{"x": 0.30, "y": 0.62, "id": "hat-mon", "name": "Hát Môn", "description": "Khu vực sông Hát / Hát Môn — nơi cuộc khởi nghĩa bắt đầu năm 40.", "contextLabel": "Nơi phát khởi"}, {"x": 0.48, "y": 0.42, "id": "me-linh", "name": "Mê Linh", "description": "Vùng Mê Linh — quê hương và nơi quy tụ lực lượng.", "contextLabel": "Nơi quy tụ"}, {"x": 0.72, "y": 0.34, "id": "luy-lau", "name": "Luy Lâu", "description": "Luy Lâu — trung tâm hành chính của nhà Đông Hán ở Giao Chỉ.", "contextLabel": "Trung tâm Hán"}]}, "audio": [{"cue": "ENTER", "stepId": "context", "volume": 0.4, "assetRef": "amb-battle"}, {"cue": "ENTER", "stepId": "outbreak", "volume": 0.5, "assetRef": "amb-battle"}, {"cue": "ENTER", "stepId": "gather", "volume": 0.5, "assetRef": "amb-battle"}, {"cue": "ENTER", "stepId": "advance", "volume": 0.6, "assetRef": "amb-battle"}, {"cue": "EXIT", "fadeMs": 800, "stepId": "meaning", "assetRef": "amb-battle"}], "steps": [{"id": "context", "hint": "Fade in đánh dấu mở cảnh.", "title": "Bối cảnh", "easing": "easeInOut", "narration": "Đầu thế kỷ I sau Công nguyên, vùng đồng bằng Bắc Bộ chịu sự cai trị của nhà Đông Hán. Fade in mở màn.", "durationMs": 1100, "targetState": {"markerVisibility": {}}}, {"id": "outbreak", "hint": "Camera pan + zoom vào Hát Môn, glow nhấn điểm phát khởi.", "title": "Khởi nghĩa bùng lên", "easing": "easeInOut", "narration": "Năm 40, cuộc khởi nghĩa bùng lên ở sông Hát / Hát Môn. Camera zoom vào điểm phát khởi với glow đánh dấu.", "durationMs": 1100, "targetState": {"markerVisibility": {"hat-mon": 1}, "focusedLocationId": "hat-mon"}}, {"id": "gather", "hint": "Camera pan sang Mê Linh, route reveal trên bản đồ.", "title": "Quy tụ lực lượng", "easing": "easeInOut", "narration": "Từ điểm phát khởi, lực lượng quy tụ về Mê Linh. Camera tiếp tục pan theo hướng di chuyển.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1}, "markerVisibility": {"hat-mon": 1, "me-linh": 1}, "focusedLocationId": "me-linh"}}, {"id": "advance", "hint": "Zoom mạnh nhất tại Luy Lâu.", "title": "Hướng về Luy Lâu", "easing": "easeInOut", "narration": "Cuộc khởi nghĩa hướng tới Luy Lâu — camera zoom sâu nhất khi nhắm trung tâm cai trị Hán.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}, "focusedLocationId": "luy-lau"}}, {"id": "explore", "hint": "Camera zoom out, mở khám phá tương tác.", "title": "Khám phá bản đồ", "easing": "easeInOut", "narration": "Camera trở về tổng quan — chạm vào từng địa điểm để đọc ý nghĩa lịch sử.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}}, "allowedInteractions": ["TAP_TO_EXPLORE"]}, {"id": "meaning", "hint": "Fade out kết thúc cinematic.", "title": "Ý nghĩa", "easing": "easeInOut", "narration": "Cuộc khởi nghĩa năm 40 thể hiện tinh thần độc lập mạnh mẽ. Fade out khép lại hành trình.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}}}], "title": "Khởi nghĩa Hai Bà Trưng năm 40 — Cinematic", "assets": [{"id": "amb-battle", "role": "AUDIO", "assetId": "d7a60000-0000-4000-8000-000000000001"}], "camera": {"steps": [{"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, {"target": {"x": 0.3, "y": 0.62, "zoom": 1.4, "focusLocationId": "hat-mon"}}, {"target": {"x": 0.48, "y": 0.42, "zoom": 1.4, "focusLocationId": "me-linh"}}, {"target": {"x": 0.72, "y": 0.34, "zoom": 1.5, "focusLocationId": "luy-lau"}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}], "initial": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, "canvas": {"aspectRatio": 1.6}, "tracks": [], "effects": [{"type": "FADE_IN", "stepId": "context", "durationMs": 800}, {"type": "GLOW", "params": {"x": 0.30, "y": 0.62, "intensity": 0.6}, "stepId": "outbreak", "durationMs": 2200}, {"type": "GLOW", "params": {"x": 0.72, "y": 0.34, "intensity": 0.6}, "stepId": "advance", "durationMs": 2200}, {"type": "FADE_OUT", "stepId": "meaning", "durationMs": 1000}], "objects": [], "disclaimer": "Bản đồ minh họa schematic + cinematic camera — không theo tỉ lệ, không phải bản đồ địa lý chính xác.", "prediction": {"options": [{"text": "Vì đây là nơi cuộc khởi nghĩa bắt đầu năm 40."}, {"text": "Vì đây là trung tâm hành chính của nhà Hán ở Giao Chỉ."}], "question": "Tại sao Luy Lâu là một địa điểm quan trọng trong diễn biến khởi nghĩa?", "retryHint": "Nhìn lại sơ đồ: Hát Môn mới là nơi phát khởi. Luy Lâu đóng vai trò khác trong thể chế cai trị.", "explanation": "Luy Lâu là trung tâm hành chính của nhà Đông Hán tại Giao Chỉ — cuộc khởi nghĩa hướng về Luy Lâu thách thức trực tiếp bộ máy cai trị.", "revealTargetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}, "focusedLocationId": "luy-lau"}, "explainedOptionIndex": 1}, "initialState": {}, "interactions": ["TAP_TO_EXPLORE", "PREDICTION"], "rendererCode": "JOURNEY_MAP", "schemaVersion": 2, "rendererVersion": 1, "sourceReferences": [{"title": "Bảo tàng Lịch sử Quốc gia — \\"Cuộc khởi nghĩa Hai Bà Trưng (năm 40–43 sau Công nguyên)\\" (baotanglichsuquocgia.vn)."}], "learningObjective": "Nhận biết các địa điểm then chốt qua camera pan điện ảnh + route reveal — Hát Môn, Mê Linh, Luy Lâu."}	34063da69863414e737ae223f31030963a9fb68e03c3f41e7b22ad5908a767c5	2026-10-24 13:08:01.730606+00	00000000-0000-4000-8000-000000000001
d7a50000-0000-4000-8000-000000000003	d7a40000-0000-4000-8000-000000000003	1	2	JOURNEY_MAP	1	{"map": {"routes": [{"id": "relocation", "to": "dai-la", "via": [{"x": 0.45, "y": 0.58}], "from": "hoa-lu", "explanation": "Dời kinh đô từ Hoa Lư về Đại La."}], "locations": [{"x": 0.28, "y": 0.70, "id": "hoa-lu", "name": "Hoa Lư", "description": "Hoa Lư — kinh đô của các triều Đinh và Tiền Lê.", "contextLabel": "Kinh đô cũ"}, {"x": 0.62, "y": 0.40, "id": "dai-la", "name": "Đại La — Thăng Long", "description": "Thành Đại La — nơi Lý Thái Tổ chọn làm kinh đô mới năm 1010.", "contextLabel": "Kinh đô mới"}]}, "audio": [{"cue": "ENTER", "stepId": "old-capital", "volume": 0.4, "assetRef": "amb-court"}, {"cue": "ENTER", "stepId": "chosen", "volume": 0.6, "assetRef": "amb-court"}, {"cue": "EXIT", "fadeMs": 1000, "stepId": "thang-long", "assetRef": "amb-court"}], "steps": [{"id": "old-capital", "hint": "Camera đã zoom sẵn vào Hoa Lư từ đầu.", "title": "Hoa Lư — kinh đô cũ", "easing": "easeInOut", "narration": "Hoa Lư từng là kinh đô của các triều Đinh và Tiền Lê. Camera bắt đầu zoom sẵn tại đây + fade in mở màn.", "durationMs": 1100, "targetState": {"markerVisibility": {"hoa-lu": 1}, "focusedLocationId": "hoa-lu"}}, {"id": "considering", "hint": "Camera zoom out — chuẩn bị reveal lựa chọn mới.", "title": "Cân nhắc dời đô", "easing": "easeInOut", "narration": "Sau khi lên ngôi, Lý Thái Tổ cân nhắc vị trí kinh đô mới — camera kéo ra để bao quát cả hai vùng.", "durationMs": 1100, "targetState": {"markerVisibility": {"hoa-lu": 1}}}, {"id": "chosen", "hint": "Zoom + glow đánh dấu Đại La được chọn.", "title": "Đại La được chọn", "easing": "easeInOut", "narration": "Năm 1010, Lý Thái Tổ chọn Đại La làm kinh đô mới — camera zoom sâu nhất + glow đánh dấu.", "durationMs": 1100, "targetState": {"markerVisibility": {"dai-la": 1, "hoa-lu": 1}, "focusedLocationId": "dai-la"}}, {"id": "relocated", "hint": "Camera zoom out để nhìn cả hành trình.", "title": "Dời đô năm 1010", "easing": "easeInOut", "narration": "Quyết định dời đô thực hiện — camera kéo ra để bao trọn tuyến dời đô.", "durationMs": 1100, "targetState": {"routeProgress": {"relocation": 1}, "markerVisibility": {"dai-la": 1, "hoa-lu": 1}, "focusedLocationId": "dai-la"}}, {"id": "thang-long", "hint": "Fade out kết thúc cinematic.", "title": "Thăng Long", "easing": "easeInOut", "narration": "Kinh đô mới được đặt tên Thăng Long — \\"rồng bay lên\\". Fade out khép lại hành trình điện ảnh.", "durationMs": 1100, "targetState": {"routeProgress": {"relocation": 1}, "markerHighlight": ["dai-la"], "markerVisibility": {"dai-la": 1, "hoa-lu": 1}}, "allowedInteractions": ["TAP_TO_EXPLORE"]}], "title": "Lý Thái Tổ dời đô năm 1010 — Cinematic", "assets": [{"id": "amb-court", "role": "AUDIO", "assetId": "d7a60000-0000-4000-8000-000000000001"}], "camera": {"steps": [{"target": {"x": 0.28, "y": 0.70, "zoom": 1.5}}, {"target": {"x": 0.45, "y": 0.55, "zoom": 1.2}}, {"target": {"x": 0.62, "y": 0.40, "zoom": 1.6, "focusLocationId": "dai-la"}}, {"target": {"x": 0.45, "y": 0.58, "zoom": 1.0}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}], "initial": {"x": 0.28, "y": 0.70, "zoom": 1.3, "focusLocationId": "hoa-lu"}}, "canvas": {"aspectRatio": 1.6}, "tracks": [], "effects": [{"type": "FADE_IN", "stepId": "old-capital", "durationMs": 900}, {"type": "GLOW", "params": {"x": 0.62, "y": 0.40, "intensity": 0.7}, "stepId": "chosen", "durationMs": 2200}, {"type": "FADE_OUT", "stepId": "thang-long", "durationMs": 1200}], "objects": [], "disclaimer": "Bản đồ minh họa schematic + cinematic camera — không theo tỉ lệ, không phải bản đồ địa lý chính xác.", "prediction": {"options": [{"text": "Hoa Lư — kinh đô cũ được giữ nguyên."}, {"text": "Đại La — sau này mang tên Thăng Long."}], "question": "Địa điểm nào được Lý Thái Tổ lựa chọn làm kinh đô mới?", "retryHint": "Hoa Lư là kinh đô CŨ. Hãy xem lại sơ đồ: địa điểm nào vừa xuất hiện?", "explanation": "Năm 1010, Lý Thái Tổ chọn thành Đại La làm kinh đô mới và đổi tên thành Thăng Long.", "revealTargetState": {"routeProgress": {"relocation": 1}, "markerHighlight": ["dai-la"], "markerVisibility": {"dai-la": 1, "hoa-lu": 1}, "focusedLocationId": "dai-la"}, "explainedOptionIndex": 1}, "initialState": {}, "interactions": ["TAP_TO_EXPLORE", "PREDICTION"], "rendererCode": "JOURNEY_MAP", "schemaVersion": 2, "rendererVersion": 1, "sourceReferences": [{"title": "Bảo tàng Lịch sử Quốc gia — \\"Thăng Long thời nhà Lý (1009–1225)\\" và \\"Hà Nội — địa linh nhân kiệt\\" (baotanglichsuquocgia.vn)."}], "learningObjective": "Hiểu vì sao Lý Thái Tổ chọn Đại La làm kinh đô mới — qua cinematic zoom-out reveal."}	f39d31341019c2ffac31ff9219fae9faec721d8e79a3814045f5b90cb4365e4e	2026-10-24 13:08:01.730606+00	00000000-0000-4000-8000-000000000001
d7a90000-0000-4000-8000-000000000001	d7a80000-0000-4000-8000-000000000001	1	2	RIVER_TIDE	1	{"audio": [{"cue": "ENTER", "stepId": "estuary", "volume": 0.9, "assetRef": "voice"}], "river": {"stakes": [{"x": 0.40, "id": "stake-1", "length": 0.22}, {"x": 0.45, "id": "stake-2", "length": 0.19}, {"x": 0.50, "id": "stake-3", "length": 0.24}, {"x": 0.55, "id": "stake-4", "length": 0.17}, {"x": 0.60, "id": "stake-5", "length": 0.21}, {"x": 0.43, "id": "stake-6", "length": 0.16}, {"x": 0.57, "id": "stake-7", "length": 0.23}, {"x": 0.52, "id": "stake-8", "length": 0.18}]}, "steps": [{"id": "estuary", "hint": "Bản đồ minh họa vùng cửa sông hiện ra rồi mờ dần — camera giữ góc nhìn tổng quan.", "title": "Cửa sông Bạch Đằng", "easing": "easeInOut", "narration": "Cửa sông Bạch Đằng nối ra biển Đông — địa thế triều mạnh, luồng nông, nhiều bãi bồi. Đây là nơi Ngô Quyền chọn làm trận địa đón quân Nam Hán.", "durationMs": 1200, "targetState": {"obstructed": false, "waterLevel": 0.55, "boatProgress": 0.0}}, {"id": "stake-prep", "hint": "Camera hạ xuống mặt nước, các cọc lần lượt lộ ở vùng bãi.", "title": "Đóng cọc ngầm", "easing": "easeInOut", "narration": "Trước trận, quân ta đóng sẵn bãi cọc gỗ lim bịt sắt dưới lòng sông. Sử liệu không ghi bố trí chính xác — sơ đồ chỉ minh họa ý tưởng trận địa.", "durationMs": 1200, "targetState": {"obstructed": false, "waterLevel": 0.30, "boatProgress": 0.0, "highlightStakes": true}}, {"id": "tide-rise", "hint": "Kéo mực nước lên để tự thấy cọc chìm hẳn.", "title": "Triều lên", "easing": "easeInOut", "narration": "Nước triều dâng cao, che khuất đỉnh cọc. Từ trên thuyền nhìn xuống khó nhận ra chướng ngại vật ẩn phía dưới.", "durationMs": 1200, "targetState": {"obstructed": false, "waterLevel": 0.90, "boatProgress": 0.0}, "allowedInteractions": ["WATER_LEVEL_CONTROL"]}, {"id": "decoy", "hint": "Camera bám theo thuyền dụ — thuyền địch tiến từ mép phải vào trung tâm bãi.", "title": "Dụ địch vào bãi", "easing": "easeInOut", "narration": "Lúc nước lớn, thuyền dụ dẫn hạm đội Nam Hán tiến vào vùng bãi cọc. Đoàn địch theo sau, không biết đáy sông đã bố trận.", "durationMs": 1200, "targetState": {"obstructed": false, "waterLevel": 0.90, "boatProgress": 0.72, "decoyProgress": 1}}, {"id": "prediction", "hint": "Dừng lại và dự đoán trước khi xem nước rút.", "title": "Điểm quyết định", "easing": "easeInOut", "narration": "Triều sắp rút. Nếu thuyền địch đã vào sâu bãi cọc, điều gì sẽ xảy ra khi mực nước hạ? Đây là lúc cả trận địa chuyển pha.", "durationMs": 1400, "targetState": {"obstructed": false, "waterLevel": 0.85, "boatProgress": 0.72, "decoyProgress": 1}, "allowedInteractions": ["PREDICTION"]}, {"id": "tide-fall", "hint": "Camera zoom vào bãi + gợn nước đánh dấu điểm mấu chốt.", "title": "Triều rút — cọc lộ", "easing": "easeInOut", "narration": "Triều rút nhanh, đỉnh cọc nhô lên khỏi mặt sông. Thuyền địch mắc vào bãi, không thể quay đầu hay tiếp tục tiến.", "durationMs": 1200, "targetState": {"obstructed": false, "waterLevel": 0.26, "boatProgress": 0.85, "decoyProgress": 1, "highlightStakes": true}, "allowedInteractions": ["WATER_LEVEL_CONTROL"]}, {"id": "counterattack", "hint": "Glow quanh thuyền dụ đánh dấu điểm dồn lực — thuyền địch mắc kẹt.", "title": "Phản công phối hợp", "easing": "easeInOut", "narration": "Khi thuyền địch vướng cọc, quân ta phản công đồng loạt từ nhiều hướng. Thời điểm triều hạ chính là thời điểm quyết định trận đánh.", "durationMs": 1200, "targetState": {"obstructed": true, "waterLevel": 0.26, "boatProgress": 0.85, "decoyProgress": 1, "counterattackProgress": 1}}, {"id": "evidence", "hint": "Fade out — chuỗi quyết định khép lại bằng chứng cứ.", "title": "Kết luận có chứng cứ", "easing": "easeInOut", "narration": "Chiến thắng Bạch Đằng là kết quả của chuỗi chủ động: chọn địa thế triều → chuẩn bị trận địa → dụ địch đúng lúc nước lớn → phản công đúng lúc nước rút. Đây là kết luận dựa trên bối cảnh, không phải chi tiết từng cọc hay từng thuyền được ghi lại.", "durationMs": 1400, "targetState": {"obstructed": true, "waterLevel": 0.26, "boatProgress": 0.85, "decoyProgress": 1, "showSequenceSummary": true, "counterattackProgress": 1}}], "title": "Trận Bạch Đằng năm 938 — Trải nghiệm điện ảnh", "assets": [{"id": "bg-hero", "role": "BACKGROUND", "assetId": "d7a70000-0000-4000-8000-000000000001"}, {"id": "map-base", "role": "OBJECT", "assetId": "d7a70000-0000-4000-8000-000000000002"}, {"id": "voice", "role": "AUDIO", "assetId": "d7a70000-0000-4000-8000-000000000003"}], "camera": {"steps": [{"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, {"target": {"x": 0.52, "y": 0.62, "zoom": 1.35}}, {"target": {"x": 0.5, "y": 0.55, "zoom": 1.1}}, {"target": {"x": 0.45, "y": 0.42, "zoom": 1.25, "focusObjectId": "boat-decoy"}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, {"target": {"x": 0.52, "y": 0.6, "zoom": 1.55}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.8}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}], "initial": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, "canvas": {"aspectRatio": 1.6}, "tracks": [{"objectId": "map-plate", "property": "opacity", "keyframes": [{"tMs": 0, "value": 0.85, "easing": "linear"}, {"tMs": 2200, "value": 0.0, "easing": "linear"}, {"tMs": 8800, "value": 0.0, "easing": "linear"}]}, {"objectId": "boat-decoy", "property": "position", "keyframes": [{"tMs": 0, "value": {"x": 0.14, "y": 0.46}, "easing": "linear"}, {"tMs": 3300, "value": {"x": 0.30, "y": 0.42}, "easing": "linear"}, {"tMs": 4400, "value": {"x": 0.52, "y": 0.40}, "easing": "linear"}, {"tMs": 6600, "value": {"x": 0.52, "y": 0.40}, "easing": "linear"}]}, {"objectId": "boat-decoy", "property": "rotation", "keyframes": [{"tMs": 0, "value": 0, "easing": "easeInOut"}, {"tMs": 4400, "value": 0, "easing": "easeInOut"}, {"tMs": 6600, "value": -22, "easing": "easeInOut"}]}, {"objectId": "boat-fleet", "property": "position", "keyframes": [{"tMs": 0, "value": {"x": 0.88, "y": 0.30}, "easing": "linear"}, {"tMs": 3300, "value": {"x": 0.72, "y": 0.34}, "easing": "linear"}, {"tMs": 4400, "value": {"x": 0.58, "y": 0.38}, "easing": "linear"}, {"tMs": 6600, "value": {"x": 0.58, "y": 0.38}, "easing": "linear"}]}], "effects": [{"type": "MIST", "params": {"intensity": 0.3}}, {"type": "FADE_IN", "stepId": "estuary", "durationMs": 900}, {"type": "WATER_RIPPLE", "params": {"x": 0.52, "y": 0.60, "intensity": 0.75}, "stepId": "tide-fall", "durationMs": 2000}, {"type": "GLOW", "params": {"x": 0.52, "y": 0.42, "objectId": "boat-decoy", "intensity": 0.55}, "stepId": "counterattack", "durationMs": 2000}, {"type": "FADE_OUT", "stepId": "evidence", "durationMs": 900}], "objects": [{"id": "map-plate", "type": "LOCATION", "layer": -1, "scale": 1.0, "shape": "rect", "opacity": 0.85, "visible": true, "assetRef": "map-base", "position": {"x": 0.5, "y": 0.5}, "rotation": 0}, {"id": "boat-decoy", "type": "BOAT", "layer": 2, "scale": 0.13, "opacity": 1, "visible": true, "position": {"x": 0.14, "y": 0.46}, "rotation": 0}, {"id": "boat-fleet", "type": "BOAT", "layer": 2, "scale": 0.11, "opacity": 1, "visible": true, "position": {"x": 0.88, "y": 0.30}, "rotation": 0}], "disclaimer": "Cảnh minh họa 2.5D dựa trên tư liệu — không theo tỉ lệ, không phải phục dựng chính xác. Một số chi tiết trang phục/thuyền là suy luận minh họa.", "prediction": {"options": [{"text": "Cọc vẫn chìm sâu, thuyền địch rút lui an toàn."}, {"text": "Cọc lộ ra, thuyền địch mắc kẹt và bị phản công."}], "question": "Khi triều rút sau khi thuyền địch đã vào bãi cọc, kết quả nào hợp lý nhất?", "retryHint": "Kéo mực nước xuống thấp ở bước trước và quan sát phần cọc lộ ra.", "explanation": "Mực nước hạ làm đỉnh cọc nhô lên — thuyền đã tiến vào lúc nước lớn sẽ vướng phải chướng ngại vật và mất khả năng cơ động.", "revealTargetState": {"obstructed": true, "waterLevel": 0.22, "boatProgress": 0.85, "highlightStakes": true}, "explainedOptionIndex": 1}, "environment": {"glow": 0.15, "mist": 0.3}, "initialState": {}, "interactions": ["WATER_LEVEL_CONTROL", "PREDICTION"], "rendererCode": "RIVER_TIDE", "schemaVersion": 2, "rendererVersion": 1, "sourceReferences": [{"title": "Đại Việt Sử Ký Toàn Thư — Tiền Ngô Vương Kỷ."}, {"title": "Việt Sử Tiêu Án — ghi chép chiến thắng Bạch Đằng 938."}, {"title": "Bảo tàng Lịch sử Quốc gia — \\"Ngô Quyền và chiến thắng Bạch Đằng năm 938\\"."}], "learningObjective": "Diễn giải chuỗi quyết định — chuẩn bị bãi cọc, bám nhịp triều, dụ địch, khống chế, phản công — qua cảnh điện ảnh 2.5D có chứng cứ."}	a9820b721ca94dbbea5042c7cef5c0d05b278fd7a30971008b6bdcd536928735	2026-10-24 13:08:01.769276+00	00000000-0000-4000-8000-000000000001
\.


--
-- Data for Name: animation_scenes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.animation_scenes (id, template_id, event_id, title, draft_json, status, current_version_id, created_by, updated_by, created_at, updated_at, row_version) FROM stdin;
d7a20000-0000-4000-8000-000000000001	d7a10000-0000-4000-8000-000000000001	\N	Trận Bạch Đằng năm 938	{"river": {"stakes": [{"x": 0.42, "id": "stake-1", "length": 0.20}, {"x": 0.47, "id": "stake-2", "length": 0.22}, {"x": 0.52, "id": "stake-3", "length": 0.17}, {"x": 0.57, "id": "stake-4", "length": 0.24}, {"x": 0.62, "id": "stake-5", "length": 0.19}, {"x": 0.45, "id": "stake-6", "length": 0.16}, {"x": 0.55, "id": "stake-7", "length": 0.21}, {"x": 0.65, "id": "stake-8", "length": 0.23}, {"x": 0.60, "id": "stake-9", "length": 0.18}]}, "steps": [{"id": "prepare", "hint": "Quan sát vị trí các cọc nhô lên từ đáy sông.", "title": "Chuẩn bị", "easing": "easeInOut", "narration": "Trước trận đánh, quân ta đã đóng sẵn một bãi cọc gỗ ngầm dưới lòng sông. Sơ đồ chỉ vẽ cọc mang tính minh họa — sử liệu không ghi bố trí chính xác từng cọc.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.30, "boatProgress": 0.0}}, {"id": "tide-rise", "hint": "Kéo thanh mực nước để tự thấy cọc bị che đi.", "title": "Nước dâng", "easing": "easeInOut", "narration": "Khi thủy triều dâng, mặt nước cao dần và che khuất đỉnh cọc. Từ trên thuyền nhìn xuống, khó nhận ra chướng ngại vật đang ẩn phía dưới.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.90, "boatProgress": 0.0}, "allowedInteractions": ["WATER_LEVEL_CONTROL"]}, {"id": "decoy", "hint": "Thuyền dụ địch (buồm xanh lục) và vệt đường dẫn nét đứt đi trước đoàn địch về phía bãi cọc.", "title": "Dụ địch vào bãi", "easing": "easeInOut", "narration": "Sử liệu ghi nhận quân ta đã lợi dụng lúc nước lớn dụ hoặc dẫn thuyền địch vào vùng bãi cọc. Trên sơ đồ, thuyền xanh lục (phòng thủ) đi trước dẫn hướng đoàn địch tiến vào — đây là chỉ báo sơ đồ chiến thuật, không phải lộ trình cụ thể được ghi lại.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.90, "boatProgress": 0.72, "decoyProgress": 1}}, {"id": "tide-fall", "hint": "Thử kéo mực nước xuống thấp để thấy cọc lộ rõ.", "title": "Nước rút", "easing": "easeInOut", "narration": "Khi triều rút, mực nước hạ dần và những đỉnh cọc lộ ra. Đường đi của thuyền bỗng trở nên nguy hiểm.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.28, "boatProgress": 0.85, "decoyProgress": 1}, "allowedInteractions": ["WATER_LEVEL_CONTROL"]}, {"id": "counterattack", "hint": "Thuyền địch mắc cọc + thuyền xanh lục tiến vào từ mép trái + mũi tên phối hợp cùng hướng.", "title": "Phản công phối hợp", "easing": "easeInOut", "narration": "Thuyền địch vướng vào bãi cọc, khó di chuyển. Sử liệu ghi nhận quân ta đã đánh úp, phối hợp phản công đúng lúc triều hạ. Trên sơ đồ, thuyền phòng thủ (buồm xanh lục) tiến vào từ phía sau cùng mũi tên phối hợp hướng về bãi — minh họa hướng tác chiến, không phải đội hình hay vị trí thật.", "durationMs": 1100, "targetState": {"obstructed": true, "waterLevel": 0.28, "boatProgress": 0.85, "decoyProgress": 1, "counterattackProgress": 1}}, {"id": "summary", "hint": "Sơ đồ chuỗi 5 giai đoạn: đây là kết luận, không phải một cảnh hành động mới.", "title": "Tổng kết", "easing": "easeInOut", "effects": ["SHOW_SEQUENCE_SUMMARY"], "narration": "Chiến thắng đến từ một chuỗi chủ động: chuẩn bị bãi cọc → tính toán nhịp thủy triều → dụ thuyền địch vào đúng lúc nước lớn → vật cản khống chế → phản công phối hợp khi triều rút. Cơ chế vật lý chỉ là một phần của mưu lược — sơ đồ bên trên tóm tắt lại trình tự đó.", "durationMs": 1100, "targetState": {"obstructed": true, "waterLevel": 0.28, "boatProgress": 0.85, "decoyProgress": 1, "showSequenceSummary": true, "counterattackProgress": 1}}], "title": "Trận Bạch Đằng năm 938", "assets": [], "canvas": {"aspectRatio": 1.6}, "objects": [], "disclaimer": "Sơ đồ minh họa chiến thuật, không theo tỉ lệ và không phải phục dựng chính xác trận đánh.", "prediction": {"options": [{"text": "Các cọc vẫn chìm sâu và không ảnh hưởng đến đường đi."}, {"text": "Các cọc dần lộ ra, khiến thuyền khó di chuyển."}], "question": "Khi nước triều rút xuống, điều gì thay đổi đối với thuyền tiến vào khu vực bãi cọc?", "retryHint": "Thử kéo mực nước xuống thấp rồi quan sát: phần cọc nào còn chìm, phần nào đã lộ? Thuyền nổi trên mặt nước sẽ chạm vào đâu?", "explanation": "Khi mực nước hạ, đỉnh cọc nhô lên khỏi mặt sông. Thuyền đã tiến vào vùng bãi cọc lúc nước lớn sẽ vướng phải chướng ngại vật này — chính là cơ chế khiến đội hình địch bị khống chế để phản công.", "revealTargetState": {"obstructed": true, "waterLevel": 0.22, "boatProgress": 0.85, "highlightStakes": true}, "explainedOptionIndex": 1}, "initialState": {}, "interactions": ["WATER_LEVEL_CONTROL", "PREDICTION"], "rendererCode": "RIVER_TIDE", "schemaVersion": 1, "rendererVersion": 1, "sourceReferences": [{"title": "Bảo tàng Lịch sử Quốc gia — \\"Ngô Quyền và chiến thắng Bạch Đằng năm 938\\" (baotanglichsuquocgia.vn)."}], "learningObjective": "Hiểu mối liên hệ giữa bãi cọc được chuẩn bị trước, thủy triều, việc dụ thuyền địch và thời điểm phản công phối hợp trong chiến thắng Bạch Đằng."}	PUBLISHED	d7a30000-0000-4000-8000-000000000001	00000000-0000-4000-8000-000000000001	00000000-0000-4000-8000-000000000001	2026-10-24 13:08:01.670146+00	2026-10-24 13:08:01.670146+00	0
d7a20000-0000-4000-8000-000000000002	d7a10000-0000-4000-8000-000000000002	\N	Khởi nghĩa Hai Bà Trưng năm 40	{"map": {"routes": [{"id": "gather", "to": "me-linh", "via": [{"x": 0.40, "y": 0.55}], "from": "hat-mon", "explanation": "Từ điểm phát khởi, lực lượng và người dân quy tụ về Mê Linh — sơ đồ minh họa, không phải đường đi cụ thể."}, {"id": "advance", "to": "luy-lau", "via": [{"x": 0.60, "y": 0.40}], "from": "me-linh", "explanation": "Cuộc khởi nghĩa hướng về Luy Lâu, trung tâm cai trị của nhà Hán — tuyến chỉ mang tính minh họa hướng phát triển."}], "locations": [{"x": 0.30, "y": 0.62, "id": "hat-mon", "name": "Hát Môn", "description": "Khu vực sông Hát / Hát Môn — nơi cuộc khởi nghĩa bắt đầu năm 40 theo truyền thống lịch sử được ghi nhận rộng rãi.", "contextLabel": "Nơi phát khởi"}, {"x": 0.48, "y": 0.42, "id": "me-linh", "name": "Mê Linh", "description": "Vùng Mê Linh — quê hương và nơi quy tụ lực lượng, người dân các vùng lân cận hưởng ứng cuộc khởi nghĩa.", "contextLabel": "Nơi quy tụ"}, {"x": 0.72, "y": 0.34, "id": "luy-lau", "name": "Luy Lâu", "description": "Luy Lâu — trung tâm hành chính của nhà Đông Hán ở Giao Chỉ, đại diện cho bộ máy cai trị mà cuộc khởi nghĩa hướng tới.", "contextLabel": "Trung tâm Hán"}]}, "steps": [{"id": "context", "hint": "Quan sát sơ đồ khu vực rồi tiếp tục.", "title": "Bối cảnh", "easing": "easeInOut", "narration": "Đầu thế kỷ I sau Công nguyên, vùng đồng bằng Bắc Bộ chịu sự cai trị của nhà Đông Hán. Sơ đồ chỉ gợi ý một số địa điểm tiêu biểu — không phải bản đồ hành chính của thời kỳ đó.", "durationMs": 1100, "targetState": {"markerVisibility": {}}}, {"id": "outbreak", "hint": "Địa điểm sáng lên là nơi khởi nghĩa bắt đầu.", "title": "Khởi nghĩa bùng lên", "easing": "easeInOut", "narration": "Năm 40, cuộc khởi nghĩa do Hai Bà Trưng khởi xướng bắt đầu ở khu vực sông Hát / Hát Môn. Sử liệu không ghi lại vị trí chính xác từng điểm — đây chỉ là minh họa vùng.", "durationMs": 1100, "targetState": {"markerVisibility": {"hat-mon": 1}, "focusedLocationId": "hat-mon"}}, {"id": "gather", "hint": "Tuyến nét đứt chỉ mang tính sơ đồ hóa quan hệ giữa hai vùng.", "title": "Quy tụ lực lượng", "easing": "easeInOut", "narration": "Từ điểm phát khởi, lực lượng và người dân các nơi quy tụ về Mê Linh — quê hương của Hai Bà Trưng. Tuyến nối trên sơ đồ là minh họa sự lan rộng, không khẳng định đường đi thật.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1}, "markerVisibility": {"hat-mon": 1, "me-linh": 1}, "focusedLocationId": "me-linh"}}, {"id": "advance", "hint": "Vì sao Luy Lâu lại là điểm quan trọng?", "title": "Hướng về Luy Lâu", "easing": "easeInOut", "narration": "Cuộc khởi nghĩa lan rộng và hướng tới Luy Lâu — trung tâm hành chính của nhà Đông Hán ở Giao Chỉ, nơi đặt bộ máy cai trị của Tô Định.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}, "focusedLocationId": "luy-lau"}}, {"id": "explore", "hint": "Thử chạm vào Hát Môn, Mê Linh và Luy Lâu.", "title": "Khám phá bản đồ", "easing": "easeInOut", "narration": "Chạm vào từng địa điểm để đọc ý nghĩa lịch sử của nó. Mỗi địa điểm là một mảnh của bức tranh khởi nghĩa: nơi phát khởi, nơi quy tụ và mục tiêu chính trị.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}}, "allowedInteractions": ["TAP_TO_EXPLORE"]}, {"id": "meaning", "hint": "Có thể tua lại các bước hoặc chạm địa điểm để xem lại.", "title": "Ý nghĩa", "easing": "easeInOut", "narration": "Cuộc khởi nghĩa năm 40 thể hiện tinh thần độc lập mạnh mẽ và trực tiếp thách thức bộ máy cai trị của nhà Hán tại Luy Lâu. Tuy nhiên, đây mới là giai đoạn đầu — cuộc đấu tranh còn kéo dài và chưa mang lại độc lập lâu dài ngay lúc đó.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}}}], "title": "Khởi nghĩa Hai Bà Trưng năm 40", "assets": [], "canvas": {"aspectRatio": 1.6}, "objects": [], "disclaimer": "Bản đồ minh họa schematic, không theo tỉ lệ, không phải bản đồ địa lý hay phục dựng chính xác đường đi.", "prediction": {"options": [{"text": "Vì đây là nơi cuộc khởi nghĩa bắt đầu năm 40."}, {"text": "Vì đây là trung tâm hành chính của nhà Hán ở Giao Chỉ, đại diện cho bộ máy cai trị mà cuộc khởi nghĩa hướng tới."}], "question": "Tại sao Luy Lâu là một địa điểm quan trọng trong diễn biến khởi nghĩa?", "retryHint": "Nhìn lại sơ đồ: Hát Môn mới là nơi phát khởi. Luy Lâu đóng vai trò khác trong thể chế cai trị — thử suy nghĩ về vai trò đó.", "explanation": "Luy Lâu là trung tâm hành chính của nhà Đông Hán tại Giao Chỉ. Việc cuộc khởi nghĩa hướng về Luy Lâu cho thấy sức lan tỏa của phong trào và thách thức trực tiếp đến bộ máy cai trị — chứ không chỉ là một cuộc nổi dậy cục bộ.", "revealTargetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}, "focusedLocationId": "luy-lau"}, "explainedOptionIndex": 1}, "initialState": {}, "interactions": ["TAP_TO_EXPLORE", "PREDICTION"], "rendererCode": "JOURNEY_MAP", "schemaVersion": 1, "rendererVersion": 1, "sourceReferences": [{"title": "Bảo tàng Lịch sử Quốc gia — \\"Cuộc khởi nghĩa Hai Bà Trưng (năm 40–43 sau Công nguyên)\\" (baotanglichsuquocgia.vn)."}], "learningObjective": "Nhận biết các địa điểm then chốt của cuộc khởi nghĩa năm 40 và hiểu vai trò của Luy Lâu như trung tâm cai trị của nhà Hán."}	PUBLISHED	d7a30000-0000-4000-8000-000000000002	00000000-0000-4000-8000-000000000001	00000000-0000-4000-8000-000000000001	2026-10-24 13:08:01.670146+00	2026-10-24 13:08:01.670146+00	0
d7a20000-0000-4000-8000-000000000003	d7a10000-0000-4000-8000-000000000002	\N	Lý Thái Tổ dời đô năm 1010	{"map": {"routes": [{"id": "relocation", "to": "dai-la", "via": [{"x": 0.45, "y": 0.58}], "from": "hoa-lu", "explanation": "Dời kinh đô từ Hoa Lư về Đại La — tuyến minh họa khái niệm, không phải đường đi hay đường thủy thật."}], "locations": [{"x": 0.28, "y": 0.70, "id": "hoa-lu", "name": "Hoa Lư", "description": "Hoa Lư — kinh đô của các triều Đinh và Tiền Lê, kinh đô cũ trước khi triều Lý quyết định dời đô năm 1010.", "contextLabel": "Kinh đô cũ"}, {"x": 0.62, "y": 0.40, "id": "dai-la", "name": "Đại La — Thăng Long", "description": "Thành Đại La — nơi Lý Thái Tổ chọn làm kinh đô mới năm 1010, sau đổi tên thành Thăng Long. Đại La và Thăng Long là CÙNG một địa điểm, không phải hai thành khác nhau.", "contextLabel": "Kinh đô mới"}]}, "steps": [{"id": "old-capital", "hint": "Địa điểm sáng lên là kinh đô cũ.", "title": "Hoa Lư — kinh đô cũ", "easing": "easeInOut", "narration": "Hoa Lư từng là kinh đô của các triều Đinh và Tiền Lê — trung tâm chính trị trước khi nhà Lý lên ngôi. Địa thế núi non hiểm trở phù hợp phòng thủ nhưng hạn chế cho phát triển lâu dài.", "durationMs": 1100, "targetState": {"markerVisibility": {"hoa-lu": 1}, "focusedLocationId": "hoa-lu"}}, {"id": "considering", "hint": "Vì sao một kinh đô mới lại được cân nhắc?", "title": "Cân nhắc dời đô", "easing": "easeInOut", "narration": "Sau khi lên ngôi, Lý Thái Tổ và triều thần cân nhắc vị trí kinh đô. Theo tư liệu truyền thống, việc chọn địa điểm mới gắn với cân nhắc về địa thế và hướng phát triển lâu dài của đất nước — sử liệu không ghi đầy đủ mọi lý do cụ thể.", "durationMs": 1100, "targetState": {"markerVisibility": {"hoa-lu": 1}}}, {"id": "chosen", "hint": "Địa điểm mới xuất hiện là kinh đô được chọn.", "title": "Đại La được chọn", "easing": "easeInOut", "narration": "Năm 1010, Lý Thái Tổ chọn vùng thành Đại La làm kinh đô mới. Vị trí trung tâm vùng đồng bằng, thuận lợi giao thông và phát triển — theo cách hiểu được ghi nhận trong tư liệu.", "durationMs": 1100, "targetState": {"markerVisibility": {"dai-la": 1, "hoa-lu": 1}, "focusedLocationId": "dai-la"}}, {"id": "relocated", "hint": "Tuyến đứt nét là sơ đồ khái niệm, không phải đường thật.", "title": "Dời đô năm 1010", "easing": "easeInOut", "narration": "Quyết định dời đô từ Hoa Lư về Đại La được thực hiện năm 1010. Tuyến nối trên sơ đồ chỉ minh họa quan hệ giữa hai địa điểm — không phải đường đi hay hành trình cụ thể của triều đình.", "durationMs": 1100, "targetState": {"routeProgress": {"relocation": 1}, "markerVisibility": {"dai-la": 1, "hoa-lu": 1}, "focusedLocationId": "dai-la"}}, {"id": "thang-long", "hint": "Chạm vào từng địa điểm để đọc vai trò của nó.", "title": "Thăng Long", "easing": "easeInOut", "narration": "Kinh đô mới ở Đại La được đặt tên Thăng Long — \\"rồng bay lên\\". Quyết định năm 1010 đặt nền móng cho một trung tâm chính trị lâu dài, gắn với Hà Nội ngày nay.", "durationMs": 1100, "targetState": {"routeProgress": {"relocation": 1}, "markerHighlight": ["dai-la"], "markerVisibility": {"dai-la": 1, "hoa-lu": 1}}, "allowedInteractions": ["TAP_TO_EXPLORE"]}], "title": "Lý Thái Tổ dời đô năm 1010", "assets": [], "canvas": {"aspectRatio": 1.6}, "objects": [], "disclaimer": "Bản đồ minh họa schematic, không theo tỉ lệ, không phải bản đồ địa lý hay đường đi thực tế của triều đình.", "prediction": {"options": [{"text": "Hoa Lư — kinh đô cũ được giữ nguyên."}, {"text": "Đại La — sau này mang tên Thăng Long."}], "question": "Địa điểm nào được Lý Thái Tổ lựa chọn làm kinh đô mới?", "retryHint": "Hoa Lư là kinh đô CŨ. Hãy xem lại sơ đồ: địa điểm nào vừa xuất hiện ở bước \\"Đại La được chọn\\"?", "explanation": "Năm 1010, Lý Thái Tổ chọn thành Đại La làm kinh đô mới và đổi tên thành Thăng Long. Đại La và Thăng Long là cùng một địa điểm — quyết định này gắn với cân nhắc địa thế trung tâm và tầm phát triển lâu dài.", "revealTargetState": {"routeProgress": {"relocation": 1}, "markerHighlight": ["dai-la"], "markerVisibility": {"dai-la": 1, "hoa-lu": 1}, "focusedLocationId": "dai-la"}, "explainedOptionIndex": 1}, "initialState": {}, "interactions": ["TAP_TO_EXPLORE", "PREDICTION"], "rendererCode": "JOURNEY_MAP", "schemaVersion": 1, "rendererVersion": 1, "sourceReferences": [{"title": "Bảo tàng Lịch sử Quốc gia — \\"Thăng Long thời nhà Lý (1009–1225)\\" và \\"Hà Nội — địa linh nhân kiệt\\" (baotanglichsuquocgia.vn)."}], "learningObjective": "Hiểu vì sao Lý Thái Tổ chọn Đại La làm kinh đô mới và ý nghĩa lâu dài của quyết định dời đô năm 1010."}	PUBLISHED	d7a30000-0000-4000-8000-000000000003	00000000-0000-4000-8000-000000000001	00000000-0000-4000-8000-000000000001	2026-10-24 13:08:01.670146+00	2026-10-24 13:08:01.670146+00	0
d7a40000-0000-4000-8000-000000000001	d7a10000-0000-4000-8000-000000000001	\N	Trận Bạch Đằng năm 938 — Cinematic	{"audio": [{"cue": "LOOP", "stepId": "prepare", "volume": 0.4, "assetRef": "amb-river"}, {"cue": "ENTER", "stepId": "tide-fall", "volume": 0.5, "assetRef": "amb-river"}, {"cue": "ENTER", "stepId": "counterattack", "volume": 0.7, "assetRef": "amb-river"}, {"cue": "EXIT", "fadeMs": 600, "stepId": "summary", "assetRef": "amb-river"}], "river": {"stakes": [{"x": 0.42, "id": "stake-1", "length": 0.20}, {"x": 0.47, "id": "stake-2", "length": 0.22}, {"x": 0.52, "id": "stake-3", "length": 0.17}, {"x": 0.57, "id": "stake-4", "length": 0.24}, {"x": 0.62, "id": "stake-5", "length": 0.19}, {"x": 0.45, "id": "stake-6", "length": 0.16}, {"x": 0.55, "id": "stake-7", "length": 0.21}, {"x": 0.65, "id": "stake-8", "length": 0.23}, {"x": 0.60, "id": "stake-9", "length": 0.18}]}, "steps": [{"id": "prepare", "hint": "Quan sát vị trí các cọc nhô lên từ đáy sông.", "title": "Chuẩn bị", "easing": "easeInOut", "narration": "Trước trận đánh, quân ta đã đóng sẵn một bãi cọc gỗ ngầm dưới lòng sông. Sơ đồ chỉ vẽ cọc mang tính minh họa — sử liệu không ghi bố trí chính xác từng cọc.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.30, "boatProgress": 0.0}}, {"id": "tide-rise", "hint": "Kéo thanh mực nước để tự thấy cọc bị che đi.", "title": "Nước dâng", "easing": "easeInOut", "narration": "Khi thủy triều dâng, mặt nước cao dần và che khuất đỉnh cọc. Từ trên thuyền nhìn xuống, khó nhận ra chướng ngại vật đang ẩn phía dưới.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.90, "boatProgress": 0.0}, "allowedInteractions": ["WATER_LEVEL_CONTROL"]}, {"id": "decoy", "hint": "Camera theo thuyền dụ vào vùng bãi cọc.", "title": "Dụ địch vào bãi", "easing": "easeInOut", "narration": "Sử liệu ghi nhận quân ta đã lợi dụng lúc nước lớn dụ hoặc dẫn thuyền địch vào vùng bãi cọc. Thuyền dụ địch (track keyframe) trượt về phía bãi.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.90, "boatProgress": 0.72, "decoyProgress": 1}}, {"id": "tide-fall", "hint": "Camera zoom + ripple overlay đánh dấu bãi cọc lộ.", "title": "Nước rút", "easing": "easeInOut", "narration": "Khi triều rút, mực nước hạ dần và những đỉnh cọc lộ ra — camera zoom vào bãi cọc; gợn nước đánh dấu điểm mấu chốt.", "durationMs": 1100, "targetState": {"obstructed": false, "waterLevel": 0.28, "boatProgress": 0.85, "decoyProgress": 1}, "allowedInteractions": ["WATER_LEVEL_CONTROL"]}, {"id": "counterattack", "hint": "Glow + camera zoom tối đa khi phản công.", "title": "Phản công phối hợp", "easing": "easeInOut", "narration": "Thuyền địch vướng vào bãi cọc, khó di chuyển. Camera zoom sâu hơn; glow quanh thuyền dụ đánh dấu điểm dồn lực phản công.", "durationMs": 1100, "targetState": {"obstructed": true, "waterLevel": 0.28, "boatProgress": 0.85, "decoyProgress": 1, "counterattackProgress": 1}}, {"id": "summary", "hint": "Fade out kết thúc cinematic.", "title": "Tổng kết", "easing": "easeInOut", "effects": ["SHOW_SEQUENCE_SUMMARY"], "narration": "Chiến thắng đến từ chuỗi chủ động: chuẩn bị bãi cọc → tính nhịp thủy triều → dụ địch → khống chế → phản công. Fade out khép lại cảnh điện ảnh.", "durationMs": 1100, "targetState": {"obstructed": true, "waterLevel": 0.28, "boatProgress": 0.85, "decoyProgress": 1, "showSequenceSummary": true, "counterattackProgress": 1}}], "title": "Trận Bạch Đằng năm 938 — Cinematic", "assets": [{"id": "amb-river", "role": "AUDIO", "assetId": "d7a60000-0000-4000-8000-000000000001"}], "camera": {"steps": [{"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, {"target": {"x": 0.55, "y": 0.55, "zoom": 1.2, "focusObjectId": "boat-decoy"}}, {"target": {"x": 0.52, "y": 0.55, "zoom": 1.6}}, {"target": {"x": 0.55, "y": 0.5, "zoom": 1.8}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}], "initial": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, "canvas": {"aspectRatio": 1.6}, "tracks": [{"objectId": "boat-decoy", "property": "position", "keyframes": [{"tMs": 0, "value": {"x": 0.15, "y": 0.45}, "easing": "linear"}, {"tMs": 2200, "value": {"x": 0.45, "y": 0.42}, "easing": "linear"}, {"tMs": 4400, "value": {"x": 0.62, "y": 0.40}, "easing": "linear"}, {"tMs": 6600, "value": {"x": 0.62, "y": 0.40}, "easing": "linear"}]}, {"objectId": "boat-decoy", "property": "rotation", "keyframes": [{"tMs": 0, "value": 0, "easing": "easeInOut"}, {"tMs": 4400, "value": 0, "easing": "easeInOut"}, {"tMs": 6600, "value": -25, "easing": "easeInOut"}]}], "effects": [{"type": "MIST", "params": {"intensity": 0.3}}, {"type": "WATER_RIPPLE", "params": {"x": 0.55, "y": 0.62, "intensity": 0.7}, "stepId": "tide-fall", "durationMs": 2200}, {"type": "GLOW", "params": {"x": 0.55, "y": 0.45, "objectId": "boat-decoy", "intensity": 0.5}, "stepId": "counterattack", "durationMs": 2200}, {"type": "FADE_OUT", "stepId": "summary", "durationMs": 800}], "objects": [{"id": "boat-decoy", "type": "BOAT", "layer": 1, "scale": 0.14, "opacity": 1, "visible": true, "position": {"x": 0.15, "y": 0.45}, "rotation": 0}], "disclaimer": "Sơ đồ minh họa chiến thuật + cinematic camera — không theo tỉ lệ, không phải phục dựng chính xác trận đánh.", "prediction": {"options": [{"text": "Các cọc vẫn chìm sâu và không ảnh hưởng đến đường đi."}, {"text": "Các cọc dần lộ ra, khiến thuyền khó di chuyển."}], "question": "Khi nước triều rút xuống, điều gì thay đổi đối với thuyền tiến vào khu vực bãi cọc?", "retryHint": "Thử kéo mực nước xuống thấp rồi quan sát: phần cọc nào còn chìm, phần nào đã lộ?", "explanation": "Khi mực nước hạ, đỉnh cọc nhô lên khỏi mặt sông — thuyền đã tiến vào vùng bãi cọc lúc nước lớn sẽ vướng phải chướng ngại vật này.", "revealTargetState": {"obstructed": true, "waterLevel": 0.22, "boatProgress": 0.85, "highlightStakes": true}, "explainedOptionIndex": 1}, "environment": {"glow": 0.2, "mist": 0.35}, "initialState": {}, "interactions": ["WATER_LEVEL_CONTROL", "PREDICTION"], "rendererCode": "RIVER_TIDE", "schemaVersion": 2, "rendererVersion": 1, "sourceReferences": [{"title": "Bảo tàng Lịch sử Quốc gia — \\"Ngô Quyền và chiến thắng Bạch Đằng năm 938\\" (baotanglichsuquocgia.vn)."}], "learningObjective": "Hiểu mối liên hệ giữa bãi cọc, thủy triều, việc dụ địch và phản công phối hợp — qua lăng kính điện ảnh: camera pan/zoom, object chuyển động, hiệu ứng môi trường."}	PUBLISHED	d7a50000-0000-4000-8000-000000000001	00000000-0000-4000-8000-000000000001	00000000-0000-4000-8000-000000000001	2026-10-24 13:08:01.730606+00	2026-10-24 13:08:01.730606+00	0
d7a40000-0000-4000-8000-000000000002	d7a10000-0000-4000-8000-000000000002	\N	Khởi nghĩa Hai Bà Trưng năm 40 — Cinematic	{"map": {"routes": [{"id": "gather", "to": "me-linh", "via": [{"x": 0.40, "y": 0.55}], "from": "hat-mon", "explanation": "Từ điểm phát khởi, lực lượng quy tụ về Mê Linh."}, {"id": "advance", "to": "luy-lau", "via": [{"x": 0.60, "y": 0.40}], "from": "me-linh", "explanation": "Cuộc khởi nghĩa hướng về Luy Lâu."}], "locations": [{"x": 0.30, "y": 0.62, "id": "hat-mon", "name": "Hát Môn", "description": "Khu vực sông Hát / Hát Môn — nơi cuộc khởi nghĩa bắt đầu năm 40.", "contextLabel": "Nơi phát khởi"}, {"x": 0.48, "y": 0.42, "id": "me-linh", "name": "Mê Linh", "description": "Vùng Mê Linh — quê hương và nơi quy tụ lực lượng.", "contextLabel": "Nơi quy tụ"}, {"x": 0.72, "y": 0.34, "id": "luy-lau", "name": "Luy Lâu", "description": "Luy Lâu — trung tâm hành chính của nhà Đông Hán ở Giao Chỉ.", "contextLabel": "Trung tâm Hán"}]}, "audio": [{"cue": "ENTER", "stepId": "context", "volume": 0.4, "assetRef": "amb-battle"}, {"cue": "ENTER", "stepId": "outbreak", "volume": 0.5, "assetRef": "amb-battle"}, {"cue": "ENTER", "stepId": "gather", "volume": 0.5, "assetRef": "amb-battle"}, {"cue": "ENTER", "stepId": "advance", "volume": 0.6, "assetRef": "amb-battle"}, {"cue": "EXIT", "fadeMs": 800, "stepId": "meaning", "assetRef": "amb-battle"}], "steps": [{"id": "context", "hint": "Fade in đánh dấu mở cảnh.", "title": "Bối cảnh", "easing": "easeInOut", "narration": "Đầu thế kỷ I sau Công nguyên, vùng đồng bằng Bắc Bộ chịu sự cai trị của nhà Đông Hán. Fade in mở màn.", "durationMs": 1100, "targetState": {"markerVisibility": {}}}, {"id": "outbreak", "hint": "Camera pan + zoom vào Hát Môn, glow nhấn điểm phát khởi.", "title": "Khởi nghĩa bùng lên", "easing": "easeInOut", "narration": "Năm 40, cuộc khởi nghĩa bùng lên ở sông Hát / Hát Môn. Camera zoom vào điểm phát khởi với glow đánh dấu.", "durationMs": 1100, "targetState": {"markerVisibility": {"hat-mon": 1}, "focusedLocationId": "hat-mon"}}, {"id": "gather", "hint": "Camera pan sang Mê Linh, route reveal trên bản đồ.", "title": "Quy tụ lực lượng", "easing": "easeInOut", "narration": "Từ điểm phát khởi, lực lượng quy tụ về Mê Linh. Camera tiếp tục pan theo hướng di chuyển.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1}, "markerVisibility": {"hat-mon": 1, "me-linh": 1}, "focusedLocationId": "me-linh"}}, {"id": "advance", "hint": "Zoom mạnh nhất tại Luy Lâu.", "title": "Hướng về Luy Lâu", "easing": "easeInOut", "narration": "Cuộc khởi nghĩa hướng tới Luy Lâu — camera zoom sâu nhất khi nhắm trung tâm cai trị Hán.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}, "focusedLocationId": "luy-lau"}}, {"id": "explore", "hint": "Camera zoom out, mở khám phá tương tác.", "title": "Khám phá bản đồ", "easing": "easeInOut", "narration": "Camera trở về tổng quan — chạm vào từng địa điểm để đọc ý nghĩa lịch sử.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}}, "allowedInteractions": ["TAP_TO_EXPLORE"]}, {"id": "meaning", "hint": "Fade out kết thúc cinematic.", "title": "Ý nghĩa", "easing": "easeInOut", "narration": "Cuộc khởi nghĩa năm 40 thể hiện tinh thần độc lập mạnh mẽ. Fade out khép lại hành trình.", "durationMs": 1100, "targetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}}}], "title": "Khởi nghĩa Hai Bà Trưng năm 40 — Cinematic", "assets": [{"id": "amb-battle", "role": "AUDIO", "assetId": "d7a60000-0000-4000-8000-000000000001"}], "camera": {"steps": [{"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, {"target": {"x": 0.3, "y": 0.62, "zoom": 1.4, "focusLocationId": "hat-mon"}}, {"target": {"x": 0.48, "y": 0.42, "zoom": 1.4, "focusLocationId": "me-linh"}}, {"target": {"x": 0.72, "y": 0.34, "zoom": 1.5, "focusLocationId": "luy-lau"}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}], "initial": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, "canvas": {"aspectRatio": 1.6}, "tracks": [], "effects": [{"type": "FADE_IN", "stepId": "context", "durationMs": 800}, {"type": "GLOW", "params": {"x": 0.30, "y": 0.62, "intensity": 0.6}, "stepId": "outbreak", "durationMs": 2200}, {"type": "GLOW", "params": {"x": 0.72, "y": 0.34, "intensity": 0.6}, "stepId": "advance", "durationMs": 2200}, {"type": "FADE_OUT", "stepId": "meaning", "durationMs": 1000}], "objects": [], "disclaimer": "Bản đồ minh họa schematic + cinematic camera — không theo tỉ lệ, không phải bản đồ địa lý chính xác.", "prediction": {"options": [{"text": "Vì đây là nơi cuộc khởi nghĩa bắt đầu năm 40."}, {"text": "Vì đây là trung tâm hành chính của nhà Hán ở Giao Chỉ."}], "question": "Tại sao Luy Lâu là một địa điểm quan trọng trong diễn biến khởi nghĩa?", "retryHint": "Nhìn lại sơ đồ: Hát Môn mới là nơi phát khởi. Luy Lâu đóng vai trò khác trong thể chế cai trị.", "explanation": "Luy Lâu là trung tâm hành chính của nhà Đông Hán tại Giao Chỉ — cuộc khởi nghĩa hướng về Luy Lâu thách thức trực tiếp bộ máy cai trị.", "revealTargetState": {"routeProgress": {"gather": 1, "advance": 1}, "markerHighlight": ["luy-lau"], "markerVisibility": {"hat-mon": 1, "luy-lau": 1, "me-linh": 1}, "focusedLocationId": "luy-lau"}, "explainedOptionIndex": 1}, "initialState": {}, "interactions": ["TAP_TO_EXPLORE", "PREDICTION"], "rendererCode": "JOURNEY_MAP", "schemaVersion": 2, "rendererVersion": 1, "sourceReferences": [{"title": "Bảo tàng Lịch sử Quốc gia — \\"Cuộc khởi nghĩa Hai Bà Trưng (năm 40–43 sau Công nguyên)\\" (baotanglichsuquocgia.vn)."}], "learningObjective": "Nhận biết các địa điểm then chốt qua camera pan điện ảnh + route reveal — Hát Môn, Mê Linh, Luy Lâu."}	PUBLISHED	d7a50000-0000-4000-8000-000000000002	00000000-0000-4000-8000-000000000001	00000000-0000-4000-8000-000000000001	2026-10-24 13:08:01.730606+00	2026-10-24 13:08:01.730606+00	0
d7a40000-0000-4000-8000-000000000003	d7a10000-0000-4000-8000-000000000002	\N	Lý Thái Tổ dời đô năm 1010 — Cinematic	{"map": {"routes": [{"id": "relocation", "to": "dai-la", "via": [{"x": 0.45, "y": 0.58}], "from": "hoa-lu", "explanation": "Dời kinh đô từ Hoa Lư về Đại La."}], "locations": [{"x": 0.28, "y": 0.70, "id": "hoa-lu", "name": "Hoa Lư", "description": "Hoa Lư — kinh đô của các triều Đinh và Tiền Lê.", "contextLabel": "Kinh đô cũ"}, {"x": 0.62, "y": 0.40, "id": "dai-la", "name": "Đại La — Thăng Long", "description": "Thành Đại La — nơi Lý Thái Tổ chọn làm kinh đô mới năm 1010.", "contextLabel": "Kinh đô mới"}]}, "audio": [{"cue": "ENTER", "stepId": "old-capital", "volume": 0.4, "assetRef": "amb-court"}, {"cue": "ENTER", "stepId": "chosen", "volume": 0.6, "assetRef": "amb-court"}, {"cue": "EXIT", "fadeMs": 1000, "stepId": "thang-long", "assetRef": "amb-court"}], "steps": [{"id": "old-capital", "hint": "Camera đã zoom sẵn vào Hoa Lư từ đầu.", "title": "Hoa Lư — kinh đô cũ", "easing": "easeInOut", "narration": "Hoa Lư từng là kinh đô của các triều Đinh và Tiền Lê. Camera bắt đầu zoom sẵn tại đây + fade in mở màn.", "durationMs": 1100, "targetState": {"markerVisibility": {"hoa-lu": 1}, "focusedLocationId": "hoa-lu"}}, {"id": "considering", "hint": "Camera zoom out — chuẩn bị reveal lựa chọn mới.", "title": "Cân nhắc dời đô", "easing": "easeInOut", "narration": "Sau khi lên ngôi, Lý Thái Tổ cân nhắc vị trí kinh đô mới — camera kéo ra để bao quát cả hai vùng.", "durationMs": 1100, "targetState": {"markerVisibility": {"hoa-lu": 1}}}, {"id": "chosen", "hint": "Zoom + glow đánh dấu Đại La được chọn.", "title": "Đại La được chọn", "easing": "easeInOut", "narration": "Năm 1010, Lý Thái Tổ chọn Đại La làm kinh đô mới — camera zoom sâu nhất + glow đánh dấu.", "durationMs": 1100, "targetState": {"markerVisibility": {"dai-la": 1, "hoa-lu": 1}, "focusedLocationId": "dai-la"}}, {"id": "relocated", "hint": "Camera zoom out để nhìn cả hành trình.", "title": "Dời đô năm 1010", "easing": "easeInOut", "narration": "Quyết định dời đô thực hiện — camera kéo ra để bao trọn tuyến dời đô.", "durationMs": 1100, "targetState": {"routeProgress": {"relocation": 1}, "markerVisibility": {"dai-la": 1, "hoa-lu": 1}, "focusedLocationId": "dai-la"}}, {"id": "thang-long", "hint": "Fade out kết thúc cinematic.", "title": "Thăng Long", "easing": "easeInOut", "narration": "Kinh đô mới được đặt tên Thăng Long — \\"rồng bay lên\\". Fade out khép lại hành trình điện ảnh.", "durationMs": 1100, "targetState": {"routeProgress": {"relocation": 1}, "markerHighlight": ["dai-la"], "markerVisibility": {"dai-la": 1, "hoa-lu": 1}}, "allowedInteractions": ["TAP_TO_EXPLORE"]}], "title": "Lý Thái Tổ dời đô năm 1010 — Cinematic", "assets": [{"id": "amb-court", "role": "AUDIO", "assetId": "d7a60000-0000-4000-8000-000000000001"}], "camera": {"steps": [{"target": {"x": 0.28, "y": 0.70, "zoom": 1.5}}, {"target": {"x": 0.45, "y": 0.55, "zoom": 1.2}}, {"target": {"x": 0.62, "y": 0.40, "zoom": 1.6, "focusLocationId": "dai-la"}}, {"target": {"x": 0.45, "y": 0.58, "zoom": 1.0}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}], "initial": {"x": 0.28, "y": 0.70, "zoom": 1.3, "focusLocationId": "hoa-lu"}}, "canvas": {"aspectRatio": 1.6}, "tracks": [], "effects": [{"type": "FADE_IN", "stepId": "old-capital", "durationMs": 900}, {"type": "GLOW", "params": {"x": 0.62, "y": 0.40, "intensity": 0.7}, "stepId": "chosen", "durationMs": 2200}, {"type": "FADE_OUT", "stepId": "thang-long", "durationMs": 1200}], "objects": [], "disclaimer": "Bản đồ minh họa schematic + cinematic camera — không theo tỉ lệ, không phải bản đồ địa lý chính xác.", "prediction": {"options": [{"text": "Hoa Lư — kinh đô cũ được giữ nguyên."}, {"text": "Đại La — sau này mang tên Thăng Long."}], "question": "Địa điểm nào được Lý Thái Tổ lựa chọn làm kinh đô mới?", "retryHint": "Hoa Lư là kinh đô CŨ. Hãy xem lại sơ đồ: địa điểm nào vừa xuất hiện?", "explanation": "Năm 1010, Lý Thái Tổ chọn thành Đại La làm kinh đô mới và đổi tên thành Thăng Long.", "revealTargetState": {"routeProgress": {"relocation": 1}, "markerHighlight": ["dai-la"], "markerVisibility": {"dai-la": 1, "hoa-lu": 1}, "focusedLocationId": "dai-la"}, "explainedOptionIndex": 1}, "initialState": {}, "interactions": ["TAP_TO_EXPLORE", "PREDICTION"], "rendererCode": "JOURNEY_MAP", "schemaVersion": 2, "rendererVersion": 1, "sourceReferences": [{"title": "Bảo tàng Lịch sử Quốc gia — \\"Thăng Long thời nhà Lý (1009–1225)\\" và \\"Hà Nội — địa linh nhân kiệt\\" (baotanglichsuquocgia.vn)."}], "learningObjective": "Hiểu vì sao Lý Thái Tổ chọn Đại La làm kinh đô mới — qua cinematic zoom-out reveal."}	PUBLISHED	d7a50000-0000-4000-8000-000000000003	00000000-0000-4000-8000-000000000001	00000000-0000-4000-8000-000000000001	2026-10-24 13:08:01.730606+00	2026-10-24 13:08:01.730606+00	0
d7a80000-0000-4000-8000-000000000001	d7a10000-0000-4000-8000-000000000001	00000000-0000-0000-0000-000000000001	Trận Bạch Đằng năm 938 — Production	{"audio": [{"cue": "ENTER", "stepId": "estuary", "volume": 0.9, "assetRef": "voice"}], "river": {"stakes": [{"x": 0.40, "id": "stake-1", "length": 0.22}, {"x": 0.45, "id": "stake-2", "length": 0.19}, {"x": 0.50, "id": "stake-3", "length": 0.24}, {"x": 0.55, "id": "stake-4", "length": 0.17}, {"x": 0.60, "id": "stake-5", "length": 0.21}, {"x": 0.43, "id": "stake-6", "length": 0.16}, {"x": 0.57, "id": "stake-7", "length": 0.23}, {"x": 0.52, "id": "stake-8", "length": 0.18}]}, "steps": [{"id": "estuary", "hint": "Bản đồ minh họa vùng cửa sông hiện ra rồi mờ dần — camera giữ góc nhìn tổng quan.", "title": "Cửa sông Bạch Đằng", "easing": "easeInOut", "narration": "Cửa sông Bạch Đằng nối ra biển Đông — địa thế triều mạnh, luồng nông, nhiều bãi bồi. Đây là nơi Ngô Quyền chọn làm trận địa đón quân Nam Hán.", "durationMs": 1200, "targetState": {"obstructed": false, "waterLevel": 0.55, "boatProgress": 0.0}}, {"id": "stake-prep", "hint": "Camera hạ xuống mặt nước, các cọc lần lượt lộ ở vùng bãi.", "title": "Đóng cọc ngầm", "easing": "easeInOut", "narration": "Trước trận, quân ta đóng sẵn bãi cọc gỗ lim bịt sắt dưới lòng sông. Sử liệu không ghi bố trí chính xác — sơ đồ chỉ minh họa ý tưởng trận địa.", "durationMs": 1200, "targetState": {"obstructed": false, "waterLevel": 0.30, "boatProgress": 0.0, "highlightStakes": true}}, {"id": "tide-rise", "hint": "Kéo mực nước lên để tự thấy cọc chìm hẳn.", "title": "Triều lên", "easing": "easeInOut", "narration": "Nước triều dâng cao, che khuất đỉnh cọc. Từ trên thuyền nhìn xuống khó nhận ra chướng ngại vật ẩn phía dưới.", "durationMs": 1200, "targetState": {"obstructed": false, "waterLevel": 0.90, "boatProgress": 0.0}, "allowedInteractions": ["WATER_LEVEL_CONTROL"]}, {"id": "decoy", "hint": "Camera bám theo thuyền dụ — thuyền địch tiến từ mép phải vào trung tâm bãi.", "title": "Dụ địch vào bãi", "easing": "easeInOut", "narration": "Lúc nước lớn, thuyền dụ dẫn hạm đội Nam Hán tiến vào vùng bãi cọc. Đoàn địch theo sau, không biết đáy sông đã bố trận.", "durationMs": 1200, "targetState": {"obstructed": false, "waterLevel": 0.90, "boatProgress": 0.72, "decoyProgress": 1}}, {"id": "prediction", "hint": "Dừng lại và dự đoán trước khi xem nước rút.", "title": "Điểm quyết định", "easing": "easeInOut", "narration": "Triều sắp rút. Nếu thuyền địch đã vào sâu bãi cọc, điều gì sẽ xảy ra khi mực nước hạ? Đây là lúc cả trận địa chuyển pha.", "durationMs": 1400, "targetState": {"obstructed": false, "waterLevel": 0.85, "boatProgress": 0.72, "decoyProgress": 1}, "allowedInteractions": ["PREDICTION"]}, {"id": "tide-fall", "hint": "Camera zoom vào bãi + gợn nước đánh dấu điểm mấu chốt.", "title": "Triều rút — cọc lộ", "easing": "easeInOut", "narration": "Triều rút nhanh, đỉnh cọc nhô lên khỏi mặt sông. Thuyền địch mắc vào bãi, không thể quay đầu hay tiếp tục tiến.", "durationMs": 1200, "targetState": {"obstructed": false, "waterLevel": 0.26, "boatProgress": 0.85, "decoyProgress": 1, "highlightStakes": true}, "allowedInteractions": ["WATER_LEVEL_CONTROL"]}, {"id": "counterattack", "hint": "Glow quanh thuyền dụ đánh dấu điểm dồn lực — thuyền địch mắc kẹt.", "title": "Phản công phối hợp", "easing": "easeInOut", "narration": "Khi thuyền địch vướng cọc, quân ta phản công đồng loạt từ nhiều hướng. Thời điểm triều hạ chính là thời điểm quyết định trận đánh.", "durationMs": 1200, "targetState": {"obstructed": true, "waterLevel": 0.26, "boatProgress": 0.85, "decoyProgress": 1, "counterattackProgress": 1}}, {"id": "evidence", "hint": "Fade out — chuỗi quyết định khép lại bằng chứng cứ.", "title": "Kết luận có chứng cứ", "easing": "easeInOut", "narration": "Chiến thắng Bạch Đằng là kết quả của chuỗi chủ động: chọn địa thế triều → chuẩn bị trận địa → dụ địch đúng lúc nước lớn → phản công đúng lúc nước rút. Đây là kết luận dựa trên bối cảnh, không phải chi tiết từng cọc hay từng thuyền được ghi lại.", "durationMs": 1400, "targetState": {"obstructed": true, "waterLevel": 0.26, "boatProgress": 0.85, "decoyProgress": 1, "showSequenceSummary": true, "counterattackProgress": 1}}], "title": "Trận Bạch Đằng năm 938 — Trải nghiệm điện ảnh", "assets": [{"id": "bg-hero", "role": "BACKGROUND", "assetId": "d7a70000-0000-4000-8000-000000000001"}, {"id": "map-base", "role": "OBJECT", "assetId": "d7a70000-0000-4000-8000-000000000002"}, {"id": "voice", "role": "AUDIO", "assetId": "d7a70000-0000-4000-8000-000000000003"}], "camera": {"steps": [{"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, {"target": {"x": 0.52, "y": 0.62, "zoom": 1.35}}, {"target": {"x": 0.5, "y": 0.55, "zoom": 1.1}}, {"target": {"x": 0.45, "y": 0.42, "zoom": 1.25, "focusObjectId": "boat-decoy"}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, {"target": {"x": 0.52, "y": 0.6, "zoom": 1.55}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.8}}, {"target": {"x": 0.5, "y": 0.5, "zoom": 1.0}}], "initial": {"x": 0.5, "y": 0.5, "zoom": 1.0}}, "canvas": {"aspectRatio": 1.6}, "tracks": [{"objectId": "map-plate", "property": "opacity", "keyframes": [{"tMs": 0, "value": 0.85, "easing": "linear"}, {"tMs": 2200, "value": 0.0, "easing": "linear"}, {"tMs": 8800, "value": 0.0, "easing": "linear"}]}, {"objectId": "boat-decoy", "property": "position", "keyframes": [{"tMs": 0, "value": {"x": 0.14, "y": 0.46}, "easing": "linear"}, {"tMs": 3300, "value": {"x": 0.30, "y": 0.42}, "easing": "linear"}, {"tMs": 4400, "value": {"x": 0.52, "y": 0.40}, "easing": "linear"}, {"tMs": 6600, "value": {"x": 0.52, "y": 0.40}, "easing": "linear"}]}, {"objectId": "boat-decoy", "property": "rotation", "keyframes": [{"tMs": 0, "value": 0, "easing": "easeInOut"}, {"tMs": 4400, "value": 0, "easing": "easeInOut"}, {"tMs": 6600, "value": -22, "easing": "easeInOut"}]}, {"objectId": "boat-fleet", "property": "position", "keyframes": [{"tMs": 0, "value": {"x": 0.88, "y": 0.30}, "easing": "linear"}, {"tMs": 3300, "value": {"x": 0.72, "y": 0.34}, "easing": "linear"}, {"tMs": 4400, "value": {"x": 0.58, "y": 0.38}, "easing": "linear"}, {"tMs": 6600, "value": {"x": 0.58, "y": 0.38}, "easing": "linear"}]}], "effects": [{"type": "MIST", "params": {"intensity": 0.3}}, {"type": "FADE_IN", "stepId": "estuary", "durationMs": 900}, {"type": "WATER_RIPPLE", "params": {"x": 0.52, "y": 0.60, "intensity": 0.75}, "stepId": "tide-fall", "durationMs": 2000}, {"type": "GLOW", "params": {"x": 0.52, "y": 0.42, "objectId": "boat-decoy", "intensity": 0.55}, "stepId": "counterattack", "durationMs": 2000}, {"type": "FADE_OUT", "stepId": "evidence", "durationMs": 900}], "objects": [{"id": "map-plate", "type": "LOCATION", "layer": -1, "scale": 1.0, "shape": "rect", "opacity": 0.85, "visible": true, "assetRef": "map-base", "position": {"x": 0.5, "y": 0.5}, "rotation": 0}, {"id": "boat-decoy", "type": "BOAT", "layer": 2, "scale": 0.13, "opacity": 1, "visible": true, "position": {"x": 0.14, "y": 0.46}, "rotation": 0}, {"id": "boat-fleet", "type": "BOAT", "layer": 2, "scale": 0.11, "opacity": 1, "visible": true, "position": {"x": 0.88, "y": 0.30}, "rotation": 0}], "disclaimer": "Cảnh minh họa 2.5D dựa trên tư liệu — không theo tỉ lệ, không phải phục dựng chính xác. Một số chi tiết trang phục/thuyền là suy luận minh họa.", "prediction": {"options": [{"text": "Cọc vẫn chìm sâu, thuyền địch rút lui an toàn."}, {"text": "Cọc lộ ra, thuyền địch mắc kẹt và bị phản công."}], "question": "Khi triều rút sau khi thuyền địch đã vào bãi cọc, kết quả nào hợp lý nhất?", "retryHint": "Kéo mực nước xuống thấp ở bước trước và quan sát phần cọc lộ ra.", "explanation": "Mực nước hạ làm đỉnh cọc nhô lên — thuyền đã tiến vào lúc nước lớn sẽ vướng phải chướng ngại vật và mất khả năng cơ động.", "revealTargetState": {"obstructed": true, "waterLevel": 0.22, "boatProgress": 0.85, "highlightStakes": true}, "explainedOptionIndex": 1}, "environment": {"glow": 0.15, "mist": 0.3}, "initialState": {}, "interactions": ["WATER_LEVEL_CONTROL", "PREDICTION"], "rendererCode": "RIVER_TIDE", "schemaVersion": 2, "rendererVersion": 1, "sourceReferences": [{"title": "Đại Việt Sử Ký Toàn Thư — Tiền Ngô Vương Kỷ."}, {"title": "Việt Sử Tiêu Án — ghi chép chiến thắng Bạch Đằng 938."}, {"title": "Bảo tàng Lịch sử Quốc gia — \\"Ngô Quyền và chiến thắng Bạch Đằng năm 938\\"."}], "learningObjective": "Diễn giải chuỗi quyết định — chuẩn bị bãi cọc, bám nhịp triều, dụ địch, khống chế, phản công — qua cảnh điện ảnh 2.5D có chứng cứ."}	PUBLISHED	d7a90000-0000-4000-8000-000000000001	00000000-0000-4000-8000-000000000001	00000000-0000-4000-8000-000000000001	2026-10-24 13:08:01.769276+00	2026-10-24 13:07:39.798445+00	1
\.


--
-- Data for Name: animation_templates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.animation_templates (id, code, name, description, renderer_code, renderer_version, schema_version, capabilities_json, default_config_json, thumbnail_asset_id, enabled, created_at, updated_at) FROM stdin;
d7a10000-0000-4000-8000-000000000001	RIVER_TIDE	Sông & thủy triều	Cảnh sông với mực nước lên xuống, chướng ngại ngầm và thuyền di chuyển.	RIVER_TIDE	1	1	{"stateKeys": ["waterLevel", "boatProgress", "decoyProgress", "counterattackProgress", "obstructed", "highlightStakes", "showSequenceSummary"], "interactions": ["WATER_LEVEL_CONTROL", "PREDICTION"]}	{}	\N	t	2026-10-24 13:08:01.670146+00	2026-10-24 13:08:01.670146+00
d7a10000-0000-4000-8000-000000000002	JOURNEY_MAP	Hành trình bản đồ	Bản đồ schematic với địa điểm, tuyến di chuyển và marker tương tác.	JOURNEY_MAP	1	1	{"stateKeys": ["markerVisibility", "routeProgress", "markerHighlight", "focusedLocationId"], "interactions": ["TAP_TO_EXPLORE", "PREDICTION"]}	{}	\N	t	2026-10-24 13:08:01.670146+00	2026-10-24 13:08:01.670146+00
d7a11000-0000-4000-8000-000000000001	html-webview	Hoạt họa HTML	Self-contained HTML file rendered inside an app WebView	HTML_WEBVIEW	1	2	{"html": true}	{"rendererCode": "HTML_WEBVIEW", "schemaVersion": 2, "rendererVersion": 1}	\N	t	2026-10-24 13:08:01.859579+00	2026-10-24 13:08:01.859579+00
\.


--
-- Data for Name: assets; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.assets (id, storage_key, original_filename, mime_type, size_bytes, checksum_sha256, state, alt_text, created_at, created_by, retired_at) FROM stdin;
d7a60000-0000-4000-8000-000000000001	assets/d7a60000-0000-4000-8000-000000000001.wav	silence.wav	audio/wav	46	\N	ACTIVE	Silent ambience fixture for cinematic demo scenes	2026-10-24 13:08:01.730606+00	00000000-0000-4000-8000-000000000001	\N
d7a70000-0000-4000-8000-000000000001	assets/d7a70000-0000-4000-8000-000000000001.jpg	dv_EVT_ngoquyen_bachdang_hero_v01.jpg	image/jpeg	1164505	\N	ACTIVE	Ngô Quyền chỉ huy thủy quân trên sông Bạch Đằng, bãi cọc nhô phía trước	2026-10-24 13:08:01.769276+00	00000000-0000-4000-8000-000000000001	\N
d7a70000-0000-4000-8000-000000000002	assets/d7a70000-0000-4000-8000-000000000002.jpg	dv_MAP_ngoquyen_bachdang-base_v01.jpg	image/jpeg	1079580	\N	ACTIVE	Cửa sông Bạch Đằng minh họa: sông uốn qua đồng bằng, núi đá vôi, làng chài ven bờ	2026-10-24 13:08:01.769276+00	00000000-0000-4000-8000-000000000001	\N
d7a70000-0000-4000-8000-000000000003	assets/d7a70000-0000-4000-8000-000000000003.wav	narration_bach_dang.wav	audio/wav	749744	\N	ACTIVE	Thuyết minh 8.5 giây tóm tắt trận Bạch Đằng 938	2026-10-24 13:08:01.769276+00	00000000-0000-4000-8000-000000000001	\N
385f7d3f-3bfe-4937-a4cd-cd8a07a58388	assets/385f7d3f-3bfe-4937-a4cd-cd8a07a58388.jpg	photo_2026-04-13_23-33-02.jpg	image/jpeg	51678	30c43ad86d288adc8b26578ec035fe57a88131a9e37cc32e0ff8e4cd0c17c913	ACTIVE	\N	2026-10-24 14:20:53.852305+00	061585cf-42e9-4312-ab4a-3e02c9ac8e70	\N
\.


--
-- Data for Name: auth_refresh_tokens; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.auth_refresh_tokens (id, user_id, token_hash, token_family_id, previous_token_id, expires_at, revoked_at, created_at, last_used_at) FROM stdin;
2b125fc4-3f7d-4d98-b3c7-206a60da5c57	061585cf-42e9-4312-ab4a-3e02c9ac8e70	2b0e98d3e9e09a1e3c86f8494c77c5e0dc90700010900b6403672925a9de72cc	06a445e5-5106-4d4a-9f4c-17625ae1841a	\N	2026-11-07 13:23:05.204554+00	\N	2026-10-24 13:23:05.504394+00	\N
4daf637e-8ea7-49a8-a063-65787a94d5e5	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	8ffbd5f9a3dfc73d124c99bf55e0f364ed740e8a4ef265e371d7e8563e5275c6	c736dc4d-b542-4143-875d-f61becbe7d07	\N	2026-11-07 13:43:15.043254+00	\N	2026-10-24 13:43:15.215562+00	\N
761d2a45-b1e0-4659-85ba-dfb56f47f184	061585cf-42e9-4312-ab4a-3e02c9ac8e70	1decc5dda6147f60d4cf57c62485c0fa56b7176d427cc36e52e7b0928765d4e2	a8cda6cc-d4f0-4d4a-bd0f-0b772844f7ec	\N	2026-11-07 14:03:50.621308+00	2026-10-24 14:03:54.461859+00	2026-10-24 14:03:50.662512+00	2026-10-24 14:03:54.461859+00
92e2d58a-f573-45fc-ba2e-e50d535376c5	061585cf-42e9-4312-ab4a-3e02c9ac8e70	3372fe1eaae9926299d5dc34043faabdce40026be5fbae9717d00745e2168e60	a8cda6cc-d4f0-4d4a-bd0f-0b772844f7ec	c523a85d-d06b-4bbd-baf6-fc424ee4a5dd	2026-11-07 14:18:50.89644+00	\N	2026-10-24 14:18:50.914682+00	\N
c523a85d-d06b-4bbd-baf6-fc424ee4a5dd	061585cf-42e9-4312-ab4a-3e02c9ac8e70	cf83c6211f87aaa6a029eef78693ed90b9f0bcf221b88c3850501eaad3c52943	a8cda6cc-d4f0-4d4a-bd0f-0b772844f7ec	761d2a45-b1e0-4659-85ba-dfb56f47f184	2026-11-07 14:03:54.469494+00	2026-10-24 14:18:50.876351+00	2026-10-24 14:03:54.49424+00	2026-10-24 14:18:50.876351+00
ea15117b-5138-4bec-b838-0bc111f0fcc0	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	51fe1db1bdd3c526d0892b172d8da7e93135364b1498f549ac5e5550ad590272	10acb840-0833-4ef5-8035-dccdcfc7765f	\N	2026-11-07 14:40:41.397492+00	\N	2026-10-24 14:40:41.497121+00	\N
5b0e139f-02dd-46ad-995a-2a187c133602	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	3d0af7694b2de85a593c1452cb90a3cac50fbd3dff5c8667bd039f08def81cf7	0201e934-57bc-46dc-b71a-eea6b4c9f0d0	\N	2026-11-07 14:55:34.082315+00	\N	2026-10-24 14:55:34.122028+00	\N
cdc5b9a1-37e0-4b2a-b87d-f3c0b2840c49	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	4447e39384b35abc070b23195177cf08f0266c91d4b146b82540ee63a0cba19c	438984b6-91c6-4ade-8f85-ddd22b76e50b	\N	2026-11-07 14:55:59.422059+00	\N	2026-10-24 14:55:59.427017+00	\N
0958d355-e48a-40a7-9a76-f6c26fedd3a4	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	590248baf83168f4ae1b3b0fd015a8935ff29b178c87a37ac4ae5d9f3262a6f1	4403be96-164e-431e-8ef4-d84ff8d8df42	\N	2026-11-07 14:56:53.75091+00	\N	2026-10-24 14:56:53.756017+00	\N
48959c90-e48c-4090-830d-142480d75161	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	7a109877af99b7df257e66df52cd9625aec000f395a2449ae7c7a5a8d9b367d3	6edaebbf-8ae9-4c8f-85b1-31fbfb21164b	\N	2026-11-07 14:57:03.892738+00	\N	2026-10-24 14:57:03.896142+00	\N
4d4944a3-7c89-4c52-b67f-1f3a50ba3e45	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	6f2c5647b90634273eec92f13bb1b03b52374d783cca35eb11c51f731b25dcad	28d1bb61-8a9b-4ce9-bdaa-c199f1938d2a	\N	2026-11-07 14:59:40.117738+00	\N	2026-10-24 14:59:40.123377+00	\N
ba43568c-d65d-45bf-b046-924df059c8bf	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	3569c4d7cd4d1da100006f5d4a6ce5ba67f6b2f36d2e0ba413bcbfda07d0899a	606705c8-35b6-4a4f-b6cd-bba625387dec	\N	2026-11-07 16:05:21.543459+00	\N	2026-10-24 16:05:21.646526+00	\N
de35b0c8-17be-42ec-b3ac-2a56747ffe88	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	b089ee395c3724634d91a989862bd67c795b91c712055e3ce299cb77ae0cd808	f7f977c1-3ca7-45f9-b711-967b1eb8ac9e	\N	2026-11-07 16:24:03.878981+00	\N	2026-10-24 16:24:03.902211+00	\N
306ee28f-22d3-4ea0-bd58-3ec028aac843	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	5bac1ca0641022f509735f188e4365b364bd9a8590a456adb243938ad594c61d	cf2eb5ae-714b-46ba-99ec-2c3d0d609ee4	\N	2026-11-07 16:47:12.268697+00	\N	2026-10-24 16:47:12.292358+00	\N
eeca72b3-861b-47d4-ab36-74fbce97a660	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	7c50e6127043c169d671c0ddb602f52373e04a7f3e8d9e4395c761639521c6ec	97a6f833-4a6d-4ef1-a8a6-916ce4aa8f83	\N	2026-11-07 17:05:47.050024+00	\N	2026-10-24 17:05:47.061924+00	\N
fdde5c05-9162-4972-b333-4a1e0ae56410	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	3c5c7b17313e217a10597fc2e83259898c5d69241d0b1d2fc2964389ec5af3bc	6ce183a6-17f1-44b3-8334-00429671388d	\N	2026-11-07 17:05:55.411027+00	\N	2026-10-24 17:05:55.413889+00	\N
2f5b1bc4-fcac-4e60-8e9d-4c1d2e2605c6	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	46df4bcc3d6e8ab11c99cda296df7d008b3ed3b9d9914bf259796634fecb9a85	1e2c9a0e-09c0-4a9f-9dbd-1d7bab319eb6	\N	2026-11-07 17:13:45.645341+00	\N	2026-10-24 17:13:45.658949+00	\N
c42d9306-70db-46fd-a07b-592839d0417c	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	6aff9ae43b74583ce1235447fe6d1115aae71178b7c44bc261e17a0065fb12f1	076dcc92-dd95-47e2-a7f1-ba7419cdf38b	\N	2026-11-07 17:39:56.90472+00	\N	2026-10-24 17:39:56.946334+00	\N
da6d500a-58c0-4ca5-a5ed-f2c869613fb0	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	fa6a66158edc8f7c3d5996ce763bd14d827ed9dac36788e4bb31f0c87aff0a8d	e58c4cb5-1751-4cb0-9492-c5ad9129a3a1	\N	2026-11-07 18:05:10.75071+00	\N	2026-10-24 18:05:10.774148+00	\N
16676fed-c3bc-469f-9856-b9a081d1f267	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	47f629f36890d700f81ddf79a9458a0919192513c64956ce490e057cc8d9292b	2dc2155e-7217-46ad-89d5-98069cf411b2	\N	2026-11-07 19:04:13.582298+00	\N	2026-10-24 19:04:13.617329+00	\N
0d8dc7b2-4ec4-44ec-9be7-9a115224bab5	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	814678966ec6b3f34c4062c7b45666532e0f937640fa658f13ca836754a4ce85	7e434eab-9119-4c8d-bff6-00eef5f5e0cb	\N	2026-11-07 19:29:02.778312+00	\N	2026-10-24 19:29:02.807403+00	\N
f4e6a223-0072-4786-b652-74cf433a4c71	fc8ba421-c0fe-4feb-a401-01d253822269	dca5f3d09452f0103aa9d3f347d58da07149fc8fe95a43e98a9ad8c6b1364b32	aa50211c-a40f-42f0-b6ea-3960fe2a5f5d	\N	2026-11-07 19:38:13.583086+00	\N	2026-10-24 19:38:13.592297+00	\N
ba9f173d-44e6-442e-b63d-cc5a6315049c	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	fa57a7d7d3dac7b88f6ea7a9d1bb1fd57398a43d077d7c669c47d48fea3ed280	8942f980-b619-4c98-b13a-ea5c46b0f8a9	\N	2026-11-07 19:51:30.115652+00	\N	2026-10-24 19:51:30.134674+00	\N
5ca9109f-5ad3-4890-bdc6-f0d93103f983	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	9e8eab33837add0a3a55bbace87468e64c34cc2b366a56e9f46611ce526daae6	b39107a2-07c1-4e48-bae5-44413cb4a8a9	\N	2026-11-07 20:17:35.264217+00	\N	2026-10-24 20:17:35.299168+00	\N
a55ae430-5c16-48c5-be62-f3d29ae9a26f	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	bb659a9f502a8dea4cc2a803d1358ac1159ab9596cd55c346a2e85ff99af80a7	27f552f2-8dd4-4977-a693-a1b653caa06a	\N	2026-11-07 20:42:27.126646+00	\N	2026-10-24 20:42:27.154991+00	\N
a1b5eae5-d556-4b42-b705-02622a700ada	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	e2764ba0eb65ac06bf4b96bcd6ba2ee33b13d5ae39ac7649bec2a849dfb4501b	285dc191-a4e6-4bbb-a0d1-6b2f8154d1e5	\N	2026-11-07 21:05:39.315351+00	\N	2026-10-24 21:05:39.487755+00	\N
4d9ce909-20a7-4745-94cd-a75b99f92d4a	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	872507e0f709d53d00874b6b66dd59a550edb6bb371e74fe4a9146518aa9a052	0835f027-8f26-414d-ac49-7bc2ade2a2e2	\N	2026-11-07 21:31:03.286061+00	\N	2026-10-24 21:31:03.375796+00	\N
6ade5f63-1deb-44e2-aad9-6205c6c9df3c	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	5212283f80dba23c8accbaa4957fdb6b45ecbf2f45a17cedf98d28cce45402c1	619ae5ad-b8f5-4fe2-88bb-8dddb4ac98b6	\N	2026-11-07 21:58:27.555251+00	\N	2026-10-24 21:58:27.570571+00	\N
be2188ac-cea2-4918-9c08-27e9b3d3ae57	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	c7d8f3df1474b5f78a88a56bb877695ea91e169856c257da72816978edb5b0f3	bccd9b0d-3c0d-4949-bcaa-f5d51870ff1a	\N	2026-11-08 00:44:38.809557+00	\N	2026-10-25 00:44:38.838809+00	\N
\.


--
-- Data for Name: evidences; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.evidences (id, event_id, title, evidence_type, description, source_title, source_author, source_url, source_citation, source_published_at, reliability, relevance, asset_id, status, created_by, created_at, updated_at, row_version) FROM stdin;
20000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	Đại Việt Sử Ký Toàn Thư ghi chép về Trưng Nữ Vương	HISTORICAL_TEXT	Trưng Trắc, Trưng Nhị là phụ nữ, hô một tiếng mà các quận Giao Chỉ, Cửu Chân, Nhật Nam, Hợp Phố cùng 65 thành ở Lĩnh Ngoại đều hưởng ứng, dựng nước xưng vương dễ như trở bàn tay.	Đại Việt Sử Ký Toàn Thư - Kỷ Trưng Nữ Vương	Ng?? S?? Li??n	\N	Ngô Sĩ Liên, Đại Việt Sử Ký Toàn Thư, Bản kỷ Quyển III	\N	HIGH	S??? li???u quan tr???ng ghi nh???n quy m?? r???ng l???n v?? s??? ???ng h??? tuy???t ?????i c???a nh??n d??n v???i cu???c kh???i ngh??a.	\N	APPROVED	061585cf-42e9-4312-ab4a-3e02c9ac8e70	2026-10-24 14:32:05.455414+00	2026-10-25 00:56:51.071443+00	0
20000000-0000-0000-0000-000000000003	00000000-0000-0000-0000-000000000003	Bài thơ thần Nam Quốc Sơn Hà vang trên sông Như Nguyệt	HISTORICAL_TEXT	Nam quốc sơn hà Nam đế cư / Tiệt nhiên định phận tại thiên thư / Như hà nghịch lỗ lai xâm phạm / Nhữ đẳng hành khan thủ bại hư.	Việt Điện U Linh Tập & Đại Việt Sử Ký Toàn Thư	Khuy???t danh (t????ng truy???n L?? Th?????ng Ki???t)	\N	Lý Tế Xuyên, Việt Điện U Linh Tập & Khâm định Việt sử Thông giám Cương mục	\N	HIGH	Tuy??n ng??n ?????c l???p ?????u ti??n, ????n chi???n tranh t??m l?? xu???t s???c b??? g??y ?? ch?? qu??n T???ng.	\N	APPROVED	061585cf-42e9-4312-ab4a-3e02c9ac8e70	2026-10-24 14:32:05.455414+00	2026-10-25 00:56:51.071443+00	0
20000000-0000-0000-0000-000000000004	00000000-0000-0000-0000-000000000004	Mệnh lệnh chuyển phương châm tác chiến chiến dịch Điện Biên Phủ	MILITARY_DOCUMENT	Quyết định hoãn giờ nổ súng ngày 26/01/1954, lệnh kéo pháo ra để chuẩn bị thế trận theo phương châm Đánh chắc, tiến chắc.	Hồi ký Điểm hẹn lịch sử	?????i t?????ng V?? Nguy??n Gi??p	\N	Đại tướng Võ Nguyên Giáp, Điểm hẹn lịch sử, NXB Quân đội Nhân dân	\N	HIGH	Ch???ng c??? l???ch s??? then ch???t ch???ng minh s??? thay ?????i chi???n thu???t mang t??nh quy???t ?????nh th???ng l???i.	\N	APPROVED	061585cf-42e9-4312-ab4a-3e02c9ac8e70	2026-10-24 14:32:05.455414+00	2026-10-25 00:56:51.071443+00	0
\.


--
-- Data for Name: flyway_schema_history; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.flyway_schema_history (installed_rank, version, description, type, script, checksum, installed_by, installed_on, execution_time, success) FROM stdin;
1	1	create historical events	SQL	V1__create_historical_events.sql	453286122	dauviet	2026-10-24 20:08:00.610001	70	t
2	2	users and auth	SQL	V2__users_and_auth.sql	-2128051261	dauviet	2026-10-24 20:08:00.707615	75	t
3	3	authoring publishing evidence assets	SQL	V3__authoring_publishing_evidence_assets.sql	-1096875950	dauviet	2026-10-24 20:08:00.801384	163	t
4	4	learner runtime progress rewards	SQL	V4__learner_runtime_progress_rewards.sql	559701232	dauviet	2026-10-24 20:08:00.976254	168	t
5	5	add historical events row version	SQL	V5__add_historical_events_row_version.sql	-1936859179	dauviet	2026-10-24 20:08:01.158207	10	t
6	6	evidences row version	SQL	V6__evidences_row_version.sql	-772766884	dauviet	2026-10-24 20:08:01.183655	7	t
7	7	seed default lesson template	SQL	V7__seed_default_lesson_template.sql	-598911281	dauviet	2026-10-24 20:08:01.204307	8	t
8	8	map locations	SQL	V8__map_locations.sql	481780108	dauviet	2026-10-24 20:08:01.227601	46	t
9	9	map locations published at	SQL	V9__map_locations_published_at.sql	560124266	dauviet	2026-10-24 20:08:01.289393	9	t
10	10	user evidence collection	SQL	V10__user_evidence_collection.sql	-871198037	dauviet	2026-10-24 20:08:01.313403	27	t
11	11	user evidence dedup index	SQL	V11__user_evidence_dedup_index.sql	-1176731160	dauviet	2026-10-24 20:08:01.356723	8	t
12	12	rewards inventory	SQL	V12__rewards_inventory.sql	873901986	dauviet	2026-10-24 20:08:01.378548	90	t
13	13	catalog description alignment	SQL	V13__catalog_description_alignment.sql	543290474	dauviet	2026-10-24 20:08:01.484271	17	t
14	14	animation engine	SQL	V14__animation_engine.sql	-473886822	dauviet	2026-10-24 20:08:01.521073	127	t
15	15	animation seed	SQL	V15__animation_seed.sql	786868616	dauviet	2026-10-24 20:08:01.658603	37	t
16	16	animation cinematic demos	SQL	V16__animation_cinematic_demos.sql	-1141635056	dauviet	2026-10-24 20:08:01.716526	20	t
17	17	bachdang production scene	SQL	V17__bachdang_production_scene.sql	559410197	dauviet	2026-10-24 20:08:01.758215	16	t
18	18	animation scene versions checksum varchar	SQL	V18__animation_scene_versions_checksum_varchar.sql	1342132263	dauviet	2026-10-24 20:08:01.795085	38	t
19	19	html webview animation	SQL	V19__html_webview_animation.sql	83345243	dauviet	2026-10-24 20:08:01.852988	37	t
\.


--
-- Data for Name: historical_events; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.historical_events (id, slug, title, era, period, start_year, summary, description, location, cover_asset_key, tags, status, created_at, updated_at, row_version) FROM stdin;
00000000-0000-0000-0000-000000000005	hung-vuong-van-lang	Thời Đại Hùng Vương - Dựng Nước Văn Lang	Thời Hùng Vương - Văn Lang (~2879 - 258 TCN)	Khoảng thế kỷ VII TCN	-700	Thời kỳ dựng nước đầu tiên của dân tộc Việt Nam với 18 đời vua Hùng, đặt nền móng cho nền văn minh sông Hồng.	Mười tám đời vua Hùng nối tiếp nhau trị vì non sông, khai hoang lập ấp, định đô tại Phong Châu (Phú Thọ ngày nay), sáng tạo nền văn hóa Đông Sơn rực rỡ với trống đồng thiêng liêng.	Khu di tích lịch sử Đền Hùng, Nghĩa Lĩnh, Phong Châu, Phú Thọ	events/hung-vuong/hero.jpg	{hung-vuong,van-lang,phong-chau,trong-dong,den-hung}	PUBLISHED	2026-10-24 19:37:41.381948+00	2026-10-25 00:56:51.065201+00	0
00000000-0000-0000-0000-000000000002	khoi-nghia-hai-ba-trung-40	Khởi Nghĩa Hai Bà Trưng (Năm 40)	Thời kỳ Bắc thuộc lần 1	Mùa Xuân năm 40 SCN	40	Cuộc khởi nghĩa vũ trang đầu tiên của người Việt chống ách đô hộ của nhà Đông Hán, do Trưng Trắc và Trưng Nhị lãnh đạo, giải phóng Mê Linh và 65 thành trì.	Bất bình trước chính sách đồng hóa tàn bạo và sưu thuế hà khắc của viên Thái thú Tô Định, cùng thù riêng khi Thi Sách bị sát hại, Trưng Trắc cùng em gái là Trưng Nhị dựng cờ khởi nghĩa tại cửa sông Hát. Khởi nghĩa được nhân dân khắp nơi hưởng ứng nhiệt liệt, nhanh chóng quét sạch chính quyền đô hộ, lập nên nền độc lập tự chủ kéo dài gần 3 năm.	Hát Môn (Phúc Thọ, Hà Nội) & Mê Linh	events/hai-ba-trung-40/hero.jpg	{hai-ba-trung,khoi-nghia,me-linh,bac-thuoc}	PUBLISHED	2026-10-24 14:32:05.455414+00	2026-10-25 00:56:51.065201+00	0
00000000-0000-0000-0000-000000000001	bach-dang-938	Đại Chiến Bạch Đằng 938	Thời Ngô - Đinh - Tiền Lê (938 - 1009)	Mùa Đông 938 SCN	938	Trận thủy chiến kinh điển cắm cọc gỗ lim bịt sắt lợi dụng con nước triều, tiêu diệt hoàn toàn thủy quân Nam Hán của Lưu Hoằng Tháo, chính thức chấm dứt hơn 1.000 năm Bắc thuộc.	Năm 938, Ngô Quyền lợi dụng địa thế cửa sông Bạch Đằng và quy luật thủy triều để bố trí trận địa cọc ngầm bịt sắt, nhử hạm đội Nam Hán vào trận địa rồi tiêu diệt khi nước rút. Chiến thắng mở ra kỷ nguyên độc lập lâu dài cho Việt Nam.	Cửa sông Bạch Đằng, Quảng Ninh - Hải Phòng	events/bach-dang-938/hero.jpg	{ngo-quyen,thuy-chien,bac-thuoc,bach-dang}	PUBLISHED	2026-10-24 13:07:39.748797+00	2026-10-25 00:56:51.065201+00	0
00000000-0000-0000-0000-000000000003	chien-thang-nhu-nguyet-1077	Chiến Thắng Như Nguyệt 1077	Thời nhà Lý (1009 - 1225)	Mùa Xuân năm 1077	1077	Trận quyết chiến chiến lược trên sông Như Nguyệt do Thái úy Lý Thường Kiệt chỉ huy, chặn đứng hoàn toàn 10 vạn đại quân xâm lược Tống và bảo vệ vững chắc Thăng Long.	Năm 1077, quân Tống do Quách Quỳ chỉ huy tràn vào Đại Việt. Lý Thường Kiệt đã chủ động lập phòng tuyến kiên cố men bờ nam sông Như Nguyệt (sông Cầu), dùng cọc tre, lũy đất tạo thế phòng ngự vững chắc. Kết hợp chiến tranh tâm lý với bài thơ thần Nam quốc sơn hà vang dội trong đêm, quân ta mở đòn phản công chớp nhoáng khiến địch tan rã, buộc phải chấp nhận giảng hòa rút quân.	Phòng tuyến sông Như Nguyệt (sông Cầu, Bắc Ninh)	events/nhu-nguyet-1077/hero.jpg	{ly-thuong-kiet,nhu-nguyet,nha-ly,nam-quoc-son-ha}	PUBLISHED	2026-10-24 14:32:05.455414+00	2026-10-25 00:56:51.065201+00	0
00000000-0000-0000-0000-000000000004	chien-dich-dien-bien-phu-1954	Chiến Dịch Điện Biên Phủ 1954	Thời kỳ Kháng chiến chống Pháp (1945 - 1954)	13/03/1954 - 07/05/1954	1954	Chiến thắng lừng lẫy năm châu, chấn động địa cầu, đập tan tập đoàn cứ điểm quân sự mạnh nhất Đông Dương của Pháp, quyết định thắng lợi trên bàn đàm phán Hiệp định Genève.	Tập đoàn cứ điểm Điện Biên Phủ gồm 49 cứ điểm được quân Pháp coi là pháo đài bất khả xâm phạm. Dưới sự chỉ huy sáng suốt của Đại tướng Võ Nguyên Giáp, quân và dân ta đã thay đổi phương châm từ đánh nhanh thắng nhanh sang đánh chắc tiến chắc, đào hàng trăm km chiến hào siết chặt vòng vây, tiêu diệt hoàn toàn quân viễn chinh Pháp sau 56 ngày đêm chiến đấu kiên cường.	Thung lũng Điện Biên Phủ, tỉnh Lai Châu (nay thuộc Điện Biên)	events/dien-bien-phu-1954/hero.jpg	{dien-bien-phu,vo-nguyen-giap,khang-chien-phap,muong-thanh,1954}	PUBLISHED	2026-10-24 14:32:05.455414+00	2026-10-25 00:56:51.065201+00	0
\.


--
-- Data for Name: idempotency_records; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.idempotency_records (id, user_id, idempotency_key, operation, request_hash, response_json, http_status, created_at, expires_at) FROM stdin;
44e04354-9ee3-41e4-99b8-9f166a24fc1e	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	8af51933-cc88-4b93-8b00-6967c1f4f75f	SUBMIT_ACTIVITY	87bd5fe3b45ea2445584f97170d3af909c18c4f4eed7103e62856b6155dc8068	{"next": {"stageId": "verify", "activityId": "mc-hbt-cause", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 14:59:48.155195+00	2026-10-25 14:59:48.155195+00
b4fa4f18-eff9-439a-a78b-9a4c3174cd07	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	d4ebd3bc-11f1-4b1d-b826-ff4902db66cc	SUBMIT_ACTIVITY	8ec7fe27489a14b702957193fca2c904d25aa6665e57594d030a80b4e6bfccbf	{"next": {"stageId": "conclusion", "activityId": "read-hbt-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 14:59:51.672882+00	2026-10-25 14:59:51.672882+00
a37faa3f-0ebb-44cf-8b77-01e8e422a634	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	13d07d5f-923c-4284-952e-2f7a1cd6e922	SUBMIT_ACTIVITY	d7ba16ec7763478e93be9232e06cf0f5504d5e66864d19fe3240a3dbdc07a9ce	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 14:59:54.28249+00	2026-10-25 14:59:54.28249+00
3a88877b-718c-4009-907c-066579709c99	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	20ff144f-fa37-411f-9d89-1d1290b8fc2e	COMPLETE_ATTEMPT	001bb5e16f436a851689a4704e8a146ced0bffb5211deb02563fb81ddac811a3	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "b29f88c1-0f90-41ef-a833-ff1cf8a98dea", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T14:59:55.437633400Z", "alreadyCompleted": false}	200	2026-10-24 14:59:55.430331+00	2026-10-25 14:59:55.430331+00
5c5f207f-90bf-49ed-bad2-bb6158944190	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	975ad1fc-01c2-4f2a-a675-6047e96e1d57	SUBMIT_ACTIVITY	0bc7309392f1738e8c1c522a01d24e8279499dd5802a2b4c9c58c995afd2a7f3	{"next": {"stageId": "verify", "activityId": "mc-hbt-cause", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:06:22.770073+00	2026-10-25 16:06:22.770073+00
6cf4b5a1-a2af-494c-9c4e-8b566ca36326	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	28ea71ec-3214-40e4-a1f6-f477aef31289	SUBMIT_ACTIVITY	dc79de18c549365c13efde253ac4f0d2f52a10adbea0a567c800b0aeb127fc70	{"next": {"stageId": "conclusion", "activityId": "read-hbt-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:06:43.817058+00	2026-10-25 16:06:43.817058+00
b49d6f77-c6eb-4fba-889c-5fea2972baf3	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	778e4f4b-b604-4333-97a0-a5602ce45a3f	SUBMIT_ACTIVITY	de9907b0e76127aa915d0fc50a64b44a07564c413386032ecc3aaea228b5ff71	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:08:23.882162+00	2026-10-25 16:08:23.882162+00
d399707d-cc3a-47db-a7fa-8f639549e043	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	dbecdfdf-72f4-4260-a65b-d6edc3a2792f	COMPLETE_ATTEMPT	d9b20441f51082aa1b00372e1966aadda6a699a2c5b55d74e36c638fd5752db7	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "9bc7e6d0-5d8f-4a6b-8197-85a8beddd6e2", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T16:08:25.041163100Z", "alreadyCompleted": false}	200	2026-10-24 16:08:25.021866+00	2026-10-25 16:08:25.021866+00
7ff2cdc0-dee3-473d-baae-1304a29f37bd	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	e08f3d09-3a0d-40e4-9960-f7209c00f4d2	SUBMIT_ACTIVITY	f880f2505a4a309ce3202b85ebd51c0492c703863e6e1e00e99c761996b772c1	{"next": {"stageId": "verify", "activityId": "mc-hbt-cause", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:11:22.488186+00	2026-10-25 16:11:22.488186+00
1e940c01-f4e9-4fff-84e2-e3c040dc7e34	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	9b980cad-e022-4daa-842d-d3bb63dca56b	SUBMIT_ACTIVITY	ee139c183d5f13a21ea2dca318adf141cfd32f8a4398886e5160fbd00b3b7881	{"next": {"stageId": "conclusion", "activityId": "read-hbt-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:12:09.345509+00	2026-10-25 16:12:09.345509+00
5fa5cff4-9fc0-4f02-9b48-010ed0ed7a57	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	ef781efc-5a63-43e8-b904-35b77d33ec6d	SUBMIT_ACTIVITY	1b910881335e8eb410ee6121ac3572037ada94c0e4f002bd1149f830175ce083	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:18:13.965349+00	2026-10-25 16:18:13.965349+00
add21c5e-7f2c-46bc-a110-53bd1576ba0e	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	0e6926ac-cb78-4352-ad87-c4c58556dd80	SUBMIT_ACTIVITY	15f340754d218a3363bc7332ef8da178ceb2a543136bd28b4aa4e96b58e0fca0	{"next": {"stageId": "verify", "activityId": "mc-hbt-cause", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:18:23.016093+00	2026-10-25 16:18:23.016093+00
3d548994-95ae-4375-b463-a1d0fec832f1	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	440ac5e1-823d-4297-8514-b1f7d0589980	SUBMIT_ACTIVITY	c1f09e33b4d1c19c80085d6278a234a71d3d4acbe39ae9c7c75f66fe4b8471e5	{"next": {"stageId": "conclusion", "activityId": "read-hbt-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:18:26.094549+00	2026-10-25 16:18:26.094549+00
4e4d6a3e-336d-4da2-a962-5ff469cb8c13	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	008487a0-e302-4f07-842a-e3b71c2bda35	SUBMIT_ACTIVITY	f883637b8e77a3614f3849e78f52d7ad7a8a01c4b934a0079b837e75283897f9	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:18:29.975821+00	2026-10-25 16:18:29.975821+00
879336f9-4b1c-4a1a-814e-0877a93e5b76	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	1cd66de9-afa9-42ea-b610-fce864b78b3d	COMPLETE_ATTEMPT	bb387335647ee4655496e28a2663eb1bec2767b3fb9a885ce0e78bf6c19ea512	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "a1cdbc7f-e176-4824-be1e-1a0a3de60ed6", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T16:18:31.401007Z", "alreadyCompleted": false}	200	2026-10-24 16:18:31.39428+00	2026-10-25 16:18:31.39428+00
3cf21665-6500-444a-a026-9410a3c37c5b	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	90c40bb3-4117-41c5-ae9e-53df561268a7	SUBMIT_ACTIVITY	938141838657b5feeed8ce3f4c2a6ba7bfe736bd383821004baa2a594c87a66e	{"next": {"stageId": "verify", "activityId": "mc-hbt-cause", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:25:53.446327+00	2026-10-25 16:25:53.446327+00
dbe4c79e-f7cf-469c-bc70-29ac86587ff2	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	ed09a9f9-91d9-482c-a7e8-2fbc458dfc83	SUBMIT_ACTIVITY	8d54877c64dc243fb18fe0fe97fbd0a98a3c93bec6aaebe824b794e06d1d9cfd	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:26:34.339606+00	2026-10-25 16:26:34.339606+00
362884e4-f1d0-4677-80f9-0418a8a0bb03	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	44f66a8c-5799-4bb5-be72-53b71a824ae1	SUBMIT_ACTIVITY	417ee4c090d1182cc749c4d8105eb38be9bdf3ee60bc842d701a575ccd93671b	{"next": {"stageId": "verify", "activityId": "mc-hbt-cause", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:28:34.37039+00	2026-10-25 16:28:34.37039+00
254fc5fe-141b-4baf-9238-9192e0cd8032	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	bc1110fe-cf4b-44a7-8dfa-03b018200f92	SUBMIT_ACTIVITY	114a8b8042b93ca7d0910aa52c385955ef5b23914da10ffd93bb1946e1022f08	{"next": {"stageId": "conclusion", "activityId": "read-hbt-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:28:43.294441+00	2026-10-25 16:28:43.294441+00
f16c4bf4-566c-42bd-a238-9e0ab1e62e11	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	3ea74a69-453a-4811-a226-e439848c2816	COMPLETE_ATTEMPT	5da911730b23070f9e8e4e77dd2d9c5ff2ece7e1635db2289739aa8b91a7070d	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "76ee8a1a-8c08-4f8a-b79e-12de8c6efb9c", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T16:18:16.452047400Z", "alreadyCompleted": false}	200	2026-10-24 16:18:16.439161+00	2026-10-25 16:18:16.439161+00
14006d90-48a0-4fc5-b6c5-d0782b8baf7a	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	d408015a-a526-4b41-9529-fe03a988c0c8	SUBMIT_ACTIVITY	19229a949887ac7e5da819e04cc753b7035ec711752a9110eed0df3e18d4806f	{"next": {"stageId": "conclusion", "activityId": "read-hbt-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:26:28.492522+00	2026-10-25 16:26:28.492522+00
c7fbee59-6c36-4c50-b55f-861b80abe321	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	f22dce3d-d04c-4781-9c5d-ce6e2cfee53b	COMPLETE_ATTEMPT	5261239d2fecf1bd545d1b72a7b70cf90b669dbdf90f17d7617fe2ee63885463	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "652de175-1eb1-4fb7-81f4-e2ce7177e758", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T16:26:35.568668300Z", "alreadyCompleted": false}	200	2026-10-24 16:26:35.559665+00	2026-10-25 16:26:35.559665+00
cdacbd62-b4ec-4626-a8da-5655f6b42785	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	5b3dcabd-35fb-4bd5-809f-b5d0a6097a16	SUBMIT_ACTIVITY	b4851c7235205719c656c056cebe2a0aaa18ebde8637e851c9ad35df088326c5	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:28:44.900934+00	2026-10-25 16:28:44.900934+00
cdb49b2f-e559-4af6-bb85-cf59c496825f	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	9c976bda-97b5-453b-b250-51168cce97f9	COMPLETE_ATTEMPT	75eeeed69513010f48d67ab1b7884a408ac7ebe890376d271a676234e71fbdab	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "055d991d-2b51-40fd-b4d4-fb6ed68afddf", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T16:28:46.224261700Z", "alreadyCompleted": false}	200	2026-10-24 16:28:46.213377+00	2026-10-25 16:28:46.213377+00
ae7124c1-5c4b-45af-9596-a113540b6dea	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	5941da90-c1e8-4d5a-b32a-5508c0d2643a	SUBMIT_ACTIVITY	fd10ca44cc89e4ed112e1f0b552411653405a254c9011912af0182d17a9dc918	{"next": {"stageId": "verify", "activityId": "mc-hbt-cause", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:47:20.875673+00	2026-10-25 16:47:20.875673+00
8fd08f41-d85f-48cf-9307-c03a52aa29f2	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	7ef5dd79-ade8-45fd-91b6-30a4706edf47	SUBMIT_ACTIVITY	b4e04b6aa46959225609bfb432533e0f2748924845667fc56c901d6c7e3e196d	{"next": {"stageId": "conclusion", "activityId": "read-hbt-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:47:23.638218+00	2026-10-25 16:47:23.638218+00
b11a25c8-a94f-40d3-ba6b-a09aee743ea5	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	99ee274e-b201-4cf4-ac4b-a1155578ef30	SUBMIT_ACTIVITY	72e82de1f736f388aab3350f822abab733c5adb2cbbbc72e8a2b0a8ae958d31f	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:47:26.937383+00	2026-10-25 16:47:26.937383+00
e51fe1c4-8b56-447f-ba2f-0d92a3335c55	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	14a8b1cc-253c-4718-8345-7637797747ab	COMPLETE_ATTEMPT	b90cd0ffbd4f110c00af5257c31e5ab16e19c1bee436afeec0e20b4f023a4382	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "6ed3df0f-9aa5-4aba-9880-a4ef2ad40b72", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T16:47:27.631479500Z", "alreadyCompleted": false}	200	2026-10-24 16:47:27.617559+00	2026-10-25 16:47:27.617559+00
82cb1ba6-595d-4cbf-b572-650bfdec7da6	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	d9ae168a-24c1-41ea-835e-6da25f7deeab	SUBMIT_ACTIVITY	a13af8c33c94f7c21bf62afa9ce3ff11dba859fe7f9ce6c4712b9d13fce9f82c	{"next": {"stageId": "verify", "activityId": "mc-hbt-cause", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:52:10.885081+00	2026-10-25 16:52:10.885081+00
1bab45ac-e220-4198-a868-aab5a5d30bb7	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	334cd94e-1c04-4b2e-be47-73f6175727f9	SUBMIT_ACTIVITY	58ae3a4ae727845d013500a1ab3eebeb25e100997f9f68e89efd22f2b61b7956	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:52:16.676027+00	2026-10-25 16:52:16.676027+00
8b094e3f-0543-4254-8e10-31c67f8e973f	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	f5813ad1-b68c-45f8-a402-6d59f3960731	SUBMIT_ACTIVITY	6cbb76b18496b135d6f4ea6b5a10c741eff107ffcb207a551d375e73e295d03b	{"next": {"stageId": "conclusion", "activityId": "read-hbt-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 16:52:13.30808+00	2026-10-25 16:52:13.30808+00
8a7e0269-69aa-46b6-ad12-fe5e170bb85a	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	37cc80fc-178f-4822-af07-d68a59e5493b	COMPLETE_ATTEMPT	e6e1e91324d8b9c2e1351d215d451db7d62709c874dcf1e9c9e813df15726a4f	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "8f03c376-529b-4279-b25b-38b8d0339182", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T16:52:17.772478900Z", "alreadyCompleted": false}	200	2026-10-24 16:52:17.751274+00	2026-10-25 16:52:17.751274+00
4ee35d9f-675d-435e-9947-2df22b168e68	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	84ac721d-5c26-49d4-a823-85b0375c53c7	SUBMIT_ACTIVITY	418b0577d329fc80b9378c9a0b3f77c94a97fced7f9bba66133c51596199839a	{"next": {"stageId": "verify", "activityId": "mc-hbt-cause", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 17:13:52.731045+00	2026-10-25 17:13:52.731045+00
66fbf164-8732-475a-afff-5761f291ae80	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	10ff8818-0aa2-451b-b4f6-53eaacdf8dd9	SUBMIT_ACTIVITY	6fece0376967138a01c41ef3ef4b6e7d5bd2b308582c1139747126b76ece9905	{"next": {"stageId": "conclusion", "activityId": "read-hbt-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 17:14:29.988714+00	2026-10-25 17:14:29.988714+00
e049948c-5a83-45db-ae1c-eef3d5f55bd1	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	da68e81f-fb65-46ee-9a78-a8dbb02397f0	SUBMIT_ACTIVITY	ce912d5fb6dd18ea1a4a1b4c614ea8b2e6b86dd1ed862de63c290dda6e8da7c4	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 17:14:37.351232+00	2026-10-25 17:14:37.351232+00
75fa6db1-3ae9-45a1-abf5-c7da1f660453	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	277725f5-b7c4-44c9-9d42-edd6f4c0b665	COMPLETE_ATTEMPT	55d4fdbc2e9ca9cfdf6b57dde2ea28deaf6dcac9f614b6435853b38a4fa9a1aa	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "b2186fce-e2e4-4e14-a875-c738ed1e2417", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T17:14:39.955088300Z", "alreadyCompleted": false}	200	2026-10-24 17:14:39.948309+00	2026-10-25 17:14:39.948309+00
656cda04-6417-41f0-acdb-e20732d08e60	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	9cb3077d-099f-48b1-881f-f70dac2d9f45	SUBMIT_ACTIVITY	28d7d0a29fc85b4dda616f1e35d5d84f399d458680cd50be0cbffcaf5c4eaff9	{"next": {"stageId": "verify", "activityId": "mc-hbt-cause", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 17:40:09.490091+00	2026-10-25 17:40:09.490091+00
27285241-9125-4413-9bc5-3ccb55d8361d	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	3da4deda-6dd7-475b-8d5c-a9b8d2a896cd	SUBMIT_ACTIVITY	0c3a50c1c0ac741f094ed85344a15086f65f61f18720a2c1bc9fefcbf6880cf5	{"next": {"stageId": "conclusion", "activityId": "read-hbt-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 17:40:20.690236+00	2026-10-25 17:40:20.690236+00
70a0a789-ea27-4ff8-8a72-d4cf7ac353e8	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	6e1ccc9a-cd35-41c6-8d44-111f37e35a57	SUBMIT_ACTIVITY	9172dc339717302968769d61a0e2198846eccfe869d3a3f7a22c31225ad90406	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 17:40:31.035496+00	2026-10-25 17:40:31.035496+00
fc1937e7-49cf-4bdf-93b6-60165c98eed1	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	4e3de374-fbf4-4375-affa-1b983bd7bcb4	COMPLETE_ATTEMPT	b44bd21f2c27db98a93b5027f85d00129cc2d74407576eb9b529d3c13c03b0c4	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "ac7205c6-7933-4d00-9f87-aa2fb5b0f59a", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T17:40:41.090539100Z", "alreadyCompleted": false}	200	2026-10-24 17:40:41.066734+00	2026-10-25 17:40:41.066734+00
59224a45-8b0d-41a8-8b7f-9b4570525fb7	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	fcf1a643-8a33-4c92-940b-d8074e7ab40b	SUBMIT_ACTIVITY	495a17beb6880820bc39398b3cbbd778a93e44df2e4a3d6353ed9c190195105f	{"next": {"stageId": "verify", "activityId": "mc-hbt-cause", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 18:05:21.521761+00	2026-10-25 18:05:21.521761+00
57f9f314-57e1-434d-a67d-1c084361ae0a	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	820c764c-129b-4adb-9fda-8967af5caf0d	SUBMIT_ACTIVITY	5921eb772e537c0ea2eef76ca1c7a4717fe6841f67f7839f35f0eb805e5bffc5	{"next": {"stageId": "conclusion", "activityId": "read-hbt-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 18:05:29.20823+00	2026-10-25 18:05:29.20823+00
32631496-5d26-48a2-acde-a408280bb3bd	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	563ba811-88f8-473c-bce5-8197bed38bd4	SUBMIT_ACTIVITY	2c8ee79e7b2096b4501016879b11d0f9cf03ec6be80803ecc126f281e01f58d8	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 18:05:35.621582+00	2026-10-25 18:05:35.621582+00
75f823bf-6b78-4cdf-83a9-bc88f51b6e20	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	bedc63cb-8a70-4874-a692-25dd12c4a51c	COMPLETE_ATTEMPT	55639847850cf55824d347ce5b72916789b25dacbed44483c73199c19de8cbb2	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "25c2b985-104e-4fbe-a499-a9e199681b3e", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T18:06:03.357180400Z", "alreadyCompleted": false}	200	2026-10-24 18:06:03.351529+00	2026-10-25 18:06:03.351529+00
5693d3c5-e974-4199-a86d-30f3bb8b6dd2	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	306f3f94-e26f-426f-95b0-ba89524a4efd	SUBMIT_ACTIVITY	c53943fadfad1e6fc9f9ad1f1eb3b53d93c531572eb0242ff726f31ca5603def	{"next": {"stageId": "verify", "activityId": "mc-hbt-cause", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 18:06:12.60307+00	2026-10-25 18:06:12.60307+00
3ce89612-086c-4529-97f7-b65fe4c24730	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	fbc0ae91-3ac4-4283-9adb-c9b8576db00b	SUBMIT_ACTIVITY	29846c4f1f7d1894ff47b4cf1e610b5989695418206f1b545472fd0e27c2f0b5	{"next": {"stageId": "conclusion", "activityId": "read-hbt-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 18:06:15.8537+00	2026-10-25 18:06:15.8537+00
2bcd52e8-0e41-4e8a-9f96-f3ca3fd4ce4d	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	cad16a01-57d0-410c-9296-2a0cc1cb47bc	SUBMIT_ACTIVITY	2245b4c3b3943e174969b927424bd1a3f889bef673db3e82478bef025771a480	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 18:06:17.777891+00	2026-10-25 18:06:17.777891+00
3ce337fb-22eb-40d7-bf60-a324abba2bb1	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	1fa9d558-ff01-4e7e-8e9c-ffe8283e6136	COMPLETE_ATTEMPT	3e3ada4cacbd6ae32e4d36544c174c9f6e1fcd2d28cfa3e88a04bddf2b81cfdf	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "f299af52-46fd-4b45-8078-5dd762497caa", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T18:06:19.223917700Z", "alreadyCompleted": false}	200	2026-10-24 18:06:19.215355+00	2026-10-25 18:06:19.215355+00
a0bfdf71-31bd-4de0-92bd-6f778fd78c1c	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	22bd692d-e3f9-4390-84ee-ae1de87dac73	SUBMIT_ACTIVITY	eb3f9e9cb720c1f7eca7bebf7d405bc8e93a71f818ddeef45dc2ada926220701	{"next": {"stageId": "verify", "activityId": "mc-hbt-cause", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 18:13:33.060043+00	2026-10-25 18:13:33.060043+00
8176ed26-7f4c-4b24-88af-201a78f216e9	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	bc24aaf6-766b-4c5a-816d-a38a4195d1d7	SUBMIT_ACTIVITY	8b643fdb167357f31626089130632608381227b9a108ef1646066f8fad27f760	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 18:13:37.801425+00	2026-10-25 18:13:37.801425+00
19282fa9-31de-4045-89e4-ea8d393a4065	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	fdeb0e33-bea9-486f-938c-c4b62f7f7e50	COMPLETE_ATTEMPT	c1e234f1e270c409d5d83b35fe9fc0a80f1fbb47ea524afd1d34106edfe95146	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "1a15cdd0-315e-4353-b0ac-e0d5a4597db4", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T18:13:38.874679800Z", "alreadyCompleted": false}	200	2026-10-24 18:13:38.869765+00	2026-10-25 18:13:38.869765+00
1b4f7680-b058-43b5-ba70-c762f4f6b750	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	b5833546-d8aa-4b0b-b09b-d9c9c80ce3c0	SUBMIT_ACTIVITY	d4f11e793670035c350cd49ed0ad08fc04a07177c49e544337ab98c3a6ac94b1	{"next": {"stageId": "conclusion", "activityId": "read-dbp-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-25 00:45:28.403466+00	2026-10-26 00:45:28.403466+00
3e2c7249-e6f7-48cf-a8b4-e132303e7ce6	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	7d826339-dbee-430e-879e-d2d1f11c093b	SUBMIT_ACTIVITY	91ad5420c708a4f4d443d50754b2b2a5ea7bfdb1b259cb2efcef41af16074fd4	{"next": {"stageId": "conclusion", "activityId": "read-hbt-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "INCORRECT", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 18:13:36.138758+00	2026-10-25 18:13:36.138758+00
6cddf3f6-cf01-4746-ace6-1ef0f76556ab	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	6bc24f8c-7fb1-472b-85f2-6906a7c81221	SUBMIT_ACTIVITY	8591a4681e33e8e32eadf59c5e2364165d65aaaab0601638231fc383c9327570	{"next": {"stageId": "verify", "activityId": "mc-hbt-cause", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 19:29:34.120172+00	2026-10-25 19:29:34.120172+00
bfb284a9-38fb-446c-8cc0-04e4187336d5	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	677ed02a-5844-4d83-9735-9251130635f7	SUBMIT_ACTIVITY	7b4426130f0a82f8f3449855309cc6f65140cf0d7f3e174a51a259ed6da76e45	{"next": {"stageId": "conclusion", "activityId": "read-hbt-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 20:04:38.509413+00	2026-10-25 20:04:38.509413+00
62e23413-4f2f-4e0f-bf5a-996fe1c8cf24	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	a75709b1-27f6-40a6-9105-4caee927d199	SUBMIT_ACTIVITY	f33cfe09274c1e0304a397e1e783d50c5441012c5d75f1a87469c38b093c56ea	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 20:44:02.036291+00	2026-10-25 20:44:02.036291+00
7812940f-cef6-4226-801e-fab07471155f	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	03572ca1-e90c-47f8-b445-419e57deb945	COMPLETE_ATTEMPT	a183e8b12782584e4ff25dcfe3d3e5195e4970b19383d041885ee0e59eb0b3b1	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "bfe3e17a-e8c9-471c-adcf-58597abf2eee", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T20:44:07.103341700Z", "alreadyCompleted": false}	200	2026-10-24 20:44:07.096484+00	2026-10-25 20:44:07.096484+00
a6db7d86-579e-42c8-b217-6633905874df	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	25e73626-9b1e-464c-b8ee-c1ff6ef81783	SUBMIT_ACTIVITY	3e7ceef10ead8d6a2c03ec264ecf34fadf22f68b75a031373ff4c0e3e4c505f1	{"next": {"stageId": "verify", "activityId": "mc-dbp-decision", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 21:06:08.713651+00	2026-10-25 21:06:08.713651+00
03b8712c-93d8-48c4-89bf-dd240d55cecb	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	decce63f-8f18-4c4c-b5fd-121d5c1d2897	SUBMIT_ACTIVITY	df540425248128a8834a1744ed29e02254694f6cf2f8afa6b65ef13024d8ba8c	{"next": {"stageId": "conclusion", "activityId": "read-dbp-conclusion", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 2}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["conclusion"], "completedRequired": 2}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 21:06:14.723796+00	2026-10-25 21:06:14.723796+00
f14e1106-8cb8-4dde-9e5e-ba3afd84b97f	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	2171eb3d-65a9-4086-8f02-34abc16e79ba	SUBMIT_ACTIVITY	c15640f9aac9b1d916db506aaab4e5b39a2c3395dd5508957fc44e4e1b0ff48c	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-24 21:06:16.455675+00	2026-10-25 21:06:16.455675+00
85dccfab-ac77-4a63-ad9e-86ed0d669730	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	2c4fd68e-bb7a-4657-949a-53a613d383c2	COMPLETE_ATTEMPT	b84b97a3a136e4d3a760c34b4366335dcdc2e4fdebbcf0132de2f7c45fe831fd	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "0349305f-568e-4ee2-9299-0a49d109f4ef", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-24T21:06:18.373798600Z", "alreadyCompleted": false}	200	2026-10-24 21:06:18.364058+00	2026-10-25 21:06:18.364058+00
79ed4db2-7293-46f5-8ca7-a9bf90ea3793	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	279f77e8-df70-41eb-887e-f004adc4badf	SUBMIT_ACTIVITY	b48227fc4732f258961ca005bda5c0712fd1a61a0a6f298bc3cb05f0bc40740b	{"next": {"stageId": "verify", "activityId": "mc-dbp-decision", "activityType": null, "learnerConfig": null}, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 1}, "completion": {"detail": {"totalRequired": 3, "missingStageIds": ["verify", "conclusion"], "completedRequired": 1}, "reason": "NOT_COMPLETE", "complete": false}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-25 00:45:21.377718+00	2026-10-26 00:45:21.377718+00
ab7c739f-d0c0-4edf-822f-cad399408c3e	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	1efd99b8-235d-490b-8579-44f94d2e78bc	SUBMIT_ACTIVITY	f8b70d8dee124dec33ac240079a8ae835dd83fe32af4e2b05f63a15ae5673b8e	{"next": null, "status": "ACCEPTED", "progress": {"totalRequired": 3, "completedRequired": 3}, "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "evaluation": {"output": {"viewed": true}, "outcome": "COMPLETED", "completed": true, "feedbackCode": null}, "activityCompleted": true}	200	2026-10-25 00:45:31.200766+00	2026-10-26 00:45:31.200766+00
3a4b16a5-f807-4ab1-81d4-27537dbdbbb7	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	ab412e88-3303-4a97-a1ee-ffc6ceb09909	COMPLETE_ATTEMPT	f2f1304c20725a114434bc20d1a84e61568e1c4124008f05c359a5300345932e	{"status": "COMPLETED", "progress": {"totalRequired": 3, "completedRequired": 3}, "attemptId": "3927bcd2-1e9e-451a-bf9e-147d06d456d4", "completion": {"detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "complete": true}, "completedAt": "2026-10-25T00:45:33.261238100Z", "alreadyCompleted": false}	200	2026-10-25 00:45:33.251752+00	2026-10-26 00:45:33.251752+00
\.


--
-- Data for Name: item_catalog; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.item_catalog (id, code, name, description, category, item_type, rarity, asset_id, source_metadata, active, created_at, updated_at, row_version) FROM stdin;
57049a70-91ca-4bad-a579-891d7794a535	HUY_HIEU_DIEN_BIEN_PHU	Huy hiệu kỷ niệm Điện Biên Phủ	Huy hiệu kỷ niệm chiến dịch Điện Biên Phủ 1954. Mở khóa khi hoàn thành đủ số bài học đầu tiên của hành trình lịch sử.	HUY_HIEU	COMMEMORATIVE_BADGE	COMMON	\N	{"note": "Huy hiệu kỷ niệm, không phải hiện vật", "commemorates": "Chiến dịch Điện Biên Phủ, 1954"}	t	2026-10-24 13:08:01.386456+00	2026-10-24 13:08:01.386456+00	0
543e3d14-3286-4486-8443-fc21b0f459da	MO_HINH_TRONG_DONG_DONG_SON	Mô hình trống đồng Đông Sơn	Mô hình thu nhỏ của trống đồng Đông Sơn — biểu tượng nền văn hóa Đông Sơn (khoảng thế kỷ VII TCN đến thế kỷ I SCN). Mở khóa khi sưu tầm đủ 12 bằng chứng bất kỳ trong Bộ Sưu Tập.	MO_HINH	HISTORICAL_REPLICA	RARE	\N	{"note": "Mô hình phục vụ học tập, không phải hiện vật thật", "heldBy": "Bảo tàng Lịch sử Quốc gia", "referenceArtifact": "Trống đồng Đông Sơn"}	t	2026-10-24 13:08:01.386456+00	2026-10-24 13:08:01.386456+00	0
d0d52e0c-fcbb-4a21-976e-07fefa71e9b3	PHIEN_BAN_SO_COC_BACH_DANG	Phiên bản số cọc ngầm Bạch Đằng	Phiên bản số tái hiện cọc ngầm trận Bạch Đằng 938 — di chỉ cọc gỗ được nghiên cứu niên đại C-14. Mở khóa khi sưu tầm đủ 5 bằng chứng bất kỳ trong Bộ Sưu Tập.	PHIEN_BAN_SO	DIGITAL_EDITION	UNCOMMON	\N	{"note": "Tái hiện số cho mục đích giáo dục", "referenceSite": "Bãi cọc Yên Giang, Quảng Yên"}	t	2026-10-24 13:08:01.386456+00	2026-10-24 13:08:01.386456+00	0
59c35937-2a1c-4cea-ad58-7a99e706f756	MO_HINH_THANH_NHA_HO	Mô hình Thành nhà Hồ	Mô hình thu nhỏ Thành nhà Hồ (Vĩnh Lộc, Thanh Hóa) — di sản thế giới UNESCO công nhận 2011. Mở khóa khi sưu tầm đủ 10 bằng chứng bất kỳ trong Bộ Sưu Tập.	MO_HINH	HISTORICAL_REPLICA	RARE	\N	{"note": "Mô hình phục vụ học tập", "recognizedBy": "UNESCO World Heritage", "referenceSite": "Thành nhà Hồ, Thanh Hóa"}	t	2026-10-24 13:08:01.386456+00	2026-10-24 13:08:01.386456+00	0
15e99e89-86c8-4df4-9e95-521f588d0d82	PHIEN_BAN_SO_CO_LOA	Phiên bản số thành Cổ Loa	Phiên bản số sơ đồ ba vòng thành xoắn ốc Cổ Loa — kinh đô Âu Lạc thế kỷ III TCN. Mở khóa khi sưu tầm đủ 6 bằng chứng bất kỳ trong Bộ Sưu Tập.	PHIEN_BAN_SO	DIGITAL_EDITION	UNCOMMON	\N	{"note": "Tái hiện số cho mục đích giáo dục", "referenceSite": "Khu di tích Cổ Loa, Hà Nội"}	t	2026-10-24 13:08:01.386456+00	2026-10-24 13:08:01.386456+00	0
62050d2b-2a20-4844-92fe-627cc952a322	HUY_HIEU_HAI_BA_TRUNG	Huy hiệu kỷ niệm Hai Bà Trưng	Huy hiệu kỷ niệm khởi nghĩa Hai Bà Trưng năm 40 — tinh thần độc lập đầu tiên sau thời kỳ Bắc thuộc. Mở khóa khi sưu tầm đủ 3 bằng chứng bất kỳ trong Bộ Sưu Tập.	HUY_HIEU	COMMEMORATIVE_BADGE	COMMON	\N	{"note": "Huy hiệu kỷ niệm, không phải hiện vật", "commemorates": "Khởi nghĩa Hai Bà Trưng, 40 SCN"}	t	2026-10-24 13:08:01.386456+00	2026-10-24 13:08:01.386456+00	0
6e248fdc-e2dc-4505-88dc-8e1ebd8f9c45	MO_HINH_CHUA_MY_SON	Mô hình tháp Mỹ Sơn	Mô hình thu nhỏ tháp Chăm tại thánh địa Mỹ Sơn — di sản thế giới UNESCO 1999. Mở khóa khi sưu tầm đủ 15 bằng chứng bất kỳ trong Bộ Sưu Tập.	MO_HINH	HISTORICAL_REPLICA	EPIC	\N	{"note": "Mô hình phục vụ học tập", "recognizedBy": "UNESCO World Heritage", "referenceSite": "Thánh địa Mỹ Sơn, Quảng Nam"}	t	2026-10-24 13:08:01.386456+00	2026-10-24 13:08:01.386456+00	0
530bcf7d-50a5-4f8f-938d-b9e5ed19c69c	PHIEN_BAN_SO_PHO_HOI_AN	Phiên bản số phố cổ Hội An	Phiên bản số một góc phố cổ Hội An — thương cảng quốc tế thế kỷ XVI-XVII, di sản UNESCO 1999. Mở khóa khi sưu tầm đủ 8 bằng chứng bất kỳ trong Bộ Sưu Tập.	PHIEN_BAN_SO	DIGITAL_EDITION	UNCOMMON	\N	{"note": "Tái hiện số cho mục đích giáo dục", "recognizedBy": "UNESCO World Heritage", "referenceSite": "Phố cổ Hội An"}	t	2026-10-24 13:08:01.386456+00	2026-10-24 13:08:01.386456+00	0
\.


--
-- Data for Name: item_unlock_rule; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.item_unlock_rule (id, item_id, rule_type, lesson_id, threshold, active, created_at) FROM stdin;
dcca1111-9e40-400a-bc84-33a14692113e	543e3d14-3286-4486-8443-fc21b0f459da	COLLECTION_COUNT	\N	12	t	2026-10-24 13:08:01.386456+00
6b1128f9-fd8a-4015-99e8-d9c209c3430c	d0d52e0c-fcbb-4a21-976e-07fefa71e9b3	COLLECTION_COUNT	\N	5	t	2026-10-24 13:08:01.386456+00
5b208623-7217-4a21-848c-80cb72500d42	59c35937-2a1c-4cea-ad58-7a99e706f756	COLLECTION_COUNT	\N	10	t	2026-10-24 13:08:01.386456+00
d740fade-dff6-4413-919b-c8cc14717dd8	15e99e89-86c8-4df4-9e95-521f588d0d82	COLLECTION_COUNT	\N	6	t	2026-10-24 13:08:01.386456+00
325a76d3-421e-435a-a391-52a2bb8a7525	62050d2b-2a20-4844-92fe-627cc952a322	COLLECTION_COUNT	\N	3	t	2026-10-24 13:08:01.386456+00
a8d1b554-40cd-4316-b843-6fd7bbc24554	6e248fdc-e2dc-4505-88dc-8e1ebd8f9c45	COLLECTION_COUNT	\N	15	t	2026-10-24 13:08:01.386456+00
999d8088-8502-4921-ba10-b67a3aa2b25d	530bcf7d-50a5-4f8f-938d-b9e5ed19c69c	COLLECTION_COUNT	\N	8	t	2026-10-24 13:08:01.386456+00
fe188917-0322-4bce-984b-56caa9ee702f	57049a70-91ca-4bad-a579-891d7794a535	LESSON_COUNT	\N	5	t	2026-10-24 13:08:01.386456+00
\.


--
-- Data for Name: learner_attempts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.learner_attempts (id, user_id, lesson_version_id, status, current_stage_id, current_activity_id, state_json, started_at, last_active_at, completed_at, row_version) FROM stdin;
9bc7e6d0-5d8f-4a6b-8197-85a8beddd6e2	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000002	COMPLETED	conclusion	read-hbt-conclusion	{"outputs": {"mc-hbt-cause": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "read-hbt-context": {"viewed": true}, "read-hbt-conclusion": {"viewed": true}}, "attemptCounts": {"mc-hbt-cause": 1, "read-hbt-context": 1, "read-hbt-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-hbt-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-hbt-context", "mc-hbt-cause", "read-hbt-conclusion"]}	2026-10-24 16:06:19.296821+00	2026-10-24 16:08:25.041163+00	2026-10-24 16:08:25.041163+00	4
6ed3df0f-9aa5-4aba-9880-a4ef2ad40b72	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000002	COMPLETED	conclusion	read-hbt-conclusion	{"outputs": {"mc-hbt-cause": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "read-hbt-context": {"viewed": true}, "read-hbt-conclusion": {"viewed": true}}, "attemptCounts": {"mc-hbt-cause": 1, "read-hbt-context": 1, "read-hbt-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-hbt-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-hbt-context", "mc-hbt-cause", "read-hbt-conclusion"]}	2026-10-24 16:47:19.519433+00	2026-10-24 16:47:27.63148+00	2026-10-24 16:47:27.63148+00	4
055d991d-2b51-40fd-b4d4-fb6ed68afddf	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000002	COMPLETED	conclusion	read-hbt-conclusion	{"outputs": {"mc-hbt-cause": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "read-hbt-context": {"viewed": true}, "read-hbt-conclusion": {"viewed": true}}, "attemptCounts": {"mc-hbt-cause": 1, "read-hbt-context": 1, "read-hbt-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-hbt-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-hbt-context", "mc-hbt-cause", "read-hbt-conclusion"]}	2026-10-24 16:26:52.209137+00	2026-10-24 16:28:46.224262+00	2026-10-24 16:28:46.224262+00	4
76ee8a1a-8c08-4f8a-b79e-12de8c6efb9c	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000002	COMPLETED	conclusion	read-hbt-conclusion	{"outputs": {"mc-hbt-cause": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "read-hbt-context": {"viewed": true}, "read-hbt-conclusion": {"viewed": true}}, "attemptCounts": {"mc-hbt-cause": 1, "read-hbt-context": 1, "read-hbt-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-hbt-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-hbt-context", "mc-hbt-cause", "read-hbt-conclusion"]}	2026-10-24 16:11:16.916976+00	2026-10-24 16:18:16.452047+00	2026-10-24 16:18:16.452047+00	4
b29f88c1-0f90-41ef-a833-ff1cf8a98dea	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000002	COMPLETED	conclusion	read-hbt-conclusion	{"outputs": {"mc-hbt-cause": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "read-hbt-context": {"viewed": true}, "read-hbt-conclusion": {"viewed": true}}, "attemptCounts": {"mc-hbt-cause": 1, "read-hbt-context": 1, "read-hbt-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-hbt-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-hbt-context", "mc-hbt-cause", "read-hbt-conclusion"]}	2026-10-24 14:59:45.927702+00	2026-10-24 14:59:55.437633+00	2026-10-24 14:59:55.437633+00	4
652de175-1eb1-4fb7-81f4-e2ce7177e758	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000002	COMPLETED	conclusion	read-hbt-conclusion	{"outputs": {"mc-hbt-cause": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "read-hbt-context": {"viewed": true}, "read-hbt-conclusion": {"viewed": true}}, "attemptCounts": {"mc-hbt-cause": 1, "read-hbt-context": 1, "read-hbt-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-hbt-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-hbt-context", "mc-hbt-cause", "read-hbt-conclusion"]}	2026-10-24 16:25:47.124315+00	2026-10-24 16:26:35.568668+00	2026-10-24 16:26:35.568668+00	4
a1cdbc7f-e176-4824-be1e-1a0a3de60ed6	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000002	COMPLETED	conclusion	read-hbt-conclusion	{"outputs": {"mc-hbt-cause": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "read-hbt-context": {"viewed": true}, "read-hbt-conclusion": {"viewed": true}}, "attemptCounts": {"mc-hbt-cause": 1, "read-hbt-context": 1, "read-hbt-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-hbt-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-hbt-context", "mc-hbt-cause", "read-hbt-conclusion"]}	2026-10-24 16:18:21.839467+00	2026-10-24 16:18:31.401007+00	2026-10-24 16:18:31.401007+00	4
8f03c376-529b-4279-b25b-38b8d0339182	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000002	COMPLETED	conclusion	read-hbt-conclusion	{"outputs": {"mc-hbt-cause": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "read-hbt-context": {"viewed": true}, "read-hbt-conclusion": {"viewed": true}}, "attemptCounts": {"mc-hbt-cause": 1, "read-hbt-context": 1, "read-hbt-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-hbt-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-hbt-context", "mc-hbt-cause", "read-hbt-conclusion"]}	2026-10-24 16:52:09.484159+00	2026-10-24 16:52:17.772479+00	2026-10-24 16:52:17.772479+00	4
b2186fce-e2e4-4e14-a875-c738ed1e2417	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000002	COMPLETED	conclusion	read-hbt-conclusion	{"outputs": {"mc-hbt-cause": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "read-hbt-context": {"viewed": true}, "read-hbt-conclusion": {"viewed": true}}, "attemptCounts": {"mc-hbt-cause": 1, "read-hbt-context": 1, "read-hbt-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-hbt-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-hbt-context", "mc-hbt-cause", "read-hbt-conclusion"]}	2026-10-24 17:13:51.248821+00	2026-10-24 17:14:39.955088+00	2026-10-24 17:14:39.955088+00	4
ac7205c6-7933-4d00-9f87-aa2fb5b0f59a	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000002	COMPLETED	conclusion	read-hbt-conclusion	{"outputs": {"mc-hbt-cause": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "read-hbt-context": {"viewed": true}, "read-hbt-conclusion": {"viewed": true}}, "attemptCounts": {"mc-hbt-cause": 1, "read-hbt-context": 1, "read-hbt-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-hbt-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-hbt-context", "mc-hbt-cause", "read-hbt-conclusion"]}	2026-10-24 17:40:07.032816+00	2026-10-24 17:40:41.090539+00	2026-10-24 17:40:41.090539+00	4
25c2b985-104e-4fbe-a499-a9e199681b3e	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000002	COMPLETED	conclusion	read-hbt-conclusion	{"outputs": {"mc-hbt-cause": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "read-hbt-context": {"viewed": true}, "read-hbt-conclusion": {"viewed": true}}, "attemptCounts": {"mc-hbt-cause": 1, "read-hbt-context": 1, "read-hbt-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-hbt-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-hbt-context", "mc-hbt-cause", "read-hbt-conclusion"]}	2026-10-24 18:05:19.774047+00	2026-10-24 18:06:03.35718+00	2026-10-24 18:06:03.35718+00	4
bfe3e17a-e8c9-471c-adcf-58597abf2eee	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000002	COMPLETED	conclusion	read-hbt-conclusion	{"outputs": {"mc-hbt-cause": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "read-hbt-context": {"viewed": true}, "read-hbt-conclusion": {"viewed": true}}, "attemptCounts": {"mc-hbt-cause": 1, "read-hbt-context": 1, "read-hbt-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-hbt-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-hbt-context", "mc-hbt-cause", "read-hbt-conclusion"]}	2026-10-24 19:29:32.031047+00	2026-10-24 20:44:07.103342+00	2026-10-24 20:44:07.103342+00	4
f299af52-46fd-4b45-8078-5dd762497caa	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000002	COMPLETED	conclusion	read-hbt-conclusion	{"outputs": {"mc-hbt-cause": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "read-hbt-context": {"viewed": true}, "read-hbt-conclusion": {"viewed": true}}, "attemptCounts": {"mc-hbt-cause": 1, "read-hbt-context": 1, "read-hbt-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-hbt-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-hbt-context", "mc-hbt-cause", "read-hbt-conclusion"]}	2026-10-24 18:06:11.366727+00	2026-10-24 18:06:19.223918+00	2026-10-24 18:06:19.223918+00	4
3927bcd2-1e9e-451a-bf9e-147d06d456d4	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000004	COMPLETED	conclusion	read-dbp-conclusion	{"outputs": {"mc-dbp-decision": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "read-dbp-context": {"viewed": true}, "read-dbp-conclusion": {"viewed": true}}, "attemptCounts": {"mc-dbp-decision": 1, "read-dbp-context": 1, "read-dbp-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-dbp-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-dbp-context", "mc-dbp-decision", "read-dbp-conclusion"]}	2026-10-25 00:45:18.127717+00	2026-10-25 00:45:33.261238+00	2026-10-25 00:45:33.261238+00	4
1a15cdd0-315e-4353-b0ac-e0d5a4597db4	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000002	COMPLETED	conclusion	read-hbt-conclusion	{"outputs": {"mc-hbt-cause": {"correct": false, "exhausted": true, "attemptCount": 1, "selectedCount": 1}, "read-hbt-context": {"viewed": true}, "read-hbt-conclusion": {"viewed": true}}, "attemptCounts": {"mc-hbt-cause": 1, "read-hbt-context": 1, "read-hbt-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-hbt-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-hbt-context", "mc-hbt-cause", "read-hbt-conclusion"]}	2026-10-24 18:13:31.990097+00	2026-10-24 18:13:38.87468+00	2026-10-24 18:13:38.87468+00	4
0349305f-568e-4ee2-9299-0a49d109f4ef	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	30000000-0000-0000-0000-000000000004	COMPLETED	conclusion	read-dbp-conclusion	{"outputs": {"mc-dbp-decision": {"correct": true, "attemptCount": 1, "selectedCount": 1}, "read-dbp-context": {"viewed": true}, "read-dbp-conclusion": {"viewed": true}}, "attemptCounts": {"mc-dbp-decision": 1, "read-dbp-context": 1, "read-dbp-conclusion": 1}, "currentStageId": "conclusion", "currentActivityId": "read-dbp-conclusion", "discoveredMarkerIds": [], "completedActivityIds": ["read-dbp-context", "mc-dbp-decision", "read-dbp-conclusion"]}	2026-10-24 21:06:07.73502+00	2026-10-24 21:06:18.373799+00	2026-10-24 21:06:18.373799+00	4
\.


--
-- Data for Name: lesson_results; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lesson_results (id, learner_attempt_id, score, result_json, completed_at) FROM stdin;
b1638cad-7960-4a99-897a-60eb352f98f1	b29f88c1-0f90-41ef-a833-ff1cf8a98dea	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "b29f88c1-0f90-41ef-a833-ff1cf8a98dea", "totalRequired": 3, "knowledgeScore": 100.0, "lessonVersionId": "30000000-0000-0000-0000-000000000002", "completedRequired": 3}	2026-10-24 14:59:55.437633+00
738e3032-ad77-4b87-b476-5f9fb0d31b68	9bc7e6d0-5d8f-4a6b-8197-85a8beddd6e2	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "9bc7e6d0-5d8f-4a6b-8197-85a8beddd6e2", "totalRequired": 3, "knowledgeScore": 0.0, "lessonVersionId": "30000000-0000-0000-0000-000000000002", "completedRequired": 3}	2026-10-24 16:08:25.041163+00
3143d4df-db08-4588-85bc-5641d006bb0c	76ee8a1a-8c08-4f8a-b79e-12de8c6efb9c	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "76ee8a1a-8c08-4f8a-b79e-12de8c6efb9c", "totalRequired": 3, "knowledgeScore": 0.0, "lessonVersionId": "30000000-0000-0000-0000-000000000002", "completedRequired": 3}	2026-10-24 16:18:16.452047+00
9eb0c4bc-8a94-45d2-8bf2-06f88376e3ea	a1cdbc7f-e176-4824-be1e-1a0a3de60ed6	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "a1cdbc7f-e176-4824-be1e-1a0a3de60ed6", "totalRequired": 3, "knowledgeScore": 0.0, "lessonVersionId": "30000000-0000-0000-0000-000000000002", "completedRequired": 3}	2026-10-24 16:18:31.401007+00
9b09445f-e5a3-442f-9128-cecf8156a124	652de175-1eb1-4fb7-81f4-e2ce7177e758	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "652de175-1eb1-4fb7-81f4-e2ce7177e758", "totalRequired": 3, "knowledgeScore": 0.0, "lessonVersionId": "30000000-0000-0000-0000-000000000002", "completedRequired": 3}	2026-10-24 16:26:35.568668+00
ba85f0f2-4928-4d5b-8aa9-35ad23560ef0	055d991d-2b51-40fd-b4d4-fb6ed68afddf	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "055d991d-2b51-40fd-b4d4-fb6ed68afddf", "totalRequired": 3, "knowledgeScore": 100.0, "lessonVersionId": "30000000-0000-0000-0000-000000000002", "completedRequired": 3}	2026-10-24 16:28:46.224262+00
cf3912f3-74a3-4c80-88de-31709d4822ce	6ed3df0f-9aa5-4aba-9880-a4ef2ad40b72	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "6ed3df0f-9aa5-4aba-9880-a4ef2ad40b72", "totalRequired": 3, "knowledgeScore": 0.0, "lessonVersionId": "30000000-0000-0000-0000-000000000002", "completedRequired": 3}	2026-10-24 16:47:27.63148+00
bcaae880-dd04-46cb-ae3f-cd7ffc3820ca	8f03c376-529b-4279-b25b-38b8d0339182	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "8f03c376-529b-4279-b25b-38b8d0339182", "totalRequired": 3, "knowledgeScore": 0.0, "lessonVersionId": "30000000-0000-0000-0000-000000000002", "completedRequired": 3}	2026-10-24 16:52:17.772479+00
7710e7e6-e64c-4fba-9310-98f1e4238f17	b2186fce-e2e4-4e14-a875-c738ed1e2417	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "b2186fce-e2e4-4e14-a875-c738ed1e2417", "totalRequired": 3, "knowledgeScore": 0.0, "lessonVersionId": "30000000-0000-0000-0000-000000000002", "completedRequired": 3}	2026-10-24 17:14:39.955088+00
64c76cc9-ee6d-4bea-ac45-00ade18e3c45	ac7205c6-7933-4d00-9f87-aa2fb5b0f59a	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "ac7205c6-7933-4d00-9f87-aa2fb5b0f59a", "totalRequired": 3, "knowledgeScore": 100.0, "lessonVersionId": "30000000-0000-0000-0000-000000000002", "completedRequired": 3}	2026-10-24 17:40:41.090539+00
e545990d-01f9-4525-918e-212f6947cf9e	25c2b985-104e-4fbe-a499-a9e199681b3e	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "25c2b985-104e-4fbe-a499-a9e199681b3e", "totalRequired": 3, "knowledgeScore": 0.0, "lessonVersionId": "30000000-0000-0000-0000-000000000002", "completedRequired": 3}	2026-10-24 18:06:03.35718+00
b2c485f1-5e6c-4dfc-b91c-73212d4d27f3	f299af52-46fd-4b45-8078-5dd762497caa	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "f299af52-46fd-4b45-8078-5dd762497caa", "totalRequired": 3, "knowledgeScore": 0.0, "lessonVersionId": "30000000-0000-0000-0000-000000000002", "completedRequired": 3}	2026-10-24 18:06:19.223918+00
57ee2e7c-36f8-4829-88ef-e3532415c1be	1a15cdd0-315e-4353-b0ac-e0d5a4597db4	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "1a15cdd0-315e-4353-b0ac-e0d5a4597db4", "totalRequired": 3, "knowledgeScore": 0.0, "lessonVersionId": "30000000-0000-0000-0000-000000000002", "completedRequired": 3}	2026-10-24 18:13:38.87468+00
333e0772-00a3-4060-a7ee-68fec17bd864	bfe3e17a-e8c9-471c-adcf-58597abf2eee	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "bfe3e17a-e8c9-471c-adcf-58597abf2eee", "totalRequired": 3, "knowledgeScore": 100.0, "lessonVersionId": "30000000-0000-0000-0000-000000000002", "completedRequired": 3}	2026-10-24 20:44:07.103342+00
834ee7f8-183b-4eee-bc53-f4c4ca97a2a0	0349305f-568e-4ee2-9299-0a49d109f4ef	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "0349305f-568e-4ee2-9299-0a49d109f4ef", "totalRequired": 3, "knowledgeScore": 100.0, "lessonVersionId": "30000000-0000-0000-0000-000000000004", "completedRequired": 3}	2026-10-24 21:06:18.373799+00
6b41b50a-9695-4a88-a6f0-0a5a501039f0	3927bcd2-1e9e-451a-bf9e-147d06d456d4	100.00	{"score": 100.0, "detail": {"totalRequired": 3, "completedRequired": 3}, "reason": "ALL_REQUIRED_STAGES", "attemptId": "3927bcd2-1e9e-451a-bf9e-147d06d456d4", "totalRequired": 3, "knowledgeScore": 100.0, "lessonVersionId": "30000000-0000-0000-0000-000000000004", "completedRequired": 3}	2026-10-25 00:45:33.261238+00
\.


--
-- Data for Name: lesson_templates; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lesson_templates (id, code, name, description, schema_version, preset_json, enabled, created_at, updated_at) FROM stdin;
d7a00000-0000-4000-8000-000000000001	HISTORY_INVESTIGATION	Điều tra sự kiện lịch sử	Khung bài học gồm bốn giai đoạn: bối cảnh, bằng chứng, tái dựng và kết luận.	1	{"stages": [{"id": "context", "type": "CONTEXT", "title": "Bối cảnh lịch sử", "required": true, "activities": [], "nextStageIds": ["evidence"]}, {"id": "evidence", "type": "EVIDENCE", "title": "Điều tra bằng chứng", "required": true, "activities": [], "nextStageIds": ["reconstruction"]}, {"id": "reconstruction", "type": "RECONSTRUCTION", "title": "Tái dựng diễn biến", "required": true, "activities": [], "nextStageIds": ["conclusion"]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Lập luận và kết luận", "required": true, "activities": [], "nextStageIds": []}], "completion": {"requireAllRequiredStages": true}, "schemaVersion": 1}	t	2026-10-24 13:08:01.209637+00	2026-10-24 13:08:01.209637+00
8b2ba314-7953-484e-a4fb-5e504e7c537a	a	Aqua Resigen 10.4EW - 1 lít	a	1	{"stages": [{"id": "context", "type": "DISCOVERY", "title": "Bối cảnh lịch sử", "required": true, "activities": [], "nextStageIds": ["evidence"]}, {"id": "evidence", "type": "EVIDENCE", "title": "Điều tra bằng chứng", "required": true, "activities": [], "nextStageIds": ["reconstruction"]}, {"id": "reconstruction", "type": "RECONSTRUCTION", "title": "Tái dựng diễn biến", "required": true, "activities": [], "nextStageIds": ["conclusion"]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Lập luận và kết luận", "required": true, "activities": [], "nextStageIds": []}], "schemaVersion": 1}	t	2026-10-24 14:10:02.697855+00	2026-10-24 14:10:02.697855+00
\.


--
-- Data for Name: lesson_versions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lesson_versions (id, lesson_id, version_no, schema_version, snapshot_json, published_at, published_by) FROM stdin;
30000000-0000-0000-0000-000000000002	10000000-0000-0000-0000-000000000002	1	1	{"stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh lịch sử", "required": true, "activities": [{"id": "read-hbt-context", "type": "READ", "config": {"text": "Đầu thế kỷ 1, nhà Đông Hán tăng cường đồng hóa và bóc lột hà khắc nhân dân Lạc Việt. Thái thú Tô Định nổi tiếng tham lam, tàn bạo. Khi Thi Sách (chồng bà Trưng Trắc) bị sát hại nhằm răn đe các thủ lĩnh người Việt, Trưng Trắc cùng em gái là Trưng Nhị đã phất cờ khởi nghĩa tại cửa sông Hát với 4 câu thề bất hủ:\\n\\nMột xin rửa sạch quốc thù,\\nHai xin đem lại nghiệp xưa họ Hùng,\\nBa kẻo oan ức lòng chồng,\\nBốn xin vẹn vẹn sở công lênh này.\\n\\nKhởi nghĩa bùng nổ, các quận Giao Chỉ, Cửu Chân, Nhật Nam đều đồng lòng hưởng ứng."}, "required": true, "instruction": "Đọc tư liệu về ách cai trị của Thái thú Tô Định và Lời thề Hát Môn"}], "nextStageIds": ["verify"]}, {"id": "verify", "type": "VERIFICATION", "title": "Điều tra chứng cứ & Đánh giá", "required": true, "activities": [{"id": "mc-hbt-cause", "type": "MULTIPLE_CHOICE", "config": {"options": [{"id": "opt-1", "label": "Giành lại quyền tự chủ cho dân tộc và phục hưng cơ nghiệp các vua Hùng"}, {"id": "opt-2", "label": "Chỉ thuần túy là trả thù riêng cho chồng là Thi Sách"}, {"id": "opt-3", "label": "Mong muốn được triều đình Hán phong thưởng tước vị"}], "question": "Mục tiêu lớn nhất và bao trùm của cuộc khởi nghĩa Hai Bà Trưng là gì?", "correctOptionIds": ["opt-1"]}, "required": true, "instruction": "Chọn nhận định đúng nhất về động lực khởi nghĩa"}], "nextStageIds": ["conclusion"]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Ý nghĩa lịch sử", "required": true, "activities": [{"id": "read-hbt-conclusion", "type": "READ", "config": {"text": "Khởi nghĩa Hai Bà Trưng là trang sử oanh liệt đầu tiên khẳng định ý chí độc lập, bất khuất của dân tộc Việt Nam, mở đầu cho truyền thống quật cường chống ngoại xâm của nhân dân ta."}, "required": true, "instruction": "Đúc kết bài học lịch sử"}], "nextStageIds": []}], "completion": {"requireAllRequiredStages": true}, "schemaVersion": 1}	2026-10-24 14:55:32.65923+00	061585cf-42e9-4312-ab4a-3e02c9ac8e70
30000000-0000-0000-0000-000000000003	10000000-0000-0000-0000-000000000003	1	1	{"stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh chiến dịch", "required": true, "activities": [{"id": "read-ly-context", "type": "READ", "config": {"text": "Năm 1077, 10 vạn đại quân Tống do Quách Quỳ chỉ huy tràn vào xâm lược Đại Việt. Thái úy Lý Thường Kiệt đã chủ động lập phòng tuyến kiên cố men bờ nam sông Như Nguyệt (sông Cầu, Bắc Ninh). Tuyến phòng thủ dài hơn 30km, được đắp lũy đất cao, cắm cọc tre dày đặc dưới lòng sông và chiến thuyền cơ động án ngữ, chặn đứng hoàn toàn bước tiến của quân thù trước cửa ngõ kinh thành Thăng Long."}, "required": true, "instruction": "Tìm hiểu phòng tuyến sông Như Nguyệt năm 1077"}], "nextStageIds": ["verify"]}, {"id": "verify", "type": "VERIFICATION", "title": "Nghệ thuật quân sự", "required": true, "activities": [{"id": "mc-ly-tactic", "type": "MULTIPLE_CHOICE", "config": {"options": [{"id": "opt-1", "label": "Chủ động phòng ngự kiên cố, tiêu hao sinh lực địch rồi phản công quyết định kết hợp đòn tâm lý chiến"}, {"id": "opt-2", "label": "Dồn toàn lực tấn công ồ ạt ngay khi quân Tống vừa tới bờ sông"}, {"id": "opt-3", "label": "Rút lui toàn bộ về kinh thành cố thủ chờ quân chi viện"}], "question": "Điểm độc đáo nhất trong nghệ thuật kháng chiến của Lý Thường Kiệt tại sông Như Nguyệt là gì?", "correctOptionIds": ["opt-1"]}, "required": true, "instruction": "Chọn nhận định chính xác về chiến thuật của Lý Thường Kiệt"}], "nextStageIds": ["conclusion"]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Đúc kết bài học", "required": true, "activities": [{"id": "read-ly-conclusion", "type": "READ", "config": {"text": "Chiến thắng Như Nguyệt gắn liền với bài thơ thần Nam quốc sơn hà - bản Tuyên ngôn Độc lập đầu tiên của nước Việt, đập tan ý chí xâm lược của nhà Tống, khẳng định chủ quyền thiêng liêng bất khả xâm phạm."}, "required": true, "instruction": "Ý nghĩa lịch sử của chiến thắng"}], "nextStageIds": []}], "completion": {"requireAllRequiredStages": true}, "schemaVersion": 1}	2026-10-24 14:55:32.65923+00	061585cf-42e9-4312-ab4a-3e02c9ac8e70
30000000-0000-0000-0000-000000000004	10000000-0000-0000-0000-000000000004	1	1	{"stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh chiến dịch", "required": true, "activities": [{"id": "read-dbp-context", "type": "READ", "config": {"text": "Tập đoàn cứ điểm Điện Biên Phủ gồm 49 cứ điểm liên hoàn, được thực dân Pháp xây dựng thành pháo đài bất khả xâm phạm. Ban đầu, Bộ chỉ huy chiến dịch dự kiến phương án Đánh nhanh thắng nhanh. Tuy nhiên, sau khi trực tiếp thị sát trận địa và nhận thấy địch đã gia cố công sự kiên cố, đêm 25 rạng sáng 26/1/1954, Đại tướng Võ Nguyên Giáp đã đưa ra quyết định lịch sử khó khăn nhất đời mình: Ra lệnh hoãn nổ súng, kéo pháo ra và chuyển sang phương châm Đánh chắc tiến chắc."}, "required": true, "instruction": "Tình hình chiến trường Điện Biên Phủ tháng 1/1954"}], "nextStageIds": ["verify"]}, {"id": "verify", "type": "VERIFICATION", "title": "Phân tích chiến lược", "required": true, "activities": [{"id": "mc-dbp-decision", "type": "MULTIPLE_CHOICE", "config": {"options": [{"id": "opt-1", "label": "Giúp bộ đội đào chiến hào siết chặt vòng vây, bóc dỡ từng cứ điểm và triệt tiêu ưu thế không quân, pháo binh địch"}, {"id": "opt-2", "label": "Kéo dài thời gian để chờ quân tiếp viện từ đồng minh"}, {"id": "opt-3", "label": "Nhằm mục đích rút bớt quân chủ lực về bảo vệ đồng bằng Bắc Bộ"}], "question": "Vì sao phương châm 'Đánh chắc, tiến chắc' là chìa khóa mở ra chiến thắng Điện Biên Phủ?", "correctOptionIds": ["opt-1"]}, "required": true, "instruction": "Đánh giá về quyết định chuyển phương châm tác chiến"}], "nextStageIds": ["conclusion"]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Tổng kết chiến thắng", "required": true, "activities": [{"id": "read-dbp-conclusion", "type": "READ", "config": {"text": "Sau 56 ngày đêm khoét núi, ngủ hầm, mưa dầm, cơm vắt, ngày 7/5/1954 lá cờ Quyết chiến Quyết thắng tung bay trên nóc hầm De Castries. Chiến thắng Điện Biên Phủ lừng lẫy năm châu, chấn động địa cầu đã buộc Pháp phải ký Hiệp định Genève chấm dứt chiến tranh tại Đông Dương."}, "required": true, "instruction": "Tầm vóc thời đại của chiến thắng Điện Biên Phủ"}], "nextStageIds": []}], "completion": {"requireAllRequiredStages": true}, "schemaVersion": 1}	2026-10-24 14:55:32.65923+00	061585cf-42e9-4312-ab4a-3e02c9ac8e70
\.


--
-- Data for Name: lessons; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.lessons (id, event_id, template_id, title, central_question, objectives_json, draft_json, status, current_version_id, created_by, updated_by, created_at, updated_at, row_version) FROM stdin;
4424fee2-cac3-472b-a21a-a3598f75df72	00000000-0000-0000-0000-000000000001	d7a00000-0000-4000-8000-000000000001	Hehehe	Vì sao ngô quyền đánh thắng quân bạch đăng	["Giúp hs ôn tập lịch sử hiệu quả"]	{"stages": [{"id": "context", "type": "CONTEXT", "title": "Bối cảnh lịch sử", "required": true, "activities": [], "nextStageIds": ["evidence"]}, {"id": "evidence", "type": "EVIDENCE", "title": "Điều tra bằng chứng", "required": true, "activities": [], "nextStageIds": ["reconstruction"]}, {"id": "reconstruction", "type": "RECONSTRUCTION", "title": "Tái dựng diễn biến", "required": true, "activities": [], "nextStageIds": ["conclusion"]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Lập luận và kết luận", "required": true, "activities": [], "nextStageIds": []}], "completion": {"requireAllRequiredStages": true}, "schemaVersion": 1}	DRAFT	\N	061585cf-42e9-4312-ab4a-3e02c9ac8e70	061585cf-42e9-4312-ab4a-3e02c9ac8e70	2026-10-24 14:05:27.352018+00	2026-10-24 14:05:27.352018+00	0
c3f5665a-f047-4cf4-b44b-e4e6539fb615	00000000-0000-0000-0000-000000000001	d7a00000-0000-4000-8000-000000000001	a	a	["a"]	{"stages": [{"id": "context", "type": "CONTEXT", "title": "Bối cảnh lịch sử", "required": true, "activities": [], "nextStageIds": ["evidence"]}, {"id": "evidence", "type": "EVIDENCE", "title": "Điều tra bằng chứng", "required": true, "activities": [], "nextStageIds": ["reconstruction"]}, {"id": "reconstruction", "type": "RECONSTRUCTION", "title": "Tái dựng diễn biến", "required": true, "activities": [], "nextStageIds": ["conclusion"]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Lập luận và kết luận", "required": true, "activities": [], "nextStageIds": []}], "completion": {"requireAllRequiredStages": true}, "schemaVersion": 1}	DRAFT	\N	061585cf-42e9-4312-ab4a-3e02c9ac8e70	061585cf-42e9-4312-ab4a-3e02c9ac8e70	2026-10-24 14:15:23.757276+00	2026-10-24 14:15:23.757276+00	0
10000000-0000-0000-0000-000000000003	00000000-0000-0000-0000-000000000003	d7a00000-0000-4000-8000-000000000001	Chiến Tuyến Sông Cầu: Bẻ Gãy Mưu Đồ Xâm Lược Nhà Tống	Nghệ thuật quân sự độc đáo nào đã giúp quân dân nhà Lý đánh bại 10 vạn quân Tống xâm lược?	["Nắm vững bối cảnh chiến trường phòng tuyến sông Như Nguyệt năm 1077", "Phân tích tác dụng của bài thơ thần Nam Quốc Sơn Hà trong chiến tranh tâm lý", "Đánh giá tài thao lược chủ động tấn công để phòng vệ của Thái úy Lý Thường Kiệt"]	{"stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh chiến dịch", "required": true, "activities": [{"id": "read-ly-context", "type": "READ", "config": {"text": "Năm 1077, 10 vạn đại quân Tống do Quách Quỳ chỉ huy tràn vào xâm lược Đại Việt. Thái úy Lý Thường Kiệt đã chủ động lập phòng tuyến kiên cố men bờ nam sông Như Nguyệt (sông Cầu, Bắc Ninh). Tuyến phòng thủ dài hơn 30km, được đắp lũy đất cao, cắm cọc tre dày đặc dưới lòng sông và chiến thuyền cơ động án ngữ, chặn đứng hoàn toàn bước tiến của quân thù trước cửa ngõ kinh thành Thăng Long."}, "required": true, "instruction": "Tìm hiểu phòng tuyến sông Như Nguyệt năm 1077"}], "nextStageIds": ["verify"]}, {"id": "verify", "type": "VERIFICATION", "title": "Nghệ thuật quân sự", "required": true, "activities": [{"id": "mc-ly-tactic", "type": "MULTIPLE_CHOICE", "config": {"options": [{"id": "opt-1", "label": "Chủ động phòng ngự kiên cố, tiêu hao sinh lực địch rồi phản công quyết định kết hợp đòn tâm lý chiến"}, {"id": "opt-2", "label": "Dồn toàn lực tấn công ồ ạt ngay khi quân Tống vừa tới bờ sông"}, {"id": "opt-3", "label": "Rút lui toàn bộ về kinh thành cố thủ chờ quân chi viện"}], "question": "Điểm độc đáo nhất trong nghệ thuật kháng chiến của Lý Thường Kiệt tại sông Như Nguyệt là gì?", "correctOptionIds": ["opt-1"]}, "required": true, "instruction": "Chọn nhận định chính xác về chiến thuật của Lý Thường Kiệt"}], "nextStageIds": ["conclusion"]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Đúc kết bài học", "required": true, "activities": [{"id": "read-ly-conclusion", "type": "READ", "config": {"text": "Chiến thắng Như Nguyệt gắn liền với bài thơ thần Nam quốc sơn hà - bản Tuyên ngôn Độc lập đầu tiên của nước Việt, đập tan ý chí xâm lược của nhà Tống, khẳng định chủ quyền thiêng liêng bất khả xâm phạm."}, "required": true, "instruction": "Ý nghĩa lịch sử của chiến thắng"}], "nextStageIds": []}], "completion": {"requireAllRequiredStages": true}, "schemaVersion": 1}	PUBLISHED	30000000-0000-0000-0000-000000000003	061585cf-42e9-4312-ab4a-3e02c9ac8e70	061585cf-42e9-4312-ab4a-3e02c9ac8e70	2026-10-24 14:32:05.455414+00	2026-10-25 00:56:51.086802+00	0
10000000-0000-0000-0000-000000000004	00000000-0000-0000-0000-000000000004	d7a00000-0000-4000-8000-000000000001	Quyết Định Lịch Sử: Chuyển Phương Châm Tại Điện Biên Phủ	Vì sao Đại tướng Võ Nguyên Giáp quyết định thay đổi phương châm từ Đánh nhanh thắng nhanh sang Đánh chắc tiến chắc?	["Hiểu rõ cấu trúc tập đoàn cứ điểm Điện Biên Phủ của Pháp", "Phân tích nguyên nhân và tầm quan trọng của quyết định chuyển phương châm tác chiến ngày 26/1/1954", "Ý nghĩa chiến thắng Điện Biên Phủ đối với nền độc lập dân tộc"]	{"stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh chiến dịch", "required": true, "activities": [{"id": "read-dbp-context", "type": "READ", "config": {"text": "Tập đoàn cứ điểm Điện Biên Phủ gồm 49 cứ điểm liên hoàn, được thực dân Pháp xây dựng thành pháo đài bất khả xâm phạm. Ban đầu, Bộ chỉ huy chiến dịch dự kiến phương án Đánh nhanh thắng nhanh. Tuy nhiên, sau khi trực tiếp thị sát trận địa và nhận thấy địch đã gia cố công sự kiên cố, đêm 25 rạng sáng 26/1/1954, Đại tướng Võ Nguyên Giáp đã đưa ra quyết định lịch sử khó khăn nhất đời mình: Ra lệnh hoãn nổ súng, kéo pháo ra và chuyển sang phương châm Đánh chắc tiến chắc."}, "required": true, "instruction": "Tình hình chiến trường Điện Biên Phủ tháng 1/1954"}], "nextStageIds": ["verify"]}, {"id": "verify", "type": "VERIFICATION", "title": "Phân tích chiến lược", "required": true, "activities": [{"id": "mc-dbp-decision", "type": "MULTIPLE_CHOICE", "config": {"options": [{"id": "opt-1", "label": "Giúp bộ đội đào chiến hào siết chặt vòng vây, bóc dỡ từng cứ điểm và triệt tiêu ưu thế không quân, pháo binh địch"}, {"id": "opt-2", "label": "Kéo dài thời gian để chờ quân tiếp viện từ đồng minh"}, {"id": "opt-3", "label": "Nhằm mục đích rút bớt quân chủ lực về bảo vệ đồng bằng Bắc Bộ"}], "question": "Vì sao phương châm 'Đánh chắc, tiến chắc' là chìa khóa mở ra chiến thắng Điện Biên Phủ?", "correctOptionIds": ["opt-1"]}, "required": true, "instruction": "Đánh giá về quyết định chuyển phương châm tác chiến"}], "nextStageIds": ["conclusion"]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Tổng kết chiến thắng", "required": true, "activities": [{"id": "read-dbp-conclusion", "type": "READ", "config": {"text": "Sau 56 ngày đêm khoét núi, ngủ hầm, mưa dầm, cơm vắt, ngày 7/5/1954 lá cờ Quyết chiến Quyết thắng tung bay trên nóc hầm De Castries. Chiến thắng Điện Biên Phủ lừng lẫy năm châu, chấn động địa cầu đã buộc Pháp phải ký Hiệp định Genève chấm dứt chiến tranh tại Đông Dương."}, "required": true, "instruction": "Tầm vóc thời đại của chiến thắng Điện Biên Phủ"}], "nextStageIds": []}], "completion": {"requireAllRequiredStages": true}, "schemaVersion": 1}	PUBLISHED	30000000-0000-0000-0000-000000000004	061585cf-42e9-4312-ab4a-3e02c9ac8e70	061585cf-42e9-4312-ab4a-3e02c9ac8e70	2026-10-24 14:32:05.455414+00	2026-10-25 00:56:51.089294+00	0
10000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000002	d7a00000-0000-4000-8000-000000000001	Tiếng Trống Mê Linh: Nguyên Nhân và Sức Mạnh Khởi Nghĩa	Vì sao cuộc khởi nghĩa của Hai Bà Trưng được đông đảo nhân dân và các Lạc tướng khắp 65 thành trì hưởng ứng?	["Hiểu rõ nguyên nhân sâu xa và trực tiếp của khởi nghĩa Mê Linh", "Phân tích lời thề Hát Môn và tinh thần bất khuất của phụ nữ Việt Nam", "Ý nghĩa lịch sử mở đầu trang sử đấu tranh chống Bắc thuộc"]	{"stages": [{"id": "ctx", "type": "CONTEXT", "title": "Bối cảnh lịch sử", "required": true, "activities": [{"id": "read-hbt-context", "type": "READ", "config": {"text": "Đầu thế kỷ 1, nhà Đông Hán tăng cường đồng hóa và bóc lột hà khắc nhân dân Lạc Việt. Thái thú Tô Định nổi tiếng tham lam, tàn bạo. Khi Thi Sách (chồng bà Trưng Trắc) bị sát hại nhằm răn đe các thủ lĩnh người Việt, Trưng Trắc cùng em gái là Trưng Nhị đã phất cờ khởi nghĩa tại cửa sông Hát với 4 câu thề bất hủ:\\n\\nMột xin rửa sạch quốc thù,\\nHai xin đem lại nghiệp xưa họ Hùng,\\nBa kẻo oan ức lòng chồng,\\nBốn xin vẹn vẹn sở công lênh này.\\n\\nKhởi nghĩa bùng nổ, các quận Giao Chỉ, Cửu Chân, Nhật Nam đều đồng lòng hưởng ứng."}, "required": true, "instruction": "Đọc tư liệu về ách cai trị của Thái thú Tô Định và Lời thề Hát Môn"}], "nextStageIds": ["verify"]}, {"id": "verify", "type": "VERIFICATION", "title": "Điều tra chứng cứ & Đánh giá", "required": true, "activities": [{"id": "mc-hbt-cause", "type": "MULTIPLE_CHOICE", "config": {"options": [{"id": "opt-1", "label": "Giành lại quyền tự chủ cho dân tộc và phục hưng cơ nghiệp các vua Hùng"}, {"id": "opt-2", "label": "Chỉ thuần túy là trả thù riêng cho chồng là Thi Sách"}, {"id": "opt-3", "label": "Mong muốn được triều đình Hán phong thưởng tước vị"}], "question": "Mục tiêu lớn nhất và bao trùm của cuộc khởi nghĩa Hai Bà Trưng là gì?", "correctOptionIds": ["opt-1"]}, "required": true, "instruction": "Chọn nhận định đúng nhất về động lực khởi nghĩa"}], "nextStageIds": ["conclusion"]}, {"id": "conclusion", "type": "CONCLUSION", "title": "Ý nghĩa lịch sử", "required": true, "activities": [{"id": "read-hbt-conclusion", "type": "READ", "config": {"text": "Khởi nghĩa Hai Bà Trưng là trang sử oanh liệt đầu tiên khẳng định ý chí độc lập, bất khuất của dân tộc Việt Nam, mở đầu cho truyền thống quật cường chống ngoại xâm của nhân dân ta."}, "required": true, "instruction": "Đúc kết bài học lịch sử"}], "nextStageIds": []}], "completion": {"requireAllRequiredStages": true}, "schemaVersion": 1}	PUBLISHED	30000000-0000-0000-0000-000000000002	061585cf-42e9-4312-ab4a-3e02c9ac8e70	061585cf-42e9-4312-ab4a-3e02c9ac8e70	2026-10-24 14:32:05.455414+00	2026-10-25 00:56:51.083599+00	0
\.


--
-- Data for Name: map_locations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.map_locations (id, event_id, title, description, latitude, longitude, unlock_lesson_id, display_order, status, created_at, updated_at, row_version, published_at) FROM stdin;
a0000000-0000-0000-0000-000000000001	00000000-0000-0000-0000-000000000005	Khu di tích Đền Hùng	Núi Nghĩa Lĩnh, Phong Châu — nơi hội tụ linh khí non sông, nơi phụng thờ 18 đời Hùng Vương mở cõi dựng nước.	21.3653	105.3262	\N	1	PUBLISHED	2026-10-24 19:37:56.778289+00	2026-10-24 19:37:56.778289+00	0	2026-10-25 00:56:51.092307+00
a0000000-0000-0000-0000-000000000002	00000000-0000-0000-0000-000000000005	Làng Cổ Văn Lang & Ngã Ba Hạc	Nơi hợp lưu của ba con sông lớn sông Hồng, sông Lô và sông Đà — cái nôi của nền văn minh lúa nước và văn hóa Đông Sơn.	21.3121	105.4215	\N	2	PUBLISHED	2026-10-24 19:37:56.778289+00	2026-10-24 19:37:56.778289+00	0	2026-10-25 00:56:51.092307+00
a0000000-0000-0000-0000-000000000003	00000000-0000-0000-0000-000000000001	Bến Bạch Đằng - Trận Địa Cọc	Cửa sông Bạch Đằng lịch sử — nơi Ngô Quyền cắm cọc vạt nhọn bọc sắt tiêu diệt hạm đội thuyền giặc Nam Hán năm 938.	20.8492	106.6891	\N	1	PUBLISHED	2026-10-24 19:37:56.778289+00	2026-10-24 19:37:56.778289+00	0	2026-10-25 00:56:51.092307+00
a0000000-0000-0000-0000-000000000004	00000000-0000-0000-0000-000000000001	Bãi Cọc Yên Giang (Quảng Yên)	Chứng tích những thân gỗ lim cắm sâu lòng sông ngầm, biểu tượng mưu trí và sức mạnh quật cường của quân dân Việt.	20.9324	106.8123	\N	2	PUBLISHED	2026-10-24 19:37:56.778289+00	2026-10-24 19:37:56.778289+00	0	2026-10-25 00:56:51.092307+00
a0000000-0000-0000-0000-000000000005	00000000-0000-0000-0000-000000000001	Cửa Sông Nam Triệu	Cửa ngõ huyết mạch dẫn từ biển vào Bạch Đằng giang, nơi giặc lọt vào thế trận mai phục khi thủy triều rút kiệt.	20.7801	106.7902	\N	3	PUBLISHED	2026-10-24 19:37:56.778289+00	2026-10-24 19:37:56.778289+00	0	2026-10-25 00:56:51.092307+00
a0000000-0000-0000-0000-000000000006	00000000-0000-0000-0000-000000000002	Cửa Sông Hát (Hát Môn)	Nơi Hai Bà Trưng tế cờ khởi nghĩa mùa xuân năm 40, truyền vang lời thề cứu nước cứu dân đuổi quân đô hộ Đông Hán.	21.1452	105.5801	10000000-0000-0000-0000-000000000002	1	PUBLISHED	2026-10-24 19:37:56.778289+00	2026-10-24 19:37:56.778289+00	0	2026-10-25 00:56:51.092307+00
a0000000-0000-0000-0000-000000000007	00000000-0000-0000-0000-000000000002	Thành Cổ Mê Linh	Trung tâm chỉ huy nghĩa quân và kinh đô sau khi Trưng Nữ Vương xưng vương, giành lại 65 thành trì Lĩnh Ngoại.	21.1804	105.7103	\N	2	PUBLISHED	2026-10-24 19:37:56.778289+00	2026-10-24 19:37:56.778289+00	0	2026-10-25 00:56:51.092307+00
a0000000-0000-0000-0000-000000000008	00000000-0000-0000-0000-000000000003	Phòng Tuyến Sông Cầu	Phòng tuyến hiểm trở dài hàng trăm dặm do Lý Thường Kiệt đắp luỹ cắm chông chặn đứng 30 vạn quân Tống xâm lược.	21.2175	106.0024	10000000-0000-0000-0000-000000000003	1	PUBLISHED	2026-10-24 19:37:56.778289+00	2026-10-24 19:37:56.778289+00	0	2026-10-25 00:56:51.092307+00
a0000000-0000-0000-0000-000000000009	00000000-0000-0000-0000-000000000003	Đền Xà - Bài Thơ Thần	Bản tuyên ngôn độc lập đầu tiên Nam Quốc Sơn Hà ngân vang giữa đêm trăng làm rung chuyển ý chí quân xâm lược.	21.2051	106.0182	\N	2	PUBLISHED	2026-10-24 19:37:56.778289+00	2026-10-24 19:37:56.778289+00	0	2026-10-25 00:56:51.092307+00
a0000000-0000-0000-0000-000000000010	00000000-0000-0000-0000-000000000004	Cứ Điểm Đồi A1 (Eliane 2)	Trận địa đẫm máu then chốt bảo vệ trung tâm Mường Thanh, ngọn đồi quyết định cục diện chiến trường Điện Biên Phủ.	21.3854	103.0185	10000000-0000-0000-0000-000000000004	1	PUBLISHED	2026-10-24 19:37:56.778289+00	2026-10-24 19:37:56.778289+00	0	2026-10-25 00:56:51.092307+00
a0000000-0000-0000-0000-000000000011	00000000-0000-0000-0000-000000000004	Hầm Tướng De Castries	Nơi cờ quyết chiến quyết thắng tung bay vào chiều ngày 7/5/1954, kết thúc 56 ngày đêm chấn động địa cầu.	21.3882	103.0151	\N	2	PUBLISHED	2026-10-24 19:37:56.778289+00	2026-10-24 19:37:56.778289+00	0	2026-10-25 00:56:51.092307+00
\.


--
-- Data for Name: reward_transactions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.reward_transactions (id, user_id, learner_attempt_id, reward_type, amount, reason, cause_key, created_at) FROM stdin;
f806ad0e-acd0-441a-b98b-51b29a57943b	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	b29f88c1-0f90-41ef-a833-ff1cf8a98dea	EXP	100	Hoàn thành lần đầu một bài học	LESSON_FIRST_COMPLETE:373c2afd-9dc6-44ed-b4a9-accaf2fa0422:10000000-0000-0000-0000-000000000002:EXP	2026-10-24 15:00:24.666651+00
b0a891bd-120c-4c61-ad4f-763e32badfc4	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	b29f88c1-0f90-41ef-a833-ff1cf8a98dea	HISTORY_POINTS	50	Hoàn thành lần đầu một bài học	LESSON_FIRST_COMPLETE:373c2afd-9dc6-44ed-b4a9-accaf2fa0422:10000000-0000-0000-0000-000000000002:HISTORY_POINTS	2026-10-24 15:00:24.666651+00
8348696a-9991-4e1d-b15c-69237759790c	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	0349305f-568e-4ee2-9299-0a49d109f4ef	EXP	100	Hoàn thành lần đầu một bài học	LESSON_FIRST_COMPLETE:373c2afd-9dc6-44ed-b4a9-accaf2fa0422:10000000-0000-0000-0000-000000000004:EXP	2026-10-24 21:06:47.751681+00
85971fc2-5faf-43e9-b42e-d2828714eac2	373c2afd-9dc6-44ed-b4a9-accaf2fa0422	0349305f-568e-4ee2-9299-0a49d109f4ef	HISTORY_POINTS	50	Hoàn thành lần đầu một bài học	LESSON_FIRST_COMPLETE:373c2afd-9dc6-44ed-b4a9-accaf2fa0422:10000000-0000-0000-0000-000000000004:HISTORY_POINTS	2026-10-24 21:06:47.751681+00
\.


--
-- Data for Name: user_evidence; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_evidence (id, user_id, learner_attempt_id, evidence_id, collected_at, snapshot_json, evidence_type, event_id) FROM stdin;
\.


--
-- Data for Name: user_inventory; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.user_inventory (id, user_id, item_id, acquired_at, acquisition_source, source_lesson_id, source_attempt_id) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (id, email, password_hash, display_name, role, status, email_verified_at, last_login_at, created_at, updated_at, row_version) FROM stdin;
00000000-0000-4000-8000-000000000001	system@dauviet.local	!locked!	Dấu Việt System	CONTENT_ADMIN	DISABLED	\N	\N	2026-10-24 13:08:01.670146+00	2026-10-24 13:08:01.670146+00	0
061585cf-42e9-4312-ab4a-3e02c9ac8e70	admin@dauviet.local	$2a$10$l7LPoQje1.91IDcWNJ7HLu/jvf2n7JVKn10O5BX5Y7foXkgiNrOq6	Admin Dau Viet	CONTENT_ADMIN	ACTIVE	\N	2026-10-24 14:03:50.603203+00	2026-10-24 13:22:25.27756+00	2026-10-24 14:03:50.673782+00	2
fc8ba421-c0fe-4feb-a401-01d253822269	testexplorer@dauviet.vn	$2a$10$.TzU5pUmoDOMznDY0hlsvO14t0SjhSujs77jLU7OFQK8FVr2QCZA6	NguoiKhamPha	LEARNER	ACTIVE	\N	2026-10-24 19:38:13.582085+00	2026-10-24 19:38:07.825647+00	2026-10-24 19:38:13.596388+00	1
373c2afd-9dc6-44ed-b4a9-accaf2fa0422	learner@dauviet.vn	$2a$10$4hQH4ppMts6QkRJ3SKwLFeo030sT4ZHcDk5Q.icRuUrhCAPHooNry	Hoc Vien	LEARNER	ACTIVE	\N	2026-10-25 00:44:38.802423+00	2026-10-24 13:24:39.337729+00	2026-10-25 00:44:38.859425+00	24
\.


--
-- Name: activity_attempts activity_attempts_learner_attempt_id_activity_id_attempt_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_attempts
    ADD CONSTRAINT activity_attempts_learner_attempt_id_activity_id_attempt_no_key UNIQUE (learner_attempt_id, activity_id, attempt_no);


--
-- Name: activity_attempts activity_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_attempts
    ADD CONSTRAINT activity_attempts_pkey PRIMARY KEY (id);


--
-- Name: animation_scene_asset_refs animation_scene_asset_refs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scene_asset_refs
    ADD CONSTRAINT animation_scene_asset_refs_pkey PRIMARY KEY (scene_version_id, asset_id, role);


--
-- Name: animation_scene_html animation_scene_html_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scene_html
    ADD CONSTRAINT animation_scene_html_pkey PRIMARY KEY (scene_id);


--
-- Name: animation_scene_version_html animation_scene_version_html_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scene_version_html
    ADD CONSTRAINT animation_scene_version_html_pkey PRIMARY KEY (version_id);


--
-- Name: animation_scene_versions animation_scene_versions_id_scene_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scene_versions
    ADD CONSTRAINT animation_scene_versions_id_scene_id_key UNIQUE (id, scene_id);


--
-- Name: animation_scene_versions animation_scene_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scene_versions
    ADD CONSTRAINT animation_scene_versions_pkey PRIMARY KEY (id);


--
-- Name: animation_scene_versions animation_scene_versions_scene_id_version_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scene_versions
    ADD CONSTRAINT animation_scene_versions_scene_id_version_no_key UNIQUE (scene_id, version_no);


--
-- Name: animation_scenes animation_scenes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scenes
    ADD CONSTRAINT animation_scenes_pkey PRIMARY KEY (id);


--
-- Name: animation_templates animation_templates_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_templates
    ADD CONSTRAINT animation_templates_code_key UNIQUE (code);


--
-- Name: animation_templates animation_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_templates
    ADD CONSTRAINT animation_templates_pkey PRIMARY KEY (id);


--
-- Name: assets assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_pkey PRIMARY KEY (id);


--
-- Name: assets assets_storage_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_storage_key_key UNIQUE (storage_key);


--
-- Name: auth_refresh_tokens auth_refresh_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_refresh_tokens
    ADD CONSTRAINT auth_refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: auth_refresh_tokens auth_refresh_tokens_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_refresh_tokens
    ADD CONSTRAINT auth_refresh_tokens_token_hash_key UNIQUE (token_hash);


--
-- Name: evidences evidences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidences
    ADD CONSTRAINT evidences_pkey PRIMARY KEY (id);


--
-- Name: flyway_schema_history flyway_schema_history_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flyway_schema_history
    ADD CONSTRAINT flyway_schema_history_pk PRIMARY KEY (installed_rank);


--
-- Name: historical_events historical_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.historical_events
    ADD CONSTRAINT historical_events_pkey PRIMARY KEY (id);


--
-- Name: idempotency_records idempotency_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idempotency_records
    ADD CONSTRAINT idempotency_records_pkey PRIMARY KEY (id);


--
-- Name: idempotency_records idempotency_records_user_id_operation_idempotency_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idempotency_records
    ADD CONSTRAINT idempotency_records_user_id_operation_idempotency_key_key UNIQUE (user_id, operation, idempotency_key);


--
-- Name: item_catalog item_catalog_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_catalog
    ADD CONSTRAINT item_catalog_code_key UNIQUE (code);


--
-- Name: item_catalog item_catalog_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_catalog
    ADD CONSTRAINT item_catalog_pkey PRIMARY KEY (id);


--
-- Name: item_unlock_rule item_unlock_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_unlock_rule
    ADD CONSTRAINT item_unlock_rule_pkey PRIMARY KEY (id);


--
-- Name: learner_attempts learner_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learner_attempts
    ADD CONSTRAINT learner_attempts_pkey PRIMARY KEY (id);


--
-- Name: lesson_results lesson_results_learner_attempt_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_results
    ADD CONSTRAINT lesson_results_learner_attempt_id_key UNIQUE (learner_attempt_id);


--
-- Name: lesson_results lesson_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_results
    ADD CONSTRAINT lesson_results_pkey PRIMARY KEY (id);


--
-- Name: lesson_templates lesson_templates_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_templates
    ADD CONSTRAINT lesson_templates_code_key UNIQUE (code);


--
-- Name: lesson_templates lesson_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_templates
    ADD CONSTRAINT lesson_templates_pkey PRIMARY KEY (id);


--
-- Name: lesson_versions lesson_versions_id_lesson_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_versions
    ADD CONSTRAINT lesson_versions_id_lesson_id_key UNIQUE (id, lesson_id);


--
-- Name: lesson_versions lesson_versions_lesson_id_version_no_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_versions
    ADD CONSTRAINT lesson_versions_lesson_id_version_no_key UNIQUE (lesson_id, version_no);


--
-- Name: lesson_versions lesson_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_versions
    ADD CONSTRAINT lesson_versions_pkey PRIMARY KEY (id);


--
-- Name: lessons lessons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lessons
    ADD CONSTRAINT lessons_pkey PRIMARY KEY (id);


--
-- Name: map_locations map_locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_locations
    ADD CONSTRAINT map_locations_pkey PRIMARY KEY (id);


--
-- Name: reward_transactions reward_transactions_cause_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reward_transactions
    ADD CONSTRAINT reward_transactions_cause_key_key UNIQUE (cause_key);


--
-- Name: reward_transactions reward_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reward_transactions
    ADD CONSTRAINT reward_transactions_pkey PRIMARY KEY (id);


--
-- Name: user_evidence user_evidence_learner_attempt_id_evidence_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_evidence
    ADD CONSTRAINT user_evidence_learner_attempt_id_evidence_id_key UNIQUE (learner_attempt_id, evidence_id);


--
-- Name: user_evidence user_evidence_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_evidence
    ADD CONSTRAINT user_evidence_pkey PRIMARY KEY (id);


--
-- Name: user_inventory user_inventory_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_inventory
    ADD CONSTRAINT user_inventory_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: lessons ux_lessons_event_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lessons
    ADD CONSTRAINT ux_lessons_event_id UNIQUE (event_id, id);


--
-- Name: user_inventory ux_user_inventory; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_inventory
    ADD CONSTRAINT ux_user_inventory UNIQUE (user_id, item_id);


--
-- Name: flyway_schema_history_s_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX flyway_schema_history_s_idx ON public.flyway_schema_history USING btree (success);


--
-- Name: idx_activity_attempt_history; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activity_attempt_history ON public.activity_attempts USING btree (learner_attempt_id, activity_id, created_at);


--
-- Name: idx_anim_asset_refs_asset; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_anim_asset_refs_asset ON public.animation_scene_asset_refs USING btree (asset_id);


--
-- Name: idx_anim_version_scene_published; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_anim_version_scene_published ON public.animation_scene_versions USING btree (scene_id, published_at DESC);


--
-- Name: idx_animation_scenes_event_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_animation_scenes_event_status ON public.animation_scenes USING btree (event_id, status);


--
-- Name: idx_animation_scenes_template; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_animation_scenes_template ON public.animation_scenes USING btree (template_id);


--
-- Name: idx_animation_tpl_renderer; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_animation_tpl_renderer ON public.animation_templates USING btree (renderer_code, enabled);


--
-- Name: idx_assets_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_assets_state ON public.assets USING btree (state);


--
-- Name: idx_attempt_user_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attempt_user_status ON public.learner_attempts USING btree (user_id, status);


--
-- Name: idx_attempt_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attempt_version ON public.learner_attempts USING btree (lesson_version_id);


--
-- Name: idx_evidence_asset; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_evidence_asset ON public.evidences USING btree (asset_id);


--
-- Name: idx_evidence_event_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_evidence_event_status ON public.evidences USING btree (event_id, status);


--
-- Name: idx_historical_events_published_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_historical_events_published_year ON public.historical_events USING btree (start_year) WHERE ((status)::text = 'PUBLISHED'::text);


--
-- Name: idx_historical_events_start_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_historical_events_start_year ON public.historical_events USING btree (start_year);


--
-- Name: idx_historical_events_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_historical_events_status ON public.historical_events USING btree (status);


--
-- Name: idx_idempotency_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_idempotency_expiry ON public.idempotency_records USING btree (expires_at);


--
-- Name: idx_item_catalog_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_catalog_active ON public.item_catalog USING btree (active) WHERE active;


--
-- Name: idx_item_unlock_rule_lesson; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_unlock_rule_lesson ON public.item_unlock_rule USING btree (lesson_id) WHERE (lesson_id IS NOT NULL);


--
-- Name: idx_lessons_event_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lessons_event_status ON public.lessons USING btree (event_id, status);


--
-- Name: idx_lessons_template; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lessons_template ON public.lessons USING btree (template_id);


--
-- Name: idx_map_locations_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_map_locations_event ON public.map_locations USING btree (event_id, status, display_order);


--
-- Name: idx_map_locations_unlock_lesson; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_map_locations_unlock_lesson ON public.map_locations USING btree (unlock_lesson_id);


--
-- Name: idx_refresh_active_expiry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refresh_active_expiry ON public.auth_refresh_tokens USING btree (expires_at) WHERE (revoked_at IS NULL);


--
-- Name: idx_refresh_family; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refresh_family ON public.auth_refresh_tokens USING btree (token_family_id);


--
-- Name: idx_refresh_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refresh_user ON public.auth_refresh_tokens USING btree (user_id);


--
-- Name: idx_reward_attempt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reward_attempt ON public.reward_transactions USING btree (learner_attempt_id);


--
-- Name: idx_reward_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reward_user_created ON public.reward_transactions USING btree (user_id, created_at DESC);


--
-- Name: idx_user_evidence_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_evidence_user ON public.user_evidence USING btree (user_id, collected_at DESC);


--
-- Name: idx_user_evidence_user_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_evidence_user_event ON public.user_evidence USING btree (user_id, event_id);


--
-- Name: idx_user_inventory_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_inventory_user ON public.user_inventory USING btree (user_id, acquired_at DESC);


--
-- Name: idx_users_role_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_role_status ON public.users USING btree (role, status);


--
-- Name: idx_version_lesson_published; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_version_lesson_published ON public.lesson_versions USING btree (lesson_id, published_at DESC);


--
-- Name: ux_attempt_active_user_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_attempt_active_user_version ON public.learner_attempts USING btree (user_id, lesson_version_id) WHERE ((status)::text = 'IN_PROGRESS'::text);


--
-- Name: ux_historical_events_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_historical_events_slug ON public.historical_events USING btree (slug);


--
-- Name: ux_item_unlock_rule_item; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_item_unlock_rule_item ON public.item_unlock_rule USING btree (item_id) WHERE active;


--
-- Name: ux_user_evidence_user_evidence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_user_evidence_user_evidence ON public.user_evidence USING btree (user_id, evidence_id);


--
-- Name: ux_users_email_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX ux_users_email_lower ON public.users USING btree (lower((email)::text));


--
-- Name: animation_scene_version_html trg_animation_scene_version_html_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_animation_scene_version_html_immutable BEFORE DELETE OR UPDATE ON public.animation_scene_version_html FOR EACH ROW EXECUTE FUNCTION public.prevent_animation_scene_version_html_mutation();


--
-- Name: animation_scene_versions trg_animation_scene_versions_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_animation_scene_versions_immutable BEFORE DELETE OR UPDATE ON public.animation_scene_versions FOR EACH ROW EXECUTE FUNCTION public.prevent_animation_scene_version_mutation();


--
-- Name: lesson_versions trg_lesson_versions_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_lesson_versions_immutable BEFORE DELETE OR UPDATE ON public.lesson_versions FOR EACH ROW EXECUTE FUNCTION public.prevent_lesson_version_mutation();


--
-- Name: activity_attempts activity_attempts_learner_attempt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_attempts
    ADD CONSTRAINT activity_attempts_learner_attempt_id_fkey FOREIGN KEY (learner_attempt_id) REFERENCES public.learner_attempts(id);


--
-- Name: animation_scene_asset_refs animation_scene_asset_refs_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scene_asset_refs
    ADD CONSTRAINT animation_scene_asset_refs_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.assets(id);


--
-- Name: animation_scene_asset_refs animation_scene_asset_refs_scene_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scene_asset_refs
    ADD CONSTRAINT animation_scene_asset_refs_scene_version_id_fkey FOREIGN KEY (scene_version_id) REFERENCES public.animation_scene_versions(id);


--
-- Name: animation_scene_html animation_scene_html_scene_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scene_html
    ADD CONSTRAINT animation_scene_html_scene_id_fkey FOREIGN KEY (scene_id) REFERENCES public.animation_scenes(id) ON DELETE CASCADE;


--
-- Name: animation_scene_version_html animation_scene_version_html_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scene_version_html
    ADD CONSTRAINT animation_scene_version_html_version_id_fkey FOREIGN KEY (version_id) REFERENCES public.animation_scene_versions(id) ON DELETE RESTRICT;


--
-- Name: animation_scene_versions animation_scene_versions_published_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scene_versions
    ADD CONSTRAINT animation_scene_versions_published_by_fkey FOREIGN KEY (published_by) REFERENCES public.users(id);


--
-- Name: animation_scene_versions animation_scene_versions_scene_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scene_versions
    ADD CONSTRAINT animation_scene_versions_scene_id_fkey FOREIGN KEY (scene_id) REFERENCES public.animation_scenes(id);


--
-- Name: animation_scenes animation_scenes_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scenes
    ADD CONSTRAINT animation_scenes_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: animation_scenes animation_scenes_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scenes
    ADD CONSTRAINT animation_scenes_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.historical_events(id);


--
-- Name: animation_scenes animation_scenes_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scenes
    ADD CONSTRAINT animation_scenes_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.animation_templates(id);


--
-- Name: animation_scenes animation_scenes_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scenes
    ADD CONSTRAINT animation_scenes_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: animation_templates animation_templates_thumbnail_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_templates
    ADD CONSTRAINT animation_templates_thumbnail_asset_id_fkey FOREIGN KEY (thumbnail_asset_id) REFERENCES public.assets(id);


--
-- Name: assets assets_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: auth_refresh_tokens auth_refresh_tokens_previous_token_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_refresh_tokens
    ADD CONSTRAINT auth_refresh_tokens_previous_token_id_fkey FOREIGN KEY (previous_token_id) REFERENCES public.auth_refresh_tokens(id);


--
-- Name: auth_refresh_tokens auth_refresh_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_refresh_tokens
    ADD CONSTRAINT auth_refresh_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: evidences evidences_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidences
    ADD CONSTRAINT evidences_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.assets(id);


--
-- Name: evidences evidences_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidences
    ADD CONSTRAINT evidences_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: evidences evidences_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidences
    ADD CONSTRAINT evidences_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.historical_events(id);


--
-- Name: animation_scenes fk_anim_scenes_current_own_version; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.animation_scenes
    ADD CONSTRAINT fk_anim_scenes_current_own_version FOREIGN KEY (current_version_id, id) REFERENCES public.animation_scene_versions(id, scene_id) DEFERRABLE;


--
-- Name: lessons fk_lessons_current_own_version; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lessons
    ADD CONSTRAINT fk_lessons_current_own_version FOREIGN KEY (current_version_id, id) REFERENCES public.lesson_versions(id, lesson_id) DEFERRABLE;


--
-- Name: map_locations fk_map_location_unlock_lesson_same_event; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_locations
    ADD CONSTRAINT fk_map_location_unlock_lesson_same_event FOREIGN KEY (event_id, unlock_lesson_id) REFERENCES public.lessons(event_id, id);


--
-- Name: idempotency_records idempotency_records_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.idempotency_records
    ADD CONSTRAINT idempotency_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: item_catalog item_catalog_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_catalog
    ADD CONSTRAINT item_catalog_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.assets(id);


--
-- Name: item_unlock_rule item_unlock_rule_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_unlock_rule
    ADD CONSTRAINT item_unlock_rule_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item_catalog(id);


--
-- Name: item_unlock_rule item_unlock_rule_lesson_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_unlock_rule
    ADD CONSTRAINT item_unlock_rule_lesson_id_fkey FOREIGN KEY (lesson_id) REFERENCES public.lessons(id);


--
-- Name: learner_attempts learner_attempts_lesson_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learner_attempts
    ADD CONSTRAINT learner_attempts_lesson_version_id_fkey FOREIGN KEY (lesson_version_id) REFERENCES public.lesson_versions(id);


--
-- Name: learner_attempts learner_attempts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.learner_attempts
    ADD CONSTRAINT learner_attempts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: lesson_results lesson_results_learner_attempt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_results
    ADD CONSTRAINT lesson_results_learner_attempt_id_fkey FOREIGN KEY (learner_attempt_id) REFERENCES public.learner_attempts(id);


--
-- Name: lesson_versions lesson_versions_lesson_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_versions
    ADD CONSTRAINT lesson_versions_lesson_id_fkey FOREIGN KEY (lesson_id) REFERENCES public.lessons(id);


--
-- Name: lesson_versions lesson_versions_published_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lesson_versions
    ADD CONSTRAINT lesson_versions_published_by_fkey FOREIGN KEY (published_by) REFERENCES public.users(id);


--
-- Name: lessons lessons_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lessons
    ADD CONSTRAINT lessons_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id);


--
-- Name: lessons lessons_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lessons
    ADD CONSTRAINT lessons_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.historical_events(id);


--
-- Name: lessons lessons_template_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lessons
    ADD CONSTRAINT lessons_template_id_fkey FOREIGN KEY (template_id) REFERENCES public.lesson_templates(id);


--
-- Name: lessons lessons_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lessons
    ADD CONSTRAINT lessons_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id);


--
-- Name: map_locations map_locations_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_locations
    ADD CONSTRAINT map_locations_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.historical_events(id);


--
-- Name: map_locations map_locations_unlock_lesson_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_locations
    ADD CONSTRAINT map_locations_unlock_lesson_id_fkey FOREIGN KEY (unlock_lesson_id) REFERENCES public.lessons(id);


--
-- Name: reward_transactions reward_transactions_learner_attempt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reward_transactions
    ADD CONSTRAINT reward_transactions_learner_attempt_id_fkey FOREIGN KEY (learner_attempt_id) REFERENCES public.learner_attempts(id);


--
-- Name: reward_transactions reward_transactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reward_transactions
    ADD CONSTRAINT reward_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_evidence user_evidence_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_evidence
    ADD CONSTRAINT user_evidence_event_id_fkey FOREIGN KEY (event_id) REFERENCES public.historical_events(id);


--
-- Name: user_evidence user_evidence_evidence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_evidence
    ADD CONSTRAINT user_evidence_evidence_id_fkey FOREIGN KEY (evidence_id) REFERENCES public.evidences(id);


--
-- Name: user_evidence user_evidence_learner_attempt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_evidence
    ADD CONSTRAINT user_evidence_learner_attempt_id_fkey FOREIGN KEY (learner_attempt_id) REFERENCES public.learner_attempts(id);


--
-- Name: user_evidence user_evidence_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_evidence
    ADD CONSTRAINT user_evidence_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_inventory user_inventory_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_inventory
    ADD CONSTRAINT user_inventory_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.item_catalog(id);


--
-- Name: user_inventory user_inventory_source_attempt_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_inventory
    ADD CONSTRAINT user_inventory_source_attempt_id_fkey FOREIGN KEY (source_attempt_id) REFERENCES public.learner_attempts(id);


--
-- Name: user_inventory user_inventory_source_lesson_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_inventory
    ADD CONSTRAINT user_inventory_source_lesson_id_fkey FOREIGN KEY (source_lesson_id) REFERENCES public.lessons(id);


--
-- Name: user_inventory user_inventory_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_inventory
    ADD CONSTRAINT user_inventory_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- PostgreSQL database dump complete
--

\unrestrict XvJrgfS4ENlcHLRVfcBumvu1UewAlLBl2b2JL4JqK0kyvWW8LCNCPVU5peBQe9V

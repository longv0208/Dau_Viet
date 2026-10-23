package com.dauviet.animation.manifest;

import java.util.Map;
import java.util.Set;

/**
 * Versioned animation manifest schema — whitelists, bounds and renderer
 * catalogs. A manifest is DATA, never executable code: only whitelisted
 * fields/types/effects/interactions may appear.
 */
public final class AnimationManifestSchema {

    private AnimationManifestSchema() {
    }

    /**
     * Cinematic manifest schema. v2 adds optional top-level keys
     * (camera, tracks, effects, audio, environment); a manifest containing
     * any of them must declare schemaVersion &gt;= 2 (validator enforces).
     * v1 manifests (none of those keys) stay valid forever.
     */
    public static final int CURRENT_SCHEMA_VERSION = 2;

    /** Renderers this backend + the mobile runtime both support. */
    public static final Set<String> RENDERER_CODES = Set.of("RIVER_TIDE", "JOURNEY_MAP");

    /** Whitelisted object types inside manifest.objects[]. */
    public static final Set<String> OBJECT_TYPES = Set.of(
            "STAKE", "BOAT", "DECOY", "MARKER", "LABEL", "ROUTE",
            "BACKGROUND", "LOCATION", "WATER", "TEXT");

    /** Whitelisted easing curves for step transitions. */
    public static final Set<String> EASINGS = Set.of(
            "linear", "easeIn", "easeOut", "easeInOut", "easeInOutCubic");

    /** Whitelisted step effects (purely declarative hints). */
    public static final Set<String> EFFECTS = Set.of(
            "HIGHLIGHT", "PULSE", "SHAKE", "FADE_IN", "FADE_OUT",
            "SHOW_SEQUENCE_SUMMARY", "REVEAL");

    /** Whitelisted learner interactions declared per scene/step. */
    public static final Set<String> INTERACTIONS = Set.of(
            "WATER_LEVEL_CONTROL", "TAP_TO_EXPLORE", "PREDICTION");

    /** Whitelisted playback modes stored on the READ activity config. */
    public static final Set<String> PLAYBACK_MODES = Set.of(
            "AUTO", "STEPPED", "INTERACTIVE");

    /** Asset roles inside manifest.assets[] / asset refs table. */
    public static final Set<String> ASSET_ROLES = Set.of(
            "BACKGROUND", "OBJECT", "THUMBNAIL", "AUDIO", "OVERLAY");

    /** Bounds — defensive limits so a draft can never be pathological. */
    public static final int MAX_MANIFEST_BYTES = 256 * 1024;
    public static final int MAX_DEPTH = 24;
    public static final int MAX_OBJECTS = 200;
    public static final int MAX_STEPS = 60;
    public static final int MAX_LOCATIONS = 100;
    public static final int MAX_ROUTES = 60;
    public static final int MAX_STAKES = 200;
    public static final int MAX_ASSETS = 60;
    public static final int MAX_TEXT = 2_000;
    public static final int MAX_TITLE = 255;
    public static final int MAX_STEP_DURATION_MS = 120_000;
    public static final int MAX_PREDICTION_OPTIONS = 6;

    /** Top-level fields allowed in the manifest document. */
    public static final Set<String> TOP_LEVEL_KEYS = Set.of(
            "schemaVersion", "rendererCode", "rendererVersion", "title",
            "learningObjective", "canvas", "assets", "objects", "initialState",
            "steps", "interactions", "narration", "prediction",
            "sourceReferences", "disclaimer", "river", "map",
            "camera", "tracks", "effects", "audio", "environment");

    /** Keys that mark a manifest as v2 — presence requires schemaVersion >= 2. */
    public static final Set<String> V2_KEYS = Set.of(
            "camera", "tracks", "effects", "audio", "environment");

    /** Whitelisted keyframe-track properties (objects[] / camera targets). */
    public static final Set<String> TRACK_PROPERTIES = Set.of(
            "position", "scale", "rotation", "opacity", "visible");

    /** Whitelisted typed overlay effects (scene-level effects[]). */
    public static final Set<String> EFFECT_TYPES_V2 = Set.of(
            "WATER_RIPPLE", "MIST", "GLOW", "ROUTE_REVEAL",
            "FADE_IN", "FADE_OUT");

    /** Whitelisted audio cue kinds for audio[]. */
    public static final Set<String> AUDIO_CUES = Set.of(
            "ENTER", "EXIT", "LOOP");

    /** Camera bounds — center normalized 0..1, zoom range. */
    public static final double CAMERA_ZOOM_MIN = 0.5;
    public static final double CAMERA_ZOOM_MAX = 3.0;
    public static final double ROTATION_MIN = -360.0;
    public static final double ROTATION_MAX = 360.0;
    public static final int MAX_EFFECT_PARAMS_DEPTH = 4;
    public static final int MAX_TRACKS = 100;
    public static final int MAX_KEYFRAMES_PER_TRACK = 60;
    public static final int MAX_AUDIO_CUES = 40;
    public static final int MAX_SCENE_EFFECTS = 40;

    /** Per-renderer state keys allowed inside initialState / step.targetState. */
    public static final Map<String, Set<String>> STATE_KEYS = Map.of(
            "RIVER_TIDE", Set.of(
                    "waterLevel", "boatProgress", "boatCount", "boatLane",
                    "decoyProgress", "counterattackProgress", "obstructed",
                    "showSequenceSummary", "hasWaterControl", "highlightStakes",
                    "stakeVisibility", "stakeHighlight"),
            "JOURNEY_MAP", Set.of(
                    "markerVisibility", "markerHighlight", "focusedLocationId",
                    "routeProgress", "locationInfoId", "tapToExplore",
                    "schematicDisclaimer"));
}

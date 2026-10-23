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

    public static final int CURRENT_SCHEMA_VERSION = 1;

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
            "sourceReferences", "disclaimer", "river", "map");

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

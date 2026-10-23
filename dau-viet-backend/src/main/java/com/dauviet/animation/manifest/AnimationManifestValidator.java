package com.dauviet.animation.manifest;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;

import org.springframework.stereotype.Component;

import com.dauviet.animation.domain.AnimationExceptions.ManifestFieldError;
import com.dauviet.animation.domain.AnimationTemplate;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.fasterxml.jackson.databind.JsonNode;

import static com.dauviet.animation.manifest.AnimationManifestSchema.*;

/**
 * ~15-point manifest validation. Returns structured {path, code, message}
 * errors — never throws — so /validate probes and /publish share one path.
 * A manifest is whitelisted data only: unknown fields, types, effects and
 * interactions are rejected (no executable or arbitrary payloads).
 */
@Component
public class AnimationManifestValidator {

    private static final Pattern ID_PATTERN =
            Pattern.compile("[a-z0-9][a-z0-9-]{0,63}");

    private final AssetRepository assets;

    public AnimationManifestValidator(AssetRepository assets) {
        this.assets = assets;
    }

    /**
     * Validate `manifest` against `template`. Returns the error list
     * (empty = valid). Persistence lookups are limited to asset state.
     */
    public List<ManifestFieldError> validate(JsonNode manifest, AnimationTemplate template) {
        List<ManifestFieldError> errors = new ArrayList<>();
        if (manifest == null || !manifest.isObject()) {
            errors.add(err("manifest", "INVALID_TYPE", "manifest must be a JSON object"));
            return errors;
        }

        // (1) byte/depth/count bounds — reject pathological documents first.
        String text = manifest.toString();
        if (text.length() > MAX_MANIFEST_BYTES) {
            errors.add(err("manifest", "TOO_LARGE",
                    "manifest exceeds " + MAX_MANIFEST_BYTES + " bytes"));
            return errors;
        }
        if (depth(manifest, 0) > MAX_DEPTH) {
            errors.add(err("manifest", "TOO_DEEP",
                    "manifest nesting exceeds " + MAX_DEPTH));
        }

        // (2) unknown top-level keys — whitelisted schema only.
        for (var it = manifest.fieldNames(); it.hasNext();) {
            String key = it.next();
            if (!TOP_LEVEL_KEYS.contains(key)) {
                errors.add(err("manifest." + key, "UNKNOWN_FIELD",
                        "field '" + key + "' is not part of the manifest schema"));
            }
        }

        // (3) schemaVersion / rendererCode / rendererVersion.
        int schemaVersion = manifest.path("schemaVersion").asInt(-1);
        if (!manifest.hasNonNull("schemaVersion") || schemaVersion < 1) {
            errors.add(err("manifest.schemaVersion", "MISSING_FIELD",
                    "schemaVersion is required (>=1)"));
        } else if (schemaVersion != CURRENT_SCHEMA_VERSION
                && schemaVersion != template.getSchemaVersion()) {
            errors.add(err("manifest.schemaVersion", "UNSUPPORTED_SCHEMA",
                    "unsupported schemaVersion " + schemaVersion));
        }
        String rendererCode = manifest.path("rendererCode").asText(null);
        if (rendererCode == null) {
            errors.add(err("manifest.rendererCode", "MISSING_FIELD",
                    "rendererCode is required"));
        } else if (!RENDERER_CODES.contains(rendererCode)) {
            errors.add(err("manifest.rendererCode", "UNSUPPORTED_RENDERER",
                    "rendererCode '" + rendererCode + "' is not supported"));
        } else if (!rendererCode.equals(template.getRendererCode())) {
            // (4) renderer must match the scene's template.
            errors.add(err("manifest.rendererCode", "RENDERER_MISMATCH",
                    "manifest rendererCode '" + rendererCode
                            + "' does not match template renderer '"
                            + template.getRendererCode() + "'"));
        }
        if (manifest.has("rendererVersion")) {
            int rv = manifest.get("rendererVersion").asInt(0);
            if (rv < 1) {
                errors.add(err("manifest.rendererVersion", "INVALID_VALUE",
                        "rendererVersion must be >= 1"));
            } else if (rv > template.getRendererVersion()) {
                // P1-6 — manifest viết cho renderer mới hơn template hiện
                // có: reject rõ ràng thay vì publish rồi app không đọc được.
                errors.add(err("manifest.rendererVersion", "UNSUPPORTED_VERSION",
                        "rendererVersion " + rv + " exceeds template's "
                                + template.getRendererVersion()));
            }
        }

        // (5) title — required learner-facing label.
        if (text(manifest, "title") == null || text(manifest, "title").isBlank()) {
            errors.add(err("manifest.title", "MISSING_FIELD", "title is required"));
        } else if (text(manifest, "title").length() > MAX_TITLE) {
            errors.add(err("manifest.title", "TOO_LONG",
                    "title exceeds " + MAX_TITLE + " chars"));
        }

        // (6) canvas — optional; when present requires aspect ratio or dims.
        JsonNode canvas = manifest.get("canvas");
        if (canvas != null && canvas.isObject()) {
            JsonNode ar = canvas.get("aspectRatio");
            if (ar != null && (!ar.isNumber() || ar.asDouble() <= 0)) {
                errors.add(err("manifest.canvas.aspectRatio", "INVALID_VALUE",
                        "aspectRatio must be a positive number"));
            }
        }

        // (7) assets[] — {id, assetId, role}, ids unique, assets ACTIVE.
        Set<String> declaredAssetKeys = new LinkedHashSet<>();
        JsonNode assetArr = manifest.get("assets");
        if (assetArr != null && assetArr.isArray()) {
            if (assetArr.size() > MAX_ASSETS) {
                errors.add(err("manifest.assets", "TOO_MANY",
                        "assets exceeds " + MAX_ASSETS));
            }
            for (int i = 0; i < assetArr.size(); i++) {
                JsonNode a = assetArr.get(i);
                String p = "manifest.assets[" + i + "]";
                if (!a.isObject()) {
                    errors.add(err(p, "INVALID_TYPE", "asset entry must be an object"));
                    continue;
                }
                String id = a.path("id").asText(null);
                if (id == null || !ID_PATTERN.matcher(id).matches()) {
                    errors.add(err(p + ".id", "INVALID_ID",
                            "asset id must match " + ID_PATTERN.pattern()));
                } else if (!declaredAssetKeys.add(id)) {
                    errors.add(err(p + ".id", "DUPLICATE_ID", "duplicate asset id '" + id + "'"));
                }
                String assetId = a.path("assetId").asText(null);
                if (assetId == null) {
                    errors.add(err(p + ".assetId", "MISSING_FIELD", "assetId is required"));
                } else {
                    UUID uuid = parseUuid(assetId);
                    if (uuid == null || !assets.existsByIdAndState(uuid, "ACTIVE")) {
                        errors.add(err(p + ".assetId", "ASSET_NOT_FOUND",
                                "asset '" + assetId + "' is not active"));
                    }
                }
                String role = a.path("role").asText("OBJECT");
                if (!ASSET_ROLES.contains(role)) {
                    errors.add(err(p + ".role", "INVALID_VALUE",
                            "role must be one of " + ASSET_ROLES));
                }
            }
        }

        // (8) objects[] — whitelisted types, unique stable ids, normalized pos.
        Set<String> objectIds = new LinkedHashSet<>();
        JsonNode objects = manifest.get("objects");
        if (objects != null && objects.isArray()) {
            if (objects.size() > MAX_OBJECTS) {
                errors.add(err("manifest.objects", "TOO_MANY",
                        "objects exceeds " + MAX_OBJECTS));
            }
            for (int i = 0; i < objects.size(); i++) {
                JsonNode o = objects.get(i);
                String p = "manifest.objects[" + i + "]";
                if (!o.isObject()) {
                    errors.add(err(p, "INVALID_TYPE", "object must be an object"));
                    continue;
                }
                String oid = o.path("id").asText(null);
                if (oid == null || !ID_PATTERN.matcher(oid).matches()) {
                    errors.add(err(p + ".id", "INVALID_ID",
                            "object id must match " + ID_PATTERN.pattern()));
                } else if (!objectIds.add(oid)) {
                    errors.add(err(p + ".id", "DUPLICATE_ID", "duplicate object id '" + oid + "'"));
                }
                String type = o.path("type").asText(null);
                if (type == null || !OBJECT_TYPES.contains(type)) {
                    errors.add(err(p + ".type", "INVALID_TYPE",
                            "type must be one of " + OBJECT_TYPES));
                }
                checkNormalizedPos(o.get("position"), p + ".position", errors);
            }
        }

        // (9) per-renderer required sections + state key whitelist.
        if ("RIVER_TIDE".equals(rendererCode)) {
            validateRiver(manifest, objectIds, errors);
        } else if ("JOURNEY_MAP".equals(rendererCode)) {
            validateMap(manifest, errors);
        }
        checkStateKeys(manifest.get("initialState"), "manifest.initialState",
                rendererCode, errors);

        // (10) steps[] — ids unique, fields bounded, target states whitelisted.
        JsonNode steps = manifest.get("steps");
        if (steps == null || !steps.isArray() || steps.isEmpty()) {
            errors.add(err("manifest.steps", "MISSING_FIELD",
                    "steps must be a non-empty array"));
        } else {
            if (steps.size() > MAX_STEPS) {
                errors.add(err("manifest.steps", "TOO_MANY",
                        "steps exceeds " + MAX_STEPS));
            }
            Set<String> stepIds = new HashSet<>();
            for (int i = 0; i < steps.size(); i++) {
                JsonNode s = steps.get(i);
                String p = "manifest.steps[" + i + "]";
                if (!s.isObject()) {
                    errors.add(err(p, "INVALID_TYPE", "step must be an object"));
                    continue;
                }
                String sid = s.path("id").asText(null);
                if (sid == null || sid.isBlank()) {
                    errors.add(err(p + ".id", "MISSING_FIELD", "step id is required"));
                } else if (!stepIds.add(sid)) {
                    errors.add(err(p + ".id", "DUPLICATE_ID", "duplicate step id '" + sid + "'"));
                }
                if (s.has("durationMs")) {
                    long d = s.get("durationMs").asLong(-1);
                    if (d < 0 || d > MAX_STEP_DURATION_MS) {
                        errors.add(err(p + ".durationMs", "OUT_OF_RANGE",
                                "durationMs must be 0.." + MAX_STEP_DURATION_MS));
                    }
                }
                String easing = s.path("easing").asText(null);
                if (easing != null && !EASINGS.contains(easing)) {
                    errors.add(err(p + ".easing", "INVALID_VALUE",
                            "easing must be one of " + EASINGS));
                }
                JsonNode effects = s.get("effects");
                if (effects != null && effects.isArray()) {
                    for (int j = 0; j < effects.size(); j++) {
                        String e = effects.get(j).asText(null);
                        if (e == null || !EFFECTS.contains(e)) {
                            errors.add(err(p + ".effects[" + j + "]", "INVALID_VALUE",
                                    "effect must be one of " + EFFECTS));
                        }
                    }
                }
                checkStateKeys(s.get("targetState"), p + ".targetState",
                        rendererCode, errors);
                JsonNode inter = s.get("allowedInteractions");
                if (inter != null && inter.isArray()) {
                    for (int j = 0; j < inter.size(); j++) {
                        String it = inter.get(j).asText(null);
                        if (it == null || !INTERACTIONS.contains(it)) {
                            errors.add(err(p + ".allowedInteractions[" + j + "]",
                                    "INVALID_VALUE",
                                    "interaction must be one of " + INTERACTIONS));
                        }
                    }
                }
                checkLen(s, "title", p + ".title", MAX_TEXT, errors);
                checkLen(s, "narration", p + ".narration", MAX_TEXT, errors);
                checkLen(s, "hint", p + ".hint", MAX_TEXT, errors);
            }
        }

        // (11) interactions[] (scene-level) — whitelist.
        JsonNode sceneInter = manifest.get("interactions");
        if (sceneInter != null && sceneInter.isArray()) {
            for (int i = 0; i < sceneInter.size(); i++) {
                String it = sceneInter.get(i).asText(null);
                if (it == null || !INTERACTIONS.contains(it)) {
                    errors.add(err("manifest.interactions[" + i + "]", "INVALID_VALUE",
                            "interaction must be one of " + INTERACTIONS));
                }
            }
        }

        // (12) prediction — when present: question + >=2 options + valid answer idx.
        JsonNode pred = manifest.get("prediction");
        if (pred != null && pred.isObject()) {
            if (text(pred, "question") == null || text(pred, "question").isBlank()) {
                errors.add(err("manifest.prediction.question", "MISSING_FIELD",
                        "prediction.question is required"));
            }
            JsonNode opts = pred.get("options");
            if (opts == null || !opts.isArray() || opts.size() < 2) {
                errors.add(err("manifest.prediction.options", "MISSING_FIELD",
                        "prediction.options must have >= 2 entries"));
            } else {
                if (opts.size() > MAX_PREDICTION_OPTIONS) {
                    errors.add(err("manifest.prediction.options", "TOO_MANY",
                            "options exceeds " + MAX_PREDICTION_OPTIONS));
                }
                int idx = pred.path("explainedOptionIndex").asInt(-1);
                if (idx < 0 || idx >= opts.size()) {
                    errors.add(err("manifest.prediction.explainedOptionIndex",
                            "OUT_OF_RANGE", "explainedOptionIndex must index options"));
                }
            }
        }

        // (13) sourceReferences[] — REQUIRED provenance: every published
        // scene must cite at least one source, each with a title.
        JsonNode refs = manifest.get("sourceReferences");
        if (refs == null || !refs.isArray() || refs.isEmpty()) {
            errors.add(err("manifest.sourceReferences", "MISSING_FIELD",
                    "sourceReferences must list at least one source"));
        } else {
            for (int i = 0; i < refs.size(); i++) {
                JsonNode r = refs.get(i);
                if (!r.isObject() || text(r, "title") == null || text(r, "title").isBlank()) {
                    errors.add(err("manifest.sourceReferences[" + i + "]",
                            "MISSING_FIELD", "source reference requires a title"));
                }
            }
        }

        // (14) disclaimer — required learner-facing honesty note.
        if (text(manifest, "disclaimer") == null || text(manifest, "disclaimer").isBlank()) {
            errors.add(err("manifest.disclaimer", "MISSING_FIELD",
                    "disclaimer is required (schematic/historical-honesty note)"));
        }

        // (15) narration / disclaimer length bounds.
        checkLen(manifest, "narration", "manifest.narration", MAX_TEXT, errors);
        checkLen(manifest, "disclaimer", "manifest.disclaimer", MAX_TEXT, errors);

        return errors;
    }

    /* ---------- RIVER_TIDE ---------- */

    private void validateRiver(JsonNode manifest, Set<String> objectIds,
                               List<ManifestFieldError> errors) {
        JsonNode river = manifest.get("river");
        if (river == null || !river.isObject()) {
            errors.add(err("manifest.river", "MISSING_FIELD",
                    "RIVER_TIDE manifests require a 'river' section"));
            return;
        }
        JsonNode stakes = river.get("stakes");
        if (stakes == null || !stakes.isArray() || stakes.isEmpty()) {
            errors.add(err("manifest.river.stakes", "MISSING_FIELD",
                    "river.stakes must be a non-empty array"));
        } else {
            if (stakes.size() > MAX_STAKES) {
                errors.add(err("manifest.river.stakes", "TOO_MANY",
                        "stakes exceeds " + MAX_STAKES));
            }
            Set<String> stakeIds = new HashSet<>();
            for (int i = 0; i < stakes.size(); i++) {
                JsonNode s = stakes.get(i);
                String p = "manifest.river.stakes[" + i + "]";
                String sid = s.path("id").asText(null);
                if (sid == null || !ID_PATTERN.matcher(sid).matches()) {
                    errors.add(err(p + ".id", "INVALID_ID",
                            "stake id must match " + ID_PATTERN.pattern()));
                } else if (!stakeIds.add(sid)) {
                    errors.add(err(p + ".id", "DUPLICATE_ID",
                            "duplicate stake id '" + sid + "'"));
                }
                check01(s, "x", p + ".x", errors);
                if (!s.has("length") || !s.get("length").isNumber()
                        || s.get("length").asDouble() <= 0) {
                    errors.add(err(p + ".length", "INVALID_VALUE",
                            "stake length must be a positive number"));
                }
            }
        }
        // RIVER numeric bounds in initialState / step.targetState —
        // water/boat/decoy/counterattack progress are normalized 0..1.
        checkRiverState(manifest.get("initialState"), "manifest.initialState",
                stakeIdSet(stakes), errors);
        JsonNode steps = manifest.get("steps");
        if (steps != null && steps.isArray()) {
            for (int i = 0; i < steps.size(); i++) {
                JsonNode s = steps.get(i);
                if (s.isObject()) {
                    checkRiverState(s.get("targetState"),
                            "manifest.steps[" + i + "].targetState",
                            stakeIdSet(stakes), errors);
                }
            }
        }
    }

    private Set<String> stakeIdSet(JsonNode stakes) {
        Set<String> ids = new LinkedHashSet<>();
        if (stakes != null && stakes.isArray()) {
            for (JsonNode s : stakes) {
                String sid = s.path("id").asText(null);
                if (sid != null) ids.add(sid);
            }
        }
        return ids;
    }

    /** RIVER_TIDE state bounds + stake refs — water/boat 0..1. */
    private void checkRiverState(JsonNode state, String path,
                                 Set<String> stakeIds,
                                 List<ManifestFieldError> errors) {
        if (state == null || !state.isObject()) return;
        for (String f : new String[]{
                "waterLevel", "boatProgress", "decoyProgress",
                "counterattackProgress"}) {
            JsonNode v = state.get(f);
            if (v != null && v.isNumber()
                    && (v.asDouble() < 0 || v.asDouble() > 1)) {
                errors.add(err(path + "." + f, "OUT_OF_RANGE",
                        f + " must be a normalized 0..1 number"));
            }
        }
        JsonNode vis = state.get("stakeVisibility");
        if (vis != null && vis.isObject() && !stakeIds.isEmpty()) {
            for (var it = vis.fieldNames(); it.hasNext();) {
                String k = it.next();
                if (!stakeIds.contains(k)) {
                    errors.add(err(path + ".stakeVisibility." + k, "UNKNOWN_REF",
                            "stakeVisibility references unknown stake '" + k + "'"));
                }
            }
        }
        JsonNode hl = state.get("stakeHighlight");
        if (hl != null && hl.isArray() && !stakeIds.isEmpty()) {
            for (int i = 0; i < hl.size(); i++) {
                String ref = hl.get(i).asText(null);
                if (ref != null && !stakeIds.contains(ref)) {
                    errors.add(err(path + ".stakeHighlight[" + i + "]", "UNKNOWN_REF",
                            "stakeHighlight references unknown stake '" + ref + "'"));
                }
            }
        }
    }

    /* ---------- JOURNEY_MAP ---------- */

    private void validateMap(JsonNode manifest, List<ManifestFieldError> errors) {
        JsonNode map = manifest.get("map");
        if (map == null || !map.isObject()) {
            errors.add(err("manifest.map", "MISSING_FIELD",
                    "JOURNEY_MAP manifests require a 'map' section"));
            return;
        }
        Set<String> locationIds = new LinkedHashSet<>();
        JsonNode locs = map.get("locations");
        if (locs == null || !locs.isArray() || locs.isEmpty()) {
            errors.add(err("manifest.map.locations", "MISSING_FIELD",
                    "map.locations must be a non-empty array"));
        } else {
            if (locs.size() > MAX_LOCATIONS) {
                errors.add(err("manifest.map.locations", "TOO_MANY",
                        "locations exceeds " + MAX_LOCATIONS));
            }
            for (int i = 0; i < locs.size(); i++) {
                JsonNode l = locs.get(i);
                String p = "manifest.map.locations[" + i + "]";
                String lid = l.path("id").asText(null);
                if (lid == null || !ID_PATTERN.matcher(lid).matches()) {
                    errors.add(err(p + ".id", "INVALID_ID",
                            "location id must match " + ID_PATTERN.pattern()));
                } else if (!locationIds.add(lid)) {
                    errors.add(err(p + ".id", "DUPLICATE_ID",
                            "duplicate location id '" + lid + "'"));
                }
                if (text(l, "name") == null || text(l, "name").isBlank()) {
                    errors.add(err(p + ".name", "MISSING_FIELD",
                            "location name is required"));
                }
                check01(l, "x", p + ".x", errors);
                check01(l, "y", p + ".y", errors);
            }
        }
        JsonNode routes = map.get("routes");
        if (routes != null && routes.isArray()) {
            if (routes.size() > MAX_ROUTES) {
                errors.add(err("manifest.map.routes", "TOO_MANY",
                        "routes exceeds " + MAX_ROUTES));
            }
            Set<String> routeIds = new HashSet<>();
            for (int i = 0; i < routes.size(); i++) {
                JsonNode r = routes.get(i);
                String p = "manifest.map.routes[" + i + "]";
                String rid = r.path("id").asText(null);
                if (rid == null || !ID_PATTERN.matcher(rid).matches()) {
                    errors.add(err(p + ".id", "INVALID_ID",
                            "route id must match " + ID_PATTERN.pattern()));
                } else if (!routeIds.add(rid)) {
                    errors.add(err(p + ".id", "DUPLICATE_ID",
                            "duplicate route id '" + rid + "'"));
                }
                for (String end : new String[]{"from", "to"}) {
                    String ref = r.path(end).asText(null);
                    if (ref == null || !locationIds.contains(ref)) {
                        errors.add(err(p + "." + end, "UNKNOWN_REF",
                                "route." + end + " must reference a location id"));
                    }
                }
                JsonNode via = r.get("via");
                if (via != null && via.isArray()) {
                    for (int j = 0; j < via.size(); j++) {
                        checkNormalizedPos(via.get(j), p + ".via[" + j + "]", errors);
                    }
                }
            }
        }
        // map.backgroundAssetId — must reference an ACTIVE asset (same
        // check as manifest.assets[].assetId).
        String bg = map.path("backgroundAssetId").asText(null);
        if (bg != null) {
            UUID uuid = parseUuid(bg);
            if (uuid == null || !assets.existsByIdAndState(uuid, "ACTIVE")) {
                errors.add(err("manifest.map.backgroundAssetId", "ASSET_NOT_FOUND",
                        "backgroundAssetId '" + bg + "' is not an active asset"));
            }
        }
        // State-map references — markerVisibility/markerHighlight/
        // focusedLocationId/routeProgress must point at declared ids.
        checkStateRefs(manifest.get("initialState"), "manifest.initialState",
                locationIds, routeIdsOf(routes), errors);
        JsonNode steps = manifest.get("steps");
        if (steps != null && steps.isArray()) {
            for (int i = 0; i < steps.size(); i++) {
                JsonNode s = steps.get(i);
                if (s.isObject()) {
                    checkStateRefs(s.get("targetState"),
                            "manifest.steps[" + i + "].targetState",
                            locationIds, routeIdsOf(routes), errors);
                }
            }
        }
    }

    private Set<String> routeIdsOf(JsonNode routes) {
        Set<String> ids = new LinkedHashSet<>();
        if (routes != null && routes.isArray()) {
            for (JsonNode r : routes) {
                String rid = r.path("id").asText(null);
                if (rid != null) ids.add(rid);
            }
        }
        return ids;
    }

    /** Validate JOURNEY_MAP state keys that reference declared ids. */
    private void checkStateRefs(JsonNode state, String path,
                                Set<String> locationIds, Set<String> routeIds,
                                List<ManifestFieldError> errors) {
        if (state == null || !state.isObject() || locationIds.isEmpty()) return;
        JsonNode vis = state.get("markerVisibility");
        if (vis != null && vis.isObject()) {
            for (var it = vis.fieldNames(); it.hasNext();) {
                String k = it.next();
                if (!locationIds.contains(k)) {
                    errors.add(err(path + ".markerVisibility." + k, "UNKNOWN_REF",
                            "markerVisibility references unknown location '" + k + "'"));
                }
                JsonNode v = vis.get(k);
                if (v.isNumber() && (v.asDouble() < 0 || v.asDouble() > 1)) {
                    errors.add(err(path + ".markerVisibility." + k, "OUT_OF_RANGE",
                            "markerVisibility." + k + " must be 0..1"));
                }
            }
        }
        JsonNode hl = state.get("markerHighlight");
        if (hl != null && hl.isArray()) {
            for (int i = 0; i < hl.size(); i++) {
                String ref = hl.get(i).asText(null);
                if (ref != null && !locationIds.contains(ref)) {
                    errors.add(err(path + ".markerHighlight[" + i + "]", "UNKNOWN_REF",
                            "markerHighlight references unknown location '" + ref + "'"));
                }
            }
        }
        String focused = state.path("focusedLocationId").asText(null);
        if (focused != null && !locationIds.contains(focused)) {
            errors.add(err(path + ".focusedLocationId", "UNKNOWN_REF",
                    "focusedLocationId references unknown location '" + focused + "'"));
        }
        JsonNode rp = state.get("routeProgress");
        if (rp != null && rp.isObject()) {
            for (var it = rp.fieldNames(); it.hasNext();) {
                String k = it.next();
                if (!routeIds.contains(k)) {
                    errors.add(err(path + ".routeProgress." + k, "UNKNOWN_REF",
                            "routeProgress references unknown route '" + k + "'"));
                }
                JsonNode v = rp.get(k);
                if (v.isNumber() && (v.asDouble() < 0 || v.asDouble() > 1)) {
                    errors.add(err(path + ".routeProgress." + k, "OUT_OF_RANGE",
                            "routeProgress." + k + " must be 0..1"));
                }
            }
        }
    }

    /* ---------- helpers ---------- */

    private void checkStateKeys(JsonNode state, String path, String rendererCode,
                                List<ManifestFieldError> errors) {
        if (state == null || !state.isObject() || rendererCode == null) return;
        Set<String> allowed = STATE_KEYS.getOrDefault(rendererCode, Set.of());
        for (var it = state.fieldNames(); it.hasNext();) {
            String key = it.next();
            if (!allowed.contains(key)) {
                errors.add(err(path + "." + key, "UNKNOWN_STATE_KEY",
                        "state key '" + key + "' is not supported by " + rendererCode));
            }
        }
    }

    private void checkNormalizedPos(JsonNode pos, String path,
                                    List<ManifestFieldError> errors) {
        if (pos == null) return;
        if (!pos.isObject()) {
            errors.add(err(path, "INVALID_TYPE", "position must be {x,y}"));
            return;
        }
        check01(pos, "x", path + ".x", errors);
        check01(pos, "y", path + ".y", errors);
    }

    private void check01(JsonNode node, String field, String path,
                         List<ManifestFieldError> errors) {
        JsonNode v = node.get(field);
        if (v == null || !v.isNumber() || v.asDouble() < 0 || v.asDouble() > 1) {
            errors.add(err(path, "OUT_OF_RANGE",
                    field + " must be a normalized 0..1 number"));
        }
    }

    private void checkLen(JsonNode node, String field, String path, int max,
                          List<ManifestFieldError> errors) {
        JsonNode v = node.get(field);
        if (v != null && v.isTextual() && v.asText().length() > max) {
            errors.add(err(path, "TOO_LONG", field + " exceeds " + max + " chars"));
        }
    }

    private int depth(JsonNode node, int d) {
        if (d > MAX_DEPTH || node == null) return d;
        if (node.isObject()) {
            int max = d;
            for (var it = node.fields(); it.hasNext();) {
                max = Math.max(max, depth(it.next().getValue(), d + 1));
            }
            return max;
        }
        if (node.isArray()) {
            int max = d;
            for (JsonNode item : node) {
                max = Math.max(max, depth(item, d + 1));
            }
            return max;
        }
        return d;
    }

    private static String text(JsonNode node, String field) {
        JsonNode v = node.get(field);
        return v != null && v.isTextual() ? v.asText() : null;
    }

    private static UUID parseUuid(String text) {
        try {
            return UUID.fromString(text);
        } catch (RuntimeException e) {
            return null;
        }
    }

    private static ManifestFieldError err(String path, String code, String message) {
        return new ManifestFieldError(path, code, message);
    }
}

package com.dauviet.lesson.draft;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import com.dauviet.lesson.domain.EvidenceStatus;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;
import com.dauviet.lesson.infrastructure.persistence.EvidenceRepository;

/**
 * Validates the canonical draft_json v1 document.
 * Two levels: SAVE tolerates incomplete drafts; PUBLISH enforces all
 * LEARNING_ENGINE_DESIGN §9 guardrails and evidence/asset existence.
 * Never logs or echoes `validation`/`config.correct*` contents — paths only.
 */
@Service
public class DraftValidator {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final Map<ActivityType, ActivityConfigValidator> registry;
    private final EvidenceRepository evidences;
    private final AssetRepository assets;
    private final com.dauviet.animation.infrastructure.persistence
            .AnimationSceneVersionRepository sceneVersions;

    public DraftValidator(List<ActivityConfigValidator> impls,
                          EvidenceRepository evidences,
                          AssetRepository assets,
                          com.dauviet.animation.infrastructure.persistence
                                  .AnimationSceneVersionRepository sceneVersions) {
        Map<ActivityType, ActivityConfigValidator> map = new EnumMap<>(ActivityType.class);
        for (ActivityConfigValidator v : impls) {
            ActivityConfigValidator prev = map.put(v.supports(), v);
            if (prev != null) {
                throw new IllegalStateException(
                        "duplicate validator for " + v.supports() + ": "
                        + prev.getClass().getName() + " and " + v.getClass().getName());
            }
        }
        this.registry = map;
        this.evidences = evidences;
        this.assets = assets;
        this.sceneVersions = sceneVersions;
    }

    /**
     * Validate the full draft. Returns an ordered, never-null error list.
     * draftJson may be null/blank — treated as empty document.
     */
    public List<FieldError> validate(JsonNode draft, UUID eventId, ValidationLevel level) {
        List<FieldError> errors = new ArrayList<>();
        if (draft == null || draft.isNull()) {
            if (level == ValidationLevel.PUBLISH) {
                errors.add(new FieldError("$", "MISSING_DRAFT", "draft must not be empty"));
            }
            return errors;
        }
        if (!draft.isObject()) {
            errors.add(new FieldError("$", "INVALID_DRAFT", "draft must be a JSON object"));
            return errors;
        }

        checkUnknownKeys(draft, DraftSchema.TOP_LEVEL_KEYS, "$", errors);
        validateSchemaVersion(draft, level, errors);

        Set<String> stageIds = new HashSet<>();
        Map<String, JsonNode> stageById = new HashMap<>();
        Map<String, List<String>> transitions = new HashMap<>();
        // Single PUBLISH-level lookup context shared by the whole draft walk
        // so evidence/asset queries are issued once per validate() call.
        ValidationContext ctx = buildContext(eventId, level);

        JsonNode stages = draft.get("stages");
        if (stages != null && stages.isArray()) {
            // Activity ids share one global namespace inside a snapshot —
            // the runtime indexes activities by id alone, so a collision
            // across stages would silently shadow an activity.
            Set<String> activityIds = new HashSet<>();
            validateStages(stages, stageIds, stageById, transitions, activityIds, ctx, errors);
        } else if (level == ValidationLevel.PUBLISH) {
            errors.add(new FieldError("stages", "MISSING_FIELD", "stages array required"));
        }

        validateStageGraph(draft, stageIds, transitions, level, errors);
        validateCompletion(draft.get("completion"), stageIds, level, errors);
        if (level == ValidationLevel.PUBLISH) {
            validatePublishGuardrails(stageIds, stageById, draft.get("completion"), errors);
        }
        return errors;
    }

    /* ---------- structural ---------- */

    private void validateSchemaVersion(JsonNode draft, ValidationLevel level,
                                       List<FieldError> errors) {
        JsonNode sv = draft.get("schemaVersion");
        if (sv == null) {
            // Missing is tolerated at SAVE (author may still be assembling the
            // draft) but a publishable snapshot must declare its schema version.
            if (level == ValidationLevel.PUBLISH) {
                errors.add(new FieldError("schemaVersion", "MISSING_FIELD",
                        "schemaVersion is required and must be " + DraftSchema.CURRENT_VERSION));
            }
            return;
        }
        if (!sv.isInt() || sv.asInt() != DraftSchema.CURRENT_VERSION) {
            errors.add(new FieldError("schemaVersion", "UNSUPPORTED_SCHEMA_VERSION",
                    "schemaVersion must be " + DraftSchema.CURRENT_VERSION));
        }
    }

    private void checkUnknownKeys(JsonNode node, Set<String> allowed, String path,
                                  List<FieldError> errors) {
        node.fieldNames().forEachRemaining(name -> {
            if (!allowed.contains(name)) {
                errors.add(new FieldError(path + "." + name, "UNKNOWN_FIELD",
                        "field '" + name + "' is not allowed"));
            }
        });
    }

    private void validateStages(JsonNode stages, Set<String> stageIds,
                                Map<String, JsonNode> stageById,
                                Map<String, List<String>> transitions,
                                Set<String> activityIds,
                                ValidationContext ctx,
                                List<FieldError> errors) {
        for (int i = 0; i < stages.size(); i++) {
            JsonNode stage = stages.get(i);
            String base = "stages[" + i + "]";
            if (!stage.isObject()) {
                errors.add(new FieldError(base, "INVALID_TYPE", "stage must be an object"));
                continue;
            }
            checkUnknownKeys(stage, DraftSchema.STAGE_KEYS, base, errors);
            String id = validateId(stage.get("id"), base + ".id", errors);
            if (id != null && !stageIds.add(id)) {
                errors.add(new FieldError(base + ".id", "DUPLICATE_ID",
                        "duplicate stage id '" + id + "'"));
            }
            if (id != null) stageById.put(id, stage);

            StageType st = parseEnum(StageType.class, stage.get("type"),
                    base + ".type", "UNKNOWN_STAGE_TYPE", errors);

            collectTransitions(stage, id, transitions, errors, base);
            validateStageEvidenceRefs(stage, base, ctx, errors);
            validateActivities(stage, st, base, activityIds, ctx, errors);
        }
    }

    private void collectTransitions(JsonNode stage, String stageId,
                                    Map<String, List<String>> transitions,
                                    List<FieldError> errors, String base) {
        JsonNode next = stage.get("nextStageIds");
        if (next == null || !next.isArray()) {
            transitions.put(stageId, List.of());
            return;
        }
        List<String> targets = new ArrayList<>();
        for (int i = 0; i < next.size(); i++) {
            JsonNode t = next.get(i);
            if (!t.isTextual()) {
                errors.add(new FieldError(base + ".nextStageIds[" + i + "]",
                        "INVALID_TYPE", "transition target must be a string"));
                continue;
            }
            targets.add(t.asText());
        }
        transitions.put(stageId, targets);
    }

    private void validateStageEvidenceRefs(JsonNode stage, String base,
                                           ValidationContext ctx,
                                           List<FieldError> errors) {
        if (!ctx.isPublish()) return;
        JsonNode refs = stage.get("requiredEvidenceIds");
        if (refs == null || !refs.isArray()) return;
        for (int i = 0; i < refs.size(); i++) {
            String evId = refs.get(i).asText();
            if (!ctx.evidenceUsable(evId)) {
                errors.add(new FieldError(base + ".requiredEvidenceIds[" + i + "]",
                        "EVIDENCE_NOT_FOUND", "evidence '" + evId + "' not usable for this event"));
            }
        }
    }

    private void validateActivities(JsonNode stage, StageType stageType,
                                    String stagePath, Set<String> activityIds,
                                    ValidationContext ctx,
                                    List<FieldError> errors) {
        JsonNode acts = stage.get("activities");
        if (acts == null || !acts.isArray()) return;
        for (int j = 0; j < acts.size(); j++) {
            JsonNode act = acts.get(j);
            String apath = stagePath + ".activities[" + j + "]";
            if (!act.isObject()) {
                errors.add(new FieldError(apath, "INVALID_TYPE", "activity must be an object"));
                continue;
            }
            checkUnknownKeys(act, DraftSchema.ACTIVITY_KEYS, apath, errors);
            String actId = validateId(act.get("id"), apath + ".id", errors);
            if (actId != null && !activityIds.add(actId)) {
                errors.add(new FieldError(apath + ".id", "DUPLICATE_ID",
                        "duplicate activity id '" + actId + "'"));
            }
            ActivityType at = parseEnum(ActivityType.class, act.get("type"),
                    apath + ".type", "UNSUPPORTED_ACTIVITY_TYPE", errors);
            if (at != null && stageType != null
                    && !DraftSchema.STAGE_ALLOWED_ACTIVITIES.get(stageType).contains(at)) {
                errors.add(new FieldError(apath + ".type", "STAGE_ACTIVITY_MISMATCH",
                        "activity type " + at + " not allowed in stage " + stageType));
            }
            ActivityConfigValidator v = at == null ? null : registry.get(at);
            if (v != null) {
                v.validate(act, apath, ctx, errors);
            }
            // Stage-level evidence refs inside an activity
            JsonNode evRefs = act.get("evidenceRefs");
            if (ctx.isPublish() && evRefs != null && evRefs.isArray()) {
                for (int k = 0; k < evRefs.size(); k++) {
                    String evId = evRefs.get(k).asText();
                    if (!ctx.evidenceUsable(evId)) {
                        errors.add(new FieldError(apath + ".evidenceRefs[" + k + "]",
                                "EVIDENCE_NOT_FOUND",
                                "evidence '" + evId + "' not usable for this event"));
                    }
                }
            }
        }
    }

    /* ---------- stage graph ---------- */

    private void validateStageGraph(JsonNode draft,
                                    Set<String> stageIds,
                                    Map<String, List<String>> transitions,
                                    ValidationLevel level,
                                    List<FieldError> errors) {
        // Unknown targets
        for (Map.Entry<String, List<String>> e : transitions.entrySet()) {
            for (String target : e.getValue()) {
                if (!stageIds.contains(target)) {
                    errors.add(new FieldError("stages[id=" + e.getKey() + "].nextStageIds",
                            "UNKNOWN_STAGE_ID", "stage '" + target + "' not found"));
                }
            }
        }
        // Cycle detection — three-colour iterative DFS over the whole graph.
        // GRAY nodes are on the current DFS path; an edge to a GRAY node is a
        // back-edge, i.e. a real directed cycle. Converging paths (diamonds,
        // shared destinations) revisit only BLACK nodes and are NOT cycles.
        Map<String, Integer> color = new HashMap<>();
        for (String start : stageIds) {
            if (color.containsKey(start)) continue;
            String cycleAt = findCycle(start, transitions, color);
            if (cycleAt != null) {
                errors.add(new FieldError("stages[id=" + cycleAt + "].nextStageIds",
                        "CIRCULAR_TRANSITION", "cycle detected through stage '" + cycleAt + "'"));
                break;
            }
        }
        // Reachable terminal stage — PUBLISH only. The entry stage is
        // stages[0] in array order; the lesson must be able to end, so a
        // stage with empty nextStageIds must be reachable from the entry.
        if (level == ValidationLevel.PUBLISH && !stageIds.isEmpty()) {
            JsonNode stages = draft.get("stages");
            String entry = (stages != null && stages.isArray() && !stages.isEmpty()
                    && stages.get(0).isObject())
                    ? stages.get(0).path("id").asText(null) : null;
            Set<String> reachable = entry == null ? Set.of()
                    : reachableFrom(entry, transitions);
            boolean terminalReachable = reachable.stream()
                    .anyMatch(s -> transitions.getOrDefault(s, List.of()).isEmpty());
            if (!terminalReachable) {
                errors.add(new FieldError("stages", "NO_TERMINAL_STAGE",
                        "no terminal stage (empty nextStageIds) is reachable from the entry stage"));
            }
        }
    }

    private static final int WHITE = 0; // unvisited
    private static final int GRAY = 1;  // on current DFS path
    private static final int BLACK = 2; // fully explored

    /**
     * Iterative three-colour DFS. Returns the stage id where a back-edge was
     * found (a real directed cycle), or null when the component is a DAG.
     * Frames on the stack are (node, nextChildIndex); a node turns BLACK only
     * after all children are explored, so GRAY always means "ancestor".
     */
    private String findCycle(String start, Map<String, List<String>> graph,
                             Map<String, Integer> color) {
        Deque<String> nodes = new ArrayDeque<>();
        Deque<int[]> cursors = new ArrayDeque<>();
        color.put(start, GRAY);
        nodes.push(start);
        cursors.push(new int[]{0});
        while (!nodes.isEmpty()) {
            String node = nodes.peek();
            int[] cursor = cursors.peek();
            List<String> next = graph.getOrDefault(node, List.of());
            if (cursor[0] >= next.size()) {
                color.put(node, BLACK);
                nodes.pop();
                cursors.pop();
                continue;
            }
            String child = next.get(cursor[0]++);
            Integer c = color.getOrDefault(child, WHITE);
            if (c == GRAY) return child;
            if (c == WHITE) {
                color.put(child, GRAY);
                nodes.push(child);
                cursors.push(new int[]{0});
            }
        }
        return null;
    }

    /** BFS over nextStageIds edges; returns all stage ids reachable from `entry`. */
    private Set<String> reachableFrom(String entry, Map<String, List<String>> graph) {
        Set<String> seen = new HashSet<>();
        Deque<String> queue = new ArrayDeque<>();
        if (entry != null) {
            seen.add(entry);
            queue.add(entry);
        }
        while (!queue.isEmpty()) {
            for (String next : graph.getOrDefault(queue.poll(), List.of())) {
                if (seen.add(next)) queue.add(next);
            }
        }
        return seen;
    }

    /* ---------- completion ---------- */

    private void validateCompletion(JsonNode completion, Set<String> stageIds,
                                    ValidationLevel level, List<FieldError> errors) {
        if (completion == null) return;
        if (!completion.isObject()) {
            errors.add(new FieldError("completion", "INVALID_TYPE",
                    "completion must be an object"));
            return;
        }
        checkUnknownKeys(completion, DraftSchema.COMPLETION_KEYS, "completion", errors);
        // An empty object selects no completion clause. At runtime it falls
        // back to DEFAULT_ALL_REQUIRED (same as an absent completion), so
        // publishing it is either a mistake or a redundant no-op — reject to
        // keep authoring intent explicit and consistent with the evaluator.
        if (level == ValidationLevel.PUBLISH && completion.isEmpty()) {
            errors.add(new FieldError("completion", "EMPTY_COMPLETION",
                    "empty completion object: declare a clause or omit the field"));
            return;
        }
        JsonNode reqIds = completion.get("requiredStageIds");
        if (reqIds != null && reqIds.isArray()) {
            for (int i = 0; i < reqIds.size(); i++) {
                String sid = reqIds.get(i).asText();
                if (!stageIds.contains(sid)) {
                    errors.add(new FieldError("completion.requiredStageIds[" + i + "]",
                            "UNKNOWN_STAGE_ID", "stage '" + sid + "' not found"));
                }
            }
        }
    }

    /** PUBLISH-level guardrails that need the full parsed stage set. */
    private void validatePublishGuardrails(Set<String> stageIds,
                                           Map<String, JsonNode> stageById,
                                           JsonNode completion,
                                           List<FieldError> errors) {
        // At least one required stage must carry a non-READ required activity,
        // otherwise the lesson is a passive READ with no assessment.
        boolean hasRequiredInteractive = false;
        boolean hasRequiredStage = false;
        for (String sid : stageIds) {
            JsonNode stage = stageById.get(sid);
            if (stage == null || !stage.path("required").asBoolean(false)) continue;
            hasRequiredStage = true;
            JsonNode acts = stage.get("activities");
            if (acts == null || !acts.isArray()) continue;
            for (JsonNode act : acts) {
                if (act.path("required").asBoolean(false)
                        && !"READ".equals(act.path("type").asText())) {
                    hasRequiredInteractive = true;
                    break;
                }
            }
            if (hasRequiredInteractive) break;
        }
        if (!hasRequiredInteractive) {
            errors.add(new FieldError("stages", "NO_REQUIRED_ACTIVITY",
                    "at least one required stage must contain a required non-READ activity"));
        }
        // requireAllRequiredStages==true is meaningless without a required stage
        if (completion != null && completion.isObject()
                && completion.path("requireAllRequiredStages").asBoolean(false)
                && !hasRequiredStage) {
            errors.add(new FieldError("completion.requireAllRequiredStages",
                    "INVALID_CONFIG",
                    "requireAllRequiredStages=true but no stage has required=true"));
        }
        // An activity flagged required inside an optional stage can never
        // gate anything: the stage flag makes its activities optional for
        // progress, transition and default completion, so the flag only
        // takes effect through an explicit completion.requiredStageIds.
        // Reject the contradictory shape at publish — either make the stage
        // required or drop the activity flag (BA: optional stage = optional
        // content, e.g. Reflection).
        for (String sid : stageIds) {
            JsonNode stage = stageById.get(sid);
            if (stage == null || stage.path("required").asBoolean(false)) continue;
            JsonNode acts = stage.get("activities");
            if (acts == null || !acts.isArray()) continue;
            for (int i = 0; i < acts.size(); i++) {
                if (acts.get(i).path("required").asBoolean(false)) {
                    errors.add(new FieldError(
                            "stages[id=" + sid + "].activities[" + i + "].required",
                            "REQUIRED_IN_OPTIONAL_STAGE",
                            "activity.required=true inside required=false stage '"
                            + sid + "' never gates progress/completion — drop the "
                            + "flag or make the stage required"));
                }
            }
        }
    }

    /* ---------- helpers ---------- */

    private String validateId(JsonNode idNode, String path, List<FieldError> errors) {
        if (idNode == null || !idNode.isTextual()) {
            errors.add(new FieldError(path, "MISSING_FIELD", "id is required"));
            return null;
        }
        String id = idNode.asText();
        if (!DraftSchema.ID_PATTERN.matcher(id).matches()) {
            errors.add(new FieldError(path, "INVALID_ID",
                    "id must match " + DraftSchema.ID_PATTERN.pattern()));
            return null;
        }
        return id;
    }

    private <E extends Enum<E>> E parseEnum(Class<E> type, JsonNode node,
                                          String path, String code,
                                          List<FieldError> errors) {
        if (node == null || !node.isTextual()) {
            if (node == null) {
                errors.add(new FieldError(path, "MISSING_FIELD", "type is required"));
            } else {
                errors.add(new FieldError(path, "INVALID_TYPE", "type must be a string"));
            }
            return null;
        }
        try {
            return Enum.valueOf(type, node.asText());
        } catch (IllegalArgumentException e) {
            errors.add(new FieldError(path, code, "unsupported type '" + node.asText() + "'"));
            return null;
        }
    }

    private ValidationContext buildContext(UUID eventId, ValidationLevel level) {
        Set<String> valid = Set.of();
        Set<String> activeAssets = Set.of();
        Map<String, UUID> versionToScene = Map.of();
        Set<UUID> publishedSceneIds = Set.of();
        if (level == ValidationLevel.PUBLISH && eventId != null) {
            valid = evidences.findIdsByEventIdAndStatusIn(eventId,
                            List.of(EvidenceStatus.DRAFT, EvidenceStatus.APPROVED))
                    .stream().map(UUID::toString).collect(Collectors.toSet());
            activeAssets = assets.findActiveIds().stream()
                    .map(UUID::toString).collect(Collectors.toSet());
            // versionId -> owning sceneId so validators can also check the pin
            // (animationSceneId must equal version.sceneId), not just existence.
            versionToScene = sceneVersions.findIdAndSceneId().stream()
                    .collect(Collectors.toMap(
                            r -> ((UUID) r[0]).toString(), r -> (UUID) r[1]));
            publishedSceneIds = new java.util.HashSet<>(
                    sceneVersions.findDistinctSceneIds());
        }
        return new ValidationContext(eventId, level, valid, activeAssets,
                versionToScene, publishedSceneIds);
    }

    /* ---------- preserved helpers used by existing code ---------- */

    /** Back-compat for LessonService raw-JSON endpoints. */
    public static String requireJsonObject(String json, String fieldName) {
        if (json == null) return null;
        try {
            JsonNode node = MAPPER.readTree(json);
            if (node == null || !node.isObject()) {
                throw new com.dauviet.lesson.domain.DraftSchemaInvalidException(
                        fieldName + " must be a JSON object");
            }
            return MAPPER.writeValueAsString(node);
        } catch (com.dauviet.lesson.domain.DraftSchemaInvalidException e) {
            throw e;
        } catch (Exception e) {
            throw new com.dauviet.lesson.domain.DraftSchemaInvalidException(
                    fieldName + " is not valid JSON: " + e.getMessage());
        }
    }

    public static String requireJsonArray(String json, String fieldName) {
        if (json == null) return null;
        try {
            JsonNode node = MAPPER.readTree(json);
            if (node == null || !node.isArray()) {
                throw new com.dauviet.lesson.domain.DraftSchemaInvalidException(
                        fieldName + " must be a JSON array");
            }
            return MAPPER.writeValueAsString(node);
        } catch (com.dauviet.lesson.domain.DraftSchemaInvalidException e) {
            throw e;
        } catch (Exception e) {
            throw new com.dauviet.lesson.domain.DraftSchemaInvalidException(
                    fieldName + " is not valid JSON: " + e.getMessage());
        }
    }
}

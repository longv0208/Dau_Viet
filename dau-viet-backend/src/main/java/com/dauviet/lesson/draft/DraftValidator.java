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

    public DraftValidator(List<ActivityConfigValidator> impls,
                          EvidenceRepository evidences,
                          AssetRepository assets) {
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
        validateSchemaVersion(draft, errors);

        Set<String> stageIds = new HashSet<>();
        Map<String, JsonNode> stageById = new HashMap<>();
        Map<String, List<String>> transitions = new HashMap<>();
        // Single PUBLISH-level lookup context shared by the whole draft walk
        // so evidence/asset queries are issued once per validate() call.
        ValidationContext ctx = buildContext(eventId, level);

        JsonNode stages = draft.get("stages");
        if (stages != null && stages.isArray()) {
            validateStages(stages, stageIds, stageById, transitions, ctx, errors);
        } else if (level == ValidationLevel.PUBLISH) {
            errors.add(new FieldError("stages", "MISSING_FIELD", "stages array required"));
        }

        validateStageGraph(stageIds, transitions, level, errors);
        validateCompletion(draft.get("completion"), stageIds, level, errors);
        if (level == ValidationLevel.PUBLISH) {
            validatePublishGuardrails(stageIds, stageById, draft.get("completion"), errors);
        }
        return errors;
    }

    /* ---------- structural ---------- */

    private void validateSchemaVersion(JsonNode draft, List<FieldError> errors) {
        JsonNode sv = draft.get("schemaVersion");
        if (sv == null) return; // missing tolerated at SAVE; PUBLISH catches via other checks
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
            validateActivities(stage, st, base, ctx, errors);
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
                                    String stagePath, ValidationContext ctx,
                                    List<FieldError> errors) {
        JsonNode acts = stage.get("activities");
        if (acts == null || !acts.isArray()) return;
        Set<String> actIds = new HashSet<>();
        for (int j = 0; j < acts.size(); j++) {
            JsonNode act = acts.get(j);
            String apath = stagePath + ".activities[" + j + "]";
            if (!act.isObject()) {
                errors.add(new FieldError(apath, "INVALID_TYPE", "activity must be an object"));
                continue;
            }
            checkUnknownKeys(act, DraftSchema.ACTIVITY_KEYS, apath, errors);
            String actId = validateId(act.get("id"), apath + ".id", errors);
            if (actId != null && !actIds.add(actId)) {
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

    private void validateStageGraph(Set<String> stageIds,
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
        // Cycle detection via DFS (iterative to avoid recursion-depth surprises)
        Set<String> visited = new HashSet<>();
        for (String start : stageIds) {
            if (visited.contains(start)) continue;
            if (hasCycle(start, transitions, visited)) {
                errors.add(new FieldError("stages[id=" + start + "].nextStageIds",
                        "CIRCULAR_TRANSITION", "cycle detected through stage '" + start + "'"));
                break;
            }
        }
        // Reachable terminal stage — PUBLISH only
        if (level == ValidationLevel.PUBLISH && !stageIds.isEmpty()) {
            boolean hasTerminal = stageIds.stream()
                    .anyMatch(s -> transitions.getOrDefault(s, List.of()).isEmpty());
            if (!hasTerminal) {
                errors.add(new FieldError("stages", "NO_TERMINAL_STAGE",
                        "at least one stage must have empty nextStageIds (terminal)"));
            }
        }
    }

    /** Iterative DFS: true if `start` reaches a node already on its stack. */
    private boolean hasCycle(String start, Map<String, List<String>> graph,
                             Set<String> globallyVisited) {
        Set<String> onStack = new HashSet<>();
        Deque<String> stack = new ArrayDeque<>();
        stack.push(start);
        while (!stack.isEmpty()) {
            String node = stack.pop();
            if (onStack.contains(node)) return true;
            if (globallyVisited.contains(node)) continue;
            globallyVisited.add(node);
            onStack.add(node);
            for (String next : graph.getOrDefault(node, List.of())) {
                if (onStack.contains(next)) return true;
                stack.push(next);
            }
        }
        return false;
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
        if (level == ValidationLevel.PUBLISH && eventId != null) {
            valid = evidences.findIdsByEventIdAndStatusIn(eventId,
                            List.of(EvidenceStatus.DRAFT, EvidenceStatus.APPROVED))
                    .stream().map(UUID::toString).collect(Collectors.toSet());
            activeAssets = assets.findActiveIds().stream()
                    .map(UUID::toString).collect(Collectors.toSet());
        }
        return new ValidationContext(eventId, level, valid, activeAssets);
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

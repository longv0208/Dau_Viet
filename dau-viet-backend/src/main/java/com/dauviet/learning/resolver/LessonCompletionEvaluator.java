package com.dauviet.learning.resolver;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import org.springframework.stereotype.Component;

import com.dauviet.learning.contract.LessonCompletion;
import com.dauviet.learning.domain.AttemptState;
import com.dauviet.learning.snapshot.SnapshotModel;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;

/**
 * Evaluates the snapshot `completion` config against AttemptState.
 * Clauses AND-combine: requireAllRequiredStages, requiredStageIds[],
 * minScore (percent of ALL required activities in the snapshot completed).
 * Absent completion config — or a config object carrying no active clause
 * (e.g. `completion:{}`) -> default rule: complete when no required
 * activity remains un-completed anywhere (DEFAULT_ALL_REQUIRED). An
 * empty config must never complete early (published-legacy snapshots
 * predate the publish-time rejection in DraftValidator).
 */
@Component
public class LessonCompletionEvaluator {

    public LessonCompletion evaluate(SnapshotModel model, AttemptState state) {
        JsonNode completion = model.completion();

        int totalRequired = 0;
        int doneRequired = 0;
        for (JsonNode stage : model.stages()) {
            for (JsonNode a : model.requiredActivities(stage.path("id").asText())) {
                totalRequired++;
                if (state.isCompleted(a.path("id").asText())) doneRequired++;
            }
        }

        if (completion == null || !completion.isObject()) {
            boolean done = totalRequired == doneRequired;
            return verdict(done, LessonCompletion.DEFAULT_ALL_REQUIRED,
                    detail(model, state, doneRequired, totalRequired, null));
        }

        boolean requireAll = completion.path("requireAllRequiredStages").asBoolean(false);
        Set<String> requiredStageIds = new LinkedHashSet<>();
        JsonNode ids = completion.get("requiredStageIds");
        if (ids != null && ids.isArray()) {
            ids.forEach(n -> { if (n.isTextual()) requiredStageIds.add(n.asText()); });
        }
        Double minScore = completion.hasNonNull("minScore")
                ? completion.get("minScore").asDouble() : null;

        ObjectNode detail = detail(model, state, doneRequired, totalRequired, null);

        if (requireAll) {
            List<String> missing = missingRequiredStages(model, state, null);
            if (!missing.isEmpty()) {
                detail.set("missingStageIds", toArray(missing));
                return verdict(false, LessonCompletion.ALL_REQUIRED_STAGES, detail);
            }
        }
        if (!requiredStageIds.isEmpty()) {
            List<String> missing = missingRequiredStages(model, state, requiredStageIds);
            if (!missing.isEmpty()) {
                detail.set("missingStageIds", toArray(missing));
                return verdict(false, LessonCompletion.REQUIRED_STAGE_IDS, detail);
            }
        }
        if (minScore != null) {
            double score = totalRequired == 0 ? 100.0
                    : (doneRequired * 100.0) / totalRequired;
            detail.put("score", Math.round(score * 100.0) / 100.0);
            detail.put("minScore", minScore);
            if (score < minScore) {
                return verdict(false, LessonCompletion.MIN_SCORE, detail);
            }
        }

        // All specified clauses held — pick the deciding reason for reporting.
        // A config object with NO active clause (`{}`, or only falsy/empty
        // values) is not an opt-out: it falls back to the default rule so a
        // lesson can never complete before its required work is done.
        if (!requireAll && requiredStageIds.isEmpty() && minScore == null) {
            boolean done = totalRequired == doneRequired;
            return verdict(done, LessonCompletion.DEFAULT_ALL_REQUIRED, detail);
        }
        String reason = requireAll ? LessonCompletion.ALL_REQUIRED_STAGES
                : !requiredStageIds.isEmpty() ? LessonCompletion.REQUIRED_STAGE_IDS
                : LessonCompletion.MIN_SCORE;
        return verdict(true, reason, detail);
    }

    /** Stage ids (of `filter`, or all required stages when null) with work left. */
    private List<String> missingRequiredStages(SnapshotModel model,
                                               AttemptState state, Set<String> filter) {
        List<String> missing = new java.util.ArrayList<>();
        for (JsonNode stage : model.stages()) {
            String sid = stage.path("id").asText();
            boolean requiredStage = stage.path("required").asBoolean(false);
            if (filter == null && !requiredStage) continue;
            if (filter != null && !filter.contains(sid)) continue;
            for (JsonNode a : model.requiredActivities(sid)) {
                if (!state.isCompleted(a.path("id").asText())) {
                    missing.add(sid);
                    break;
                }
            }
        }
        return missing;
    }

    private LessonCompletion verdict(boolean complete, String reason, ObjectNode detail) {
        return new LessonCompletion(complete,
                complete ? reason : LessonCompletion.NOT_COMPLETE, detail);
    }

    private ObjectNode detail(SnapshotModel model, AttemptState state,
                              int doneRequired, int totalRequired, ObjectNode base) {
        JsonNodeFactory f = JsonNodeFactory.instance;
        ObjectNode d = base == null ? f.objectNode() : base;
        d.put("completedRequired", doneRequired);
        d.put("totalRequired", totalRequired);
        return d;
    }

    private ArrayNode toArray(List<String> ids) {
        ArrayNode arr = JsonNodeFactory.instance.arrayNode();
        ids.forEach(arr::add);
        return arr;
    }
}

package com.dauviet.learning.resolver;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

import org.springframework.stereotype.Component;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.contract.NextActivity;
import com.dauviet.learning.contract.NextStage;
import com.dauviet.learning.domain.AttemptState;
import com.dauviet.learning.snapshot.SnapshotModel;
import com.fasterxml.jackson.databind.JsonNode;

/**
 * Decides the next executable pointer after a submission.
 * Order: (a) first incomplete required activity after the current one inside
 * the same stage; (b) REVISE hop when the last outcome maps through the
 * activity's onPartial/onContradicted field; (c) first nextStageIds target
 * still holding incomplete required activities (skipping required-free
 * stages recursively, cycle-guarded); (d) first stage in array order with
 * incomplete required activities — deterministic policy for convergent
 * non-linear graphs; (e) null — nothing left, completion evaluator decides.
 * Publish-time validation guarantees a DAG; the visited set here only
 * guards hand-edited snapshots.
 */
@Component
public class StageTransitionResolver {

    /** Result of a resolve step: exactly one of nextActivity/nextStage is set. */
    public record Transition(NextActivity nextActivity, NextStage nextStage) {
        static Transition of(NextActivity a) { return new Transition(a, null); }
        static Transition of(NextStage s) { return new Transition(null, s); }
    }

    /**
     * @param lastOutcome outcome of the just-evaluated submission (may be null)
     */
    public Transition resolve(SnapshotModel model, AttemptState state,
                              String lastActivityId, String lastOutcome) {
        String stageId = state.currentStageId();
        if (stageId == null || model.stageById(stageId) == null) {
            return null;
        }

        // (a) same-stage progression
        String nextInStage = nextIncompleteRequired(
                model.activitiesOf(stageId), state, lastActivityId);
        if (nextInStage != null) {
            return Transition.of(toNextActivity(model, stageId, nextInStage));
        }

        // (b) outcome-driven revision hop
        JsonNode activity = model.activityById(lastActivityId);
        if (activity != null) {
            String field = switch (lastOutcome == null ? "" : lastOutcome) {
                case ActivityResult.PARTIAL -> "onPartial";
                case ActivityResult.CONTRADICTED -> "onContradicted";
                default -> null;
            };
            if (field != null) {
                JsonNode target = activity.get(field);
                if (target != null && target.isTextual()
                        && model.stageById(target.asText()) != null) {
                    return Transition.of(new NextStage(
                            target.asText(), stageTypeOf(model, target.asText()),
                            NextStage.REVISE));
                }
            }
        }

        // (c) forward walk over nextStageIds
        Set<String> visited = new LinkedHashSet<>();
        String fwd = firstIncompleteStage(model, state,
                model.nextStageIds(stageId), visited);
        if (fwd != null) {
            return Transition.of(new NextStage(
                    fwd, stageTypeOf(model, fwd), NextStage.FORWARD));
        }

        // (d) convergent fallback: first stage in array order still incomplete
        for (JsonNode s : model.stages()) {
            String sid = s.path("id").asText();
            if (!stageComplete(model, state, sid)) {
                return Transition.of(new NextStage(
                        sid, stageTypeOf(model, sid), NextStage.FORWARD));
            }
        }
        return null;
    }

    /** First required activity after lastActivityId that is not completed. */
    private String nextIncompleteRequired(List<JsonNode> activities,
                                          AttemptState state, String lastActivityId) {
        boolean seen = lastActivityId == null;
        for (JsonNode a : activities) {
            String id = a.path("id").asText(null);
            if (id == null) continue;
            if (!seen) {
                seen = id.equals(lastActivityId);
                continue;
            }
            if (a.path("required").asBoolean(false) && !state.isCompleted(id)) {
                return id;
            }
        }
        return null;
    }

    /**
     * Breadth-preferring walk over nextStageIds: evaluate each target in
     * declared order; a target with unfinished required work wins immediately;
     * a target that is already complete (including required-free stages whose
     * own nextStageIds fan out) is traversed through recursively before the
     * next sibling is considered — matching the linear-reading intuition that
     * nearer stages are visited first.
     */
    private String firstIncompleteStage(SnapshotModel model, AttemptState state,
                                        List<String> ids, Set<String> visited) {
        for (String sid : ids) {
            if (model.stageById(sid) == null) continue;
            if (!visited.add(sid)) continue;   // re-encountered node — DAG-safe skip
            if (!stageComplete(model, state, sid)) {
                return sid;
            }
            if (model.requiredActivities(sid).isEmpty()) {
                // transparent stage: it gates nothing, so its own successors
                // are immediate candidates at this level
                String deeper = firstIncompleteStage(
                        model, state, model.nextStageIds(sid), visited);
                if (deeper != null) return deeper;
            }
        }
        return null;
    }

    /** A stage is complete when every required activity inside it is done. */
    private boolean stageComplete(SnapshotModel model, AttemptState state, String stageId) {
        List<JsonNode> required = model.requiredActivities(stageId);
        for (JsonNode a : required) {
            if (!state.isCompleted(a.path("id").asText())) return false;
        }
        return true;
    }

    private NextActivity toNextActivity(SnapshotModel model, String stageId, String activityId) {
        JsonNode a = model.activityById(activityId);
        String type = a != null ? a.path("type").asText(null) : null;
        return new NextActivity(stageId, activityId, type,
                a != null ? a.get("config") : null);
    }

    private String stageTypeOf(SnapshotModel model, String stageId) {
        JsonNode s = model.stageById(stageId);
        return s != null ? s.path("type").asText(null) : null;
    }
}

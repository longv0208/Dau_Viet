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
 * Order: (-1) REMEDIAL STAY — an exhausted required activity with remedial
 * budget left keeps the cursor (TASK-0020 round-3); (0) the just-submitted
 * activity is required and not completed -> REVISE hop when its outcome maps
 * through onPartial/onContradicted, else STAY so the learner can retry;
 * then, for completed or optional submissions: (a) first incomplete required
 * activity after the current one inside the same stage; (b) REVISE hop —
 * skipped when the activity's retry budget is already spent (exhausted:true),
 * so a bounded Verification hops back at most while it can still retry;
 * (c) first nextStageIds target still holding incomplete required activities
 * (skipping required-free stages recursively, cycle-guarded); (d) first
 * stage in array order with incomplete required activities — deterministic
 * policy for convergent non-linear graphs; (e) null — nothing left.
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

        JsonNode activity = model.activityById(lastActivityId);

        // (-1) Remedial routing: an activity that just exhausted its scored
        // retry budget but still carries remedial attempts — and was sent
        // back here by a downstream REVISE hop — keeps the cursor so the
        // learner can retry the remediation instead of the lesson looping
        // forever on a Verification PARTIAL it can never satisfy. Without
        // this the exhausted activity reported completed=true, the cursor
        // advanced, and Verification kept sending the learner back to
        // Hypothesis — a deterministic soft-lock (TASK-0020 round-3).
        if (activity != null
                && activity.path("required").asBoolean(false)
                && isRemedialRetry(model, state, lastActivityId)) {
            return Transition.of(toNextActivity(model, stageId, lastActivityId));
        }

        // (0) incomplete REQUIRED submission: retry, or revise when authored.
        // Without this the cursor advanced past failed required work and the
        // submit guard locked every later retry (soft-lock).
        boolean lastRequiredIncomplete = activity != null
                && activity.path("required").asBoolean(false)
                && !state.isCompleted(lastActivityId);
        if (lastRequiredIncomplete) {
            NextStage hop = reviseTarget(model, activity, lastOutcome);
            if (hop != null) {
                return Transition.of(hop);
            }
            return Transition.of(toNextActivity(model, stageId, lastActivityId));
        }

        // (a) same-stage progression
        String nextInStage = nextIncompleteRequired(
                model.activitiesOf(stageId), state, lastActivityId);
        if (nextInStage != null) {
            return Transition.of(toNextActivity(model, stageId, nextInStage));
        }

        // (b) outcome-driven revision hop — but NOT when the just-submitted
        // activity exhausted its retry budget: an exhausted VERIFICATION that
        // still hops back to an exhausted EVIDENCE_SELECT recreates the exact
        // infinite loop the remedial bound was added to break. Once the
        // budget is spent the learner must move forward and finish, not be
        // sent back to redo work that can no longer change the verdict.
        boolean budgetSpent = activity != null
                && state.outputs().get(lastActivityId) != null
                && state.outputs().get(lastActivityId)
                        .path("exhausted").asBoolean(false);
        if (activity != null && !budgetSpent) {
            NextStage hop = reviseTarget(model, activity, lastOutcome);
            if (hop != null) {
                return Transition.of(hop);
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

    /**
     * The cursor activity is an exhausted graded activity that still has
     * remedial attempts left AND was routed back by a downstream REVISE hop
     * (its persisted output already carries exhausted:true — it completed
     * for progress once, then the learner returned). The handler keeps
     * completed=false on a remedial miss, so the resolver must hold the
     * cursor for the next remediation try instead of advancing past it.
     */
    private boolean isRemedialRetry(SnapshotModel model, AttemptState state,
                                    String activityId) {
        JsonNode act = model.activityById(activityId);
        JsonNode config = act == null ? null : act.get("config");
        if (config == null) return false;
        int remedialAttempts = config.path("remedialAttempts").asInt(0);
        if (remedialAttempts <= 0) return false;
        JsonNode out = state.outputs().get(activityId);
        if (out == null || !out.path("exhausted").asBoolean(false)) return false;
        int maxAttempts = Math.max(config.path("maxAttempts").asInt(1), 1);
        // Retry budget comes from the ledger (survives output invalidation);
        // the output's own attemptCount is the legacy fallback.
        int attemptCount = state.attemptCounts().containsKey(activityId)
                ? state.attemptCounts().get(activityId)
                : out.path("attemptCount").asInt(0);
        return attemptCount < maxAttempts + remedialAttempts;
    }

    /**
     * REVISE hop target for the activity's onPartial/onContradicted field, or
     * null when the outcome maps to no field or the target stage is missing.
     */
    private NextStage reviseTarget(SnapshotModel model, JsonNode activity,
                                   String lastOutcome) {
        String field = switch (lastOutcome == null ? "" : lastOutcome) {
            case ActivityResult.PARTIAL -> "onPartial";
            case ActivityResult.CONTRADICTED -> "onContradicted";
            default -> null;
        };
        if (field == null) return null;
        JsonNode target = activity.get(field);
        if (target != null && target.isTextual()
                && model.stageById(target.asText()) != null) {
            return new NextStage(target.asText(),
                    stageTypeOf(model, target.asText()), NextStage.REVISE);
        }
        return null;
    }

    /**
     * First required activity after lastActivityId that is not completed;
     * wraps around to the start of the stage when earlier required activities
     * (e.g. non-linear clues in DISCOVERY) are still incomplete.
     */
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
        if (lastActivityId != null) {
            for (JsonNode a : activities) {
                String id = a.path("id").asText(null);
                if (id == null) continue;
                if (id.equals(lastActivityId)) break;
                if (a.path("required").asBoolean(false) && !state.isCompleted(id)) {
                    return id;
                }
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

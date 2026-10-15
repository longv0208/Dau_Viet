package com.dauviet.lesson.draft;

import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * Canonical draft_json v1 contract constants.
 * Single source for schema version, ID shape, stage→activity allow-list,
 * and the server-only field names that must never reach learner payloads.
 */
public final class DraftSchema {

    /** Current draft schema version. Bump when the JSON shape changes. */
    public static final int CURRENT_VERSION = 1;

    /** Stable stage/activity ids: slug-like, template-friendly. */
    public static final Pattern ID_PATTERN = Pattern.compile("[a-z0-9][a-z0-9-]{1,63}");

    /** Top-level field names allowed in draft_json. Unknown keys are SAVE errors. */
    public static final Set<String> TOP_LEVEL_KEYS =
            Set.of("schemaVersion", "stages", "completion", "objectives");

    /** Allowed stage field names. */
    public static final Set<String> STAGE_KEYS =
            Set.of("id", "type", "title", "required", "activities",
                    "nextStageIds", "requiredEvidenceIds");

    /** Allowed activity field names. */
    public static final Set<String> ACTIVITY_KEYS =
            Set.of("id", "type", "required", "instruction", "config",
                    "validation", "feedback", "evidenceRefs");

    /** Allowed completion field names. */
    public static final Set<String> COMPLETION_KEYS =
            Set.of("requireAllRequiredStages", "requiredStageIds", "minScore");

    /**
     * Stage → allowed activity types per LEARNING_ENGINE_DESIGN §2.
     * READ is a universal supporting activity allowed in every stage.
     */
    public static final Map<StageType, Set<ActivityType>> STAGE_ALLOWED_ACTIVITIES = Map.of(
            StageType.CONTEXT, Set.of(ActivityType.READ, ActivityType.VIEW_IMAGE),
            StageType.DISCOVERY, Set.of(ActivityType.EXPLORE_MAP, ActivityType.VIEW_IMAGE, ActivityType.READ),
            StageType.EVIDENCE, Set.of(ActivityType.EVIDENCE_SELECT, ActivityType.MULTIPLE_CHOICE, ActivityType.READ),
            StageType.REASONING, Set.of(ActivityType.MATCHING, ActivityType.REASONING_CONNECT,
                    ActivityType.MULTIPLE_CHOICE, ActivityType.READ),
            StageType.HYPOTHESIS, Set.of(ActivityType.HYPOTHESIS_CHOICE, ActivityType.READ),
            StageType.RECONSTRUCTION, Set.of(ActivityType.DRAG_ORDER, ActivityType.READ),
            StageType.VERIFICATION, Set.of(ActivityType.VERIFICATION, ActivityType.MULTIPLE_CHOICE,
                    ActivityType.READ),
            StageType.CONCLUSION, Set.of(ActivityType.CER, ActivityType.READ),
            StageType.REFLECTION, Set.of(ActivityType.REFLECTION_PROMPT, ActivityType.READ));

    /**
     * Server-only config keys — answer keys and hidden validation data.
     * Never emitted to learners (TASK-0010 publish/snapshot strips them).
     * Listed by leaf field name; matching is by simple name inside config/validation.
     */
    public static final Set<String> LEARNER_HIDDEN_KEYS = Set.of(
            "correctOptionIds", "correctPairs", "correctOrder", "expectedOrder",
            "requiredEvidenceIds", "expectedHypothesis", "answerKey",
            "answer", "key", "expected");

    private DraftSchema() {
    }
}

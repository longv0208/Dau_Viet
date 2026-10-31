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
            Set.of("schemaVersion", "stages", "completion", "objectives",
                    "flowModel", "keyTakeaways");

    /** Allowed stage field names. */
    public static final Set<String> STAGE_KEYS =
            Set.of("id", "type", "title", "description", "required", "activities",
                    "nextStageIds", "requiredEvidenceIds", "allowFreeOrder");

    /** Allowed activity field names. */
    public static final Set<String> ACTIVITY_KEYS =
            Set.of("id", "type", "required", "instruction", "config",
                    "validation", "feedback", "evidenceRefs",
                    // 4-step learning flow clue metadata
                    "clueType", "title", "description", "coverAssetId",
                    // optional revise-hop stage targets consumed by
                    // StageTransitionResolver (outcome-driven routing)
                    "onPartial", "onContradicted");

    /** Allowed completion field names. */
    public static final Set<String> COMPLETION_KEYS =
            Set.of("requireAllRequiredStages", "requiredStageIds", "minScore");

    /**
     * Stage → allowed activity types.
     * In the 4-step flow (DISCOVERY -> HYPOTHESIS -> VERIFICATION -> RECONSTRUCTION),
     * each clue in DISCOVERY and the synthesis activity in RECONSTRUCTION can use
     * any compatible activity type selected by Admin.
     */
    public static final Map<StageType, Set<ActivityType>> STAGE_ALLOWED_ACTIVITIES = Map.of(
            StageType.CONTEXT, Set.of(ActivityType.READ, ActivityType.VIEW_IMAGE),
            StageType.DISCOVERY, Set.of(
                    ActivityType.READ,
                    ActivityType.VIEW_IMAGE,
                    ActivityType.MULTIPLE_CHOICE,
                    ActivityType.MATCHING,
                    ActivityType.DRAG_ORDER,
                    ActivityType.REASONING_CONNECT,
                    ActivityType.EXPLORE_MAP,
                    ActivityType.EVIDENCE_SELECT),
            StageType.EVIDENCE, Set.of(ActivityType.EVIDENCE_SELECT, ActivityType.MULTIPLE_CHOICE,
                    ActivityType.VIEW_IMAGE, ActivityType.READ),
            StageType.REASONING, Set.of(ActivityType.MATCHING, ActivityType.REASONING_CONNECT,
                    ActivityType.MULTIPLE_CHOICE, ActivityType.READ),
            StageType.HYPOTHESIS, Set.of(
                    ActivityType.HYPOTHESIS_CHOICE,
                    ActivityType.MULTIPLE_CHOICE,
                    ActivityType.MATCHING,
                    ActivityType.REASONING_CONNECT,
                    ActivityType.READ),
            StageType.RECONSTRUCTION, Set.of(
                    ActivityType.DRAG_ORDER,
                    ActivityType.MATCHING,
                    ActivityType.REASONING_CONNECT,
                    ActivityType.MULTIPLE_CHOICE,
                    ActivityType.VIEW_IMAGE,
                    ActivityType.READ,
                    ActivityType.CER_CHOICE,
                    ActivityType.CER,
                    ActivityType.REFLECTION_PROMPT),
            StageType.VERIFICATION, Set.of(
                    ActivityType.VERIFICATION,
                    ActivityType.EVIDENCE_SELECT,
                    ActivityType.MULTIPLE_CHOICE,
                    ActivityType.READ),
            StageType.CONCLUSION, Set.of(ActivityType.CER, ActivityType.CER_CHOICE, ActivityType.READ),
            StageType.REFLECTION, Set.of(ActivityType.REFLECTION_PROMPT, ActivityType.READ));

    /**
     * Server-only config keys — answer keys and hidden validation data.
     * Never emitted to learners (TASK-0010 publish/snapshot strips them).
     * Listed by leaf field name; matching is by simple name inside config/validation.
     */
    public static final Set<String> LEARNER_HIDDEN_KEYS = Set.of(
            "correctOptionIds", "multiCorrect", "correctPairs", "correctOrder",
            "expectedOrder", "acceptedSequences", "requiredEvidenceIds",
            "expectedHypothesis", "answerKey", "answer", "key", "expected",
            "acceptedClaims", "acceptedEvidenceIds", "acceptedReasoningIds",
            "expectedRelations", "acceptedRelationSets", "acceptedOptions",
            // TASK-0020: CER_CHOICE coherent accepted combinations are the
            // same answer-key material as the legacy flat arrays.
            "acceptedCombos");

    private DraftSchema() {
    }
}

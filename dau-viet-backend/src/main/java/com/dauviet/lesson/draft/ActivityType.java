package com.dauviet.lesson.draft;

/**
 * Activity types required by the MVP per LEARNING_ENGINE_DESIGN.md §5-6.
 * Registry pattern: one ActivityConfigValidator bean per type; adding a
 * type means adding the enum constant plus its validator bean.
 */
public enum ActivityType {
    READ,
    VIEW_IMAGE,
    MULTIPLE_CHOICE,
    EXPLORE_MAP,
    EVIDENCE_SELECT,
    MATCHING,
    REASONING_CONNECT,
    HYPOTHESIS_CHOICE,
    DRAG_ORDER,
    VERIFICATION,
    CER,
    CER_CHOICE,
    REFLECTION_PROMPT
}

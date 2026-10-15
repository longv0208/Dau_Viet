package com.dauviet.lesson.draft;

/**
 * Master stage types per LEARNING_ENGINE_DESIGN.md §2.
 * The framework layer is the thinking step, not a Flutter screen —
 * a template may pick/reorder stages within guardrails; CONCLUSION
 * (or an approved equivalent) is required before lesson completion.
 */
public enum StageType {
    CONTEXT,
    DISCOVERY,
    EVIDENCE,
    REASONING,
    HYPOTHESIS,
    RECONSTRUCTION,
    VERIFICATION,
    CONCLUSION,
    REFLECTION
}

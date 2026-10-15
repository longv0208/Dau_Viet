package com.dauviet.lesson.draft;

/**
 * Draft validation strictness.
 * SAVE tolerates incomplete drafts (missing config/instruction allowed);
 * PUBLISH enforces all LEARNING_ENGINE_DESIGN §9 guardrails.
 */
public enum ValidationLevel {
    SAVE,
    PUBLISH
}

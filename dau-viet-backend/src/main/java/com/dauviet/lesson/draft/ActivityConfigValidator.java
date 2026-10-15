package com.dauviet.lesson.draft;

import java.util.List;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * Type-aware config validation. One Spring bean per ActivityType;
 * DraftValidator builds a registry keyed by supports() at startup.
 * Mirrors the TASK-0010 ActivityHandler registry so names align.
 */
public interface ActivityConfigValidator {

    ActivityType supports();

    /**
     * Validate a single activity's fields.
     * @param activity the activity JsonNode (has id/type/config/...)
     * @param path     JSONPath-ish prefix for FieldError paths, e.g. "stages[1].activities[0]"
     * @param ctx      lookups + strictness level
     * @param errors   collector — append, never throw for content issues
     */
    void validate(JsonNode activity, String path, ValidationContext ctx, List<FieldError> errors);
}

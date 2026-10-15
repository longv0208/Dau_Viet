package com.dauviet.lesson.application;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import com.dauviet.lesson.domain.DraftSchemaInvalidException;

/**
 * Minimal MVP validation for `lessons.draft_json` / `objectives_json`.
 * Draft must be a JSON object; objectives a JSON array. Full schema_version
 * validation lands with the publish workflow (TASK-0009).
 */
public final class DraftValidator {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private DraftValidator() {
    }

    /** Returns the canonical JSON string; throws on malformed/non-object. */
    public static String requireJsonObject(String json, String fieldName) {
        if (json == null) return null;
        try {
            JsonNode node = MAPPER.readTree(json);
            if (node == null || !node.isObject()) {
                throw new DraftSchemaInvalidException(fieldName + " must be a JSON object");
            }
            return MAPPER.writeValueAsString(node);
        } catch (DraftSchemaInvalidException e) {
            throw e;
        } catch (Exception e) {
            throw new DraftSchemaInvalidException(fieldName + " is not valid JSON: " + e.getMessage());
        }
    }

    /** Returns the canonical JSON string; throws on malformed/non-array. */
    public static String requireJsonArray(String json, String fieldName) {
        if (json == null) return null;
        try {
            JsonNode node = MAPPER.readTree(json);
            if (node == null || !node.isArray()) {
                throw new DraftSchemaInvalidException(fieldName + " must be a JSON array");
            }
            return MAPPER.writeValueAsString(node);
        } catch (DraftSchemaInvalidException e) {
            throw e;
        } catch (Exception e) {
            throw new DraftSchemaInvalidException(fieldName + " is not valid JSON: " + e.getMessage());
        }
    }
}

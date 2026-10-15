package com.dauviet.lesson.draft;

/**
 * One field-level validation finding for the admin CMS.
 * path uses JSONPath-ish notation, e.g. "stages[2].activities[1].id".
 * code is a stable machine-readable identifier; message is human-readable.
 */
public record FieldError(String path, String code, String message) {
}

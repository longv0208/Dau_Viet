package com.dauviet.learning.api.dto;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * Response of GET /attempts/{id}/current — learner-safe view of the activity
 * the cursor points at. `config`/`feedback` already projected (hidden keys
 * stripped) by LearnerProjectionService; null activity when the attempt has
 * no pending activity.
 */
public record CurrentActivityResponse(
        Stage stage,
        Activity activity,
        AttemptProgressResponse.Progress progress) {

    public record Stage(String id, String type, String title) {
    }

    public record Activity(String id, String type, String instruction,
                           JsonNode config, JsonNode feedback) {
    }
}

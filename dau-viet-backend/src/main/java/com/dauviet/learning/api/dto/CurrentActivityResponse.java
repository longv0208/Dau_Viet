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
                           JsonNode config, JsonNode feedback,
                           // GAME-03 additive: activity này có chấm điểm
                           // (có thể trừ Thể lực) — client hiển thị hint chi
                           // phí trước khi submit. false/null trên server cũ.
                           boolean graded,
                           // Số Thể lực trừ khi verdict INCORRECT (clamp ở số
                           // dư). Chỉ có nghĩa khi graded=true.
                           Integer incorrectPenalty) {
    }
}

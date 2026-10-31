package com.dauviet.learning.api.dto;

import java.util.List;

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
        AttemptProgressResponse.Progress progress,
        StepProgress stepProgress) {

    public CurrentActivityResponse(
            Stage stage,
            Activity activity,
            AttemptProgressResponse.Progress progress) {
        this(stage, activity, progress, null);
    }

    public record Stage(String id, String type, String title, String description) {
        public Stage(String id, String type, String title) {
            this(id, type, title, null);
        }
    }

    public record Activity(String id, String type, String instruction,
                           JsonNode config, JsonNode feedback,
                           // GAME-03 additive: activity này có chấm điểm
                           // (có thể trừ Thể lực) — client hiển thị hint chi
                           // phí trước khi submit. false/null trên server cũ.
                           boolean graded,
                           // Số Thể lực trừ khi verdict INCORRECT (clamp ở số
                           // dư). Chỉ có nghĩa khi graded=true.
                           Integer incorrectPenalty,
                           String clueType,
                           String title,
                           String description,
                           String coverAssetId,
                           boolean completed) {
        public Activity(String id, String type, String instruction,
                        JsonNode config, JsonNode feedback,
                        boolean graded, Integer incorrectPenalty) {
            this(id, type, instruction, config, feedback, graded, incorrectPenalty,
                    null, null, null, null, false);
        }
    }

    public record ClueStatus(
            String activityId,
            String clueType,
            String title,
            String description,
            String coverAssetId,
            String activityType,
            String status,
            boolean completed) {
    }

    public record StepProgress(
            int discoveryCompleted,
            int discoveryTotal,
            boolean hypothesisCompleted,
            boolean verificationCompleted,
            boolean reconstructionCompleted,
            int currentStepNumber,
            List<ClueStatus> clues) {
    }
}

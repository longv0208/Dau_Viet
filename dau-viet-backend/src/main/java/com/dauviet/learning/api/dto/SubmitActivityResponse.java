package com.dauviet.learning.api.dto;

import com.dauviet.learning.contract.ActivityResult;
import com.dauviet.learning.contract.LessonCompletion;
import com.fasterxml.jackson.databind.JsonNode;

/** Response of POST .../submissions — evaluation + next cursor + completion. */
public record SubmitActivityResponse(
        String status,
        ActivityResult evaluation,
        boolean activityCompleted,
        AttemptProgressResponse.Progress progress,
        Next next,
        LessonCompletion completion,
        // GAME-02 additive: số Thể lực vừa bị trừ cho submission này (0 nếu
        // không phạt/không graded/flag tắt) — client đồng bộ pill mà không
        // cần gọi lại /me/energy. Idempotent replay trả đúng giá trị đã lưu.
        int energyDeducted) {

    public record Next(String stageId, String activityId, String activityType,
                       JsonNode learnerConfig) {
    }
}

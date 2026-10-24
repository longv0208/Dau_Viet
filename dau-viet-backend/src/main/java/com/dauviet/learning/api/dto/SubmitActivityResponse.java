package com.dauviet.learning.api.dto;

import com.dauviet.energy.api.dto.EnergyStateResponse;
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
        // không phạt/không graded/flag tắt). Idempotent replay trả đúng giá
        // trị đã lưu.
        int energyDeducted,
        // FIX 7 additive: trạng thái energy SAU submission (đã gồm lazy
        // recovery vừa chạy trong tx) — client không suy balance từ
        // energyDeducted vì server có thể đã tự hồi trước khi chấm. Replay
        // trả snapshot đã lưu cùng response. Null khi flag tắt? Không —
        // luôn trả state thực để client đồng bộ UI kể cả chế độ theo dõi.
        EnergyStateResponse energy) {

    public record Next(String stageId, String activityId, String activityType,
                       JsonNode learnerConfig) {
    }
}

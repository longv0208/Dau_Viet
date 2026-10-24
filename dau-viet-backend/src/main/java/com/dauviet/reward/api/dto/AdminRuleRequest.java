package com.dauviet.reward.api.dto;

import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;

import jakarta.validation.constraints.Size;

/**
 * Gán unlock rule cho item (GAME-05). Hai dạng additive:
 *  - v1: ruleType (LESSON_COMPLETED | COLLECTION_COUNT | LESSON_COUNT) +
 *    lessonId/threshold — giữ nguyên tương thích;
 *  - v2: `condition` là AST {leaf | {all:[…]} | {any:[…]}} — khi có
 *    `condition`, ruleType chỉ là nhãn phân loại lưu kèm (mặc định
 *    'RULE_V2' khi client không gửi); `condition` được parse + validate
 *    nghiêm, lỗi trả 400 không bao giờ 500.
 */
public record AdminRuleRequest(
        @Size(max = 48) String ruleType,
        UUID lessonId,
        Integer threshold,
        Boolean active,
        JsonNode condition
) {
}

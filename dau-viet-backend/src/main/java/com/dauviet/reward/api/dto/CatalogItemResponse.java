package com.dauviet.reward.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * Một mục catalog phía learner: metadata + trạng thái sở hữu + điều kiện
 * mở khóa kèm tiến độ hiện tại — đủ để client render owned/locked mà
 * không phải gọi thêm endpoint.
 */
public record CatalogItemResponse(
        UUID itemId,
        String code,
        String name,
        String description,
        String category,
        String itemType,
        String rarity,
        UUID assetId,
        String renderKey,
        boolean placeable,
        UUID placedSlotId,
        JsonNode sourceMetadata,
        boolean owned,
        Instant acquiredAt,
        Requirement requirement
) {
    /**
     * Điều kiện mở khóa + tiến độ (GAME-05). Hai dạng:
     *  - leaf: type ∈ các LeafType; current/required là số đã đạt/ngưỡng;
     *  - operator: operator = ALL|ANY kèm children[] leaf — client render
     *    từng dòng điều kiện ("Hoàn thành tất cả / một trong các…") thay
     *    vì một progress bar tổng hợp gây hiểu nhầm.
     * status: SATISFIED | PENDING | UNSUPPORTED (UNSUPPORTED cho leaf chưa
     * đánh giá được — LEVEL_AT_LEAST chờ GAME-07 — không bao giờ đạt).
     * `satisfied` ở root = rule đã đạt toàn bộ.
     */
    public record Requirement(
            String operator,
            String type,
            UUID eventId,
            UUID lessonId,
            String lessonTitle,
            List<UUID> evidenceIds,
            Integer threshold,
            Long current,
            Long required,
            boolean satisfied,
            String status,
            String description,
            List<Requirement> conditions
    ) {
    }
}

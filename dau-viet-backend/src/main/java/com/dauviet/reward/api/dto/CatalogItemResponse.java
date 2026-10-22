package com.dauviet.reward.api.dto;

import java.time.Instant;
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
        JsonNode sourceMetadata,
        boolean owned,
        Instant acquiredAt,
        Requirement requirement
) {
    /**
     * Điều kiện mở khóa + tiến độ: type ∈ LESSON_COMPLETED /
     * COLLECTION_COUNT / LESSON_COUNT; current là số đã đạt (evidence đã
     * sưu tầm / bài đã hoàn thành); null nghĩa là chưa áp dụng.
     */
    public record Requirement(
            String type,
            UUID lessonId,
            String lessonTitle,
            Integer threshold,
            Long current
    ) {
    }
}

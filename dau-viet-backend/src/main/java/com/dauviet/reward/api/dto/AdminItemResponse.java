package com.dauviet.reward.api.dto;

import java.time.Instant;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;

/** Item catalog phía admin — gồm cả inactive + rule hiện tại. */
public record AdminItemResponse(
        UUID id,
        String code,
        String name,
        String description,
        String category,
        String itemType,
        String rarity,
        UUID assetId,
        JsonNode sourceMetadata,
        boolean active,
        Long rowVersion,
        Rule rule
) {
    /** Unlock rule đang gắn item (null = chưa cấu hình). */
    public record Rule(
            UUID id,
            String ruleType,
            UUID lessonId,
            Integer threshold,
            boolean active
    ) {
    }
}

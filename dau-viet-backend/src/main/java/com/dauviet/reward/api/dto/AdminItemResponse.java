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
        boolean placeable,
        String renderKey,
        Long rowVersion,
        /** Scope da duyet cua item (GAME-06): UNRESOLVED | EVENT_SCOPED | GLOBAL. */
        String scope,
        Rule rule
) {
    /**
     * Unlock rule đang gắn item (null = chưa cấu hình). GAME-05: thêm
     * ruleVersion + conditionJson (AST gốc) + ruleMetadata để admin đọc
     * lại đúng cấu hình đã publish — additive.
     */
    public record Rule(
            UUID id,
            String ruleType,
            UUID lessonId,
            Integer threshold,
            boolean active,
            Integer ruleVersion,
            JsonNode conditionJson,
            JsonNode ruleMetadata
    ) {
    }
}

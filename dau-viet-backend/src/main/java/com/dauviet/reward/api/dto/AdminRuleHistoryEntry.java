package com.dauviet.reward.api.dto;

import java.time.Instant;
import java.util.UUID;

import com.fasterxml.jackson.databind.JsonNode;

/**
 * Mot revision trong lich su rule cua item (GAME-06). `ruleVersion` la
 * schema payload (1=V1 cot phang, 2=AST); `revision` la thu tu publish
 * per-item (monotonic, FINAL FIX-3). `grantCount` = so user_inventory row
 * provenance tro ve rule nay (unlock_rule_id).
 */
public record AdminRuleHistoryEntry(
        UUID id,
        String ruleType,
        UUID lessonId,
        Integer threshold,
        int ruleVersion,
        int revision,
        boolean active,
        JsonNode conditionJson,
        JsonNode ruleMetadata,
        Instant createdAt,
        long grantCount
) {
}

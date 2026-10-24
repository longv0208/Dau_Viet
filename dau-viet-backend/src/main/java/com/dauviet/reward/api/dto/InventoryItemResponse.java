package com.dauviet.reward.api.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * Một vật phẩm learner đã sở hữu (GAME-05: thêm provenance truy vết —
 * rule + version đã cấp, event nguồn — cho audit "vì sao user có item",
 * additive nên client cũ không vỡ).
 */
public record InventoryItemResponse(
        UUID itemId,
        String code,
        String name,
        String description,
        String category,
        String itemType,
        String rarity,
        UUID assetId,
        Instant acquiredAt,
        String acquisitionSource,
        UUID sourceLessonId,
        UUID unlockRuleId,
        Integer unlockRuleVersion,
        UUID sourceEventId
) {
}

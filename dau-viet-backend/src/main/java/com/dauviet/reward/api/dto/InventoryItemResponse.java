package com.dauviet.reward.api.dto;

import java.time.Instant;
import java.util.UUID;

/** Một vật phẩm learner đã sở hữu. */
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
        UUID sourceLessonId
) {
}

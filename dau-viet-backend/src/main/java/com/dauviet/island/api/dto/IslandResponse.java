package com.dauviet.island.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * GET /api/v1/me/island — trạng thái đảo + slot map đầy đủ để client render.
 *
 * <p>ISLAND-01: thêm currentExp, currentLevel, nextTierRequiredLevel,
 * nextTierRequiredExp — eligibility dựa theo Level tài khoản.
 *
 * <p>ISLAND-02: thêm maxTier suy ra từ active island policies để Flutter
 * không cần hard-code Tier 3 là max. eventsCompleted và nextTierRequiredEvents
 * giữ lại chỉ vì tương thích — KHÔNG dùng để xét eligibility nâng cấp.
 *
 * <p>Khi đảo đã đạt tier tối đa (tier == maxTier):
 * nextTier=null, nextTierRequiredLevel=null, nextTierRequiredExp=null,
 * nextTierSlotCount=0, canUpgrade=false.
 */
public record IslandResponse(
        int tier,
        int maxTier,
        long rowVersion,
        long eventsCompleted,
        Integer nextTier,
        int nextTierRequiredEvents,
        int nextTierSlotCount,
        boolean canUpgrade,
        Instant upgradedAt,
        List<SlotView> slots,
        Instant serverTime,
        long currentExp,
        int currentLevel,
        Integer nextTierRequiredLevel,
        Long nextTierRequiredExp
) {
    /** Một ô đất: locked/unlocked + item đang đặt (null = trống). */
    public record SlotView(
            UUID slotId,
            int slotIndex,
            int tierRequired,
            boolean unlocked,
            double coordX,
            double coordY,
            UUID placedItemId,
            String placedItemCode,
            String placedRenderKey,
            Instant placedAt
    ) {
    }
}

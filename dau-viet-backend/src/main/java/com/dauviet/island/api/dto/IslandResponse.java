package com.dauviet.island.api.dto;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * GET /api/v1/me/island — trạng thái đảo + slot map đầy đủ để client render.
 *
 * <p>Mở rộng ISLAND-01: thêm level/EXP để client hiển thị tiến trình nâng
 * cấp. Tương thích ngược — eventsCompleted và nextTierRequiredEvents giữ
 * nguyên nhưng KHÔNG dùng để xét eligibility nữa; chỉ mang ý nghĩa thống kê.
 *
 * <p>Khi đảo đã đạt tier tối đa: nextTier=null, nextTierRequiredLevel=null,
 * nextTierRequiredExp=null, nextTierSlotCount=0, canUpgrade=false.
 *
 * <p>Fields (ISLAND-01):
 * <ul>
 *   <li>currentExp — EXP tích lũy hiện tại (không tiêu hao).</li>
 *   <li>currentLevel — Level tài khoản tính từ EXP.</li>
 *   <li>nextTierRequiredLevel — Level yêu cầu để nâng nextTier; null nếu đã max.</li>
 *   <li>nextTierRequiredExp — EXP tối thiểu tương ứng; null nếu đã max.</li>
 * </ul>
 */
public record IslandResponse(
        int tier,
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

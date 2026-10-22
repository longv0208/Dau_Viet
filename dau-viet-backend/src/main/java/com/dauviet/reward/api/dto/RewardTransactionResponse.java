package com.dauviet.reward.api.dto;

import java.time.Instant;
import java.util.UUID;

/** Một bút toán thưởng trong lịch sử của learner. */
public record RewardTransactionResponse(
        UUID id,
        String rewardType,
        long amount,
        String reason,
        UUID lessonId,
        Instant createdAt
) {
}

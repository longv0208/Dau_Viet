package com.dauviet.wallet.api.dto;

import java.time.Instant;
import java.util.UUID;

/**
 * Một bút toán Điểm Sử Ký trong ledger (V32).
 */
public record WalletTransactionResponse(
        UUID id,
        String direction,
        long amount,
        String reason,
        String causeKey,
        String sourceRef,
        long balanceAfter,
        Instant createdAt
) {
}

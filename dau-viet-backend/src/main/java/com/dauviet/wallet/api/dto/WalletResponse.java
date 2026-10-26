package com.dauviet.wallet.api.dto;

import java.time.Instant;
import java.util.List;

/**
 * GET /api/v1/me/wallet — số dư + tổng vào/ra + 20 giao dịch gần nhất.
 * earned/spent đọc từ ledger (SUM CREDIT/DEBIT); balance ≡ earned − spent
 * theo contract §2.3 (POINT-08 audit).
 */
public record WalletResponse(
        String currency,
        long balance,
        long pointsEarned,
        long pointsSpent,
        List<WalletTransactionResponse> recentTransactions,
        Instant serverTime
) {
}
